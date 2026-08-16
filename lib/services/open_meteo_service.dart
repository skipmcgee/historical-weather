import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/location.dart';

/// The daily archive variables we request and then average client-side.
const List<String> dailyArchiveVariables = [
  'temperature_2m_max',
  'temperature_2m_min',
  'precipitation_sum',
  'rain_sum',
  'snowfall_sum',
  'wind_speed_10m_max',
  'wind_gusts_10m_max',
  'shortwave_radiation_sum',
  'sunshine_duration',
];

class OpenMeteoException implements Exception {
  OpenMeteoException(this.message);
  final String message;

  @override
  String toString() => message;
}

class OpenMeteoService {
  OpenMeteoService({http.Client? client, this.apiKey}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Open-Meteo commercial/customer API key. When set, requests go to the
  /// `customer-` prefixed hosts with an `apikey` query parameter instead of
  /// the free public hosts.
  String? apiKey;

  Uri get _geocodingBase => Uri.parse(
        'https://${_hostPrefix}geocoding-api.open-meteo.com/v1/search',
      );
  Uri get _archiveBase => Uri.parse(
        'https://${_hostPrefix}archive-api.open-meteo.com/v1/archive',
      );

  String get _hostPrefix => (apiKey == null || apiKey!.isEmpty) ? '' : 'customer-';

  Map<String, String> _withApiKey(Map<String, String> params) {
    if (apiKey == null || apiKey!.isEmpty) return params;
    return {...params, 'apikey': apiKey!};
  }

  /// Searches Open-Meteo's geocoding API for places matching [query].
  Future<List<Location>> searchLocations(String query) async {
    final uri = _geocodingBase.replace(
      queryParameters: _withApiKey({
        'name': query,
        'count': '10',
        'language': 'en',
      }),
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw OpenMeteoException('Location search failed (HTTP ${response.statusCode}).');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>?;
    if (results == null) return [];

    return results
        .cast<Map<String, dynamic>>()
        .map(Location.fromGeocodingJson)
        .toList(growable: false);
  }

  /// Fetches the daily archive weather for [location] between [startDate]
  /// and [endDate] (inclusive), returned as the raw decoded JSON body.
  Future<Map<String, dynamic>> fetchDailyArchive({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final uri = _archiveBase.replace(
      queryParameters: _withApiKey({
        'latitude': location.latitude.toString(),
        'longitude': location.longitude.toString(),
        'start_date': _isoDate(startDate),
        'end_date': _isoDate(endDate),
        'daily': dailyArchiveVariables.join(','),
        'timezone': 'auto',
      }),
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      final body = _tryDecode(response.body);
      final reason = body?['reason'] as String?;
      throw OpenMeteoException(
        reason ?? 'Historical weather request failed (HTTP ${response.statusCode}).',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void dispose() => _client.close();
}
