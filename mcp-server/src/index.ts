#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

import { aggregateDailyArchive, hasAnyData } from "./aggregator.js";
import { fetchDailyArchive, OpenMeteoError, searchLocations } from "./openMeteoClient.js";
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

const server = new McpServer({
  name: "historical-weather",
  version: "0.1.0",
});

server.registerTool(
  "search_locations",
  {
    title: "Search locations",
    description:
      "Search Open-Meteo's geocoding database for places matching a free-text query (city/place " +
      "name). Returns candidate matches with coordinates, so an ambiguous name can be " +
      "disambiguated before calling get_historical_weather.",
    inputSchema: {
      query: z.string().min(1).describe('Place name to search for, e.g. "Austin, TX"'),
    },
  },
  async ({ query }) => {
    try {
      const results = await searchLocations(query, process.env.OPEN_METEO_API_KEY);
      return textResult(JSON.stringify(results, null, 2));
    } catch (err) {
      return textResult(err instanceof Error ? err.message : String(err), true);
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
      "applied. Provide either `location` (a place name, resolved automatically via geocoding) " +
      "or explicit `latitude`/`longitude`. Only data from 1940-01-01 onward is supported.",
    inputSchema: {
      location: z
        .string()
        .optional()
        .describe(
          'Free-text place name, e.g. "Austin, TX" -- resolved via geocoding to the best ' +
            "match. Omit if latitude/longitude are given.",
        ),
      latitude: z.number().min(-90).max(90).optional(),
      longitude: z.number().min(-180).max(180).optional(),
      start_date: z.string().regex(DATE_REGEX, "must be YYYY-MM-DD"),
      end_date: z.string().regex(DATE_REGEX, "must be YYYY-MM-DD"),
      method: z.enum(["median", "average"]).default("median"),
      units: z.enum(["metric", "imperial"]).default("imperial"),
    },
  },
  async ({ location: locationQuery, latitude, longitude, start_date, end_date, method, units }) => {
    try {
      const apiKey = process.env.OPEN_METEO_API_KEY;

      let location: Location;
      if (latitude != null && longitude != null) {
        location = {
          name: `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`,
          latitude,
          longitude,
          manual: true,
        };
      } else if (locationQuery) {
        const matches = await searchLocations(locationQuery, apiKey);
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

      const raw = await fetchDailyArchive({
        latitude: location.latitude,
        longitude: location.longitude,
        startDate: start_date,
        endDate: end_date,
        apiKey,
      });
      const daily = raw.daily as Record<string, unknown> | undefined;
      if (!daily) {
        return textResult("No daily data returned for this location/date range.", true);
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
      if (err instanceof OpenMeteoError) return textResult(err.message, true);
      return textResult(`Unexpected error: ${err instanceof Error ? err.message : String(err)}`, true);
    }
  },
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error("Fatal error starting historical-weather MCP server:", err);
  process.exit(1);
});
