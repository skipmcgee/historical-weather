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
  final shortwaveRadiation = _doubles(daily['shortwave_radiation_sum']);
  final sunshineDurationSeconds = _doubles(daily['sunshine_duration']);

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
    medianShortwaveRadiationMjm2: _median(shortwaveRadiation),
    medianSunshineHours: _median(sunshineDurationSeconds, scale: 1 / 3600),
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
