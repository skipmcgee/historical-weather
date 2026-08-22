import type { Location } from "./types.js";

/** Nominatim's public server is much faster than Open-Meteo's archive
 * endpoint for a single free-text query -- no need for the 120s allowance
 * openMeteoClient.ts gives itself. Mirrors _requestTimeout in
 * lib/services/nominatim_service.dart. */
const REQUEST_TIMEOUT_MS = 15_000;

/** Identifies this server to Nominatim's public server, as required by its
 * usage policy (https://operations.osmfoundation.org/policies/nominatim/). */
const USER_AGENT = "historical-weather-mcp-server (https://github.com/skipmcgee/historical-weather)";

export class NominatimError extends Error {}

interface NominatimResult {
  lat: string;
  lon: string;
  name?: string;
  display_name?: string;
  address?: {
    house_number?: string;
    road?: string;
    city?: string;
    town?: string;
    village?: string;
    hamlet?: string;
    state?: string;
    country?: string;
  };
}

function toLocation(r: NominatimResult): Location {
  const latitude = Number(r.lat);
  const longitude = Number(r.lon);
  const address = r.address ?? {};
  const houseNumber = address.house_number;
  const road = address.road;
  const poiName = r.name;
  const locality = address.city ?? address.town ?? address.village ?? address.hamlet;
  const state = address.state;

  let name: string;
  if (houseNumber && road) {
    name = `${houseNumber} ${road}`;
  } else if (road) {
    name = road;
  } else if (poiName) {
    name = poiName;
  } else if (locality) {
    name = locality;
  } else {
    name = r.display_name?.split(",")[0]?.trim() ?? `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`;
  }

  // Fold the city into admin1 (alongside state) only when it isn't already
  // the name itself -- mirrors Location.fromNominatimJson in
  // lib/models/location.dart.
  const admin1Parts = [locality && locality !== name ? locality : undefined, state].filter(
    (p): p is string => !!p,
  );

  return {
    name,
    latitude,
    longitude,
    admin1: admin1Parts.length ? admin1Parts.join(", ") : undefined,
    country: address.country,
    manual: false,
  };
}

/**
 * Searches OpenStreetMap's Nominatim geocoder for a free-text query --
 * unlike Open-Meteo's geocoding API (city/place names only, via GeoNames),
 * Nominatim also resolves specific street addresses and points of
 * interest. Public server, no API key: per Nominatim's usage policy, sends
 * an identifying User-Agent and stays within the same light, on-demand
 * search volume the equivalent Flutter search UI already limits itself to
 * (no bulk/automated use). Mirrors searchAddresses in
 * lib/services/nominatim_service.dart.
 */
export async function searchAddresses(query: string): Promise<Location[]> {
  const url = new URL("https://nominatim.openstreetmap.org/search");
  url.searchParams.set("q", query);
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("addressdetails", "1");
  url.searchParams.set("limit", "6");

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  let response: Response;
  try {
    response = await fetch(url, {
      signal: controller.signal,
      headers: { "User-Agent": USER_AGENT },
    });
  } catch (err) {
    if (err instanceof Error && err.name === "AbortError") {
      throw new NominatimError(
        `Address search took too long to respond (>${REQUEST_TIMEOUT_MS / 1000}s).`,
      );
    }
    throw new NominatimError(
      `Couldn't reach the address search service: ${err instanceof Error ? err.message : String(err)}`,
    );
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    throw new NominatimError(`Address search failed (HTTP ${response.status}).`);
  }

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    throw new NominatimError("Address search returned an unexpected (non-JSON) response.");
  }

  if (!Array.isArray(body)) {
    throw new NominatimError("Address search returned an unexpected response shape.");
  }

  return (body as NominatimResult[]).map(toLocation);
}
