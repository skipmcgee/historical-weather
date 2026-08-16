import 'package:flutter/material.dart';

/// Open-Meteo's archive (ERA5 reanalysis) goes back to 1940; that's the
/// practical floor for the date picker.
final DateTime earliestSupportedDate = DateTime(1940, 1, 1);

class DateRangePicker extends StatelessWidget {
  const DateRangePicker({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;

  Future<void> _pick(
    BuildContext context, {
    required DateTime? initial,
    required DateTime firstDate,
    required ValueChanged<DateTime> onChanged,
  }) async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? lastDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) onChanged(picked);
  }

  String _format(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date range', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Data is available from ${_format(earliestSupportedDate)} onward. Note that '
          'Open-Meteo switched to a higher-resolution model in 2017, so earlier years use a '
          'coarser data source.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('Start: ${_format(startDate)}'),
                onPressed: () => _pick(
                  context,
                  initial: startDate,
                  firstDate: earliestSupportedDate,
                  onChanged: onStartDateChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('End: ${_format(endDate)}'),
                onPressed: () => _pick(
                  context,
                  initial: endDate,
                  firstDate: startDate ?? earliestSupportedDate,
                  onChanged: onEndDateChanged,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
