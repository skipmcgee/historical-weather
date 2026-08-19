import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/widgets/date_range_picker.dart';

void main() {
  Widget wrap({DateTime? startDate, DateTime? endDate}) {
    return MaterialApp(
      home: Scaffold(
        body: DateRangePicker(
          startDate: startDate,
          endDate: endDate,
          onStartDateChanged: (_) {},
          onEndDateChanged: (_) {},
        ),
      ),
    );
  }

  testWidgets('shows placeholder text when no dates are chosen', (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.textContaining('Start: Select date'), findsOneWidget);
    expect(find.textContaining('End: Select date'), findsOneWidget);
  });

  testWidgets('formats chosen dates as YYYY-MM-DD', (tester) async {
    await tester.pumpWidget(wrap(startDate: DateTime(2020, 3, 5), endDate: DateTime(2020, 3, 9)));
    expect(find.textContaining('Start: 2020-03-05'), findsOneWidget);
    expect(find.textContaining('End: 2020-03-09'), findsOneWidget);
  });

  testWidgets('shows no long-range warning for a short range', (tester) async {
    await tester.pumpWidget(wrap(startDate: DateTime(2020, 1, 1), endDate: DateTime(2020, 1, 31)));
    expect(find.byIcon(Icons.warning_amber), findsNothing);
  });

  testWidgets('shows the long-range warning past the ~20 year threshold', (tester) async {
    await tester.pumpWidget(wrap(startDate: DateTime(1940, 1, 1), endDate: DateTime(2020, 1, 1)));
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.textContaining('Multi-decade ranges'), findsOneWidget);
  });

  testWidgets('shows no long-range warning right at a short boundary just under it', (tester) async {
    await tester.pumpWidget(wrap(startDate: DateTime(2019, 1, 1), endDate: DateTime(2020, 1, 1)));
    expect(find.byIcon(Icons.warning_amber), findsNothing);
  });

  testWidgets('the end-date picker\'s earliest selectable date follows the chosen start date', (tester) async {
    await tester.pumpWidget(wrap(startDate: DateTime(2015, 6, 1)));

    await tester.tap(find.textContaining('End:'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final calendar = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(calendar.firstDate, DateTime(2015, 6, 1));
  });
}
