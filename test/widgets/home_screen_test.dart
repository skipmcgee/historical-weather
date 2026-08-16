import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/models/unit_system.dart';
import 'package:historical_weather/screens/home_screen.dart';
import 'package:historical_weather/widgets/date_range_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('date picker allows dates back to the 1940 archive floor', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.textContaining('Start:'));
    // The Aeolus background behind the screen animates continuously, so
    // pumpAndSettle() would never settle; pump a bounded amount instead to
    // let the date picker dialog finish opening.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final calendar = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(calendar.firstDate, earliestSupportedDate);
    expect(calendar.firstDate.isAtSameMomentAs(DateTime(1940, 1, 1)), isTrue);
  });

  testWidgets('submit button stays disabled until a location and dates are chosen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Summon the historical weather data'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('aggregation method checkbox defaults to unchecked (median)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    final checkbox = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(checkbox.value, isFalse);
  });

  testWidgets('tapping the aggregation checkbox switches to average', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    final checkbox = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(checkbox.value, isTrue);
  });

  testWidgets('unit system toggle defaults to imperial', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    final segmented = tester.widget<SegmentedButton<UnitSystem>>(find.byType(SegmentedButton<UnitSystem>));
    expect(segmented.selected, {UnitSystem.imperial});
  });
}
