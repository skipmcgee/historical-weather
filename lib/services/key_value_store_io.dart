import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_store_base.dart';

/// macOS/iOS/Linux: one real user per device install, so persistent
/// on-disk storage (surviving app restarts) is the right behavior.
KeyValueStore createKeyValueStore() => _SharedPreferencesStore();

class _SharedPreferencesStore implements KeyValueStore {
  @override
  Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
