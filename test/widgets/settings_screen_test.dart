import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/models/aggregation_method.dart';
import 'package:historical_weather/models/app_settings.dart';
import 'package:historical_weather/models/unit_system.dart';
import 'package:historical_weather/screens/settings_screen.dart';
import 'package:historical_weather/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the passed-in defaults as initially selected', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(
        initialSettings: AppSettings(
          aggregationMethod: AggregationMethod.median,
          unitSystem: UnitSystem.imperial,
        ),
      ),
    ));
    await tester.pump();

    final method = tester.widget<SegmentedButton<AggregationMethod>>(
      find.byType(SegmentedButton<AggregationMethod>),
    );
    expect(method.selected, {AggregationMethod.median});

    final units = tester.widget<SegmentedButton<UnitSystem>>(find.byType(SegmentedButton<UnitSystem>));
    expect(units.selected, {UnitSystem.imperial});
  });

  testWidgets('changing and saving defaults persists them via SettingsService', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(initialSettings: AppSettings()),
    ));
    await tester.pump();

    await tester.tap(find.text('Average'));
    await tester.pump();
    await tester.tap(find.text('Metric'));
    await tester.pump();

    // The new "Result defaults" card pushes Save below the default test
    // viewport, inside a scroll view -- bring it into view before tapping.
    final saveButton = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveButton);
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pump();

    final saved = await SettingsService().load();
    expect(saved.aggregationMethod, AggregationMethod.average);
    expect(saved.unitSystem, UnitSystem.metric);
  });
}
