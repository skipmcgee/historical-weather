/// A geographic location, either picked from the Open-Meteo geocoding search
/// results or entered manually as raw coordinates.
class Location {
  Location({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.admin1,
    this.country,
    this.timezone,
    this.manual = false,
  });

  /// Coordinates typed in directly by the user, with no place name attached.
  factory Location.manual({required double latitude, required double longitude}) {
    return Location(
      name: '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
      latitude: latitude,
      longitude: longitude,
      manual: true,
    );
  }

  factory Location.fromGeocodingJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num).toDouble();
    final longitude = (json['longitude'] as num).toDouble();
    // Some sparse/administrative geocoding results come back without a
    // `name` -- fall back to the coordinates rather than throwing, matching
    // how Location.manual labels an otherwise-unnamed point.
    final name = json['name'] as String? ?? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    return Location(
      name: name,
      latitude: latitude,
      longitude: longitude,
      admin1: json['admin1'] as String?,
      country: json['country'] as String?,
      timezone: json['timezone'] as String?,
    );
  }

  /// The device's current position, resolved via geolocation rather than a
  /// name search.
  factory Location.currentDevicePosition({required double latitude, required double longitude}) {
    return Location(name: 'Current location', latitude: latitude, longitude: longitude, manual: true);
  }

  /// Round-trips a [Location] through local persistence (settings storage).
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      admin1: json['admin1'] as String?,
      country: json['country'] as String?,
      timezone: json['timezone'] as String?,
      manual: json['manual'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'admin1': admin1,
      'country': country,
      'timezone': timezone,
      'manual': manual,
    };
  }

  final String name;
  final double latitude;
  final double longitude;
  final String? admin1;
  final String? country;
  final String? timezone;
  final bool manual;

  /// A one-line human-readable label, e.g. "Austin, Texas, United States".
  String get displayLabel {
    if (manual) return name;
    final parts = [name, admin1, country].whereType<String>().where((p) => p.isNotEmpty);
    return parts.join(', ');
  }
}
