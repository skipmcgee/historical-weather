import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/models/location.dart';
import 'package:historical_weather/services/nominatim_service.dart';
import 'package:historical_weather/services/open_meteo_service.dart';
import 'package:historical_weather/widgets/location_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

NominatimService _emptyNominatim() =>
    NominatimService(client: MockClient((_) async => http.Response('[]', 200)));

OpenMeteoService _emptyOpenMeteo() =>
    OpenMeteoService(client: MockClient((_) async => http.Response('{}', 200)));

void main() {
  Widget wrap(
    OpenMeteoService service, {
    NominatimService? nominatim,
    Location? selected,
    ValueChanged<Location>? onSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LocationPicker(
          service: service,
          nominatimService: nominatim ?? _emptyNominatim(),
          selected: selected,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('debounces search and shows results after the delay', (tester) async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      return http.Response(
        jsonEncode({
          'results': [
            {'name': 'Austin', 'latitude': 30.27, 'longitude': -97.74, 'admin1': 'Texas', 'country': 'US'},
          ],
        }),
        200,
      );
    });
    final service = OpenMeteoService(client: client);

    await tester.pumpWidget(wrap(service));
    await tester.enterText(find.byType(TextField).first, 'Austin');
    // Immediately after typing, the debounce hasn't fired yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(callCount, 0);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(callCount, 1);
    expect(find.text('Austin'), findsOneWidget);
  });

  testWidgets('shows an address-only match found via Nominatim', (tester) async {
    final nominatim = NominatimService(
      client: MockClient((_) async => http.Response(
            jsonEncode([
              {
                'lat': '38.8976387',
                'lon': '-77.0365525',
                'name': '',
                'display_name': '1600, Pennsylvania Avenue Northwest, Washington, DC, United States',
                'address': {
                  'house_number': '1600',
                  'road': 'Pennsylvania Avenue Northwest',
                  'city': 'Washington',
                  'state': 'District of Columbia',
                  'country': 'United States',
                },
              },
            ]),
            200,
          )),
    );

    await tester.pumpWidget(wrap(_emptyOpenMeteo(), nominatim: nominatim));
    await tester.enterText(find.byType(TextField).first, '1600 Pennsylvania Ave NW');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.textContaining('1600 Pennsylvania Avenue Northwest'), findsOneWidget);
  });

  testWidgets('merges and de-duplicates results from both sources', (tester) async {
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
              // Same place as Open-Meteo's result, to within the ~100m dedupe
              // tolerance -- should be collapsed into just the one above.
              {
                'lat': '30.2712',
                'lon': '-97.7436',
                'name': 'Austin',
                'display_name': 'Austin, Travis County, Texas, United States',
                'address': {'city': 'Austin', 'state': 'Texas', 'country': 'United States'},
              },
              // A genuinely distinct address in the same city -- should show
              // up as its own separate result.
              {
                'lat': '30.2624370',
                'lon': '-97.7409120',
                'name': '',
                'display_name': '500, East Cesar Chavez Street, Austin, Texas, United States',
                'address': {
                  'house_number': '500',
                  'road': 'East Cesar Chavez Street',
                  'city': 'Austin',
                  'state': 'Texas',
                  'country': 'United States',
                },
              },
            ]),
            200,
          )),
    );

    await tester.pumpWidget(wrap(openMeteo, nominatim: nominatim));
    await tester.enterText(find.byType(TextField).first, 'Austin');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Exact match on Open-Meteo's label -- the East Cesar Chavez Street
    // result's own label also *contains* "Austin, Texas" as a substring
    // (its admin1 folds the city in), so an exact match is needed to
    // confirm the two near-identical Austin entries collapsed into one
    // instead of both showing up, without that other result confusing the
    // count.
    expect(find.text('Austin, Texas, US'), findsOneWidget);
    expect(find.textContaining('East Cesar Chavez Street'), findsOneWidget);
  });

  testWidgets('still shows results when only one source fails', (tester) async {
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

    await tester.pumpWidget(wrap(openMeteo, nominatim: nominatim));
    await tester.enterText(find.byType(TextField).first, 'Austin');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.textContaining('Austin, Texas'), findsOneWidget);
    expect(find.textContaining('Search failed'), findsNothing);
  });

  testWidgets('shows a search-failed error only when both sources fail', (tester) async {
    final openMeteo = OpenMeteoService(client: MockClient((_) async => http.Response('', 503)));
    final nominatim = NominatimService(client: MockClient((_) async => http.Response('', 503)));

    await tester.pumpWidget(wrap(openMeteo, nominatim: nominatim));
    await tester.enterText(find.byType(TextField).first, 'Austin');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.textContaining('Search failed'), findsOneWidget);
  });

  testWidgets('rejects "NaN" as a manual coordinate instead of accepting it', (tester) async {
    Location? selected;
    await tester.pumpWidget(wrap(_emptyOpenMeteo(), onSelected: (l) => selected = l));

    await tester.tap(find.text('Enter coordinates manually'));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'NaN');
    await tester.enterText(fields.at(2), '-97.74');
    await tester.tap(find.text('Use'));
    await tester.pump();

    expect(selected, isNull);
    expect(find.textContaining('Latitude must be a number'), findsOneWidget);
  });

  testWidgets('accepts valid manual coordinates', (tester) async {
    Location? selected;
    await tester.pumpWidget(wrap(_emptyOpenMeteo(), onSelected: (l) => selected = l));

    await tester.tap(find.text('Enter coordinates manually'));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '30.27');
    await tester.enterText(fields.at(2), '-97.74');
    await tester.tap(find.text('Use'));
    await tester.pump();

    expect(selected, isNotNull);
    expect(selected!.latitude, 30.27);
    expect(selected!.longitude, -97.74);
  });

  testWidgets('rejects an out-of-range latitude', (tester) async {
    Location? selected;
    await tester.pumpWidget(wrap(_emptyOpenMeteo(), onSelected: (l) => selected = l));

    await tester.tap(find.text('Enter coordinates manually'));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '95');
    await tester.enterText(fields.at(2), '0');
    await tester.tap(find.text('Use'));
    await tester.pump();

    expect(selected, isNull);
    expect(find.textContaining('Latitude must be a number'), findsOneWidget);
  });
}
