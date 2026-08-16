import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/location.dart';

/// Loads/saves [AppSettings] to local on-device storage.
class SettingsService {
  static const _apiKeyKey = 'open_meteo_api_key';
  static const _defaultLocationKey = 'default_location';
  static const _themeModeKey = 'theme_mode';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_apiKeyKey);
    final locationJson = prefs.getString(_defaultLocationKey);
    final themeModeName = prefs.getString(_themeModeKey);

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
      themeMode: _themeModeFromName(themeModeName),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    if (settings.apiKey == null || settings.apiKey!.isEmpty) {
      await prefs.remove(_apiKeyKey);
    } else {
      await prefs.setString(_apiKeyKey, settings.apiKey!);
    }

    if (settings.defaultLocation == null) {
      await prefs.remove(_defaultLocationKey);
    } else {
      await prefs.setString(_defaultLocationKey, jsonEncode(settings.defaultLocation!.toJson()));
    }

    await prefs.setString(_themeModeKey, settings.themeMode.name);
  }

  ThemeMode _themeModeFromName(String? name) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeMode.system,
    );
  }
}
