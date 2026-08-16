import 'package:flutter_test/flutter_test.dart';
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
      daily: {
        'time': ['2020-01-01', '2020-01-02', '2020-01-03'],
        'temperature_2m_max': [10.0, 12.0, 14.0],
        'temperature_2m_min': [0.0, 2.0, 4.0],
        'precipitation_sum': [1.0, 0.0, 3.0],
        'rain_sum': [1.0, 0.0, 3.0],
        'snowfall_sum': [0.0, 0.0, 0.0],
        'wind_speed_10m_max': [10.0, 20.0, 30.0],
        'wind_gusts_10m_max': [15.0, 25.0, 35.0],
        'shortwave_radiation_sum': [5.0, 6.0, 7.0],
        'sunshine_duration': [3600.0, 7200.0, 10800.0],
      },
    );

    expect(summary.dayCount, 3);
    expect(summary.medianHighC, closeTo(12.0, 1e-9));
    expect(summary.medianLowC, closeTo(2.0, 1e-9));
    expect(summary.medianMeanC, closeTo(7.0, 1e-9));
    expect(summary.totalPrecipitationMm, closeTo(4.0, 1e-9));
    // Sorted [0, 1, 3] -> median is the middle value, 1.0 (not the mean, 4/3).
    expect(summary.medianPrecipitationMm, closeTo(1.0, 1e-9));
    expect(summary.totalRainMm, closeTo(4.0, 1e-9));
    expect(summary.totalSnowfallCm, closeTo(0.0, 1e-9));
    expect(summary.medianWindSpeedMaxKmh, closeTo(20.0, 1e-9));
    expect(summary.medianWindGustsMaxKmh, closeTo(25.0, 1e-9));
    expect(summary.medianShortwaveRadiationMjm2, closeTo(6.0, 1e-9));
    // sunshine_duration is in seconds; median of 1h/2h/3h -> 2 hours.
    expect(summary.medianSunshineHours, closeTo(2.0, 1e-9));
    expect(summary.hasAnyData, isTrue);
  });

  test('median of an even number of days averages the two middle values', () {
    final summary = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: DateTime(2020, 1, 4),
      daily: {
        'time': ['2020-01-01', '2020-01-02', '2020-01-03', '2020-01-04'],
        'temperature_2m_max': [10.0, 20.0, 30.0, 40.0],
      },
    );

    // Sorted [10, 20, 30, 40] -> median is the average of the two middle
    // values, (20 + 30) / 2 = 25, not a single sample.
    expect(summary.medianHighC, closeTo(25.0, 1e-9));
  });

  test('skips null values instead of treating them as zero', () {
    final summary = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      daily: {
        'time': ['2020-01-01', '2020-01-02', '2020-01-03'],
        'temperature_2m_max': [10.0, null, 14.0],
        'temperature_2m_min': [0.0, null, 4.0],
        'precipitation_sum': [null, null, null],
      },
    );

    expect(summary.dayCount, 3);
    expect(summary.medianHighC, closeTo(12.0, 1e-9));
    expect(summary.medianMeanC, closeTo(7.0, 1e-9));
    expect(summary.totalPrecipitationMm, isNull);
    expect(summary.medianPrecipitationMm, isNull);
    expect(summary.hasAnyData, isTrue);
  });

  test('handles entirely empty daily data as "no data" rather than crashing', () {
    final summary = aggregateDailyArchive(
      location: location,
      startDate: start,
      endDate: end,
      daily: {'time': <String>[]},
    );

    expect(summary.dayCount, 0);
    expect(summary.medianHighC, isNull);
    expect(summary.medianMeanC, isNull);
    expect(summary.hasAnyData, isFalse);
  });
}
