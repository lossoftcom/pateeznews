import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sdk;

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
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final AdminSessionStore sessionStore;
  final String? apiBaseUrl;

  @override
  Future<AdminAuthState?> restoreSession() async {
    if (_usesSupabaseSdk) {
      final sdkSession = sdk.Supabase.instance.client.auth.currentSession;
      if (sdkSession != null) {
        final session = adminSessionFromSupabaseSession(sdkSession);
        await sessionStore.saveSession(session);
        final profile = await _profileForSession(session);
        return AdminAuthState(session: session, profile: profile);
      }
    }

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
    if (_usesSupabaseSdk) {
      final result = await sdk.Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final sdkSession = result.session;
      if (sdkSession == null || sdkSession.accessToken.isEmpty) {
        throw const AdminAuthException('Giriş oturumu alınamadı');
      }
      final session = adminSessionFromSupabaseSession(sdkSession);
      await sessionStore.saveSession(session);
      final profile = await _profileForSession(session);
      return AdminAuthState(session: session, profile: profile);
    }

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
    if (_usesSupabaseSdk) {
      await sdk.Supabase.instance.client.auth.signOut();
    }
    await sessionStore.clearAuth();
  }

  bool get _usesSupabaseSdk =>
      _supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty;

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

AdminSession adminSessionFromSupabaseSession(sdk.Session session) {
  final user = session.user;
  return AdminSession(
    accessToken: session.accessToken,
    tokenType: session.tokenType,
    expiresAt:
        session.expiresAt ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
    user: AdminUser(
      id: user.id,
      email: user.email,
      role: user.role,
      aud: user.aud,
      userMetadata: _mapFromSdk(user.userMetadata),
      appMetadata: _mapFromSdk(user.appMetadata),
    ),
  );
}

Map<String, Object?> _mapFromSdk(Map<String, dynamic>? value) {
  if (value == null) return const {};
  return value.map((key, nestedValue) => MapEntry(key, nestedValue));
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}
