import 'dart:convert';

import '../models/location.dart';
import '../util/date_format.dart';
import 'key_value_store.dart';

/// Caches Open-Meteo daily-archive responses, keyed by location and date
/// range, so re-running the same (or a narrower) query doesn't re-fetch
/// data that's already been retrieved. There's no user-account system in
/// this app, so this is scoped per [createKeyValueStore]'s notion of "user"
/// -- per device/install on macOS/iOS/Linux, per browser tab on web (so one
/// visitor's cache can't serve stale/mismatched data into another's tab).
///
/// Eviction: an entry expires after [maxAge] (~1 month) *or* once the
/// cache holds more than [maxEntries] (50) entries, whichever comes first
/// -- every write sweeps expired entries, then trims the oldest ones down
/// to the cap.
///
/// Only *exact* and *containing* matches are served from cache (a cached
/// range that fully covers the requested range is sliced down to it);
/// partially-overlapping ranges that don't fully contain the request still
/// go to the network. Splicing two partial responses together would need
/// to merge per-variable arrays across a gap, which isn't worth the
/// complexity for what's fundamentally a convenience cache.
class ArchiveCacheService {
  static const _prefsKey = 'archive_cache_v1';
  static const maxEntries = 50;
  static const maxAge = Duration(days: 30);

  final KeyValueStore _store = createKeyValueStore();

  Future<Map<String, dynamic>?> lookup({
    required Location location,
    required DateTime start,
    required DateTime end,
  }) async {
    final entries = await _load();
    final key = _locationKey(location);

    for (final entry in entries) {
      if (entry.locationKey != key) continue;
      if (entry.start.isAfter(start) || entry.end.isBefore(end)) continue;
      return _sliceDaily(entry.daily, start, end);
    }
    return null;
  }

  Future<void> store({
    required Location location,
    required DateTime start,
    required DateTime end,
    required Map<String, dynamic> daily,
  }) async {
    final entries = await _load();
    entries.removeWhere(
      (e) => e.locationKey == _locationKey(location) && e.start == start && e.end == end,
    );
    entries.add(_CacheEntry(
      locationKey: _locationKey(location),
      start: start,
      end: end,
      fetchedAt: DateTime.now(),
      daily: daily,
    ));
    await _save(_evict(entries));
  }

  List<_CacheEntry> _evict(List<_CacheEntry> entries) {
    final now = DateTime.now();
    final fresh = entries.where((e) => now.difference(e.fetchedAt) < maxAge).toList()
      ..sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));
    return fresh.take(maxEntries).toList();
  }

  Future<List<_CacheEntry>> _load() async {
    final raw = await _store.getString(_prefsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final entries = list
          .cast<Map<String, dynamic>>()
          .map(_CacheEntry.fromJson)
          .toList();
      final evicted = _evict(entries);
      // A lookup-only session (no store() calls) would otherwise never
      // shrink the persisted blob once entries age out or the count creeps
      // past the cap -- every load would keep re-decoding and re-discarding
      // the same stale entries.
      if (evicted.length != entries.length) await _save(evicted);
      return evicted;
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<_CacheEntry> entries) async {
    await _store.setString(_prefsKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  String _locationKey(Location location) =>
      '${location.latitude.toStringAsFixed(4)},${location.longitude.toStringAsFixed(4)}';

  Map<String, dynamic> _sliceDaily(Map<String, dynamic> daily, DateTime start, DateTime end) {
    final times = (daily['time'] as List<dynamic>? ?? const []).cast<String>();
    final startIso = isoDate(start);
    final endIso = isoDate(end);
    final indices = <int>[
      for (var i = 0; i < times.length; i++)
        if (times[i].compareTo(startIso) >= 0 && times[i].compareTo(endIso) <= 0) i,
    ];

    final sliced = <String, dynamic>{};
    for (final entry in daily.entries) {
      final list = entry.value;
      if (list is List) {
        // A per-variable array can be shorter than `time` (a sparse or
        // not-yet-processed variable near the present day) -- index past
        // its end as null rather than letting a RangeError escape, keeping
        // every sliced array the same length as `indices` so downstream
        // code (which already treats a null/missing day as "no data for
        // that day") stays aligned.
        sliced[entry.key] = [for (final i in indices) i < list.length ? list[i] : null];
      } else {
        sliced[entry.key] = entry.value;
      }
    }
    return sliced;
  }
}

class _CacheEntry {
  _CacheEntry({
    required this.locationKey,
    required this.start,
    required this.end,
    required this.fetchedAt,
    required this.daily,
  });

  final String locationKey;
  final DateTime start;
  final DateTime end;
  final DateTime fetchedAt;
  final Map<String, dynamic> daily;

  factory _CacheEntry.fromJson(Map<String, dynamic> json) => _CacheEntry(
        locationKey: json['locationKey'] as String,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        daily: json['daily'] as Map<String, dynamic>,
      );

  Map<String, dynamic> toJson() => {
        'locationKey': locationKey,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'fetchedAt': fetchedAt.toIso8601String(),
        'daily': daily,
      };
}
