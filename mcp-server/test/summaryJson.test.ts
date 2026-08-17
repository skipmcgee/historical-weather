import { describe, expect, it } from "vitest";
import { weatherSummaryToJson } from "../src/summaryJson.js";
import type { AggregationMethod, Location, WeatherSummary } from "../src/types.js";

const location: Location = { name: "Test", latitude: 30.27, longitude: -97.74, manual: true };

function buildSummary(method: AggregationMethod): WeatherSummary {
  return {
    location,
    startDate: "2020-01-01",
    endDate: "2020-01-31",
    dayCount: 31,
    method,
    highC: 20.0,
    lowC: 0.0,
    meanC: 10.0,
    totalPrecipitationMm: 25.4,
    precipitationPerDayMm: 0.82,
    totalRainMm: null,
    totalSnowfallCm: 2.54,
    windSpeedMaxKmh: 100.0,
    windGustsMaxKmh: null,
    windDirectionDeg: 90.0,
    relativeHumidityPercent: null,
    dewPointC: null,
    cloudCoverPercent: null,
    surfacePressureHpa: 1013.25,
    shortwaveRadiationMjm2: null,
    sunshineHours: null,
    totalEt0Mm: null,
    et0MmPerDay: null,
    soilMoisture0To7cm: 0.32,
    soilMoisture7To28cm: null,
    soilMoisture28To100cm: null,
    soilTemp0To7cmC: 15.0,
    soilTemp7To28cmC: null,
    soilTemp28To100cmC: null,
  };
}

describe("weatherSummaryToJson", () => {
  it("defaults to metric and reports the aggregation method", () => {
    const json = weatherSummaryToJson(buildSummary("median")) as any;

    expect(json.method).toBe("median");
    expect(json.unit_system).toBe("metric");
    expect(json.temperature.unit).toBe("°C");
    expect(json.temperature.high).toBeCloseTo(20.0, 9);
    expect(json.precipitation.unit).toBe("mm");
    expect(json.precipitation.total).toBeCloseTo(25.4, 9);
    expect(json.wind.speed_unit).toBe("km/h");
    expect(json.wind.max_speed).toBeCloseTo(100.0, 9);
    // Volumetric soil moisture is unit-agnostic.
    expect(json.soil.moisture_m3_m3["0_to_7cm"]).toBeCloseTo(0.32, 9);
  });

  it("converts every unit-affected field for imperial", () => {
    const json = weatherSummaryToJson(buildSummary("average"), "imperial") as any;

    expect(json.method).toBe("average");
    expect(json.unit_system).toBe("imperial");
    expect(json.temperature.unit).toBe("°F");
    expect(json.temperature.high).toBeCloseTo(68.0, 9); // 20C
    expect(json.temperature.low).toBeCloseTo(32.0, 9); // 0C
    expect(json.precipitation.unit).toBe("in");
    expect(json.precipitation.total).toBeCloseTo(1.0, 9); // 25.4mm
    expect(json.snowfall.unit).toBe("in");
    expect(json.snowfall.total).toBeCloseTo(1.0, 9); // 2.54cm
    expect(json.wind.speed_unit).toBe("mph");
    expect(json.wind.max_speed).toBeCloseTo(62.1, 1); // 100km/h
    expect(json.atmosphere.surface_pressure_unit).toBe("inHg");
    expect(json.atmosphere.surface_pressure).toBeCloseTo(29.92, 2);
    // Wind direction (degrees) and soil moisture (m3/m3) are never converted.
    expect(json.wind.direction_deg).toBeCloseTo(90.0, 9);
    expect(json.soil.moisture_m3_m3["0_to_7cm"]).toBeCloseTo(0.32, 9);
    // Soil temperature *is* converted, unlike soil moisture.
    expect(json.soil.temperature_unit).toBe("°F");
    expect(json.soil.temperature["0_to_7cm"]).toBeCloseTo(59.0, 9); // 15C
  });
});
