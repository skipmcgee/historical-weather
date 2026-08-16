import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/screens/home_screen.dart';
import 'package:historical_weather/widgets/date_range_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('date picker refuses dates before the 2017 cutoff', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.textContaining('Start:'));
    await tester.pumpAndSettle();

    final calendar = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(calendar.firstDate, earliestSupportedDate);
    expect(calendar.firstDate.isAtSameMomentAs(DateTime(2017, 1, 1)), isTrue);
  });

  testWidgets('submit button stays disabled until a location and dates are chosen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Get historical weather'));
    expect(button.onPressed, isNull);
  });
}
