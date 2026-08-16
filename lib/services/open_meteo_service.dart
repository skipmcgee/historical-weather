import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/location.dart';

/// Open-Meteo's archive endpoint has a noticeable cold-cache penalty: the
/// first request for a given location/date-range combo can take several
/// seconds, even though the payload itself is tiny (a few KB) and repeat
/// requests come back in well under a second regardless of how many
/// variables are requested. That's server-side and out of our control, and
/// it scales badly for very large spans: an 86-year range with the full
/// variable set measured here actually got a 504 from Open-Meteo's own
/// nginx after 10 minutes. 60s is a compromise -- generous enough that a
/// legitimately slow-but-working multi-decade query isn't cut off
/// prematurely (25s was, in practice), while still failing in bounded time
/// rather than matching Open-Meteo's own multi-minute ceiling.
const _requestTimeout = Duration(seconds: 60);

/// The daily archive variables we request and then average client-side.
const List<String> dailyArchiveVariables = [
  'temperature_2m_max',
  'temperature_2m_min',
  'precipitation_sum',
  'rain_sum',
  'snowfall_sum',
  'wind_speed_10m_max',
  'wind_gusts_10m_max',
  'wind_direction_10m_dominant',
  'shortwave_radiation_sum',
  'sunshine_duration',
  'relative_humidity_2m_mean',
  'dew_point_2m_mean',
  'cloud_cover_mean',
  'surface_pressure_mean',
  'et0_fao_evapotranspiration',
  'soil_moisture_0_to_7cm_mean',
  'soil_moisture_7_to_28cm_mean',
  'soil_moisture_28_to_100cm_mean',
  'soil_temperature_0_to_7cm_mean',
  'soil_temperature_7_to_28cm_mean',
  'soil_temperature_28_to_100cm_mean',
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

    final response = await _get(uri);
    if (response.statusCode != 200) {
      throw OpenMeteoException(_errorMessage(response, 'Location search failed'));
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

    final response = await _get(uri);
    if (response.statusCode != 200) {
      throw OpenMeteoException(_errorMessage(response, 'Historical weather request failed'));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Open-Meteo puts a human-readable explanation in a `reason` field on
  /// error responses -- including rate limiting ("Hourly API request limit
  /// exceeded...") -- so surface that verbatim whenever it's present rather
  /// than just the HTTP status code.
  String _errorMessage(http.Response response, String fallback) {
    final reason = _tryDecode(response.body)?['reason'] as String?;
    if (reason != null && reason.isNotEmpty) return reason;
    return '$fallback (HTTP ${response.statusCode}).';
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client.get(uri).timeout(_requestTimeout);
    } on TimeoutException {
      throw OpenMeteoException(
        'Open-Meteo took too long to respond (>${_requestTimeout.inSeconds}s). Very long date '
        'ranges (many decades) can be genuinely slow on their end -- try a shorter range, or try '
        'again in a moment.',
      );
    }
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
