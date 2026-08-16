import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_weather/models/app_settings.dart';
import 'package:historical_weather/models/location.dart';
import 'package:historical_weather/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load() returns defaults when nothing has been saved', () async {
    final settings = await SettingsService().load();
    expect(settings.apiKey, isNull);
    expect(settings.defaultLocation, isNull);
    expect(settings.themeMode, ThemeMode.system);
  });

  test('save() then load() round-trips api key, location, and theme mode', () async {
    final service = SettingsService();
    final location = Location(
      name: 'Austin',
      latitude: 30.27,
      longitude: -97.74,
      admin1: 'Texas',
      country: 'United States',
      timezone: 'America/Chicago',
    );

    await service.save(AppSettings(
      apiKey: 'secret-key',
      defaultLocation: location,
      themeMode: ThemeMode.dark,
    ));

    final loaded = await service.load();
    expect(loaded.apiKey, 'secret-key');
    expect(loaded.themeMode, ThemeMode.dark);
    expect(loaded.defaultLocation?.name, 'Austin');
    expect(loaded.defaultLocation?.latitude, closeTo(30.27, 1e-9));
    expect(loaded.defaultLocation?.longitude, closeTo(-97.74, 1e-9));
    expect(loaded.defaultLocation?.timezone, 'America/Chicago');
  });

  test('save() with nulls clears previously saved api key and location', () async {
    final service = SettingsService();
    await service.save(AppSettings(
      apiKey: 'secret-key',
      defaultLocation: Location.manual(latitude: 1, longitude: 2),
    ));

    await service.save(const AppSettings());

    final loaded = await service.load();
    expect(loaded.apiKey, isNull);
    expect(loaded.defaultLocation, isNull);
  });
}
