/// Display/output unit system. [WeatherSummary] always stores canonical
/// metric values internally (that's what Open-Meteo returns and what gets
/// cached) -- conversion to imperial happens only at the display/JSON-export
/// boundary, so switching this never requires a re-fetch.
enum UnitSystem {
  metric,
  imperial;

  String get label => switch (this) {
        UnitSystem.metric => 'Metric',
        UnitSystem.imperial => 'Imperial',
      };
}

extension UnitConversions on UnitSystem {
  bool get _isMetric => this == UnitSystem.metric;

  String get temperatureUnit => _isMetric ? '°C' : '°F';
  double? convertTemperatureC(double? celsius) {
    if (celsius == null) return null;
    return _isMetric ? celsius : celsius * 9 / 5 + 32;
  }

  String get precipitationUnit => _isMetric ? 'mm' : 'in';
  double? convertMm(double? mm) {
    if (mm == null) return null;
    return _isMetric ? mm : mm / 25.4;
  }

  String get snowfallUnit => _isMetric ? 'cm' : 'in';
  double? convertCm(double? cm) {
    if (cm == null) return null;
    return _isMetric ? cm : cm / 2.54;
  }

  String get windSpeedUnit => _isMetric ? 'km/h' : 'mph';
  double? convertKmh(double? kmh) {
    if (kmh == null) return null;
    return _isMetric ? kmh : kmh * 0.621371;
  }

  String get pressureUnit => _isMetric ? 'hPa' : 'inHg';
  double? convertHpa(double? hpa) {
    if (hpa == null) return null;
    return _isMetric ? hpa : hpa * 0.02953;
  }
}
