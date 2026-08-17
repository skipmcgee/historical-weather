/** How the per-day metrics are collapsed into a single figure. Mirrors
 * lib/models/aggregation_method.dart in the Flutter app. */
export type AggregationMethod = "median" | "average";

/** Mirrors lib/models/unit_system.dart. */
export type UnitSystem = "metric" | "imperial";

/** Mirrors lib/models/location.dart. */
export interface Location {
  name: string;
  latitude: number;
  longitude: number;
  admin1?: string;
  country?: string;
  timezone?: string;
  /** True for coordinates entered/resolved directly rather than picked from
   * a geocoding search result (mirrors Location.manual in the Dart model). */
  manual: boolean;
}

/**
 * Aggregated historical weather for a location over a date range. Mirrors
 * lib/models/weather_summary.dart's WeatherSummary class field-for-field
 * (always metric internally; conversion happens only when serializing to
 * JSON via weatherSummaryToJson). Totals are always sums and
 * windDirectionDeg is always a circular mean, regardless of `method`.
 */
export interface WeatherSummary {
  location: Location;
  startDate: string;
  endDate: string;
  dayCount: number;
  method: AggregationMethod;

  highC: number | null;
  lowC: number | null;
  meanC: number | null;
  totalPrecipitationMm: number | null;
  precipitationPerDayMm: number | null;
  totalRainMm: number | null;
  totalSnowfallCm: number | null;
  windSpeedMaxKmh: number | null;
  windGustsMaxKmh: number | null;
  windDirectionDeg: number | null;
  relativeHumidityPercent: number | null;
  dewPointC: number | null;
  cloudCoverPercent: number | null;
  surfacePressureHpa: number | null;
  shortwaveRadiationMjm2: number | null;
  sunshineHours: number | null;
  totalEt0Mm: number | null;
  et0MmPerDay: number | null;
  soilMoisture0To7cm: number | null;
  soilMoisture7To28cm: number | null;
  soilMoisture28To100cm: number | null;
  soilTemp0To7cmC: number | null;
  soilTemp7To28cmC: number | null;
  soilTemp28To100cmC: number | null;
}
