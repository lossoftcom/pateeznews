import 'package:web/web.dart' as web;

import 'browser_auth_storage_keys.dart';

void clearBrowserAuthStorage() {
  final storage = web.window.localStorage;
  for (final key in browserAuthStorageKeys()) {
    storage.removeItem(key);
  }
}
