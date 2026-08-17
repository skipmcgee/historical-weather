import type { UnitSystem } from "./types.js";

/**
 * Display/output unit conversions. Mirrors lib/models/unit_system.dart's
 * UnitConversions extension exactly (same conversion factors) --
 * WeatherSummary always stores canonical metric values; conversion happens
 * only here, at the JSON-export boundary.
 */

const isMetric = (u: UnitSystem) => u === "metric";

export function temperatureUnit(u: UnitSystem): string {
  return isMetric(u) ? "°C" : "°F";
}

export function convertTemperatureC(u: UnitSystem, celsius: number | null): number | null {
  if (celsius == null) return null;
  return isMetric(u) ? celsius : (celsius * 9) / 5 + 32;
}

export function precipitationUnit(u: UnitSystem): string {
  return isMetric(u) ? "mm" : "in";
}

export function convertMm(u: UnitSystem, mm: number | null): number | null {
  if (mm == null) return null;
  return isMetric(u) ? mm : mm / 25.4;
}

export function snowfallUnit(u: UnitSystem): string {
  return isMetric(u) ? "cm" : "in";
}

export function convertCm(u: UnitSystem, cm: number | null): number | null {
  if (cm == null) return null;
  return isMetric(u) ? cm : cm / 2.54;
}

export function windSpeedUnit(u: UnitSystem): string {
  return isMetric(u) ? "km/h" : "mph";
}

export function convertKmh(u: UnitSystem, kmh: number | null): number | null {
  if (kmh == null) return null;
  return isMetric(u) ? kmh : kmh * 0.621371;
}

export function pressureUnit(u: UnitSystem): string {
  return isMetric(u) ? "hPa" : "inHg";
}

export function convertHpa(u: UnitSystem, hpa: number | null): number | null {
  if (hpa == null) return null;
  return isMetric(u) ? hpa : hpa * 0.02953;
}
