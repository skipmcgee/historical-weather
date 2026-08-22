import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/models/aggregation_method.dart';
import 'package:historical_weather/models/location.dart';
import 'package:historical_weather/services/weather_aggregator.dart';

void main() {
  final location = Location.manual(latitude: 30.27, longitude: -97.74);
  final start = DateTime(2020, 1, 1);
  final end = DateTime(2020, 1, 3);

  test('computes medians and sums across all days', () {
    final summary = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      method: AggregationMethod.median,
      daily: {
        'time': ['2020-01-01', '2020-01-02', '2020-01-03'],
        'temperature_2m_max': [10.0, 12.0, 14.0],
        'temperature_2m_min': [0.0, 2.0, 4.0],
        'precipitation_sum': [1.0, 0.0, 3.0],
        'rain_sum': [1.0, 0.0, 3.0],
        'snowfall_sum': [0.0, 0.0, 0.0],
        'wind_speed_10m_max': [10.0, 20.0, 30.0],
        'wind_gusts_10m_max': [15.0, 25.0, 35.0],
        'wind_direction_10m_dominant': [80.0, 90.0, 100.0],
        'relative_humidity_2m_mean': [70.0, 80.0, 90.0],
        'shortwave_radiation_sum': [5.0, 6.0, 7.0],
        'sunshine_duration': [3600.0, 7200.0, 10800.0],
      },
    );

    expect(summary.dayCount, 3);
    expect(summary.method, AggregationMethod.median);
    expect(summary.highC, closeTo(12.0, 1e-9));
    expect(summary.lowC, closeTo(2.0, 1e-9));
    expect(summary.meanC, closeTo(7.0, 1e-9));
    expect(summary.totalPrecipitationMm, closeTo(4.0, 1e-9));
    // Sorted [0, 1, 3] -> median is the middle value, 1.0 (not the mean, 4/3).
    expect(summary.precipitationPerDayMm, closeTo(1.0, 1e-9));
    expect(summary.totalRainMm, closeTo(4.0, 1e-9));
    expect(summary.totalSnowfallCm, closeTo(0.0, 1e-9));
    expect(summary.windSpeedMaxKmh, closeTo(20.0, 1e-9));
    expect(summary.windGustsMaxKmh, closeTo(25.0, 1e-9));
    // [80, 90, 100] is symmetric around 90 -> circular mean is exactly 90.
    expect(summary.windDirectionDeg, closeTo(90.0, 1e-6));
    expect(summary.relativeHumidityPercent, closeTo(80.0, 1e-9));
    expect(summary.shortwaveRadiationMjm2, closeTo(6.0, 1e-9));
    // sunshine_duration is in seconds; median of 1h/2h/3h -> 2 hours.
    expect(summary.sunshineHours, closeTo(2.0, 1e-9));
    expect(summary.hasAnyData, isTrue);
  });

  test('AggregationMethod.average uses the arithmetic mean instead of the median', () {
    final daily = {
      'time': ['2020-01-01', '2020-01-02', '2020-01-03'],
      // Sorted [0, 1, 20]: median is 1.0, but the mean is 7.0 -- a single
      // outlier day should only move the average, not the median.
      'precipitation_sum': [1.0, 0.0, 20.0],
      'temperature_2m_max': [10.0, 12.0, 100.0],
    };

    final median = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      method: AggregationMethod.median,
      daily: daily,
    );
    final average = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      method: AggregationMethod.average,
      daily: daily,
    );

    expect(median.method, AggregationMethod.median);
    expect(median.precipitationPerDayMm, closeTo(1.0, 1e-9));
    expect(median.highC, closeTo(12.0, 1e-9));

    expect(average.method, AggregationMethod.average);
    expect(average.precipitationPerDayMm, closeTo(7.0, 1e-9));
    expect(average.highC, closeTo((10.0 + 12.0 + 100.0) / 3, 1e-9));

    // Totals are sums regardless of method -- unaffected by the choice.
    expect(median.totalPrecipitationMm, closeTo(21.0, 1e-9));
    expect(average.totalPrecipitationMm, closeTo(21.0, 1e-9));
  });

  test('wind direction is always a circular mean, regardless of AggregationMethod', () {
    final daily = {
      'time': ['2020-01-01', '2020-01-02'],
      'wind_direction_10m_dominant': [350.0, 10.0],
    };

    final median = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      method: AggregationMethod.median,
      daily: daily,
    );
    final average = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      method: AggregationMethod.average,
      daily: daily,
    );

    expect(median.windDirectionDeg, closeTo(0.0, 1e-6));
    expect(average.windDirectionDeg, closeTo(0.0, 1e-6));
  });

  test('computes atmosphere, evapotranspiration, and soil metrics', () {
    final summary = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      method: AggregationMethod.median,
      daily: {
        'time': ['2020-01-01', '2020-01-02', '2020-01-03'],
        'dew_point_2m_mean': [10.0, 12.0, 14.0],
        'cloud_cover_mean': [20.0, 50.0, 80.0],
        'surface_pressure_mean': [1000.0, 1010.0, 1020.0],
        'et0_fao_evapotranspiration': [1.0, 2.0, 3.0],
        'soil_moisture_0_to_7cm_mean': [0.30, 0.32, 0.34],
        'soil_moisture_7_to_28cm_mean': [0.35, 0.36, 0.37],
        'soil_moisture_28_to_100cm_mean': [0.40, 0.40, 0.41],
        'soil_temperature_0_to_7cm_mean': [15.0, 16.0, 17.0],
        'soil_temperature_7_to_28cm_mean': [14.0, 14.5, 15.0],
        'soil_temperature_28_to_100cm_mean': [13.0, 13.0, 13.5],
      },
    );

    expect(summary.dewPointC, closeTo(12.0, 1e-9));
    expect(summary.cloudCoverPercent, closeTo(50.0, 1e-9));
    expect(summary.surfacePressureHpa, closeTo(1010.0, 1e-9));
    expect(summary.totalEt0Mm, closeTo(6.0, 1e-9));
    expect(summary.et0MmPerDay, closeTo(2.0, 1e-9));
    expect(summary.soilMoisture0To7cm, closeTo(0.32, 1e-9));
    expect(summary.soilMoisture7To28cm, closeTo(0.36, 1e-9));
    expect(summary.soilMoisture28To100cm, closeTo(0.40, 1e-9));
    expect(summary.soilTemp0To7cmC, closeTo(16.0, 1e-9));
    expect(summary.soilTemp7To28cmC, closeTo(14.5, 1e-9));
    expect(summary.soilTemp28To100cmC, closeTo(13.0, 1e-9));
    expect(summary.hasAnyData, isTrue);
  });

  test('wind direction is averaged circularly, not numerically', () {
    final wrapped = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      method: AggregationMethod.median,
      daily: {
        'time': ['2020-01-01', '2020-01-02'],
        // A plain numeric mean/median of [350, 10] gives 180 (due south) --
        // the correct circular average, wrapping across 0/360, is ~0 (north).
        'wind_direction_10m_dominant': [350.0, 10.0],
      },
    );
    expect(wrapped.windDirectionDeg, closeTo(0.0, 1e-6));

    final opposite = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      method: AggregationMethod.median,
      daily: {
        'time': ['2020-01-01', '2020-01-02'],
        // Directly opposite directions cancel out -> no representative
        // single direction, so this should be null rather than a guess.
        'wind_direction_10m_dominant': [0.0, 180.0],
      },
    );
    expect(opposite.windDirectionDeg, isNull);
  });

  test('median of an even number of days averages the two middle values', () {
    final summary = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: DateTime(2020, 1, 4),
      method: AggregationMethod.median,
      daily: {
        'time': ['2020-01-01', '2020-01-02', '2020-01-03', '2020-01-04'],
        'temperature_2m_max': [10.0, 20.0, 30.0, 40.0],
      },
    );

    // Sorted [10, 20, 30, 40] -> median is the average of the two middle
    // values, (20 + 30) / 2 = 25, not a single sample.
    expect(summary.highC, closeTo(25.0, 1e-9));
  });

  test('skips null values instead of treating them as zero', () {
    final summary = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      method: AggregationMethod.median,
      daily: {
        'time': ['2020-01-01', '2020-01-02', '2020-01-03'],
        'temperature_2m_max': [10.0, null, 14.0],
        'temperature_2m_min': [0.0, null, 4.0],
        'precipitation_sum': [null, null, null],
      },
    );

    expect(summary.dayCount, 3);
    expect(summary.highC, closeTo(12.0, 1e-9));
    expect(summary.meanC, closeTo(7.0, 1e-9));
    expect(summary.totalPrecipitationMm, isNull);
    expect(summary.precipitationPerDayMm, isNull);
    expect(summary.hasAnyData, isTrue);
  });

  test('handles entirely empty daily data as "no data" rather than crashing', () {
    final summary = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      method: AggregationMethod.median,
      daily: {'time': <String>[]},
    );

    expect(summary.dayCount, 0);
    expect(summary.highC, isNull);
    expect(summary.meanC, isNull);
    expect(summary.hasAnyData, isFalse);
  });

  test('handles a per-variable array shorter than others without an index error', () {
    final summary = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      method: AggregationMethod.median,
      daily: {
        'time': ['2020-01-01', '2020-01-02', '2020-01-03'],
        'temperature_2m_max': [10.0, 12.0, 14.0],
        // Shorter than the others -- e.g. a variable not yet processed for
        // the most recent day(s).
        'temperature_2m_min': [0.0],
      },
    );

    expect(summary.dayCount, 3);
    expect(summary.highC, closeTo(12.0, 1e-9));
    // Only the one day with both a high and a low contributes to the
    // high/low mean -- the aligned-pair loop stops at the shorter list.
    expect(summary.meanC, closeTo(5.0, 1e-9));
  });

  test('treats a malformed (non-numeric) entry as missing instead of throwing', () {
    final summary = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      method: AggregationMethod.median,
      daily: {
        'time': ['2020-01-01', '2020-01-02', '2020-01-03'],
        'temperature_2m_max': [10.0, 'not a number', 14.0],
        'temperature_2m_min': [0.0, 2.0, 4.0],
      },
    );

    expect(summary.dayCount, 3);
    expect(summary.highC, closeTo(12.0, 1e-9));
    expect(summary.hasAnyData, isTrue);
  });
}
