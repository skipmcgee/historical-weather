import { describe, expect, it } from "vitest";
import {
  convertCm,
  convertHpa,
  convertKmh,
  convertMm,
  convertTemperatureC,
  precipitationUnit,
  pressureUnit,
  snowfallUnit,
  temperatureUnit,
  windSpeedUnit,
} from "../src/units.js";

describe("metric", () => {
  it("passes values through unchanged", () => {
    expect(convertTemperatureC("metric", 20.0)).toBeCloseTo(20.0, 9);
    expect(convertMm("metric", 10.0)).toBeCloseTo(10.0, 9);
    expect(convertCm("metric", 5.0)).toBeCloseTo(5.0, 9);
    expect(convertKmh("metric", 100.0)).toBeCloseTo(100.0, 9);
    expect(convertHpa("metric", 1013.0)).toBeCloseTo(1013.0, 9);
  });

  it("units are the metric labels", () => {
    expect(temperatureUnit("metric")).toBe("°C");
    expect(precipitationUnit("metric")).toBe("mm");
    expect(snowfallUnit("metric")).toBe("cm");
    expect(windSpeedUnit("metric")).toBe("km/h");
    expect(pressureUnit("metric")).toBe("hPa");
  });
});

describe("imperial", () => {
  it("converts temperature C -> F", () => {
    expect(convertTemperatureC("imperial", 0.0)).toBeCloseTo(32.0, 9);
    expect(convertTemperatureC("imperial", 100.0)).toBeCloseTo(212.0, 9);
    expect(convertTemperatureC("imperial", 20.0)).toBeCloseTo(68.0, 9);
  });

  it("converts mm -> inches", () => {
    expect(convertMm("imperial", 25.4)).toBeCloseTo(1.0, 9);
  });

  it("converts cm -> inches", () => {
    expect(convertCm("imperial", 2.54)).toBeCloseTo(1.0, 9);
  });

  it("converts km/h -> mph", () => {
    expect(convertKmh("imperial", 100.0)).toBeCloseTo(62.1371, 4);
  });

  it("converts hPa -> inHg", () => {
    expect(convertHpa("imperial", 1013.25)).toBeCloseTo(29.92, 2);
  });

  it("units are the imperial labels", () => {
    expect(temperatureUnit("imperial")).toBe("°F");
    expect(precipitationUnit("imperial")).toBe("in");
    expect(snowfallUnit("imperial")).toBe("in");
    expect(windSpeedUnit("imperial")).toBe("mph");
    expect(pressureUnit("imperial")).toBe("inHg");
  });
});

describe("null handling", () => {
  it("conversions pass through null for both unit systems", () => {
    for (const u of ["metric", "imperial"] as const) {
      expect(convertTemperatureC(u, null)).toBeNull();
      expect(convertMm(u, null)).toBeNull();
      expect(convertCm(u, null)).toBeNull();
      expect(convertKmh(u, null)).toBeNull();
      expect(convertHpa(u, null)).toBeNull();
    }
  });
});
