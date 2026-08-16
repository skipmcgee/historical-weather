import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/models/location.dart';
import 'package:historical_weather/services/open_meteo_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final location = Location.manual(latitude: 30.27, longitude: -97.74);

  test('fetchDailyArchive surfaces Open-Meteo\'s reason on error responses (e.g. rate limiting)', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'error': true, 'reason': 'Hourly API request limit exceeded. Please try again in the next hour.'}),
        429,
      );
    });
    final service = OpenMeteoService(client: client);

    await expectLater(
      () => service.fetchDailyArchive(
        location: location,
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2020, 1, 2),
      ),
      throwsA(
        isA<OpenMeteoException>().having(
          (e) => e.message,
          'message',
          'Hourly API request limit exceeded. Please try again in the next hour.',
        ),
      ),
    );
  });

  test('searchLocations surfaces Open-Meteo\'s reason on error responses too', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'error': true, 'reason': 'Hourly API request limit exceeded. Please try again in the next hour.'}),
        429,
      );
    });
    final service = OpenMeteoService(client: client);

    await expectLater(
      () => service.searchLocations('Austin'),
      throwsA(
        isA<OpenMeteoException>().having(
          (e) => e.message,
          'message',
          'Hourly API request limit exceeded. Please try again in the next hour.',
        ),
      ),
    );
  });

  test('falls back to a generic message when the error body has no reason', () async {
    final client = MockClient((request) async {
      return http.Response('not json', 503);
    });
    final service = OpenMeteoService(client: client);

    await expectLater(
      () => service.fetchDailyArchive(
        location: location,
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2020, 1, 2),
      ),
      throwsA(
        isA<OpenMeteoException>().having(
          (e) => e.message,
          'message',
          'Historical weather request failed (HTTP 503).',
        ),
      ),
    );
  });
}
