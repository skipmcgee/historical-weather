import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ArchiveCache } from "../src/cache.js";
import { createMcpServer } from "../src/server.js";

function jsonResponse(body: unknown, init: { status?: number } = {}): Response {
  return new Response(JSON.stringify(body), {
    status: init.status ?? 200,
    headers: { "content-type": "application/json" },
  });
}

function dailyArchiveFixture(): Record<string, unknown> {
  const time = ["2020-01-01", "2020-01-02", "2020-01-03"];
  return {
    daily: {
      time,
      temperature_2m_max: [10.0, 12.0, 14.0],
      temperature_2m_min: [0.0, 2.0, 4.0],
      precipitation_sum: [1.0, 0.0, 2.0],
      rain_sum: [1.0, 0.0, 2.0],
      snowfall_sum: [0.0, 0.0, 0.0],
      wind_speed_10m_max: [10.0, 12.0, 8.0],
      wind_gusts_10m_max: [20.0, 22.0, 18.0],
      wind_direction_10m_dominant: [90.0, 90.0, 90.0],
      shortwave_radiation_sum: [10.0, 11.0, 9.0],
      sunshine_duration: [3600, 3700, 3500],
      relative_humidity_2m_mean: [50.0, 52.0, 48.0],
      dew_point_2m_mean: [5.0, 6.0, 4.0],
      cloud_cover_mean: [30.0, 40.0, 20.0],
      surface_pressure_mean: [1013.0, 1012.0, 1014.0],
      et0_fao_evapotranspiration: [2.0, 2.2, 1.8],
      soil_moisture_0_to_7cm_mean: [0.3, 0.31, 0.29],
      soil_moisture_7_to_28cm_mean: [0.28, 0.29, 0.27],
      soil_moisture_28_to_100cm_mean: [0.25, 0.26, 0.24],
      soil_temperature_0_to_7cm_mean: [15.0, 16.0, 14.0],
      soil_temperature_7_to_28cm_mean: [14.0, 15.0, 13.0],
      soil_temperature_28_to_100cm_mean: [13.0, 14.0, 12.0],
    },
  };
}

async function connectedClient(cache: ArchiveCache): Promise<Client> {
  const server = createMcpServer(cache);
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const client = new Client({ name: "test-client", version: "0.0.1" });
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  return client;
}

function toolText(result: Awaited<ReturnType<Client["callTool"]>>): string {
  const content = result.content as Array<{ type: string; text?: string }>;
  return content[0]?.text ?? "";
}

let fetchMock: ReturnType<typeof vi.fn>;

beforeEach(() => {
  fetchMock = vi.fn();
  vi.stubGlobal("fetch", fetchMock);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("get_historical_weather", () => {
  it("returns an aggregated summary for explicit lat/lon", async () => {
    fetchMock.mockResolvedValue(jsonResponse(dailyArchiveFixture()));
    const client = await connectedClient(new ArchiveCache());

    const result = await client.callTool({
      name: "get_historical_weather",
      arguments: { latitude: 30.27, longitude: -97.74, start_date: "2020-01-01", end_date: "2020-01-03" },
    });

    expect(result.isError).toBeFalsy();
    const json = JSON.parse(toolText(result));
    expect(json.method).toBe("median");
    expect(json.unit_system).toBe("imperial");
    expect(json.period.day_count).toBe(3);
  });

  it("errors when only one of latitude/longitude is given", async () => {
    const client = await connectedClient(new ArchiveCache());
    const result = await client.callTool({
      name: "get_historical_weather",
      arguments: { latitude: 30.27, start_date: "2020-01-01", end_date: "2020-01-03" },
    });
    expect(result.isError).toBe(true);
    expect(toolText(result)).toMatch(/latitude.*longitude.*together/i);
  });

  it("errors when neither location nor coordinates are given", async () => {
    const client = await connectedClient(new ArchiveCache());
    const result = await client.callTool({
      name: "get_historical_weather",
      arguments: { start_date: "2020-01-01", end_date: "2020-01-03" },
    });
    expect(result.isError).toBe(true);
    expect(toolText(result)).toMatch(/Provide either/i);
  });

  it("rejects a start_date before the 1940 floor", async () => {
    const client = await connectedClient(new ArchiveCache());
    const result = await client.callTool({
      name: "get_historical_weather",
      arguments: {
        latitude: 30.27,
        longitude: -97.74,
        start_date: "1939-12-31",
        end_date: "1940-01-05",
      },
    });
    expect(result.isError).toBe(true);
    expect(toolText(result)).toMatch(/1940-01-01/);
  });

  it("rejects an end_date in the future", async () => {
    const client = await connectedClient(new ArchiveCache());
    const result = await client.callTool({
      name: "get_historical_weather",
      arguments: {
        latitude: 30.27,
        longitude: -97.74,
        start_date: "2020-01-01",
        end_date: "2999-01-01",
      },
    });
    expect(result.isError).toBe(true);
    expect(toolText(result)).toMatch(/cannot be in the future/);
  });

  it("rejects end_date before start_date", async () => {
    const client = await connectedClient(new ArchiveCache());
    const result = await client.callTool({
      name: "get_historical_weather",
      arguments: {
        latitude: 30.27,
        longitude: -97.74,
        start_date: "2020-01-05",
        end_date: "2020-01-01",
      },
    });
    expect(result.isError).toBe(true);
    expect(toolText(result)).toMatch(/end_date must be on or after start_date/);
  });

  it("rejects a non-existent calendar date", async () => {
    const client = await connectedClient(new ArchiveCache());
    const result = await client.callTool({
      name: "get_historical_weather",
      arguments: {
        latitude: 30.27,
        longitude: -97.74,
        start_date: "2020-02-30",
        end_date: "2020-03-01",
      },
    });
    expect(result.isError).toBe(true);
    expect(toolText(result)).toMatch(/real calendar date/);
  });

  it("resolves a `location` string via geocoding and errors on zero matches", async () => {
    fetchMock.mockResolvedValue(jsonResponse({ results: [] }));
    const client = await connectedClient(new ArchiveCache());

    const result = await client.callTool({
      name: "get_historical_weather",
      arguments: { location: "Nowhereville", start_date: "2020-01-01", end_date: "2020-01-03" },
    });
    expect(result.isError).toBe(true);
    expect(toolText(result)).toMatch(/No location found matching/);
  });

  it("serves a second identical request from cache without a second fetch", async () => {
    fetchMock.mockResolvedValue(jsonResponse(dailyArchiveFixture()));
    const cache = new ArchiveCache();
    const client = await connectedClient(cache);
    const args = {
      latitude: 30.27,
      longitude: -97.74,
      start_date: "2020-01-01",
      end_date: "2020-01-03",
    };

    await client.callTool({ name: "get_historical_weather", arguments: args });
    await client.callTool({ name: "get_historical_weather", arguments: args });

    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("errors when Open-Meteo has no data at all for the range", async () => {
    fetchMock.mockResolvedValue(
      jsonResponse({ daily: { time: ["2020-01-01"], temperature_2m_max: [null] } }),
    );
    const client = await connectedClient(new ArchiveCache());

    const result = await client.callTool({
      name: "get_historical_weather",
      arguments: {
        latitude: 30.27,
        longitude: -97.74,
        start_date: "2020-01-01",
        end_date: "2020-01-01",
      },
    });
    expect(result.isError).toBe(true);
    expect(toolText(result)).toMatch(/no historical data/i);
  });

  it("adds a non-fatal warning field for a multi-decade range", async () => {
    fetchMock.mockResolvedValue(jsonResponse(dailyArchiveFixture()));
    const client = await connectedClient(new ArchiveCache());

    const result = await client.callTool({
      name: "get_historical_weather",
      arguments: {
        latitude: 30.27,
        longitude: -97.74,
        start_date: "1940-01-01",
        end_date: "1990-01-01",
      },
    });
    expect(result.isError).toBeFalsy();
    const json = JSON.parse(toolText(result));
    expect(json.warning).toMatch(/multi-decade/);
  });
});

describe("search_locations", () => {
  it("returns matches from the geocoding API", async () => {
    fetchMock.mockResolvedValue(
      jsonResponse({
        results: [{ name: "Austin", latitude: 30.27, longitude: -97.74, admin1: "Texas", country: "US" }],
      }),
    );
    const client = await connectedClient(new ArchiveCache());

    const result = await client.callTool({ name: "search_locations", arguments: { query: "Austin" } });
    expect(result.isError).toBeFalsy();
    const results = JSON.parse(toolText(result));
    expect(results).toHaveLength(1);
    expect(results[0].name).toBe("Austin");
  });

  it("wraps an Open-Meteo error as a tool error rather than throwing", async () => {
    fetchMock.mockResolvedValue(new Response("", { status: 500 }));
    const client = await connectedClient(new ArchiveCache());

    const result = await client.callTool({ name: "search_locations", arguments: { query: "Austin" } });
    expect(result.isError).toBe(true);
    expect(toolText(result)).toMatch(/HTTP 500/);
  });
});
