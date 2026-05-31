import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_auth_models.dart';

class AdminSessionStore {
  const AdminSessionStore({
    this._secureStorage = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  });

  static const _sessionKey = 'supabase-auth-token';
  static const _profileCacheKey = 'pateez_profile_cache';

  final FlutterSecureStorage _secureStorage;

  Future<AdminSession?> readSession() async {
    var rawSession = await _secureStorage.read(key: _sessionKey);
    if (rawSession == null || rawSession.isEmpty) {
      rawSession = await _readLegacySession();
    }
    if (rawSession == null || rawSession.isEmpty) return null;

    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map) return null;
      return AdminSession.fromJson(_asStringKeyMap(decoded));
    } catch (_) {
      return null;
    }
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
    await clearSession();
    await clearProfileCache();
  }
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}
