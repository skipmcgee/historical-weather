import type { Location } from "./types.js";

const MAX_ENTRIES = 50;
const MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000;

interface CacheEntry {
  locationKey: string;
  start: string; // YYYY-MM-DD
  end: string;
  fetchedAt: number; // epoch ms -- used for age-based expiry only
  sequence: number; // monotonic insertion order -- used for recency-based eviction
  daily: Record<string, unknown>;
}

/**
 * Caches Open-Meteo daily-archive responses in memory, keyed by location
 * and date range, so re-running the same (or a narrower) query within this
 * server process's lifetime doesn't re-fetch data that's already been
 * retrieved. Mirrors lib/services/archive_cache_service.dart, minus
 * persistence -- an MCP server is a local, typically short-lived process,
 * so resetting the cache on restart is fine (there's no equivalent of the
 * Flutter app's per-tab/per-install storage concern here).
 *
 * Eviction: an entry expires after MAX_AGE_MS (~1 month) *or* once the
 * cache holds more than MAX_ENTRIES (50) entries, whichever comes first --
 * every write sweeps expired entries, then trims the oldest ones down to
 * the cap.
 *
 * Only *exact* and *containing* matches are served from cache (a cached
 * range that fully covers the requested range is sliced down to it);
 * partially-overlapping ranges that don't fully contain the request still
 * go to the network -- splicing two partial responses together would need
 * to merge per-variable arrays across a gap, which isn't worth the
 * complexity for what's fundamentally a convenience cache.
 */
export class ArchiveCache {
  private entries: CacheEntry[] = [];

  // Date.now() only has millisecond resolution, and a tight burst of writes
  // can easily land multiple entries on the same millisecond; sorting by
  // fetchedAt alone for "keep the newest N" would then fall back to a
  // stable sort's original (oldest-first) order among the tied entries,
  // potentially evicting genuinely-recent entries instead of old ones. This
  // counter gives eviction a tie-proof, strictly-increasing recency signal
  // independent of clock resolution. Instance-scoped (not module-level) so
  // separate ArchiveCache instances -- e.g. one per test -- don't share
  // eviction ordering state.
  private insertionSequence = 0;

  lookup(location: Location, start: string, end: string): Record<string, unknown> | null {
    const key = locationKey(location);
    this.entries = evict(this.entries);
    for (const entry of this.entries) {
      if (entry.locationKey !== key) continue;
      if (entry.start > start || entry.end < end) continue;
      return sliceDaily(entry.daily, start, end);
    }
    return null;
  }

  store(location: Location, start: string, end: string, daily: Record<string, unknown>): void {
    const key = locationKey(location);
    this.entries = this.entries.filter(
      (e) => !(e.locationKey === key && e.start === start && e.end === end),
    );
    this.entries.push({
      locationKey: key,
      start,
      end,
      fetchedAt: Date.now(),
      sequence: ++this.insertionSequence,
      daily,
    });
    this.entries = evict(this.entries);
  }
}

function locationKey(location: Location): string {
  return `${location.latitude.toFixed(4)},${location.longitude.toFixed(4)}`;
}

function evict(entries: CacheEntry[]): CacheEntry[] {
  const now = Date.now();
  return entries
    .filter((e) => now - e.fetchedAt < MAX_AGE_MS)
    .sort((a, b) => b.sequence - a.sequence)
    .slice(0, MAX_ENTRIES);
}

function sliceDaily(
  daily: Record<string, unknown>,
  start: string,
  end: string,
): Record<string, unknown> {
  const times = Array.isArray(daily.time) ? (daily.time as string[]) : [];
  const indices: number[] = [];
  for (let i = 0; i < times.length; i++) {
    if (times[i] >= start && times[i] <= end) indices.push(i);
  }

  const sliced: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(daily)) {
    sliced[key] = Array.isArray(value) ? indices.map((i) => value[i]) : value;
  }
  return sliced;
}
