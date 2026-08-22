import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/location.dart';

/// OpenStreetMap's Nominatim geocoder is much faster than Open-Meteo's
/// archive endpoint for a single free-text query -- no need for the 120s
/// allowance OpenMeteoService gives itself.
const _requestTimeout = Duration(seconds: 15);

/// Identifies this app to Nominatim's public server, as required by its
/// usage policy (https://operations.osmfoundation.org/policies/nominatim/).
const _userAgent = 'HistoricalWeatherApp (github.com/skipmcgee/historical-weather)';

class NominatimException implements Exception {
  NominatimException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Searches OpenStreetMap's Nominatim geocoder -- unlike
/// [OpenMeteoService.searchLocations] (city/place names only, via
/// GeoNames), Nominatim also resolves specific street addresses and named
/// points of interest. No API key: per Nominatim's usage policy, this
/// identifies itself with a User-Agent and stays within the same light,
/// on-demand/interactive search volume the app's debounced search UI
/// already limits itself to (no bulk/automated use).
class NominatimService {
  NominatimService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Location>> searchAddresses(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '6',
    });

    final http.Response response;
    try {
      response = await _client.get(uri, headers: {'User-Agent': _userAgent}).timeout(_requestTimeout);
    } on TimeoutException {
      throw NominatimException(
        'Address search took too long to respond (>${_requestTimeout.inSeconds}s).',
      );
    } catch (e) {
      throw NominatimException("Couldn't reach the address search service: $e");
    }

    if (response.statusCode != 200) {
      throw NominatimException('Address search failed (HTTP ${response.statusCode}).');
    }

    final dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      throw NominatimException('Address search returned an unexpected (non-JSON) response.');
    }

    if (body is! List) {
      throw NominatimException('Address search returned an unexpected response shape.');
    }

    return body.cast<Map<String, dynamic>>().map(Location.fromNominatimJson).toList(growable: false);
  }

  void dispose() => _client.close();
}
