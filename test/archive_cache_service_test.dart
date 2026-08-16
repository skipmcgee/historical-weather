import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/models/location.dart';
import 'package:historical_weather/services/archive_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final location = Location.manual(latitude: 30.27, longitude: -97.74);
  final otherLocation = Location.manual(latitude: 40.71, longitude: -74.01);

  test('a fresh cache has no entries', () async {
    final cache = ArchiveCacheService();
    final result = await cache.lookup(
      location: location,
      start: DateTime(2020, 1, 1),
      end: DateTime(2020, 1, 3),
    );
    expect(result, isNull);
  });

  test('serves an exact match from cache without hitting the network', () async {
    final cache = ArchiveCacheService();
    final daily = {
      'time': ['2020-01-01', '2020-01-02', '2020-01-03'],
      'temperature_2m_max': [10.0, 12.0, 14.0],
    };
    await cache.store(location: location, start: DateTime(2020, 1, 1), end: DateTime(2020, 1, 3), daily: daily);

    final result = await cache.lookup(
      location: location,
      start: DateTime(2020, 1, 1),
      end: DateTime(2020, 1, 3),
    );
    expect(result, isNotNull);
    expect(result!['time'], daily['time']);
    expect(result['temperature_2m_max'], daily['temperature_2m_max']);
  });

  test('slices a narrower request out of a cached wider range', () async {
    final cache = ArchiveCacheService();
    await cache.store(
      location: location,
      start: DateTime(2020, 1, 1),
      end: DateTime(2020, 1, 5),
      daily: {
        'time': ['2020-01-01', '2020-01-02', '2020-01-03', '2020-01-04', '2020-01-05'],
        'temperature_2m_max': [1.0, 2.0, 3.0, 4.0, 5.0],
      },
    );

    final result = await cache.lookup(
      location: location,
      start: DateTime(2020, 1, 2),
      end: DateTime(2020, 1, 4),
    );

    expect(result, isNotNull);
    expect(result!['time'], ['2020-01-02', '2020-01-03', '2020-01-04']);
    expect(result['temperature_2m_max'], [2.0, 3.0, 4.0]);
  });

  test('does not reuse cache across different locations', () async {
    final cache = ArchiveCacheService();
    await cache.store(
      location: location,
      start: DateTime(2020, 1, 1),
      end: DateTime(2020, 1, 3),
      daily: {'time': <String>[]},
    );

    final result = await cache.lookup(
      location: otherLocation,
      start: DateTime(2020, 1, 1),
      end: DateTime(2020, 1, 3),
    );
    expect(result, isNull);
  });

  test('does not reuse cache for a range only partially, not fully, covered', () async {
    final cache = ArchiveCacheService();
    await cache.store(
      location: location,
      start: DateTime(2020, 1, 1),
      end: DateTime(2020, 1, 3),
      daily: {'time': <String>[]},
    );

    final result = await cache.lookup(
      location: location,
      start: DateTime(2020, 1, 2),
      end: DateTime(2020, 1, 10),
    );
    expect(result, isNull);
  });

  test('caps the cache at 50 entries, evicting the oldest first', () async {
    final cache = ArchiveCacheService();
    for (var i = 0; i < 55; i++) {
      await cache.store(
        location: location,
        start: DateTime(2000, 1, 1).add(Duration(days: i)),
        end: DateTime(2000, 1, 2).add(Duration(days: i)),
        daily: {'time': <String>[]},
      );
    }

    // The first entries written should have been evicted...
    final earliest = await cache.lookup(
      location: location,
      start: DateTime(2000, 1, 1),
      end: DateTime(2000, 1, 2),
    );
    expect(earliest, isNull);

    // ...but the most recently written one should still be there.
    final latest = await cache.lookup(
      location: location,
      start: DateTime(2000, 1, 1).add(const Duration(days: 54)),
      end: DateTime(2000, 1, 2).add(const Duration(days: 54)),
    );
    expect(latest, isNotNull);
  });
}
