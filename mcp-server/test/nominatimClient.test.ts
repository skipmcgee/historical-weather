import { afterEach, describe, expect, it, vi } from "vitest";
import { NominatimError, searchAddresses } from "../src/nominatimClient.js";

function jsonResponse(body: unknown, init: { status?: number } = {}): Response {
  return new Response(JSON.stringify(body), {
    status: init.status ?? 200,
    headers: { "content-type": "application/json" },
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("searchAddresses", () => {
  it("builds a street-address name from house number + road", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        jsonResponse([
          {
            lat: "38.8976387",
            lon: "-77.0365525",
            name: "White House",
            display_name: "White House, 1600, Pennsylvania Avenue Northwest, Washington, United States",
            address: {
              house_number: "1600",
              road: "Pennsylvania Avenue Northwest",
              city: "Washington",
              state: "District of Columbia",
              country: "United States",
            },
          },
        ]),
      ),
    );

    const results = await searchAddresses("1600 Pennsylvania Ave NW");
    expect(results).toEqual([
      {
        name: "1600 Pennsylvania Avenue Northwest",
        latitude: 38.8976387,
        longitude: -77.0365525,
        admin1: "Washington, District of Columbia",
        country: "United States",
        manual: false,
      },
    ]);
  });

  it("uses the plain place name for a city-level result without duplicating it in admin1", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        jsonResponse([
          {
            lat: "30.2711286",
            lon: "-97.7436995",
            name: "Austin",
            address: { city: "Austin", state: "Texas", country: "United States" },
          },
        ]),
      ),
    );

    const results = await searchAddresses("Austin");
    expect(results[0]?.name).toBe("Austin");
    expect(results[0]?.admin1).toBe("Texas");
  });

  it("sends the required query params and an identifying User-Agent", async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse([]));
    vi.stubGlobal("fetch", fetchMock);

    await searchAddresses("Austin, TX");

    const [requestUrl, requestInit] = fetchMock.mock.calls[0] as [URL, RequestInit];
    expect(requestUrl.hostname).toBe("nominatim.openstreetmap.org");
    expect(requestUrl.searchParams.get("q")).toBe("Austin, TX");
    expect(requestUrl.searchParams.get("format")).toBe("jsonv2");
    expect(requestUrl.searchParams.get("addressdetails")).toBe("1");
    const headers = requestInit.headers as Record<string, string>;
    expect(headers["User-Agent"]).toBeTruthy();
  });

  it("throws on a non-200 response", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response("", { status: 503 })));

    await expect(searchAddresses("Austin")).rejects.toThrow(/HTTP 503/);
  });

  it("throws on a malformed (non-JSON) body", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response("not json", { status: 200 })));

    await expect(searchAddresses("Austin")).rejects.toThrow(NominatimError);
  });

  it("throws when the response is valid JSON but not an array", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(jsonResponse({ error: "bad request" })));

    await expect(searchAddresses("Austin")).rejects.toThrow(/unexpected response shape/);
  });

  it("wraps a generic network failure in NominatimError", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("getaddrinfo ENOTFOUND")));

    await expect(searchAddresses("Austin")).rejects.toThrow(NominatimError);
    await expect(searchAddresses("Austin")).rejects.toThrow(/Couldn't reach/);
  });

  it("gives a friendly message for a timeout (AbortError)", async () => {
    const abortError = new DOMException("The operation was aborted", "AbortError");
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(abortError));

    await expect(searchAddresses("Austin")).rejects.toThrow(/took too long to respond/);
  });
});
