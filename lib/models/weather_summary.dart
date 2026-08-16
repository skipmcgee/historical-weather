import 'location.dart';

/// Averaged/summed historical weather for a location over a date range,
/// computed from Open-Meteo's daily archive values.
class WeatherSummary {
  WeatherSummary({
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.dayCount,
    this.avgHighC,
    this.avgLowC,
    this.avgMeanC,
    this.totalPrecipitationMm,
    this.avgPrecipitationMm,
    this.totalRainMm,
    this.totalSnowfallCm,
    this.avgWindSpeedMaxKmh,
    this.avgWindGustsMaxKmh,
    this.avgShortwaveRadiationMjm2,
    this.avgSunshineHours,
  });

  final Location location;
  final DateTime startDate;
  final DateTime endDate;
  final int dayCount;

  final double? avgHighC;
  final double? avgLowC;
  final double? avgMeanC;
  final double? totalPrecipitationMm;
  final double? avgPrecipitationMm;
  final double? totalRainMm;
  final double? totalSnowfallCm;
  final double? avgWindSpeedMaxKmh;
  final double? avgWindGustsMaxKmh;
  final double? avgShortwaveRadiationMjm2;
  final double? avgSunshineHours;

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() {
    return {
      'location': {
        'name': location.displayLabel,
        'latitude': location.latitude,
        'longitude': location.longitude,
        if (location.timezone != null) 'timezone': location.timezone,
      },
      'period': {
        'start_date': _isoDate(startDate),
        'end_date': _isoDate(endDate),
        'day_count': dayCount,
      },
      'temperature_c': {
        'avg_high': avgHighC,
        'avg_low': avgLowC,
        'avg_mean': avgMeanC,
      },
      'precipitation_mm': {
        'total': totalPrecipitationMm,
        'avg_per_day': avgPrecipitationMm,
        'total_rain': totalRainMm,
      },
      'snowfall_cm': {
        'total': totalSnowfallCm,
      },
      'wind_kmh': {
        'avg_max_speed': avgWindSpeedMaxKmh,
        'avg_max_gusts': avgWindGustsMaxKmh,
      },
      'sun': {
        'avg_shortwave_radiation_mj_m2': avgShortwaveRadiationMjm2,
        'avg_sunshine_hours': avgSunshineHours,
      },
      'source': 'Open-Meteo Historical Weather API (archive-api.open-meteo.com)',
    };
  }
}
