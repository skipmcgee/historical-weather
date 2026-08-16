import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/models/aggregation_method.dart';
import 'package:historical_weather/models/location.dart';
import 'package:historical_weather/models/unit_system.dart';
import 'package:historical_weather/models/weather_summary.dart';

void main() {
  final location = Location.manual(latitude: 30.27, longitude: -97.74);

  WeatherSummary buildSummary({required AggregationMethod method}) {
    return WeatherSummary(
      location: location,
      startDate: DateTime(2020, 1, 1),
      endDate: DateTime(2020, 1, 31),
      dayCount: 31,
      method: method,
      highC: 20.0,
      lowC: 0.0,
      meanC: 10.0,
      totalPrecipitationMm: 25.4,
      precipitationPerDayMm: 0.82,
      windSpeedMaxKmh: 100.0,
      surfacePressureHpa: 1013.25,
      totalSnowfallCm: 2.54,
      soilMoisture0To7cm: 0.32,
      soilTemp0To7cmC: 15.0,
      windDirectionDeg: 90.0,
    );
  }

  test('toJson defaults to metric and reports the aggregation method', () {
    final json = buildSummary(method: AggregationMethod.median).toJson();

    expect(json['method'], 'median');
    expect(json['unit_system'], 'metric');
    expect(json['temperature']['unit'], '°C');
    expect(json['temperature']['high'], closeTo(20.0, 1e-9));
    expect(json['precipitation']['unit'], 'mm');
    expect(json['precipitation']['total'], closeTo(25.4, 1e-9));
    expect(json['wind']['speed_unit'], 'km/h');
    expect(json['wind']['max_speed'], closeTo(100.0, 1e-9));
    // Volumetric soil moisture is unit-agnostic.
    expect(json['soil']['moisture_m3_m3']['0_to_7cm'], closeTo(0.32, 1e-9));
  });

  test('toJson(unitSystem: imperial) converts every unit-affected field', () {
    final json = buildSummary(method: AggregationMethod.average).toJson(unitSystem: UnitSystem.imperial);

    expect(json['method'], 'average');
    expect(json['unit_system'], 'imperial');
    expect(json['temperature']['unit'], '°F');
    expect(json['temperature']['high'], closeTo(68.0, 1e-9)); // 20C
    expect(json['temperature']['low'], closeTo(32.0, 1e-9)); // 0C
    expect(json['precipitation']['unit'], 'in');
    expect(json['precipitation']['total'], closeTo(1.0, 1e-9)); // 25.4mm
    expect(json['snowfall']['unit'], 'in');
    expect(json['snowfall']['total'], closeTo(1.0, 1e-9)); // 2.54cm
    expect(json['wind']['speed_unit'], 'mph');
    expect(json['wind']['max_speed'], closeTo(62.1, 1e-1)); // 100km/h
    expect(json['atmosphere']['surface_pressure_unit'], 'inHg');
    expect(json['atmosphere']['surface_pressure'], closeTo(29.92, 1e-2));
    // Wind direction (degrees) and soil moisture (m3/m3) are never converted.
    expect(json['wind']['direction_deg'], closeTo(90.0, 1e-9));
    expect(json['soil']['moisture_m3_m3']['0_to_7cm'], closeTo(0.32, 1e-9));
    // Soil temperature *is* converted, unlike soil moisture.
    expect(json['soil']['temperature_unit'], '°F');
    expect(json['soil']['temperature']['0_to_7cm'], closeTo(59.0, 1e-9)); // 15C
  });

  test('hasAnyData is false when every metric is null', () {
    final empty = WeatherSummary(
      location: location,
      startDate: DateTime(2020, 1, 1),
      endDate: DateTime(2020, 1, 1),
      dayCount: 0,
      method: AggregationMethod.median,
    );
    expect(empty.hasAnyData, isFalse);
  });
}
