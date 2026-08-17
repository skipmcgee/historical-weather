import type { Location } from "./types.js";

/** The daily archive variables we request and then aggregate client-side.
 * Mirrors dailyArchiveVariables in lib/services/open_meteo_service.dart. */
export const DAILY_ARCHIVE_VARIABLES = [
  "temperature_2m_max",
  "temperature_2m_min",
  "precipitation_sum",
  "rain_sum",
  "snowfall_sum",
  "wind_speed_10m_max",
  "wind_gusts_10m_max",
  "wind_direction_10m_dominant",
  "shortwave_radiation_sum",
  "sunshine_duration",
  "relative_humidity_2m_mean",
  "dew_point_2m_mean",
  "cloud_cover_mean",
  "surface_pressure_mean",
  "et0_fao_evapotranspiration",
  "soil_moisture_0_to_7cm_mean",
  "soil_moisture_7_to_28cm_mean",
  "soil_moisture_28_to_100cm_mean",
  "soil_temperature_0_to_7cm_mean",
  "soil_temperature_7_to_28cm_mean",
  "soil_temperature_28_to_100cm_mean",
];

/**
 * Open-Meteo's archive endpoint has a noticeable cold-cache penalty: the
 * first request for a given location/date-range combo can take several
 * seconds, and it scales badly for very large spans (an 86-year range with
 * the full variable set measured against the real API got a 504 from
 * Open-Meteo's own nginx after 10 minutes). 120s bounds the wait without
 * cutting off a legitimately slow-but-working multi-decade query
 * prematurely. Mirrors _requestTimeout in
 * lib/services/open_meteo_service.dart.
 */
const REQUEST_TIMEOUT_MS = 120_000;

export class OpenMeteoError extends Error {}

function hostPrefix(apiKey: string | undefined): string {
  return apiKey ? "customer-" : "";
}

function withApiKey(
  params: Record<string, string>,
  apiKey: string | undefined,
): Record<string, string> {
  return apiKey ? { ...params, apikey: apiKey } : params;
}

function applyParams(url: URL, params: Record<string, string>): void {
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
}

async function get(url: URL): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    return await fetch(url, { signal: controller.signal });
  } catch (err) {
    if (err instanceof Error && err.name === "AbortError") {
      throw new OpenMeteoError(
        `Open-Meteo took too long to respond (>${REQUEST_TIMEOUT_MS / 1000}s). Very long date ` +
          "ranges (many decades) can be genuinely slow on their end -- try a shorter range, or " +
          "try again in a moment.",
      );
    }
    throw err;
  } finally {
    clearTimeout(timeout);
  }
}

/** Open-Meteo puts a human-readable explanation in a `reason` field on
 * error responses -- including rate limiting ("Hourly API request limit
 * exceeded...") -- so surface that verbatim whenever it's present rather
 * than just the HTTP status code. Mirrors _errorMessage() in
 * lib/services/open_meteo_service.dart. */
async function errorMessage(response: Response, fallback: string): Promise<string> {
  try {
    const body = (await response.json()) as { reason?: string };
    if (body?.reason) return body.reason;
  } catch {
    // Not JSON (or empty body) -- fall through to the generic message.
  }
  return `${fallback} (HTTP ${response.status}).`;
}

interface GeocodingResult {
  name: string;
  latitude: number;
  longitude: number;
  admin1?: string;
  country?: string;
  timezone?: string;
}

/** Searches Open-Meteo's geocoding API for places matching `query`. */
export async function searchLocations(query: string, apiKey?: string): Promise<Location[]> {
  const url = new URL(`https://${hostPrefix(apiKey)}geocoding-api.open-meteo.com/v1/search`);
  applyParams(url, withApiKey({ name: query, count: "10", language: "en" }, apiKey));

  const response = await get(url);
  if (!response.ok) {
    throw new OpenMeteoError(await errorMessage(response, "Location search failed"));
  }

  const body = (await response.json()) as { results?: GeocodingResult[] };
  if (!body.results) return [];

  return body.results.map((r) => ({
    name: r.name,
    latitude: r.latitude,
    longitude: r.longitude,
    admin1: r.admin1,
    country: r.country,
    timezone: r.timezone,
    manual: false,
  }));
}

/** Fetches the daily archive weather for a location between two dates
 * (inclusive), returning the raw decoded JSON body. */
export async function fetchDailyArchive(params: {
  latitude: number;
  longitude: number;
  startDate: string;
  endDate: string;
  apiKey?: string;
}): Promise<Record<string, unknown>> {
  const { latitude, longitude, startDate, endDate, apiKey } = params;
  const url = new URL(`https://${hostPrefix(apiKey)}archive-api.open-meteo.com/v1/archive`);
  applyParams(
    url,
    withApiKey(
      {
        latitude: String(latitude),
        longitude: String(longitude),
        start_date: startDate,
        end_date: endDate,
        daily: DAILY_ARCHIVE_VARIABLES.join(","),
        timezone: "auto",
      },
      apiKey,
    ),
  );

  const response = await get(url);
  if (!response.ok) {
    throw new OpenMeteoError(await errorMessage(response, "Historical weather request failed"));
  }
  return (await response.json()) as Record<string, unknown>;
}
