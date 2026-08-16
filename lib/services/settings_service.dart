import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/aggregation_method.dart';
import '../models/app_settings.dart';
import '../models/location.dart';
import '../models/unit_system.dart';
import 'key_value_store.dart';

/// Loads/saves [AppSettings] to local storage (see [createKeyValueStore]
/// for why that means something different on web than on a native install).
class SettingsService {
  static const _apiKeyKey = 'open_meteo_api_key';
  static const _defaultLocationKey = 'default_location';
  static const _themeModeKey = 'theme_mode';
  static const _aggregationMethodKey = 'aggregation_method';
  static const _unitSystemKey = 'unit_system';

  final KeyValueStore _store = createKeyValueStore();

  Future<AppSettings> load() async {
    final apiKey = await _store.getString(_apiKeyKey);
    final locationJson = await _store.getString(_defaultLocationKey);
    final themeModeName = await _store.getString(_themeModeKey);
    final aggregationMethodName = await _store.getString(_aggregationMethodKey);
    final unitSystemName = await _store.getString(_unitSystemKey);

    Location? defaultLocation;
    if (locationJson != null) {
      try {
        defaultLocation = Location.fromJson(jsonDecode(locationJson) as Map<String, dynamic>);
      } catch (_) {
        defaultLocation = null;
      }
    }

    return AppSettings(
      apiKey: (apiKey == null || apiKey.isEmpty) ? null : apiKey,
      defaultLocation: defaultLocation,
      themeMode: _fromName(ThemeMode.values, themeModeName, ThemeMode.system),
      aggregationMethod: _fromName(AggregationMethod.values, aggregationMethodName, AggregationMethod.median),
      unitSystem: _fromName(UnitSystem.values, unitSystemName, UnitSystem.imperial),
    );
  }

  Future<void> save(AppSettings settings) async {
    if (settings.apiKey == null || settings.apiKey!.isEmpty) {
      await _store.remove(_apiKeyKey);
    } else {
      await _store.setString(_apiKeyKey, settings.apiKey!);
    }

    if (settings.defaultLocation == null) {
      await _store.remove(_defaultLocationKey);
    } else {
      await _store.setString(_defaultLocationKey, jsonEncode(settings.defaultLocation!.toJson()));
    }

    await _store.setString(_themeModeKey, settings.themeMode.name);
    await _store.setString(_aggregationMethodKey, settings.aggregationMethod.name);
    await _store.setString(_unitSystemKey, settings.unitSystem.name);
  }

  T _fromName<T extends Enum>(List<T> values, String? name, T fallback) {
    return values.firstWhere((v) => v.name == name, orElse: () => fallback);
  }
}
