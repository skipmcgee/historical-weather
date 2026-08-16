import 'package:geolocator/geolocator.dart';

import '../models/location.dart';

/// Best-effort lookup of the device's current position. Returns `null` on
/// any failure (permission denied, location services disabled, timeout,
/// unsupported platform) rather than throwing — this is a convenience
/// default, not a requirement, so callers should treat `null` as "let the
/// user pick a location manually" with no error shown.
class DeviceLocationService {
  Future<Location?> tryGetCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
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
