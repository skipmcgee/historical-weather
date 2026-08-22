import { searchAddresses } from "./nominatimClient.js";
import { searchLocations } from "./openMeteoClient.js";
import type { Location } from "./types.js";

/**
 * Searches both Open-Meteo's place/city geocoder and OpenStreetMap's
 * Nominatim (which additionally resolves specific street addresses and
 * points of interest), merging and de-duplicating the results into one
 * list. Tolerant of either source failing individually -- one being
 * temporarily unavailable shouldn't break location search entirely -- but
 * throws if *both* fail, rather than silently reporting "no matches found"
 * for what's actually a network problem. Mirrors searchAllLocations in
 * lib/services/location_search.dart.
 */
export async function searchAllLocations(query: string, apiKey?: string): Promise<Location[]> {
  const [openMeteoResult, nominatimResult] = await Promise.allSettled([
    searchLocations(query, apiKey),
    searchAddresses(query),
  ]);

  if (openMeteoResult.status === "rejected" && nominatimResult.status === "rejected") {
    throw openMeteoResult.reason;
  }

  const openMeteoLocations = openMeteoResult.status === "fulfilled" ? openMeteoResult.value : [];
  const nominatimLocations = nominatimResult.status === "fulfilled" ? nominatimResult.value : [];

  return dedupe([...openMeteoLocations, ...nominatimLocations]);
}

/** Collapses results that resolve to essentially the same point (~100m)
 * down to one -- Open-Meteo's city-centroid result and Nominatim's
 * equivalent city-boundary result for the same place are common
 * duplicates otherwise. Keeps whichever copy was added first (Open-Meteo's
 * results are placed first by the caller, since its labels are typically
 * the cleaner of the two for a plain place name). */
function dedupe(locations: Location[]): Location[] {
  const seen = new Set<string>();
  const result: Location[] = [];
  for (const location of locations) {
    const key = `${location.latitude.toFixed(3)},${location.longitude.toFixed(3)}`;
    if (!seen.has(key)) {
      seen.add(key);
      result.push(location);
    }
  }
  return result;
}
