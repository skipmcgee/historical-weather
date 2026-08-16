import 'location.dart';

/// Median/summed historical weather for a location over a date range,
/// computed from Open-Meteo's daily archive values. Medians (rather than
/// means) are used for the per-day metrics so a handful of extreme days
/// don't skew the "typical" values shown to the user; the precipitation/
/// snowfall totals are plain sums, since a total over the period is what
/// makes sense there.
class WeatherSummary {
  WeatherSummary({
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.dayCount,
    this.medianHighC,
    this.medianLowC,
    this.medianMeanC,
    this.totalPrecipitationMm,
    this.medianPrecipitationMm,
    this.totalRainMm,
    this.totalSnowfallCm,
    this.medianWindSpeedMaxKmh,
    this.medianWindGustsMaxKmh,
    this.medianShortwaveRadiationMjm2,
    this.medianSunshineHours,
  });

  final Location location;
  final DateTime startDate;
  final DateTime endDate;
  final int dayCount;

  final double? medianHighC;
  final double? medianLowC;
  final double? medianMeanC;
  final double? totalPrecipitationMm;
  final double? medianPrecipitationMm;
  final double? totalRainMm;
  final double? totalSnowfallCm;
  final double? medianWindSpeedMaxKmh;
  final double? medianWindGustsMaxKmh;
  final double? medianShortwaveRadiationMjm2;
  final double? medianSunshineHours;

  /// False when every metric came back null — e.g. a date range Open-Meteo
  /// simply has no data for. Callers should treat this as "no data found"
  /// rather than rendering a card full of dashes.
  bool get hasAnyData => [
    medianHighC,
    medianLowC,
    medianMeanC,
    totalPrecipitationMm,
    medianPrecipitationMm,
    totalRainMm,
    totalSnowfallCm,
    medianWindSpeedMaxKmh,
    medianWindGustsMaxKmh,
    medianShortwaveRadiationMjm2,
    medianSunshineHours,
  ].any((v) => v != null);

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
        'median_high': medianHighC,
        'median_low': medianLowC,
        'median_mean': medianMeanC,
      },
      'precipitation_mm': {
        'total': totalPrecipitationMm,
        'median_per_day': medianPrecipitationMm,
        'total_rain': totalRainMm,
      },
      'snowfall_cm': {
        'total': totalSnowfallCm,
      },
      'wind_kmh': {
        'median_max_speed': medianWindSpeedMaxKmh,
        'median_max_gusts': medianWindGustsMaxKmh,
      },
      'sun': {
        'median_shortwave_radiation_mj_m2': medianShortwaveRadiationMjm2,
        'median_sunshine_hours': medianSunshineHours,
      },
      'source': 'Open-Meteo Historical Weather API (archive-api.open-meteo.com)',
    };
  }
}
