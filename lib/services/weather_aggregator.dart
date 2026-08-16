import '../models/location.dart';
import '../models/weather_summary.dart';

/// Turns the raw `daily` block of an Open-Meteo archive response into a
/// [WeatherSummary] by averaging/summing over all days present. Missing
/// (null) values for a given day are skipped rather than treated as zero.
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
    avgHighC: _average(highs),
    avgLowC: _average(lows),
    avgMeanC: dailyMeans.isEmpty ? null : _sum(dailyMeans) / dailyMeans.length,
    totalPrecipitationMm: _sumOrNull(precipitation),
    avgPrecipitationMm: _average(precipitation),
    totalRainMm: _sumOrNull(rain),
    totalSnowfallCm: _sumOrNull(snowfall),
    avgWindSpeedMaxKmh: _average(windSpeedMax),
    avgWindGustsMaxKmh: _average(windGustsMax),
    avgShortwaveRadiationMjm2: _average(shortwaveRadiation),
    avgSunshineHours: _average(sunshineDurationSeconds, scale: 1 / 3600),
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

double? _average(List<double?> values, {double scale = 1}) {
  final present = values.whereType<double>();
  if (present.isEmpty) return null;
  return (_sum(present) / present.length) * scale;
}
