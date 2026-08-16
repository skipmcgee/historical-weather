import 'package:flutter/material.dart';

import '../models/unit_system.dart';
import '../models/weather_summary.dart';
import 'glass_card.dart';

typedef _Metric = (IconData icon, String label, String value, Color color);

class WeatherSummaryView extends StatelessWidget {
  const WeatherSummaryView({super.key, required this.summary, required this.unitSystem});

  final WeatherSummary summary;
  final UnitSystem unitSystem;

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
    final m = summary.method.label;
    final u = unitSystem;

    String temp(double? c, {int decimals = 1}) => _fmt(u.convertTemperatureC(c), u.temperatureUnit, decimals: decimals);
    String mm(double? v, {int decimals = 2}) => _fmt(u.convertMm(v), u.precipitationUnit, decimals: decimals);
    String cm(double? v) => _fmt(u.convertCm(v), u.snowfallUnit, decimals: 2);
    String kmh(double? v) => _fmt(u.convertKmh(v), u.windSpeedUnit);
    String hpa(double? v) => _fmt(u.convertHpa(v), u.pressureUnit, decimals: 2);

    final temperature = <_Metric>[
      (Icons.thermostat, '$m high', temp(summary.highC), scheme.primary),
      (Icons.thermostat, '$m low', temp(summary.lowC), scheme.primary),
      (Icons.thermostat, '$m mean', temp(summary.meanC), scheme.primary),
    ];

    final precipitation = <_Metric>[
      (Icons.water_drop, 'Total precipitation', mm(summary.totalPrecipitationMm), scheme.secondary),
      (
        Icons.water_drop_outlined,
        '$m precipitation/day',
        mm(summary.precipitationPerDayMm, decimals: 3),
        scheme.secondary,
      ),
      (Icons.ac_unit, 'Total snowfall', cm(summary.totalSnowfallCm), scheme.secondary),
    ];

    final atmosphere = <_Metric>[
      (
        Icons.opacity,
        '$m relative humidity',
        _fmt(summary.relativeHumidityPercent, '%', decimals: 0),
        scheme.secondary,
      ),
      (Icons.water, '$m dew point', temp(summary.dewPointC), scheme.secondary),
      (
        Icons.cloud,
        '$m cloud cover',
        _fmt(summary.cloudCoverPercent, '%', decimals: 0),
        scheme.secondary,
      ),
      (
        Icons.speed,
        '$m surface pressure',
        hpa(summary.surfacePressureHpa),
        scheme.secondary,
      ),
    ];

    final wind = <_Metric>[
      (Icons.air, '$m max wind speed', kmh(summary.windSpeedMaxKmh), scheme.tertiary),
      (
        Icons.cyclone,
        '$m max wind gusts',
        kmh(summary.windGustsMaxKmh),
        scheme.tertiary,
      ),
      (
        Icons.navigation,
        'Wind direction',
        _fmtDirection(summary.windDirectionDeg),
        scheme.tertiary,
      ),
    ];

    final sun = <_Metric>[
      (Icons.wb_sunny, '$m sunshine', _fmt(summary.sunshineHours, 'hrs'), scheme.primary),
      (
        Icons.wb_twilight,
        '$m solar radiation',
        _fmt(summary.shortwaveRadiationMjm2, 'MJ/m²'),
        scheme.primary,
      ),
      (
        Icons.grass,
        'Total evapotranspiration',
        mm(summary.totalEt0Mm),
        scheme.primary,
      ),
    ];

    final soilRows = [
      ('0–7 cm', summary.soilMoisture0To7cm, summary.soilTemp0To7cmC),
      ('7–28 cm', summary.soilMoisture7To28cm, summary.soilTemp7To28cmC),
      ('28–100 cm', summary.soilMoisture28To100cm, summary.soilTemp28To100cmC),
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
            '(${summary.dayCount} days, $m, ${u.label.toLowerCase()})',
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
                child: Text(_fmt(unitSystem.convertTemperatureC(temp), unitSystem.temperatureUnit), style: textTheme.titleMedium),
              ),
            ],
          ),
      ],
    );
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
