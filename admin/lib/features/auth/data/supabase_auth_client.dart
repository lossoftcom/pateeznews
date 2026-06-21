import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import 'admin_auth_models.dart';
import 'admin_auth_repository.dart';
import 'admin_session_store.dart';

class SupabaseAuthClient implements AdminAuthRepository {
  const SupabaseAuthClient({
    this.httpClient,
    this.sessionStore = const AdminSessionStore(),
    this.apiBaseUrl,
  });

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final AdminSessionStore sessionStore;
  final String? apiBaseUrl;

  @override
  Future<AdminAuthState?> restoreSession() async {
    return _restoreStoredSession();
  }

  Future<AdminAuthState?> _restoreStoredSession() async {
    final storedSession = await sessionStore.readSession();
    if (storedSession == null || storedSession.accessToken.isEmpty) {
      await sessionStore.clearAuth();
      return null;
    }

    if (storedSession.isExpired) {
      await sessionStore.clearAuth();
      return null;
    }

    final result = await _postJson('/api/supabase/auth', {
      'action': 'getSession',
      'token': storedSession.accessToken,
    });

    final session = _sessionFromResult(result);
    if (session == null) {
      await sessionStore.clearAuth();
      return null;
    }

    await sessionStore.saveSession(session);
    final profile = await _profileForSession(session);
    return AdminAuthState(session: session, profile: profile);
  }

  @override
  Future<AdminAuthState> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final result = await _postJson('/api/supabase/auth', {
      'action': 'signInWithPassword',
      'email': email.trim(),
      'password': password,
    });

    _throwIfApiError(result, fallbackMessage: 'Giriş yapılamadı');
    final session = _sessionFromResult(result);
    if (session == null || session.accessToken.isEmpty) {
      throw const AdminAuthException('Giriş oturumu alınamadı');
    }

    await sessionStore.saveSession(session);
    final profile = await _profileForSession(session);
    return AdminAuthState(session: session, profile: profile);
  }

  @override
  Future<void> signOut() async {
    await sessionStore.clearAuth();
  }

  Future<AdminProfile?> _profileForSession(AdminSession session) async {
    try {
      final profile = await _fetchProfile(session.user.id);
      if (profile != null) {
        await sessionStore.saveProfileCache(profile);
        return profile;
      }

      await sessionStore.clearProfileCache();
      return null;
    } catch (_) {
      return sessionStore.readProfileCache();
    }
  }

  Future<AdminProfile?> _fetchProfile(String userId) async {
    if (userId.isEmpty) return null;

    final result = await _postJson('/api/admin/query', {
      'table': 'profiles',
      'method': 'select',
      'select': 'id,username,full_name,avatar_url,role,email',
      'filters': [
        {'type': 'comparison', 'op': 'eq', 'column': 'id', 'value': userId},
      ],
      'single': 'maybeSingle',
    });

    _throwIfApiError(result, fallbackMessage: 'Profil bilgisi alınamadı');
    final data = result['data'];
    if (data is! Map) return null;
    return AdminProfile.fromJson(_asStringKeyMap(data));
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final encodedBody = jsonEncode(body);
    final headers = await adminJsonHeaders();

    final response =
        await (httpClient?.post(
                  _uri(path),
                  headers: headers,
                  body: encodedBody,
                ) ??
                adminHttpClient.post(
                  _uri(path),
                  headers: headers,
                  body: encodedBody,
                ))
            .timeout(_requestTimeout);

    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminAuthException('Geçersiz sunucu yanıtı');
    }

    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfApiError(result, fallbackMessage: 'Sunucu isteği başarısız');
    }
    return result;
  }

  Uri _uri(String path) {
    final baseUrl = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (baseUrl.isNotEmpty) {
      return Uri.parse(baseUrl).resolve(path);
    }
    if (!kIsWeb) {
      return _defaultLocalApiBaseUrl().resolve(path);
    }
    return Uri.base.resolve(path);
  }

  Uri _defaultLocalApiBaseUrl() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse('http://10.0.2.2:4321'),
      _ => Uri.parse('http://127.0.0.1:4321'),
    };
  }

  AdminSession? _sessionFromResult(Map<String, Object?> result) {
    final data = result['data'];
    if (data is! Map) return null;
    final session = data['session'];
    if (session is! Map) return null;
    return AdminSession.fromJson(_asStringKeyMap(session));
  }

  void _throwIfApiError(
    Map<String, Object?> result, {
    required String fallbackMessage,
  }) {
    final error = result['error'];
    if (error == null) return;
    if (error is Map) {
      final message = error['message']?.toString();
      if (message != null && message.isNotEmpty) {
        throw AdminAuthException(message);
      }
    }
    throw AdminAuthException(fallbackMessage);
  }
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}
