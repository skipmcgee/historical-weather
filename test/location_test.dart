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

  test('fromNominatimJson builds a street-address name from house number + road', () {
    final location = Location.fromNominatimJson({
      'lat': '38.8976387',
      'lon': '-77.0365525',
      'name': 'White House',
      'display_name': 'White House, 1600, Pennsylvania Avenue Northwest, Washington, United States',
      'address': {
        'house_number': '1600',
        'road': 'Pennsylvania Avenue Northwest',
        'city': 'Washington',
        'state': 'District of Columbia',
        'country': 'United States',
      },
    });

    expect(location.name, '1600 Pennsylvania Avenue Northwest');
    expect(location.latitude, closeTo(38.8976387, 1e-9));
    expect(location.longitude, closeTo(-77.0365525, 1e-9));
    expect(location.admin1, 'Washington, District of Columbia');
    expect(location.country, 'United States');
    expect(location.displayLabel, '1600 Pennsylvania Avenue Northwest, Washington, District of Columbia, United States');
  });

  test('fromNominatimJson uses the plain place name for a city-level result, without duplicating it', () {
    final location = Location.fromNominatimJson({
      'lat': '30.2711286',
      'lon': '-97.7436995',
      'name': 'Austin',
      'display_name': 'Austin, Travis County, Texas, United States',
      'address': {'city': 'Austin', 'county': 'Travis County', 'state': 'Texas', 'country': 'United States'},
    });

    expect(location.name, 'Austin');
    // The city ("Austin") isn't repeated in admin1 since it's already the name.
    expect(location.admin1, 'Texas');
    expect(location.displayLabel, 'Austin, Texas, United States');
  });

  test('fromNominatimJson falls back to the road when there is no house number', () {
    final location = Location.fromNominatimJson({
      'lat': '30.27',
      'lon': '-97.74',
      'name': '',
      'display_name': 'East Cesar Chavez Street, Austin, Texas, United States',
      'address': {'road': 'East Cesar Chavez Street', 'city': 'Austin', 'state': 'Texas', 'country': 'United States'},
    });

    expect(location.name, 'East Cesar Chavez Street');
  });

  test('fromNominatimJson falls back to the first display_name segment with no other usable field', () {
    final location = Location.fromNominatimJson({
      'lat': '10.0',
      'lon': '20.0',
      'name': '',
      'display_name': 'Somewhere Remote, Nowhere Country',
      'address': <String, dynamic>{},
    });

    expect(location.name, 'Somewhere Remote');
    expect(location.admin1, isNull);
  });
}
