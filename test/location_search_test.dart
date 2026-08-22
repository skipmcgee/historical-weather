import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/services/location_search.dart';
import 'package:historical_weather/services/nominatim_service.dart';
import 'package:historical_weather/services/open_meteo_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('merges results from both sources', () async {
    final openMeteo = OpenMeteoService(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'results': [
                {'name': 'Austin', 'latitude': 30.27, 'longitude': -97.74, 'admin1': 'Texas', 'country': 'US'},
              ],
            }),
            200,
          )),
    );
    final nominatim = NominatimService(
      client: MockClient((_) async => http.Response(
            jsonEncode([
              {
                'lat': '30.2624370',
                'lon': '-97.7409120',
                'name': '',
                'address': {'house_number': '500', 'road': 'East Cesar Chavez Street', 'city': 'Austin', 'state': 'Texas', 'country': 'US'},
              },
            ]),
            200,
          )),
    );

    final results = await searchAllLocations(openMeteo: openMeteo, nominatim: nominatim, query: 'Austin');

    expect(results, hasLength(2));
    expect(results.map((l) => l.name), containsAll(['Austin', '500 East Cesar Chavez Street']));
  });

  test('collapses two results that resolve to essentially the same point', () async {
    final openMeteo = OpenMeteoService(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'results': [
                {'name': 'Austin', 'latitude': 30.2711, 'longitude': -97.7437, 'admin1': 'Texas', 'country': 'US'},
              ],
            }),
            200,
          )),
    );
    final nominatim = NominatimService(
      client: MockClient((_) async => http.Response(
            jsonEncode([
              {
                'lat': '30.2712',
                'lon': '-97.7436',
                'name': 'Austin',
                'address': {'city': 'Austin', 'state': 'Texas', 'country': 'United States'},
              },
            ]),
            200,
          )),
    );

    final results = await searchAllLocations(openMeteo: openMeteo, nominatim: nominatim, query: 'Austin');

    expect(results, hasLength(1));
    // Open-Meteo's copy is kept (added first).
    expect(results.single.country, 'US');
  });

  test('returns just the successful source\'s results when the other throws', () async {
    final openMeteo = OpenMeteoService(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'results': [
                {'name': 'Austin', 'latitude': 30.27, 'longitude': -97.74, 'admin1': 'Texas', 'country': 'US'},
              ],
            }),
            200,
          )),
    );
    final nominatim = NominatimService(client: MockClient((_) async => http.Response('', 503)));

    final results = await searchAllLocations(openMeteo: openMeteo, nominatim: nominatim, query: 'Austin');

    expect(results, hasLength(1));
    expect(results.single.name, 'Austin');
  });

  test('throws when both sources fail', () async {
    final openMeteo = OpenMeteoService(client: MockClient((_) async => http.Response('', 503)));
    final nominatim = NominatimService(client: MockClient((_) async => http.Response('', 503)));

    await expectLater(
      () => searchAllLocations(openMeteo: openMeteo, nominatim: nominatim, query: 'Austin'),
      throwsA(isA<OpenMeteoException>()),
    );
  });
}
