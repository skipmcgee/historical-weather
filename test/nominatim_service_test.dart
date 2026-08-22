import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/services/nominatim_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _ThrowingClient extends http.BaseClient {
  _ThrowingClient(this.error);
  final Object error;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => throw error;
}

void main() {
  test('parses a Nominatim jsonv2 array into Locations', () async {
    final client = MockClient((request) async {
      expect(request.headers['User-Agent'], isNotNull);
      return http.Response(
        jsonEncode([
          {
            'lat': '30.2711286',
            'lon': '-97.7436995',
            'name': 'Austin',
            'display_name': 'Austin, Travis County, Texas, United States',
            'address': {'city': 'Austin', 'state': 'Texas', 'country': 'United States'},
          },
        ]),
        200,
      );
    });
    final service = NominatimService(client: client);

    final results = await service.searchAddresses('Austin');

    expect(results, hasLength(1));
    expect(results.first.name, 'Austin');
    expect(results.first.latitude, closeTo(30.2711286, 1e-9));
  });

  test('sends q, format, addressdetails, and limit query params', () async {
    Uri? requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response('[]', 200);
    });
    final service = NominatimService(client: client);

    await service.searchAddresses('1600 Pennsylvania Ave NW');

    expect(requestedUri, isNotNull);
    expect(requestedUri!.host, 'nominatim.openstreetmap.org');
    expect(requestedUri!.queryParameters['q'], '1600 Pennsylvania Ave NW');
    expect(requestedUri!.queryParameters['format'], 'jsonv2');
    expect(requestedUri!.queryParameters['addressdetails'], '1');
  });

  test('throws on a non-200 response', () async {
    final service = NominatimService(client: MockClient((_) async => http.Response('', 503)));

    await expectLater(
      () => service.searchAddresses('Austin'),
      throwsA(isA<NominatimException>().having((e) => e.message, 'message', contains('HTTP 503'))),
    );
  });

  test('throws on a malformed (non-JSON) body', () async {
    final service = NominatimService(client: MockClient((_) async => http.Response('not json', 200)));

    await expectLater(() => service.searchAddresses('Austin'), throwsA(isA<NominatimException>()));
  });

  test('throws when the response is valid JSON but not an array', () async {
    final service = NominatimService(client: MockClient((_) async => http.Response('{"error": "bad"}', 200)));

    await expectLater(() => service.searchAddresses('Austin'), throwsA(isA<NominatimException>()));
  });

  test('wraps a generic network failure in NominatimException', () async {
    final client = _ThrowingClient(const SocketException('Failed host lookup'));
    final service = NominatimService(client: client);

    await expectLater(
      () => service.searchAddresses('Austin'),
      throwsA(
        isA<NominatimException>().having(
          (e) => e.message,
          'message',
          contains("Couldn't reach"),
        ),
      ),
    );
  });

  test('wraps a request that never responds in a friendly timeout message', () {
    fakeAsync((async) {
      final client = MockClient((request) => Completer<http.Response>().future);
      final service = NominatimService(client: client);

      NominatimException? caught;
      unawaited(Future(() async {
        try {
          await service.searchAddresses('Austin');
        } on NominatimException catch (e) {
          caught = e;
        }
      }));

      async.elapse(const Duration(seconds: 16));

      expect(caught, isNotNull);
      expect(caught!.message, contains('took too long to respond'));
    });
  });
}
