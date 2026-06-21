import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_auth_models.dart';
import 'browser_auth_storage.dart';

class AdminSessionStore {
  const AdminSessionStore({
    this._secureStorage = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
    this.browserSessionReader,
  });

  static const _sessionKey = 'supabase-auth-token';
  static const _profileCacheKey = 'pateez_profile_cache';

  final FlutterSecureStorage _secureStorage;
  final Map<String, Object?>? Function()? browserSessionReader;

  Future<AdminSession?> readSession() async {
    final browserSession = await _readBrowserSession();
    if (browserSession != null && !browserSession.isExpired) {
      return browserSession;
    }
    if (kIsWeb) return browserSession;

    var rawSession = await _secureStorage.read(key: _sessionKey);
    if (rawSession == null || rawSession.isEmpty) {
      rawSession = await _readLegacySession();
    }

    final storedSession = _sessionFromRaw(rawSession);
    return storedSession ?? browserSession;
  }

  Future<String?> _readLegacySession() async {
    final preferences = await SharedPreferences.getInstance();
    final rawSession = preferences.getString(_sessionKey);
    if (rawSession == null || rawSession.isEmpty) return null;

    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map) return null;
      await _secureStorage.write(key: _sessionKey, value: rawSession);
      await preferences.remove(_sessionKey);
      return rawSession;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(AdminSession session) async {
    await _secureStorage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
    saveBrowserAuthSession(session.toJson());
  }

  Future<AdminSession?> _readBrowserSession() async {
    final rawSession = (browserSessionReader ?? readBrowserAuthSession)();
    if (rawSession == null) return null;

    try {
      final session = AdminSession.fromJson(rawSession);
      if (session.accessToken.isEmpty) return null;
      await _secureStorage.write(
        key: _sessionKey,
        value: jsonEncode(session.toJson()),
      );
      return session;
    } catch (_) {
      return null;
    }
  }

  AdminSession? _sessionFromRaw(String? rawSession) {
    if (rawSession == null || rawSession.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map) return null;
      return AdminSession.fromJson(_asStringKeyMap(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _sessionKey);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }

  Future<AdminProfile?> readProfileCache() async {
    final preferences = await SharedPreferences.getInstance();
    final rawProfile = preferences.getString(_profileCacheKey);
    if (rawProfile == null || rawProfile.isEmpty) return null;

    try {
      final decoded = jsonDecode(rawProfile);
      if (decoded is! Map) return null;
      return AdminProfile.fromJson(_asStringKeyMap(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfileCache(AdminProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileCacheKey, jsonEncode(profile.toJson()));
  }

  Future<void> clearProfileCache() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_profileCacheKey);
  }

  Future<void> clearAuth() async {
    clearBrowserAuthStorage();
    await _ignoreStorageErrors(clearSession);
    await _ignoreStorageErrors(clearProfileCache);
  }
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}

Future<void> _ignoreStorageErrors(Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    // Browser auth has already been cleared; local storage cleanup must not
    // keep the user signed in on the public frontend.
  }
}
