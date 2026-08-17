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
} from "./units.js";
import type { Location, UnitSystem, WeatherSummary } from "./types.js";

/**
 * Serializes a WeatherSummary to the same JSON shape as
 * lib/models/weather_summary.dart's WeatherSummary.toJson() -- this is the
 * app's canonical "same data" contract (what the Flutter app's copy-paste
 * JSON panel shows), reproduced field-for-field including per-section unit
 * labels and rounding.
 */
export function weatherSummaryToJson(
  summary: WeatherSummary,
  unitSystem: UnitSystem = "metric",
): Record<string, unknown> {
  const u = unitSystem;
  return {
    location: {
      name: displayLabel(summary.location),
      latitude: summary.location.latitude,
      longitude: summary.location.longitude,
      ...(summary.location.timezone ? { timezone: summary.location.timezone } : {}),
    },
    period: {
      start_date: summary.startDate,
      end_date: summary.endDate,
      day_count: summary.dayCount,
    },
    // How the fields below (other than totals and wind direction, which
    // are always a sum / circular mean respectively) were aggregated.
    method: summary.method,
    unit_system: u,
    temperature: {
      unit: temperatureUnit(u),
      high: round(convertTemperatureC(u, summary.highC), 1),
      low: round(convertTemperatureC(u, summary.lowC), 1),
      mean: round(convertTemperatureC(u, summary.meanC), 1),
    },
    precipitation: {
      unit: precipitationUnit(u),
      total: round(convertMm(u, summary.totalPrecipitationMm), 2),
      per_day: round(convertMm(u, summary.precipitationPerDayMm), 2),
      total_rain: round(convertMm(u, summary.totalRainMm), 2),
    },
    snowfall: {
      unit: snowfallUnit(u),
      total: round(convertCm(u, summary.totalSnowfallCm), 2),
    },
    atmosphere: {
      relative_humidity_percent: summary.relativeHumidityPercent,
      dew_point_unit: temperatureUnit(u),
      dew_point: round(convertTemperatureC(u, summary.dewPointC), 1),
      cloud_cover_percent: summary.cloudCoverPercent,
      surface_pressure_unit: pressureUnit(u),
      surface_pressure: round(convertHpa(u, summary.surfacePressureHpa), 2),
    },
    wind: {
      speed_unit: windSpeedUnit(u),
      max_speed: round(convertKmh(u, summary.windSpeedMaxKmh), 1),
      max_gusts: round(convertKmh(u, summary.windGustsMaxKmh), 1),
      // Always a circular mean, regardless of `method`; degrees are
      // unit-system-agnostic.
      direction_deg: round(summary.windDirectionDeg, 0),
    },
    sun: {
      shortwave_radiation_mj_m2: summary.shortwaveRadiationMjm2,
      sunshine_hours: summary.sunshineHours,
    },
    evapotranspiration: {
      unit: precipitationUnit(u),
      total: round(convertMm(u, summary.totalEt0Mm), 2),
      per_day: round(convertMm(u, summary.et0MmPerDay), 3),
    },
    soil: {
      // Volumetric water content is a dimensionless ratio -- not affected
      // by the unit system.
      moisture_m3_m3: {
        "0_to_7cm": summary.soilMoisture0To7cm,
        "7_to_28cm": summary.soilMoisture7To28cm,
        "28_to_100cm": summary.soilMoisture28To100cm,
      },
      temperature_unit: temperatureUnit(u),
      temperature: {
        "0_to_7cm": round(convertTemperatureC(u, summary.soilTemp0To7cmC), 1),
        "7_to_28cm": round(convertTemperatureC(u, summary.soilTemp7To28cmC), 1),
        "28_to_100cm": round(convertTemperatureC(u, summary.soilTemp28To100cmC), 1),
      },
    },
    source: "Open-Meteo Historical Weather API (archive-api.open-meteo.com)",
  };
}

function displayLabel(location: Location): string {
  if (location.manual) return location.name;
  return [location.name, location.admin1, location.country].filter((p): p is string => !!p).join(", ");
}

function round(value: number | null, decimals: number): number | null {
  if (value == null) return null;
  const factor = decimals === 0 ? 1 : decimals === 1 ? 10 : decimals === 2 ? 100 : 1000;
  return Math.round(value * factor) / factor;
}
