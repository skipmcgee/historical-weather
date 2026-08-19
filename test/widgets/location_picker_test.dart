import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/models/location.dart';
import 'package:historical_weather/services/open_meteo_service.dart';
import 'package:historical_weather/widgets/location_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Widget wrap(OpenMeteoService service, {Location? selected, ValueChanged<Location>? onSelected}) {
    return MaterialApp(
      home: Scaffold(
        body: LocationPicker(
          service: service,
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

  testWidgets('rejects "NaN" as a manual coordinate instead of accepting it', (tester) async {
    Location? selected;
    await tester.pumpWidget(wrap(OpenMeteoService(client: MockClient((_) async => http.Response('{}', 200))),
        onSelected: (l) => selected = l));

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
    await tester.pumpWidget(wrap(OpenMeteoService(client: MockClient((_) async => http.Response('{}', 200))),
        onSelected: (l) => selected = l));

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
    await tester.pumpWidget(wrap(OpenMeteoService(client: MockClient((_) async => http.Response('{}', 200))),
        onSelected: (l) => selected = l));

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
