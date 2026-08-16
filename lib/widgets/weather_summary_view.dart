import 'package:flutter/material.dart';

import '../models/weather_summary.dart';

class WeatherSummaryView extends StatelessWidget {
  const WeatherSummaryView({super.key, required this.summary});

  final WeatherSummary summary;

  String _fmt(double? value, String unit, {int decimals = 1}) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(decimals)} $unit';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final metrics = <(IconData, String, String)>[
      (Icons.thermostat, 'Avg high', _fmt(summary.avgHighC, '°C')),
      (Icons.thermostat, 'Avg low', _fmt(summary.avgLowC, '°C')),
      (Icons.thermostat, 'Avg mean', _fmt(summary.avgMeanC, '°C')),
      (Icons.water_drop, 'Total precipitation', _fmt(summary.totalPrecipitationMm, 'mm')),
      (Icons.water_drop_outlined, 'Avg precipitation/day', _fmt(summary.avgPrecipitationMm, 'mm')),
      (Icons.ac_unit, 'Total snowfall', _fmt(summary.totalSnowfallCm, 'cm')),
      (Icons.air, 'Avg max wind speed', _fmt(summary.avgWindSpeedMaxKmh, 'km/h')),
      (Icons.air, 'Avg max wind gusts', _fmt(summary.avgWindGustsMaxKmh, 'km/h')),
      (Icons.wb_sunny, 'Avg sunshine', _fmt(summary.avgSunshineHours, 'hrs')),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary.location.displayLabel, style: textTheme.titleLarge),
            Text(
              '${_isoDate(summary.startDate)} — ${_isoDate(summary.endDate)} '
              '(${summary.dayCount} days)',
              style: textTheme.bodyMedium,
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final (icon, label, value) in metrics)
                  SizedBox(
                    width: 220,
                    child: Row(
                      children: [
                        Icon(icon, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: textTheme.bodySmall),
                              Text(value, style: textTheme.titleMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
