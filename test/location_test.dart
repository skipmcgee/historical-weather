import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/models/location.dart';

void main() {
  test('fromGeocodingJson uses the API-provided name', () {
    final location = Location.fromGeocodingJson({
      'name': 'Austin',
      'latitude': 30.27,
      'longitude': -97.74,
      'admin1': 'Texas',
      'country': 'United States',
    });

    expect(location.name, 'Austin');
    expect(location.latitude, 30.27);
    expect(location.longitude, -97.74);
  });

  test('fromGeocodingJson falls back to coordinates when name is missing', () {
    final location = Location.fromGeocodingJson({
      'latitude': 30.27,
      'longitude': -97.74,
    });

    expect(location.name, '30.2700, -97.7400');
  });
}
