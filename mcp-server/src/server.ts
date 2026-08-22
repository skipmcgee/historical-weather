import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

import { aggregateDailyArchive, hasAnyData } from "./aggregator.js";
import type { ArchiveCache } from "./cache.js";
import { searchAllLocations } from "./locationSearch.js";
import { fetchDailyArchive, OpenMeteoError } from "./openMeteoClient.js";
import { weatherSummaryToJson } from "./summaryJson.js";
import type { Location } from "./types.js";

/** Open-Meteo's archive (ERA5 reanalysis) goes back to 1940; that's the
 * practical floor. Mirrors earliestSupportedDate in
 * lib/widgets/date_range_picker.dart. */
const EARLIEST_SUPPORTED_DATE = "1940-01-01";

/** Past this span, warn rather than block -- mirrors _longRangeWarningDays
 * in lib/widgets/date_range_picker.dart. There's no UI to show a heads-up
 * in here, so it's surfaced as a non-fatal `warning` field instead. */
const LONG_RANGE_WARNING_DAYS = 20 * 365;

const DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

/** DATE_REGEX only checks the shape; this additionally rejects
 * syntactically-valid-looking but non-existent calendar dates (e.g.
 * 2020-02-30, 2020-13-01), which `Date.parse` would otherwise silently
 * normalize (or return NaN for) rather than reject. */
function isValidCalendarDate(iso: string): boolean {
  const [y, m, d] = iso.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
}

function todayIso(): string {
  return new Date().toISOString().slice(0, 10);
}

function daysBetween(startIso: string, endIso: string): number {
  const start = Date.parse(startIso);
  const end = Date.parse(endIso);
  return Math.round((end - start) / (1000 * 60 * 60 * 24));
}

function textResult(text: string, isError = false) {
  return { content: [{ type: "text" as const, text }], isError };
}

/** Shared error formatting for both tools' catch blocks -- OpenMeteoError
 * messages are already user-facing and safe to return verbatim; anything
 * else (a genuine bug) gets an "Unexpected error" prefix so it's never
 * mistaken for an intentional, actionable message. */
function formatError(err: unknown): string {
  if (err instanceof OpenMeteoError) return err.message;
  return `Unexpected error: ${err instanceof Error ? err.message : String(err)}`;
}

/**
 * Builds a fresh McpServer with both tools registered against the given
 * cache. Split out from index.ts so the HTTP transport (server.ts's caller
 * for Render) can create one McpServer per request -- required for
 * request-level isolation in stateless HTTP mode -- while still sharing a
 * single long-lived ArchiveCache across all of them (a fresh cache per
 * request would defeat the point of caching for the HTTP deployment). The
 * stdio entrypoint (index.ts, used by local Claude Code/Desktop) just
 * calls this once.
 */
export function createMcpServer(archiveCache: ArchiveCache): McpServer {
  const server = new McpServer({
    name: "historical-weather",
    version: "0.1.0",
  });

  server.registerTool(
    "search_locations",
    {
      title: "Search locations",
      description:
        "Search for places matching a free-text query -- a city/place name (via Open-Meteo's " +
        "geocoding database) or a specific street address or point of interest (via OpenStreetMap's " +
        "Nominatim). Returns candidate matches with coordinates, so an ambiguous name can be " +
        "disambiguated before calling get_historical_weather.",
      inputSchema: {
        query: z
          .string()
          .min(1)
          .describe('Place name or address to search for, e.g. "Austin, TX" or "1600 Pennsylvania Ave NW"'),
      },
    },
    async ({ query }) => {
      try {
        const results = await searchAllLocations(query, process.env.OPEN_METEO_API_KEY);
        return textResult(JSON.stringify(results, null, 2));
      } catch (err) {
        return textResult(formatError(err), true);
      }
    },
  );

  server.registerTool(
    "get_historical_weather",
    {
      title: "Get historical weather",
      description:
        "Look up historical weather for a location and date range via Open-Meteo's archive, " +
        "aggregated into a single summary (median or average per metric) with a unit system " +
        "applied. Provide either `location` (a place name or street address, resolved " +
        "automatically via geocoding) or explicit `latitude`/`longitude`. Only data from " +
        "1940-01-01 onward is supported.",
      inputSchema: {
        location: z
          .string()
          .optional()
          .describe(
            'Free-text place name or street address, e.g. "Austin, TX" or "1600 Pennsylvania Ave NW" ' +
              "-- resolved via geocoding to the best match. Omit if latitude/longitude are given.",
          ),
        latitude: z.number().min(-90).max(90).optional(),
        longitude: z.number().min(-180).max(180).optional(),
        start_date: z
          .string()
          .regex(DATE_REGEX, "must be YYYY-MM-DD")
          .refine(isValidCalendarDate, "must be a real calendar date"),
        end_date: z
          .string()
          .regex(DATE_REGEX, "must be YYYY-MM-DD")
          .refine(isValidCalendarDate, "must be a real calendar date"),
        method: z.enum(["median", "average"]).default("median"),
        units: z.enum(["metric", "imperial"]).default("imperial"),
      },
    },
    async ({ location: locationQuery, latitude, longitude, start_date, end_date, method, units }) => {
      try {
        const apiKey = process.env.OPEN_METEO_API_KEY;

        if ((latitude == null) !== (longitude == null)) {
          return textResult("Provide both `latitude` and `longitude` together, not just one.", true);
        }

        let location: Location;
        if (latitude != null && longitude != null) {
          location = {
            name: `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`,
            latitude,
            longitude,
            manual: true,
          };
        } else if (locationQuery) {
          const matches = await searchAllLocations(locationQuery, apiKey);
          if (matches.length === 0) {
            return textResult(`No location found matching "${locationQuery}".`, true);
          }
          location = matches[0];
        } else {
          return textResult("Provide either `location` or both `latitude` and `longitude`.", true);
        }

        if (start_date < EARLIEST_SUPPORTED_DATE) {
          return textResult(
            `start_date must be on or after ${EARLIEST_SUPPORTED_DATE} (Open-Meteo's archive floor).`,
            true,
          );
        }
        const today = todayIso();
        if (end_date > today) {
          return textResult(`end_date cannot be in the future (today is ${today}).`, true);
        }
        if (end_date < start_date) {
          return textResult("end_date must be on or after start_date.", true);
        }

        let daily = archiveCache.lookup(location, start_date, end_date);
        if (!daily) {
          const raw = await fetchDailyArchive({
            latitude: location.latitude,
            longitude: location.longitude,
            startDate: start_date,
            endDate: end_date,
            apiKey,
          });
          const fetched = raw.daily as Record<string, unknown> | undefined;
          if (!fetched) {
            return textResult("No daily data returned for this location/date range.", true);
          }
          archiveCache.store(location, start_date, end_date, fetched);
          daily = fetched;
        }

        const summary = aggregateDailyArchive({
          location,
          startDate: start_date,
          endDate: end_date,
          daily,
          method,
        });
        if (!hasAnyData(summary)) {
          return textResult(
            "Open-Meteo has no historical data for this location and date range.",
            true,
          );
        }

        const json = weatherSummaryToJson(summary, units);
        if (daysBetween(start_date, end_date) > LONG_RANGE_WARNING_DAYS) {
          json.warning =
            "This is a multi-decade range; Open-Meteo can be slow or occasionally time out for " +
            "very large requests like this.";
        }

        return textResult(JSON.stringify(json, null, 2));
      } catch (err) {
        return textResult(formatError(err), true);
      }
    },
  );

  return server;
}
