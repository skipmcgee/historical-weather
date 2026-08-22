import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:historical_weather/services/device_location_service.dart';

class _FakeGeolocatorApi implements GeolocatorApi {
  _FakeGeolocatorApi({
    this.serviceEnabled = true,
    this.initialPermission = LocationPermission.whileInUse,
    this.permissionAfterRequest,
    this.position,
    this.getCurrentPositionError,
  });

  final bool serviceEnabled;
  final LocationPermission initialPermission;
  final LocationPermission? permissionAfterRequest;
  final Position? position;
  final Object? getCurrentPositionError;

  int requestPermissionCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => initialPermission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls++;
    return permissionAfterRequest ?? initialPermission;
  }

  @override
  Future<Position> getCurrentPosition({required LocationSettings locationSettings}) async {
    if (getCurrentPositionError != null) throw getCurrentPositionError!;
    return position!;
  }
}

Position _testPosition({double latitude = 30.27, double longitude = -97.74}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2020, 1, 1),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  test('returns null when location services are disabled', () async {
    final service = DeviceLocationService(geolocator: _FakeGeolocatorApi(serviceEnabled: false));
    expect(await service.tryGetCurrentLocation(), isNull);
  });

  test('returns the device position when permission is already granted', () async {
    final fake = _FakeGeolocatorApi(
      initialPermission: LocationPermission.whileInUse,
      position: _testPosition(latitude: 30.27, longitude: -97.74),
    );
    final service = DeviceLocationService(geolocator: fake);

    final location = await service.tryGetCurrentLocation();

    expect(location, isNotNull);
    expect(location!.latitude, 30.27);
    expect(location.longitude, -97.74);
    // Already granted -- no need to prompt.
    expect(fake.requestPermissionCalls, 0);
  });

  test('requests permission when initially denied, then proceeds if granted', () async {
    final fake = _FakeGeolocatorApi(
      initialPermission: LocationPermission.denied,
      permissionAfterRequest: LocationPermission.whileInUse,
      position: _testPosition(),
    );
    final service = DeviceLocationService(geolocator: fake);

    final location = await service.tryGetCurrentLocation();

    expect(location, isNotNull);
    expect(fake.requestPermissionCalls, 1);
  });

  test('returns null when permission is denied even after requesting', () async {
    final fake = _FakeGeolocatorApi(
      initialPermission: LocationPermission.denied,
      permissionAfterRequest: LocationPermission.denied,
    );
    final service = DeviceLocationService(geolocator: fake);

    expect(await service.tryGetCurrentLocation(), isNull);
    expect(fake.requestPermissionCalls, 1);
  });

  test('returns null without prompting when permission is permanently denied', () async {
    final fake = _FakeGeolocatorApi(initialPermission: LocationPermission.deniedForever);
    final service = DeviceLocationService(geolocator: fake);

    expect(await service.tryGetCurrentLocation(), isNull);
    // deniedForever isn't `denied`, so the requestPermission() branch never
    // runs -- re-prompting a permanently-denied permission is a no-op on
    // every platform, so there's no point calling it.
    expect(fake.requestPermissionCalls, 0);
  });

  test('returns null instead of throwing when getCurrentPosition fails', () async {
    final fake = _FakeGeolocatorApi(getCurrentPositionError: Exception('timed out'));
    final service = DeviceLocationService(geolocator: fake);

    expect(await service.tryGetCurrentLocation(), isNull);
  });
}
