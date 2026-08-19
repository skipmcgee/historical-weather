import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/models/aggregation_method.dart';
import 'package:historical_weather/models/location.dart';
import 'package:historical_weather/models/unit_system.dart';
import 'package:historical_weather/models/weather_summary.dart';
import 'package:historical_weather/widgets/weather_summary_view.dart';

void main() {
  final location = Location.manual(latitude: 30.27, longitude: -97.74);

  WeatherSummary summaryWithDirection(double? degrees) {
    return WeatherSummary(
      location: location,
      startDate: DateTime(2020, 1, 1),
      endDate: DateTime(2020, 1, 3),
      dayCount: 3,
      method: AggregationMethod.median,
      windDirectionDeg: degrees,
    );
  }

  Widget wrap(WeatherSummary summary) {
    return MaterialApp(
      home: Scaffold(
        // WeatherSummaryView is normally shown inside a scrollable container
        // by its caller (HomeScreen) -- without one here, its full card
        // stack overflows the fixed test viewport and fails the test with a
        // RenderFlex overflow, unrelated to what these tests actually check.
        body: SingleChildScrollView(
          child: WeatherSummaryView(summary: summary, unitSystem: UnitSystem.imperial),
        ),
      ),
    );
  }

  final cases = <double, String>{
    0: 'N',
    90: 'E',
    180: 'S',
    270: 'W',
    360: 'N',
    11.24: 'N', // just below the N/NNE boundary at 11.25deg
    11.25: 'NNE', // exactly on the boundary
  };

  for (final entry in cases.entries) {
    testWidgets('formats ${entry.key}deg as ${entry.value}', (tester) async {
      await tester.pumpWidget(wrap(summaryWithDirection(entry.key)));
      expect(find.textContaining('(${entry.value})'), findsOneWidget);
    });
  }

  testWidgets('shows a dash for a null wind direction', (tester) async {
    await tester.pumpWidget(wrap(summaryWithDirection(null)));
    expect(find.text('—'), findsWidgets);
  });
}
