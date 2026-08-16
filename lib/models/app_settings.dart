import 'package:flutter/material.dart';

import 'location.dart';

/// User-configurable app settings, persisted locally on-device only.
class AppSettings {
  const AppSettings({this.apiKey, this.defaultLocation, this.themeMode = ThemeMode.system});

  final String? apiKey;
  final Location? defaultLocation;
  final ThemeMode themeMode;

  AppSettings copyWith({
    String? apiKey,
    bool clearApiKey = false,
    Location? defaultLocation,
    bool clearDefaultLocation = false,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      apiKey: clearApiKey ? null : (apiKey ?? this.apiKey),
      defaultLocation: clearDefaultLocation ? null : (defaultLocation ?? this.defaultLocation),
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
