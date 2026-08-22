import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/models/location.dart';
import 'package:historical_weather/services/open_meteo_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _ThrowingClient extends http.BaseClient {
  _ThrowingClient(this.error);
  final Object error;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => throw error;
}

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

  test('wraps a generic network failure (not a timeout) in OpenMeteoException', () async {
    final client = _ThrowingClient(const SocketException('Failed host lookup'));
    final service = OpenMeteoService(client: client);

    await expectLater(
      () => service.searchLocations('Austin'),
      throwsA(
        isA<OpenMeteoException>().having(
          (e) => e.message,
          'message',
          contains("Couldn't reach Open-Meteo"),
        ),
      ),
    );
  });

  test('wraps a malformed (non-JSON) body on an otherwise-successful response', () async {
    final client = MockClient((request) async => http.Response('not json', 200));
    final service = OpenMeteoService(client: client);

    await expectLater(
      () => service.searchLocations('Austin'),
      throwsA(isA<OpenMeteoException>()),
    );
  });

  test('wraps a request that never responds in a friendly timeout message', () {
    // Fast-forwards virtual time past the 120s request timeout instead of
    // actually waiting 120 real seconds.
    fakeAsync((async) {
      final client = MockClient((request) => Completer<http.Response>().future);
      final service = OpenMeteoService(client: client);

      OpenMeteoException? caught;
      unawaited(Future(() async {
        try {
          await service.fetchDailyArchive(
            location: location,
            startDate: DateTime(2020, 1, 1),
            endDate: DateTime(2020, 1, 2),
          );
        } on OpenMeteoException catch (e) {
          caught = e;
        }
      }));

      async.elapse(const Duration(seconds: 121));

      expect(caught, isNotNull);
      expect(caught!.message, contains('took too long to respond'));
    });
  });
}
