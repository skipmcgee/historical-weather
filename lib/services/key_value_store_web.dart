import 'package:web/web.dart' as web;

import 'key_value_store_base.dart';

/// Web: this is a single static page anyone can open, with no accounts or
/// backend, so there's no real notion of "the current user" beyond "the
/// browser tab someone has open." Backing this with `localStorage` (as
/// plain shared_preferences does on web) means every tab on a given
/// browser/device shares one bucket of settings -- one person's API key or
/// default location silently overwrites another's the moment they use the
/// app in a second tab. `sessionStorage` is scoped per tab (a new tab gets
/// a blank slate, even for the same URL), which keeps concurrent users on
/// the same browser from stepping on each other, at the cost of settings
/// not surviving a tab close -- an acceptable trade for a keyless, backend-
/// less app like this one.
KeyValueStore createKeyValueStore() => _SessionStorageStore();

class _SessionStorageStore implements KeyValueStore {
  @override
  Future<String?> getString(String key) async => web.window.sessionStorage.getItem(key);

  @override
  Future<void> setString(String key, String value) async {
    web.window.sessionStorage.setItem(key, value);
  }

  @override
  Future<void> remove(String key) async {
    web.window.sessionStorage.removeItem(key);
  }
}
