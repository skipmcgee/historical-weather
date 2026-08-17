import type { AggregationMethod, Location, WeatherSummary } from "./types.js";

/**
 * Turns the raw `daily` block of an Open-Meteo archive response into a
 * WeatherSummary, collapsing each per-day metric via `method` (median or
 * mean). Precipitation/snowfall/ET0 totals are always sums regardless of
 * `method`. Missing (null) values for a given day are skipped rather than
 * treated as zero -- data coverage varies across the archive (older dates
 * use a coarser reanalysis model, and the most recent few days may not be
 * processed yet), so this keeps results meaningful regardless of which
 * date range was requested.
 *
 * Direct port of lib/services/weather_aggregator.dart -- see that file for
 * the original design notes.
 */
export function aggregateDailyArchive(params: {
  location: Location;
  startDate: string;
  endDate: string;
  daily: Record<string, unknown>;
  method: AggregationMethod;
}): WeatherSummary {
  const { location, startDate, endDate, daily, method } = params;

  const times = Array.isArray(daily.time) ? (daily.time as unknown[]) : [];
  const highs = doubles(daily.temperature_2m_max);
  const lows = doubles(daily.temperature_2m_min);
  const precipitation = doubles(daily.precipitation_sum);
  const rain = doubles(daily.rain_sum);
  const snowfall = doubles(daily.snowfall_sum);
  const windSpeedMax = doubles(daily.wind_speed_10m_max);
  const windGustsMax = doubles(daily.wind_gusts_10m_max);
  const windDirection = doubles(daily.wind_direction_10m_dominant);
  const relativeHumidity = doubles(daily.relative_humidity_2m_mean);
  const dewPoint = doubles(daily.dew_point_2m_mean);
  const cloudCover = doubles(daily.cloud_cover_mean);
  const surfacePressure = doubles(daily.surface_pressure_mean);
  const shortwaveRadiation = doubles(daily.shortwave_radiation_sum);
  const sunshineDurationSeconds = doubles(daily.sunshine_duration);
  const et0 = doubles(daily.et0_fao_evapotranspiration);
  const soilMoisture0To7 = doubles(daily.soil_moisture_0_to_7cm_mean);
  const soilMoisture7To28 = doubles(daily.soil_moisture_7_to_28cm_mean);
  const soilMoisture28To100 = doubles(daily.soil_moisture_28_to_100cm_mean);
  const soilTemp0To7 = doubles(daily.soil_temperature_0_to_7cm_mean);
  const soilTemp7To28 = doubles(daily.soil_temperature_7_to_28cm_mean);
  const soilTemp28To100 = doubles(daily.soil_temperature_28_to_100cm_mean);

  const dailyMeans: number[] = [];
  for (let i = 0; i < highs.length && i < lows.length; i++) {
    const high = highs[i];
    const low = lows[i];
    if (high != null && low != null) dailyMeans.push((high + low) / 2);
  }

  const c = (values: Array<number | null>, scale = 1) => central(values, method, scale);

  return {
    location,
    startDate,
    endDate,
    dayCount: times.length,
    method,
    highC: c(highs),
    lowC: c(lows),
    meanC: c(dailyMeans),
    totalPrecipitationMm: sumOrNull(precipitation),
    precipitationPerDayMm: c(precipitation),
    totalRainMm: sumOrNull(rain),
    totalSnowfallCm: sumOrNull(snowfall),
    windSpeedMaxKmh: c(windSpeedMax),
    windGustsMaxKmh: c(windGustsMax),
    windDirectionDeg: circularMeanDegrees(windDirection),
    relativeHumidityPercent: c(relativeHumidity),
    dewPointC: c(dewPoint),
    cloudCoverPercent: c(cloudCover),
    surfacePressureHpa: c(surfacePressure),
    shortwaveRadiationMjm2: c(shortwaveRadiation),
    sunshineHours: c(sunshineDurationSeconds, 1 / 3600),
    totalEt0Mm: sumOrNull(et0),
    et0MmPerDay: c(et0),
    soilMoisture0To7cm: c(soilMoisture0To7),
    soilMoisture7To28cm: c(soilMoisture7To28),
    soilMoisture28To100cm: c(soilMoisture28To100),
    soilTemp0To7cmC: c(soilTemp0To7),
    soilTemp7To28cmC: c(soilTemp7To28),
    soilTemp28To100cmC: c(soilTemp28To100),
  };
}

/** False when every metric came back null -- e.g. a date range Open-Meteo
 * simply has no data for. Callers should treat this as "no data found"
 * rather than returning a result full of nulls. */
export function hasAnyData(summary: WeatherSummary): boolean {
  const fields: Array<number | null> = [
    summary.highC,
    summary.lowC,
    summary.meanC,
    summary.totalPrecipitationMm,
    summary.precipitationPerDayMm,
    summary.totalRainMm,
    summary.totalSnowfallCm,
    summary.windSpeedMaxKmh,
    summary.windGustsMaxKmh,
    summary.windDirectionDeg,
    summary.relativeHumidityPercent,
    summary.dewPointC,
    summary.cloudCoverPercent,
    summary.surfacePressureHpa,
    summary.shortwaveRadiationMjm2,
    summary.sunshineHours,
    summary.totalEt0Mm,
    summary.et0MmPerDay,
    summary.soilMoisture0To7cm,
    summary.soilMoisture7To28cm,
    summary.soilMoisture28To100cm,
    summary.soilTemp0To7cmC,
    summary.soilTemp7To28cmC,
    summary.soilTemp28To100cmC,
  ];
  return fields.some((v) => v != null);
}

function doubles(raw: unknown): Array<number | null> {
  if (!Array.isArray(raw)) return [];
  return raw.map((v) => (v == null ? null : Number(v)));
}

function sum(values: number[]): number {
  return values.reduce((a, b) => a + b, 0);
}

function sumOrNull(values: Array<number | null>): number | null {
  const present = values.filter((v): v is number => v != null);
  return present.length === 0 ? null : sum(present);
}

function median(values: Array<number | null>, scale = 1): number | null {
  const present = values
    .filter((v): v is number => v != null)
    .slice()
    .sort((a, b) => a - b);
  if (present.length === 0) return null;
  const mid = Math.floor(present.length / 2);
  const med = present.length % 2 === 1 ? present[mid] : (present[mid - 1] + present[mid]) / 2;
  return med * scale;
}

function mean(values: Array<number | null>, scale = 1): number | null {
  const present = values.filter((v): v is number => v != null);
  if (present.length === 0) return null;
  return (sum(present) / present.length) * scale;
}

function central(values: Array<number | null>, method: AggregationMethod, scale = 1): number | null {
  return method === "median" ? median(values, scale) : mean(values, scale);
}

/**
 * Averages a set of compass directions (degrees) via vector sum rather
 * than a plain numeric median/mean -- 350deg and 10deg should average to
 * ~0deg, not 180deg. Returns null if the vectors cancel out exactly (e.g.
 * an even split between opposite directions), since no single direction is
 * representative in that case. Not affected by AggregationMethod: this is
 * the only sensible way to average a direction, regardless of whether the
 * rest of the summary uses medians or means.
 */
function circularMeanDegrees(values: Array<number | null>): number | null {
  const present = values.filter((v): v is number => v != null);
  if (present.length === 0) return null;
  let x = 0;
  let y = 0;
  for (const degrees of present) {
    const radians = (degrees * Math.PI) / 180;
    x += Math.cos(radians);
    y += Math.sin(radians);
  }
  if (Math.abs(x) < 1e-9 && Math.abs(y) < 1e-9) return null;
  const meanRadians = Math.atan2(y, x);
  const meanDegrees = (meanRadians * 180) / Math.PI;
  return ((meanDegrees % 360) + 360) % 360;
}
