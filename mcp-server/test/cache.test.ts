import { describe, expect, it } from "vitest";
import { ArchiveCache } from "../src/cache.js";
import type { Location } from "../src/types.js";

const location: Location = { name: "Test", latitude: 30.27, longitude: -97.74, manual: true };
const otherLocation: Location = { name: "Other", latitude: 40.71, longitude: -74.01, manual: true };

describe("ArchiveCache", () => {
  it("a fresh cache has no entries", () => {
    const cache = new ArchiveCache();
    expect(cache.lookup(location, "2020-01-01", "2020-01-03")).toBeNull();
  });

  it("serves an exact match from cache without hitting the network", () => {
    const cache = new ArchiveCache();
    const daily = {
      time: ["2020-01-01", "2020-01-02", "2020-01-03"],
      temperature_2m_max: [10.0, 12.0, 14.0],
    };
    cache.store(location, "2020-01-01", "2020-01-03", daily);

    const result = cache.lookup(location, "2020-01-01", "2020-01-03");
    expect(result).not.toBeNull();
    expect(result!.time).toEqual(daily.time);
    expect(result!.temperature_2m_max).toEqual(daily.temperature_2m_max);
  });

  it("slices a narrower request out of a cached wider range", () => {
    const cache = new ArchiveCache();
    cache.store(location, "2020-01-01", "2020-01-05", {
      time: ["2020-01-01", "2020-01-02", "2020-01-03", "2020-01-04", "2020-01-05"],
      temperature_2m_max: [1.0, 2.0, 3.0, 4.0, 5.0],
    });

    const result = cache.lookup(location, "2020-01-02", "2020-01-04");
    expect(result).not.toBeNull();
    expect(result!.time).toEqual(["2020-01-02", "2020-01-03", "2020-01-04"]);
    expect(result!.temperature_2m_max).toEqual([2.0, 3.0, 4.0]);
  });

  it("does not reuse cache across different locations", () => {
    const cache = new ArchiveCache();
    cache.store(location, "2020-01-01", "2020-01-03", { time: [] });

    expect(cache.lookup(otherLocation, "2020-01-01", "2020-01-03")).toBeNull();
  });

  it("does not reuse cache for a range only partially, not fully, covered", () => {
    const cache = new ArchiveCache();
    cache.store(location, "2020-01-01", "2020-01-03", { time: [] });

    expect(cache.lookup(location, "2020-01-02", "2020-01-10")).toBeNull();
  });

  it("caps the cache at 50 entries, evicting the oldest first", () => {
    const cache = new ArchiveCache();
    const addDays = (base: Date, days: number) => {
      const d = new Date(base);
      d.setUTCDate(d.getUTCDate() + days);
      return d.toISOString().slice(0, 10);
    };
    const base = new Date("2000-01-01T00:00:00Z");

    for (let i = 0; i < 55; i++) {
      cache.store(location, addDays(base, i), addDays(base, i + 1), { time: [] });
    }

    // The first entries written should have been evicted...
    expect(cache.lookup(location, addDays(base, 0), addDays(base, 1))).toBeNull();
    // ...but the most recently written one should still be there.
    expect(cache.lookup(location, addDays(base, 54), addDays(base, 55))).not.toBeNull();
  });
});
