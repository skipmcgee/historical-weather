/// A tiny key-value string store, abstracted so platform-specific
/// persistence backends (see key_value_store_io.dart / _web.dart) can be
/// swapped in behind [createKeyValueStore].
abstract class KeyValueStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}
