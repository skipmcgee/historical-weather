import 'dart:math' as math;

import '../models/aggregation_method.dart';
import '../models/location.dart';
import '../models/weather_summary.dart';

/// Turns the raw `daily` block of an Open-Meteo archive response into a
/// [WeatherSummary], collapsing each per-day metric via [method] (median or
/// mean). Precipitation/snowfall/ET0 totals are always sums regardless of
/// [method]. Missing (null) values for a given day are skipped rather than
/// treated as zero — data coverage varies across the archive (older dates
/// use a coarser reanalysis model, and the most recent few days may not be
/// processed yet), so this keeps results meaningful regardless of which
/// date range was requested.
WeatherSummary aggregateDailyArchive({
  required Location location,
  required DateTime startDate,
  required DateTime endDate,
  required Map<String, dynamic> daily,
  required AggregationMethod method,
}) {
  final times = (daily['time'] as List<dynamic>? ?? const []);
  final highs = _doubles(daily['temperature_2m_max']);
  final lows = _doubles(daily['temperature_2m_min']);
  final precipitation = _doubles(daily['precipitation_sum']);
  final rain = _doubles(daily['rain_sum']);
  final snowfall = _doubles(daily['snowfall_sum']);
  final windSpeedMax = _doubles(daily['wind_speed_10m_max']);
  final windGustsMax = _doubles(daily['wind_gusts_10m_max']);
  final windDirection = _doubles(daily['wind_direction_10m_dominant']);
  final relativeHumidity = _doubles(daily['relative_humidity_2m_mean']);
  final dewPoint = _doubles(daily['dew_point_2m_mean']);
  final cloudCover = _doubles(daily['cloud_cover_mean']);
  final surfacePressure = _doubles(daily['surface_pressure_mean']);
  final shortwaveRadiation = _doubles(daily['shortwave_radiation_sum']);
  final sunshineDurationSeconds = _doubles(daily['sunshine_duration']);
  final et0 = _doubles(daily['et0_fao_evapotranspiration']);
  final soilMoisture0To7 = _doubles(daily['soil_moisture_0_to_7cm_mean']);
  final soilMoisture7To28 = _doubles(daily['soil_moisture_7_to_28cm_mean']);
  final soilMoisture28To100 = _doubles(daily['soil_moisture_28_to_100cm_mean']);
  final soilTemp0To7 = _doubles(daily['soil_temperature_0_to_7cm_mean']);
  final soilTemp7To28 = _doubles(daily['soil_temperature_7_to_28cm_mean']);
  final soilTemp28To100 = _doubles(daily['soil_temperature_28_to_100cm_mean']);

  final dailyMeans = <double>[];
  for (var i = 0; i < highs.length && i < lows.length; i++) {
    final high = highs[i];
    final low = lows[i];
    if (high != null && low != null) dailyMeans.add((high + low) / 2);
  }

  double? central(List<double?> values, {double scale = 1}) =>
      _central(values, method, scale: scale);

  return WeatherSummary(
    location: location,
    startDate: startDate,
    endDate: endDate,
    dayCount: times.length,
    method: method,
    highC: central(highs),
    lowC: central(lows),
    meanC: central(dailyMeans.map((v) => v as double?).toList()),
    totalPrecipitationMm: _sumOrNull(precipitation),
    precipitationPerDayMm: central(precipitation),
    totalRainMm: _sumOrNull(rain),
    totalSnowfallCm: _sumOrNull(snowfall),
    windSpeedMaxKmh: central(windSpeedMax),
    windGustsMaxKmh: central(windGustsMax),
    windDirectionDeg: _circularMeanDegrees(windDirection),
    relativeHumidityPercent: central(relativeHumidity),
    dewPointC: central(dewPoint),
    cloudCoverPercent: central(cloudCover),
    surfacePressureHpa: central(surfacePressure),
    shortwaveRadiationMjm2: central(shortwaveRadiation),
    sunshineHours: central(sunshineDurationSeconds, scale: 1 / 3600),
    totalEt0Mm: _sumOrNull(et0),
    et0MmPerDay: central(et0),
    soilMoisture0To7cm: central(soilMoisture0To7),
    soilMoisture7To28cm: central(soilMoisture7To28),
    soilMoisture28To100cm: central(soilMoisture28To100),
    soilTemp0To7cmC: central(soilTemp0To7),
    soilTemp7To28cmC: central(soilTemp7To28),
    soilTemp28To100cmC: central(soilTemp28To100),
  );
}

List<double?> _doubles(dynamic rawList) {
  if (rawList is! List) return const [];
  // A malformed/unexpected entry (a future Open-Meteo schema change, a
  // non-numeric sentinel) is treated the same as a missing day rather than
  // throwing, since `num` values are already skipped as null elsewhere in
  // this file when a day's data is incomplete.
  return rawList.map((v) => v is num ? v.toDouble() : null).toList(growable: false);
}

double _sum(Iterable<double> values) => values.fold(0.0, (a, b) => a + b);

double? _sumOrNull(List<double?> values) {
  final present = values.whereType<double>();
  return present.isEmpty ? null : _sum(present);
}

double? _central(List<double?> values, AggregationMethod method, {double scale = 1}) {
  return method == AggregationMethod.median ? _median(values, scale: scale) : _mean(values, scale: scale);
}

double? _median(List<double?> values, {double scale = 1}) {
  final present = values.whereType<double>().toList()..sort();
  if (present.isEmpty) return null;
  final mid = present.length ~/ 2;
  final median = present.length.isOdd ? present[mid] : (present[mid - 1] + present[mid]) / 2;
  return median * scale;
}

double? _mean(List<double?> values, {double scale = 1}) {
  final present = values.whereType<double>();
  if (present.isEmpty) return null;
  return (_sum(present) / present.length) * scale;
}

/// Averages a set of compass directions (degrees) via vector sum rather
/// than a plain numeric median/mean — 350deg and 10deg should average to
/// ~0deg, not 180deg. Returns null if the vectors cancel out exactly
/// (e.g. an even split between opposite directions), since no single
/// direction is representative in that case. Not affected by
/// [AggregationMethod]: this is the only sensible way to average a
/// direction, regardless of whether the rest of the summary uses medians
/// or means.
double? _circularMeanDegrees(List<double?> values) {
  final present = values.whereType<double>();
  if (present.isEmpty) return null;
  var x = 0.0, y = 0.0;
  for (final degrees in present) {
    final radians = degrees * math.pi / 180;
    x += math.cos(radians);
    y += math.sin(radians);
  }
  if (x.abs() < 1e-9 && y.abs() < 1e-9) return null;
  final meanRadians = math.atan2(y, x);
  final meanDegrees = meanRadians * 180 / math.pi;
  return (meanDegrees + 360) % 360;
}
