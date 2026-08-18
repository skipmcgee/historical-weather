import { afterEach, describe, expect, it, vi } from "vitest";
import { fetchDailyArchive, OpenMeteoError, searchLocations } from "../src/openMeteoClient.js";

function jsonResponse(body: unknown, init: { status?: number } = {}): Response {
  return new Response(JSON.stringify(body), {
    status: init.status ?? 200,
    headers: { "content-type": "application/json" },
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("searchLocations", () => {
  it("maps geocoding results to Location objects", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        jsonResponse({
          results: [
            {
              name: "Austin",
              latitude: 30.27,
              longitude: -97.74,
              admin1: "Texas",
              country: "United States",
              timezone: "America/Chicago",
            },
          ],
        }),
      ),
    );

    const results = await searchLocations("Austin");
    expect(results).toEqual([
      {
        name: "Austin",
        latitude: 30.27,
        longitude: -97.74,
        admin1: "Texas",
        country: "United States",
        timezone: "America/Chicago",
        manual: false,
      },
    ]);
  });

  it("returns an empty array when the API omits `results` entirely (no matches)", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(jsonResponse({})));
    expect(await searchLocations("nowhere")).toEqual([]);
  });

  it("uses the customer- host prefix and apikey param when an API key is set", async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ results: [] }));
    vi.stubGlobal("fetch", fetchMock);

    await searchLocations("Austin", "test-key");

    const requestedUrl = new URL((fetchMock.mock.calls[0]![0] as URL).toString());
    expect(requestedUrl.hostname).toBe("customer-geocoding-api.open-meteo.com");
    expect(requestedUrl.searchParams.get("apikey")).toBe("test-key");
  });

  it("omits the apikey param and customer- prefix without an API key", async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ results: [] }));
    vi.stubGlobal("fetch", fetchMock);

    await searchLocations("Austin");

    const requestedUrl = new URL((fetchMock.mock.calls[0]![0] as URL).toString());
    expect(requestedUrl.hostname).toBe("geocoding-api.open-meteo.com");
    expect(requestedUrl.searchParams.has("apikey")).toBe(false);
  });
});

describe("error handling (shared by both endpoints)", () => {
  it("surfaces Open-Meteo's `reason` field on a non-200 response", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        jsonResponse({ reason: "Hourly API request limit exceeded" }, { status: 429 }),
      ),
    );

    await expect(searchLocations("Austin")).rejects.toThrow(
      /Hourly API request limit exceeded/,
    );
  });

  it("falls back to a generic message with the status code when there's no `reason`", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response("", { status: 500 })));

    await expect(searchLocations("Austin")).rejects.toThrow(/HTTP 500/);
  });

  it("wraps a malformed (non-JSON) body on an otherwise-successful response", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(new Response("not json", { status: 200 })),
    );

    await expect(searchLocations("Austin")).rejects.toThrow(OpenMeteoError);
  });

  it("wraps a generic network failure (not a timeout) in OpenMeteoError", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("getaddrinfo ENOTFOUND")));

    await expect(searchLocations("Austin")).rejects.toThrow(OpenMeteoError);
    await expect(searchLocations("Austin")).rejects.toThrow(/Couldn't reach Open-Meteo/);
  });

  it("gives a friendly message for a timeout (AbortError)", async () => {
    const abortError = new DOMException("The operation was aborted", "AbortError");
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(abortError));

    await expect(searchLocations("Austin")).rejects.toThrow(/took too long to respond/);
  });
});

describe("fetchDailyArchive", () => {
  it("returns the raw decoded JSON body on success", async () => {
    const body = { daily: { time: ["2020-01-01"], temperature_2m_max: [10.0] } };
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(jsonResponse(body)));

    const result = await fetchDailyArchive({
      latitude: 30.27,
      longitude: -97.74,
      startDate: "2020-01-01",
      endDate: "2020-01-01",
    });
    expect(result).toEqual(body);
  });

  it("requests the archive- host (customer-archive- with an API key)", async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ daily: {} }));
    vi.stubGlobal("fetch", fetchMock);

    await fetchDailyArchive({
      latitude: 30.27,
      longitude: -97.74,
      startDate: "2020-01-01",
      endDate: "2020-01-01",
      apiKey: "test-key",
    });

    const requestedUrl = new URL((fetchMock.mock.calls[0]![0] as URL).toString());
    expect(requestedUrl.hostname).toBe("customer-archive-api.open-meteo.com");
    expect(requestedUrl.searchParams.get("start_date")).toBe("2020-01-01");
  });
});
