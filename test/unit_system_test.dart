import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/models/unit_system.dart';

void main() {
  group('metric', () {
    const u = UnitSystem.metric;

    test('passes values through unchanged', () {
      expect(u.convertTemperatureC(20.0), closeTo(20.0, 1e-9));
      expect(u.convertMm(10.0), closeTo(10.0, 1e-9));
      expect(u.convertCm(5.0), closeTo(5.0, 1e-9));
      expect(u.convertKmh(100.0), closeTo(100.0, 1e-9));
      expect(u.convertHpa(1013.0), closeTo(1013.0, 1e-9));
    });

    test('units are the metric labels', () {
      expect(u.temperatureUnit, '°C');
      expect(u.precipitationUnit, 'mm');
      expect(u.snowfallUnit, 'cm');
      expect(u.windSpeedUnit, 'km/h');
      expect(u.pressureUnit, 'hPa');
    });
  });

  group('imperial', () {
    const u = UnitSystem.imperial;

    test('converts temperature C -> F', () {
      expect(u.convertTemperatureC(0.0), closeTo(32.0, 1e-9));
      expect(u.convertTemperatureC(100.0), closeTo(212.0, 1e-9));
      expect(u.convertTemperatureC(20.0), closeTo(68.0, 1e-9));
    });

    test('converts mm -> inches', () {
      expect(u.convertMm(25.4), closeTo(1.0, 1e-9));
    });

    test('converts cm -> inches', () {
      expect(u.convertCm(2.54), closeTo(1.0, 1e-9));
    });

    test('converts km/h -> mph', () {
      expect(u.convertKmh(100.0), closeTo(62.1371, 1e-4));
    });

    test('converts hPa -> inHg', () {
      expect(u.convertHpa(1013.25), closeTo(29.92, 1e-2));
    });

    test('units are the imperial labels', () {
      expect(u.temperatureUnit, '°F');
      expect(u.precipitationUnit, 'in');
      expect(u.snowfallUnit, 'in');
      expect(u.windSpeedUnit, 'mph');
      expect(u.pressureUnit, 'inHg');
    });
  });

  test('conversions pass through null', () {
    for (final u in UnitSystem.values) {
      expect(u.convertTemperatureC(null), isNull);
      expect(u.convertMm(null), isNull);
      expect(u.convertCm(null), isNull);
      expect(u.convertKmh(null), isNull);
      expect(u.convertHpa(null), isNull);
    }
  });
}
