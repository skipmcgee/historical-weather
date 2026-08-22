import { describe, expect, it, vi } from "vitest";
import { searchAllLocations } from "../src/locationSearch.js";
import { OpenMeteoError } from "../src/openMeteoClient.js";
import { NominatimError } from "../src/nominatimClient.js";
import type { Location } from "../src/types.js";

const { searchLocationsMock } = vi.hoisted(() => ({ searchLocationsMock: vi.fn() }));
const { searchAddressesMock } = vi.hoisted(() => ({ searchAddressesMock: vi.fn() }));

vi.mock("../src/openMeteoClient.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/openMeteoClient.js")>();
  return { ...actual, searchLocations: searchLocationsMock };
});

vi.mock("../src/nominatimClient.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/nominatimClient.js")>();
  return { ...actual, searchAddresses: searchAddressesMock };
});

const austinFromOpenMeteo: Location = {
  name: "Austin",
  latitude: 30.2711,
  longitude: -97.7437,
  admin1: "Texas",
  country: "US",
  manual: false,
};

const addressFromNominatim: Location = {
  name: "500 East Cesar Chavez Street",
  latitude: 30.262437,
  longitude: -97.740912,
  admin1: "Austin, Texas",
  country: "United States",
  manual: false,
};

describe("searchAllLocations", () => {
  it("merges results from both sources", async () => {
    searchLocationsMock.mockResolvedValue([austinFromOpenMeteo]);
    searchAddressesMock.mockResolvedValue([addressFromNominatim]);

    const results = await searchAllLocations("Austin");

    expect(results).toHaveLength(2);
    expect(results.map((l) => l.name)).toEqual(["Austin", "500 East Cesar Chavez Street"]);
  });

  it("collapses two results that resolve to essentially the same point", async () => {
    searchLocationsMock.mockResolvedValue([austinFromOpenMeteo]);
    searchAddressesMock.mockResolvedValue([
      { ...austinFromOpenMeteo, latitude: 30.2712, longitude: -97.7436, country: "United States" },
    ]);

    const results = await searchAllLocations("Austin");

    expect(results).toHaveLength(1);
    // Open-Meteo's copy is kept (placed first).
    expect(results[0]?.country).toBe("US");
  });

  it("returns just the successful source's results when the other rejects", async () => {
    searchLocationsMock.mockResolvedValue([austinFromOpenMeteo]);
    searchAddressesMock.mockRejectedValue(new NominatimError("Address search failed (HTTP 503)."));

    const results = await searchAllLocations("Austin");

    expect(results).toEqual([austinFromOpenMeteo]);
  });

  it("throws the Open-Meteo error when both sources reject", async () => {
    searchLocationsMock.mockRejectedValue(new OpenMeteoError("Location search failed (HTTP 503)."));
    searchAddressesMock.mockRejectedValue(new NominatimError("Address search failed (HTTP 503)."));

    await expect(searchAllLocations("Austin")).rejects.toThrow(OpenMeteoError);
  });
});
