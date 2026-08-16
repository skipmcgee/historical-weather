import 'location.dart';

/// Median/summed historical weather for a location over a date range,
/// computed from Open-Meteo's daily archive values. Medians (rather than
/// means) are used for the per-day metrics so a handful of extreme days
/// don't skew the "typical" values shown to the user; the precipitation/
/// snowfall/evapotranspiration totals are plain sums, since a total over
/// the period is what makes sense there. [medianWindDirectionDeg] is the
/// one exception: wind direction is circular (0deg and 360deg are the same
/// heading), so a plain numeric median would be meaningless — it's
/// aggregated as a circular mean instead, which is the standard way to
/// average a direction.
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
    this.medianWindDirectionDeg,
    this.medianRelativeHumidityPercent,
    this.medianDewPointC,
    this.medianCloudCoverPercent,
    this.medianSurfacePressureHpa,
    this.medianShortwaveRadiationMjm2,
    this.medianSunshineHours,
    this.totalEt0Mm,
    this.medianEt0MmPerDay,
    this.medianSoilMoisture0To7cm,
    this.medianSoilMoisture7To28cm,
    this.medianSoilMoisture28To100cm,
    this.medianSoilTemp0To7cmC,
    this.medianSoilTemp7To28cmC,
    this.medianSoilTemp28To100cmC,
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
  final double? medianWindDirectionDeg;
  final double? medianRelativeHumidityPercent;
  final double? medianDewPointC;
  final double? medianCloudCoverPercent;
  final double? medianSurfacePressureHpa;
  final double? medianShortwaveRadiationMjm2;
  final double? medianSunshineHours;
  final double? totalEt0Mm;
  final double? medianEt0MmPerDay;
  final double? medianSoilMoisture0To7cm;
  final double? medianSoilMoisture7To28cm;
  final double? medianSoilMoisture28To100cm;
  final double? medianSoilTemp0To7cmC;
  final double? medianSoilTemp7To28cmC;
  final double? medianSoilTemp28To100cmC;

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
    medianWindDirectionDeg,
    medianRelativeHumidityPercent,
    medianDewPointC,
    medianCloudCoverPercent,
    medianSurfacePressureHpa,
    medianShortwaveRadiationMjm2,
    medianSunshineHours,
    totalEt0Mm,
    medianEt0MmPerDay,
    medianSoilMoisture0To7cm,
    medianSoilMoisture7To28cm,
    medianSoilMoisture28To100cm,
    medianSoilTemp0To7cmC,
    medianSoilTemp7To28cmC,
    medianSoilTemp28To100cmC,
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
      'atmosphere': {
        'median_relative_humidity_percent': medianRelativeHumidityPercent,
        'median_dew_point_c': medianDewPointC,
        'median_cloud_cover_percent': medianCloudCoverPercent,
        'median_surface_pressure_hpa': medianSurfacePressureHpa,
      },
      'wind': {
        'median_max_speed_kmh': medianWindSpeedMaxKmh,
        'median_max_gusts_kmh': medianWindGustsMaxKmh,
        'median_direction_deg': medianWindDirectionDeg,
      },
      'sun': {
        'median_shortwave_radiation_mj_m2': medianShortwaveRadiationMjm2,
        'median_sunshine_hours': medianSunshineHours,
      },
      'evapotranspiration_mm': {
        'total': totalEt0Mm,
        'median_per_day': medianEt0MmPerDay,
      },
      'soil': {
        'moisture_m3_m3': {
          '0_to_7cm': medianSoilMoisture0To7cm,
          '7_to_28cm': medianSoilMoisture7To28cm,
          '28_to_100cm': medianSoilMoisture28To100cm,
        },
        'temperature_c': {
          '0_to_7cm': medianSoilTemp0To7cmC,
          '7_to_28cm': medianSoilTemp7To28cmC,
          '28_to_100cm': medianSoilTemp28To100cmC,
        },
      },
      'source': 'Open-Meteo Historical Weather API (archive-api.open-meteo.com)',
    };
  }
}
