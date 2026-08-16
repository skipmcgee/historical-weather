import 'dart:math' as math;

import '../models/location.dart';
import '../models/weather_summary.dart';

/// Turns the raw `daily` block of an Open-Meteo archive response into a
/// [WeatherSummary]. Per-day metrics use the median (not the mean) so a
/// handful of outlier days don't skew the "typical" value shown to the
/// user; precipitation/snowfall totals are sums. Missing (null) values for
/// a given day are skipped rather than treated as zero — data coverage
/// varies across the archive (older dates use a coarser reanalysis model,
/// and the most recent few days may not be processed yet), so this keeps
/// results meaningful regardless of which date range was requested.
WeatherSummary aggregateDailyArchive({
  required Location location,
  required DateTime startDate,
  required DateTime endDate,
  required Map<String, dynamic> daily,
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

  return WeatherSummary(
    location: location,
    startDate: startDate,
    endDate: endDate,
    dayCount: times.length,
    medianHighC: _median(highs),
    medianLowC: _median(lows),
    medianMeanC: _median(dailyMeans.map((v) => v as double?).toList()),
    totalPrecipitationMm: _sumOrNull(precipitation),
    medianPrecipitationMm: _median(precipitation),
    totalRainMm: _sumOrNull(rain),
    totalSnowfallCm: _sumOrNull(snowfall),
    medianWindSpeedMaxKmh: _median(windSpeedMax),
    medianWindGustsMaxKmh: _median(windGustsMax),
    medianWindDirectionDeg: _circularMeanDegrees(windDirection),
    medianRelativeHumidityPercent: _median(relativeHumidity),
    medianDewPointC: _median(dewPoint),
    medianCloudCoverPercent: _median(cloudCover),
    medianSurfacePressureHpa: _median(surfacePressure),
    medianShortwaveRadiationMjm2: _median(shortwaveRadiation),
    medianSunshineHours: _median(sunshineDurationSeconds, scale: 1 / 3600),
    totalEt0Mm: _sumOrNull(et0),
    medianEt0MmPerDay: _median(et0),
    medianSoilMoisture0To7cm: _median(soilMoisture0To7),
    medianSoilMoisture7To28cm: _median(soilMoisture7To28),
    medianSoilMoisture28To100cm: _median(soilMoisture28To100),
    medianSoilTemp0To7cmC: _median(soilTemp0To7),
    medianSoilTemp7To28cmC: _median(soilTemp7To28),
    medianSoilTemp28To100cmC: _median(soilTemp28To100),
  );
}

List<double?> _doubles(dynamic rawList) {
  if (rawList is! List) return const [];
  return rawList.map((v) => v == null ? null : (v as num).toDouble()).toList(growable: false);
}

double _sum(Iterable<double> values) => values.fold(0.0, (a, b) => a + b);

double? _sumOrNull(List<double?> values) {
  final present = values.whereType<double>();
  return present.isEmpty ? null : _sum(present);
}

double? _median(List<double?> values, {double scale = 1}) {
  final present = values.whereType<double>().toList()..sort();
  if (present.isEmpty) return null;
  final mid = present.length ~/ 2;
  final median = present.length.isOdd ? present[mid] : (present[mid - 1] + present[mid]) / 2;
  return median * scale;
}

/// Averages a set of compass directions (degrees) via vector sum rather
/// than a plain numeric median/mean — 350deg and 10deg should average to
/// ~0deg, not 180deg. Returns null if the vectors cancel out exactly
/// (e.g. an even split between opposite directions), since no single
/// direction is representative in that case.
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
