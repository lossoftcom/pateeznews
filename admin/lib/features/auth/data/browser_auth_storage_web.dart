import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'browser_auth_storage_keys.dart';

void saveBrowserAuthSession(Map<String, Object?> session) {
  try {
    final payload = browserAuthSessionPayload(session);
    if (payload.isEmpty) return;

    final encoded = jsonEncode(payload);
    final storage = web.window.localStorage;
    storage.setItem(pateezAuthStorageKey, encoded);
    storage.setItem(supabaseAuthStorageKey(), encoded);
  } catch (_) {
    // localStorage can be unavailable in restricted browser modes.
  }
}

Object listenBrowserAuthStorageChanges(void Function() onChange) {
  final listener = ((web.Event event) {
    final storageEvent = event as web.StorageEvent;
    final key = storageEvent.key;
    if (key == null || !browserAuthStorageKeys().contains(key)) return;
    onChange();
  }).toJS;
  web.window.addEventListener('storage', listener);
  return listener;
}

void cancelBrowserAuthStorageChanges(Object? listener) {
  if (listener == null) return;
  try {
    web.window.removeEventListener('storage', listener as web.EventListener);
  } catch (_) {
    // Listener may come from the non-web stub during tests.
  }
}

void clearBrowserAuthStorage() {
  final storage = web.window.localStorage;
  for (final key in browserAuthStorageKeys()) {
    storage.removeItem(key);
  }
}
