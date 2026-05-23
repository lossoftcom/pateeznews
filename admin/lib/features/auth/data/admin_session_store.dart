import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'admin_auth_models.dart';

class AdminSessionStore {
  const AdminSessionStore();

  static const _sessionKey = 'neon-auth-token';
  static const _profileCacheKey = 'pateez_profile_cache';

  Future<AdminSession?> readSession() async {
    final preferences = await SharedPreferences.getInstance();
    final rawSession = preferences.getString(_sessionKey);
    if (rawSession == null || rawSession.isEmpty) return null;

    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map) return null;
      return AdminSession.fromJson(_asStringKeyMap(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(AdminSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clearSession() async {
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
