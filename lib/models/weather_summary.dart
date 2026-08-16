import 'aggregation_method.dart';
import 'location.dart';
import 'unit_system.dart';

/// Aggregated historical weather for a location over a date range, computed
/// from Open-Meteo's daily archive values. Internally always stored in
/// metric (that's what Open-Meteo returns and what gets cached) --
/// [toJson] takes a [UnitSystem] and converts at export time, so switching
/// units in the UI never requires a re-fetch.
///
/// [method] controls whether the per-day fields below are the median or the
/// arithmetic mean across the range -- the median is the default (a handful
/// of extreme days don't skew it the way they would a mean), but the mean
/// is offered as an option since some users want the literal average
/// instead. The precipitation/snowfall/evapotranspiration totals are plain
/// sums regardless of [method], since a total over the period is what makes
/// sense there. [windDirectionDeg] is the one field [method] doesn't
/// affect: wind direction is circular (0deg and 360deg are the same
/// heading), so a plain median/mean of the raw degrees would be
/// meaningless -- it's always a circular mean, the standard way to average
/// a direction.
class WeatherSummary {
  WeatherSummary({
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.dayCount,
    required this.method,
    this.highC,
    this.lowC,
    this.meanC,
    this.totalPrecipitationMm,
    this.precipitationPerDayMm,
    this.totalRainMm,
    this.totalSnowfallCm,
    this.windSpeedMaxKmh,
    this.windGustsMaxKmh,
    this.windDirectionDeg,
    this.relativeHumidityPercent,
    this.dewPointC,
    this.cloudCoverPercent,
    this.surfacePressureHpa,
    this.shortwaveRadiationMjm2,
    this.sunshineHours,
    this.totalEt0Mm,
    this.et0MmPerDay,
    this.soilMoisture0To7cm,
    this.soilMoisture7To28cm,
    this.soilMoisture28To100cm,
    this.soilTemp0To7cmC,
    this.soilTemp7To28cmC,
    this.soilTemp28To100cmC,
  });

  final Location location;
  final DateTime startDate;
  final DateTime endDate;
  final int dayCount;
  final AggregationMethod method;

  final double? highC;
  final double? lowC;
  final double? meanC;
  final double? totalPrecipitationMm;
  final double? precipitationPerDayMm;
  final double? totalRainMm;
  final double? totalSnowfallCm;
  final double? windSpeedMaxKmh;
  final double? windGustsMaxKmh;
  final double? windDirectionDeg;
  final double? relativeHumidityPercent;
  final double? dewPointC;
  final double? cloudCoverPercent;
  final double? surfacePressureHpa;
  final double? shortwaveRadiationMjm2;
  final double? sunshineHours;
  final double? totalEt0Mm;
  final double? et0MmPerDay;
  final double? soilMoisture0To7cm;
  final double? soilMoisture7To28cm;
  final double? soilMoisture28To100cm;
  final double? soilTemp0To7cmC;
  final double? soilTemp7To28cmC;
  final double? soilTemp28To100cmC;

  /// False when every metric came back null — e.g. a date range Open-Meteo
  /// simply has no data for. Callers should treat this as "no data found"
  /// rather than rendering a card full of dashes.
  bool get hasAnyData => [
    highC,
    lowC,
    meanC,
    totalPrecipitationMm,
    precipitationPerDayMm,
    totalRainMm,
    totalSnowfallCm,
    windSpeedMaxKmh,
    windGustsMaxKmh,
    windDirectionDeg,
    relativeHumidityPercent,
    dewPointC,
    cloudCoverPercent,
    surfacePressureHpa,
    shortwaveRadiationMjm2,
    sunshineHours,
    totalEt0Mm,
    et0MmPerDay,
    soilMoisture0To7cm,
    soilMoisture7To28cm,
    soilMoisture28To100cm,
    soilTemp0To7cmC,
    soilTemp7To28cmC,
    soilTemp28To100cmC,
  ].any((v) => v != null);

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static double? _round(double? value, int decimals) {
    if (value == null) return null;
    final factor = 1 * (decimals == 0 ? 1 : (decimals == 1 ? 10 : (decimals == 2 ? 100 : 1000)));
    return (value * factor).round() / factor;
  }

  Map<String, dynamic> toJson({UnitSystem unitSystem = UnitSystem.metric}) {
    final u = unitSystem;
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
      // How the fields below (other than totals and wind direction, which
      // are always a sum / circular mean respectively) were aggregated.
      'method': method.name,
      'unit_system': u.name,
      'temperature': {
        'unit': u.temperatureUnit,
        'high': _round(u.convertTemperatureC(highC), 1),
        'low': _round(u.convertTemperatureC(lowC), 1),
        'mean': _round(u.convertTemperatureC(meanC), 1),
      },
      'precipitation': {
        'unit': u.precipitationUnit,
        'total': _round(u.convertMm(totalPrecipitationMm), 2),
        'per_day': _round(u.convertMm(precipitationPerDayMm), 2),
        'total_rain': _round(u.convertMm(totalRainMm), 2),
      },
      'snowfall': {
        'unit': u.snowfallUnit,
        'total': _round(u.convertCm(totalSnowfallCm), 2),
      },
      'atmosphere': {
        'relative_humidity_percent': relativeHumidityPercent,
        'dew_point_unit': u.temperatureUnit,
        'dew_point': _round(u.convertTemperatureC(dewPointC), 1),
        'cloud_cover_percent': cloudCoverPercent,
        'surface_pressure_unit': u.pressureUnit,
        'surface_pressure': _round(u.convertHpa(surfacePressureHpa), 2),
      },
      'wind': {
        'speed_unit': u.windSpeedUnit,
        'max_speed': _round(u.convertKmh(windSpeedMaxKmh), 1),
        'max_gusts': _round(u.convertKmh(windGustsMaxKmh), 1),
        // Always a circular mean, regardless of `method`; degrees are
        // unit-system-agnostic.
        'direction_deg': _round(windDirectionDeg, 0),
      },
      'sun': {
        'shortwave_radiation_mj_m2': shortwaveRadiationMjm2,
        'sunshine_hours': sunshineHours,
      },
      'evapotranspiration': {
        'unit': u.precipitationUnit,
        'total': _round(u.convertMm(totalEt0Mm), 2),
        'per_day': _round(u.convertMm(et0MmPerDay), 3),
      },
      'soil': {
        // Volumetric water content is a dimensionless ratio -- not affected
        // by the unit system.
        'moisture_m3_m3': {
          '0_to_7cm': soilMoisture0To7cm,
          '7_to_28cm': soilMoisture7To28cm,
          '28_to_100cm': soilMoisture28To100cm,
        },
        'temperature_unit': u.temperatureUnit,
        'temperature': {
          '0_to_7cm': _round(u.convertTemperatureC(soilTemp0To7cmC), 1),
          '7_to_28cm': _round(u.convertTemperatureC(soilTemp7To28cmC), 1),
          '28_to_100cm': _round(u.convertTemperatureC(soilTemp28To100cmC), 1),
        },
      },
      'source': 'Open-Meteo Historical Weather API (archive-api.open-meteo.com)',
    };
  }
}
