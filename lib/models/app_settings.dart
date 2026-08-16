import 'package:flutter/material.dart';

import 'aggregation_method.dart';
import 'location.dart';
import 'unit_system.dart';

/// User-configurable app settings, persisted locally on-device only.
class AppSettings {
  const AppSettings({
    this.apiKey,
    this.defaultLocation,
    this.themeMode = ThemeMode.system,
    this.aggregationMethod = AggregationMethod.median,
    this.unitSystem = UnitSystem.imperial,
  });

  final String? apiKey;
  final Location? defaultLocation;
  final ThemeMode themeMode;
  final AggregationMethod aggregationMethod;
  final UnitSystem unitSystem;

  AppSettings copyWith({
    String? apiKey,
    bool clearApiKey = false,
    Location? defaultLocation,
    bool clearDefaultLocation = false,
    ThemeMode? themeMode,
    AggregationMethod? aggregationMethod,
    UnitSystem? unitSystem,
  }) {
    return AppSettings(
      apiKey: clearApiKey ? null : (apiKey ?? this.apiKey),
      defaultLocation: clearDefaultLocation ? null : (defaultLocation ?? this.defaultLocation),
      themeMode: themeMode ?? this.themeMode,
      aggregationMethod: aggregationMethod ?? this.aggregationMethod,
      unitSystem: unitSystem ?? this.unitSystem,
    );
  }
}
