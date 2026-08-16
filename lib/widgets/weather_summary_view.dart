import 'package:flutter/material.dart';

import '../models/weather_summary.dart';
import 'glass_card.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final metrics = <(IconData, String, String, Color)>[
      (Icons.thermostat, 'Avg high', _fmt(summary.avgHighC, '°C'), scheme.primary),
      (Icons.thermostat, 'Avg low', _fmt(summary.avgLowC, '°C'), scheme.primary),
      (Icons.thermostat, 'Avg mean', _fmt(summary.avgMeanC, '°C'), scheme.primary),
      (Icons.water_drop, 'Total precipitation', _fmt(summary.totalPrecipitationMm, 'mm'), scheme.secondary),
      (
        Icons.water_drop_outlined,
        'Avg precipitation/day',
        _fmt(summary.avgPrecipitationMm, 'mm'),
        scheme.secondary,
      ),
      (Icons.ac_unit, 'Total snowfall', _fmt(summary.totalSnowfallCm, 'cm'), scheme.secondary),
      (Icons.air, 'Avg max wind speed', _fmt(summary.avgWindSpeedMaxKmh, 'km/h'), scheme.tertiary),
      (Icons.cyclone, 'Avg max wind gusts', _fmt(summary.avgWindGustsMaxKmh, 'km/h'), scheme.tertiary),
      (Icons.wb_sunny, 'Avg sunshine', _fmt(summary.avgSunshineHours, 'hrs'), scheme.primary),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cyclone, color: scheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(summary.location.displayLabel, style: textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: 4),
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
              for (final (icon, label, value, color) in metrics)
                SizedBox(
                  width: 220,
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: color),
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
    );
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
