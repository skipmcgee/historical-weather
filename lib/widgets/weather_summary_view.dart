import 'package:flutter/material.dart';

import '../models/weather_summary.dart';
import 'glass_card.dart';

typedef _Metric = (IconData icon, String label, String value, Color color);

class WeatherSummaryView extends StatelessWidget {
  const WeatherSummaryView({super.key, required this.summary});

  final WeatherSummary summary;

  String _fmt(double? value, String unit, {int decimals = 1}) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(decimals)} $unit';
  }

  static const _compassPoints = [
    'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
    'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
  ];

  String _fmtDirection(double? degrees) {
    if (degrees == null) return '—';
    final index = ((degrees / 22.5) + 0.5).floor() % 16;
    return '${degrees.toStringAsFixed(0)}° (${_compassPoints[index]})';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final temperature = <_Metric>[
      (Icons.thermostat, 'Median high', _fmt(summary.medianHighC, '°C'), scheme.primary),
      (Icons.thermostat, 'Median low', _fmt(summary.medianLowC, '°C'), scheme.primary),
      (Icons.thermostat, 'Median mean', _fmt(summary.medianMeanC, '°C'), scheme.primary),
    ];

    final precipitation = <_Metric>[
      (Icons.water_drop, 'Total precipitation', _fmt(summary.totalPrecipitationMm, 'mm'), scheme.secondary),
      (
        Icons.water_drop_outlined,
        'Median precipitation/day',
        _fmt(summary.medianPrecipitationMm, 'mm'),
        scheme.secondary,
      ),
      (Icons.ac_unit, 'Total snowfall', _fmt(summary.totalSnowfallCm, 'cm'), scheme.secondary),
    ];

    final atmosphere = <_Metric>[
      (
        Icons.opacity,
        'Median relative humidity',
        _fmt(summary.medianRelativeHumidityPercent, '%', decimals: 0),
        scheme.secondary,
      ),
      (Icons.water, 'Median dew point', _fmt(summary.medianDewPointC, '°C'), scheme.secondary),
      (
        Icons.cloud,
        'Median cloud cover',
        _fmt(summary.medianCloudCoverPercent, '%', decimals: 0),
        scheme.secondary,
      ),
      (
        Icons.speed,
        'Median surface pressure',
        _fmt(summary.medianSurfacePressureHpa, 'hPa', decimals: 0),
        scheme.secondary,
      ),
    ];

    final wind = <_Metric>[
      (Icons.air, 'Median max wind speed', _fmt(summary.medianWindSpeedMaxKmh, 'km/h'), scheme.tertiary),
      (
        Icons.cyclone,
        'Median max wind gusts',
        _fmt(summary.medianWindGustsMaxKmh, 'km/h'),
        scheme.tertiary,
      ),
      (
        Icons.navigation,
        'Median wind direction',
        _fmtDirection(summary.medianWindDirectionDeg),
        scheme.tertiary,
      ),
    ];

    final sun = <_Metric>[
      (Icons.wb_sunny, 'Median sunshine', _fmt(summary.medianSunshineHours, 'hrs'), scheme.primary),
      (
        Icons.wb_twilight,
        'Median solar radiation',
        _fmt(summary.medianShortwaveRadiationMjm2, 'MJ/m²'),
        scheme.primary,
      ),
      (
        Icons.grass,
        'Total evapotranspiration',
        _fmt(summary.totalEt0Mm, 'mm'),
        scheme.primary,
      ),
    ];

    final soilRows = [
      ('0–7 cm', summary.medianSoilMoisture0To7cm, summary.medianSoilTemp0To7cmC),
      ('7–28 cm', summary.medianSoilMoisture7To28cm, summary.medianSoilTemp7To28cmC),
      ('28–100 cm', summary.medianSoilMoisture28To100cm, summary.medianSoilTemp28To100cmC),
    ];
    final hasSoilData = soilRows.any((r) => r.$2 != null || r.$3 != null);

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
          _section(context, 'Temperature', temperature),
          _section(context, 'Precipitation', precipitation),
          _section(context, 'Atmosphere', atmosphere),
          _section(context, 'Wind', wind),
          _section(context, 'Sun & evapotranspiration', sun),
          if (hasSoilData) ...[
            const Divider(height: 24),
            Text('Soil', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            _soilTable(context, soilRows),
          ],
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<_Metric> metrics) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text(title, style: textTheme.titleSmall),
        const SizedBox(height: 8),
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
    );
  }

  Widget _soilTable(BuildContext context, List<(String, double?, double?)> rows) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth()},
      children: [
        TableRow(
          children: [
            const SizedBox(),
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 12),
              child: Text('Moisture (m³/m³)', style: textTheme.bodySmall),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 12),
              child: Text('Temperature', style: textTheme.bodySmall),
            ),
          ],
        ),
        for (final (depth, moisture, temp) in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(depth, style: textTheme.bodyMedium?.copyWith(color: scheme.tertiary)),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                child: Text(moisture?.toStringAsFixed(3) ?? '—', style: textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                child: Text(_fmt(temp, '°C'), style: textTheme.titleMedium),
              ),
            ],
          ),
      ],
    );
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
