import 'package:geolocator/geolocator.dart';

import '../models/location.dart';

/// The small slice of `Geolocator`'s static API that
/// [DeviceLocationService] actually needs, extracted behind an interface so
/// tests can supply a fake instead of driving real platform location
/// services (which don't exist in a `flutter test` environment). Mirrors
/// the same seam `OpenMeteoService` gets from taking an injectable
/// `http.Client`.
abstract class GeolocatorApi {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition({required LocationSettings locationSettings});
}

class _RealGeolocatorApi implements GeolocatorApi {
  const _RealGeolocatorApi();

  @override
  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition({required LocationSettings locationSettings}) =>
      Geolocator.getCurrentPosition(locationSettings: locationSettings);
}

/// Best-effort lookup of the device's current position. Returns `null` on
/// any failure (permission denied, location services disabled, timeout,
/// unsupported platform) rather than throwing — this is a convenience
/// default, not a requirement, so callers should treat `null` as "let the
/// user pick a location manually" with no error shown.
class DeviceLocationService {
  DeviceLocationService({GeolocatorApi? geolocator}) : _geolocator = geolocator ?? const _RealGeolocatorApi();

  final GeolocatorApi _geolocator;

  Future<Location?> tryGetCurrentLocation() async {
    try {
      if (!await _geolocator.isLocationServiceEnabled()) return null;

      var permission = await _geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await _geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return Location.currentDevicePosition(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return null;
    }
  }
}
