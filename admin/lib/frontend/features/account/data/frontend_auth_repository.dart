import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/frontend_http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/local_api_base_url.dart';

class FrontendAuthException implements Exception {
  const FrontendAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum FrontendSocialAuthProvider {
  google('google'),
  apple('apple'),
  facebook('facebook'),
  x('x');

  const FrontendSocialAuthProvider(this.id);

  final String id;
}

class FrontendAuthUser {
  const FrontendAuthUser({
    required this.id,
    required this.email,
    required this.userMetadata,
  });

  final String id;
  final String? email;
  final Map<String, Object?> userMetadata;

  factory FrontendAuthUser.fromJson(Map<String, Object?> json) {
    return FrontendAuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString(),
      userMetadata: _asStringMap(json['user_metadata']),
    );
  }

  Map<String, Object?> toJson() {
    return {'id': id, 'email': email, 'user_metadata': userMetadata};
  }
}

class FrontendAuthSession {
  const FrontendAuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final int expiresAt;
  final FrontendAuthUser user;

  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt <= now;
  }

  factory FrontendAuthSession.fromJson(Map<String, Object?> json) {
    return FrontendAuthSession(
      accessToken: json['access_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      expiresAt: _asInt(json['expires_at']),
      user: FrontendAuthUser.fromJson(_asStringMap(json['user'])),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'expires_at': expiresAt,
      'user': user.toJson(),
    };
  }
}

class FrontendProfile {
  const FrontendProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.coverUrl,
    required this.role,
    required this.email,
    this.city,
    this.phone,
    this.address,
    this.authProvider,
  });

  final String id;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final String? coverUrl;
  final String? role;
  final String? email;
  final String? city;
  final String? phone;
  final String? address;
  final String? authProvider;

  bool get isAdmin {
    final value = role?.trim().toLowerCase() ?? '';
    return value == 'admin' || value == 'super_admin';
  }

  String get displayName {
    for (final value in [fullName, username, email]) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return 'Pateez';
  }

  String get handle {
    final value = username?.trim() ?? '';
    if (value.isEmpty) return email?.trim() ?? '';
    return value.startsWith('@') ? value : '@$value';
  }

  String get initials {
    final words = displayName
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return displayName.trim().isEmpty
        ? 'P'
        : displayName.trim()[0].toUpperCase();
  }

  factory FrontendProfile.fromJson(
    Map<String, Object?> json,
    String Function(String) resolveAvatarUrl,
  ) {
    return FrontendProfile(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString(),
      fullName: json['full_name']?.toString(),
      avatarUrl: resolveAvatarUrl(json['avatar_url']?.toString() ?? ''),
      coverUrl: resolveAvatarUrl(json['cover_url']?.toString() ?? ''),
      role: json['role']?.toString(),
      email: json['email']?.toString(),
      city: json['city']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      authProvider: json['auth_provider']?.toString(),
    );
  }

  FrontendProfile copyWith({
    String? id,
    String? username,
    String? fullName,
    String? avatarUrl,
    String? coverUrl,
    String? role,
    String? email,
    String? city,
    String? phone,
    String? address,
    String? authProvider,
  }) {
    return FrontendProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      role: role ?? this.role,
      email: email ?? this.email,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      authProvider: authProvider ?? this.authProvider,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'cover_url': coverUrl,
      'role': role,
      'email': email,
      'city': city,
      'phone': phone,
      'address': address,
      'auth_provider': authProvider,
    };
  }
}

class FrontendAuthState {
  const FrontendAuthState({required this.session, required this.profile});

  final FrontendAuthSession session;
  final FrontendProfile? profile;

  String get displayName {
    final name = profile?.displayName.trim();
    if (name != null && name.isNotEmpty) return name;
    return session.user.email?.split('@').first.trim().isNotEmpty == true
        ? session.user.email!.split('@').first
        : 'Pateez';
  }

  String get subtitle {
    final handle = profile?.handle.trim() ?? '';
    if (handle.isNotEmpty) return handle;
    return session.user.email ?? '';
  }

  String get avatarUrl => profile?.avatarUrl?.trim() ?? '';

  String get initials => profile?.initials ?? displayName[0].toUpperCase();

  bool get isAdmin => profile?.isAdmin == true;
}

class FrontendAuthStore {
  const FrontendAuthStore({
    this.secureStorage = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  });

  static const _sessionKey = 'pateez_frontend_auth_session';
  static const _profileCacheKey = 'pateez_frontend_profile_cache';

  final FlutterSecureStorage secureStorage;

  Future<FrontendAuthSession?> readSession() async {
    final rawSession = await secureStorage.read(key: _sessionKey);
    if (rawSession == null || rawSession.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map) return null;
      return FrontendAuthSession.fromJson(_asStringMap(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(FrontendAuthSession session) {
    return secureStorage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<void> clearSession() {
    return secureStorage.delete(key: _sessionKey);
  }

  Future<FrontendProfile?> readProfileCache(
    String Function(String) resolveAvatarUrl,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final rawProfile = preferences.getString(_profileCacheKey);
    if (rawProfile == null || rawProfile.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawProfile);
      if (decoded is! Map) return null;
      return FrontendProfile.fromJson(_asStringMap(decoded), resolveAvatarUrl);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfileCache(FrontendProfile profile) async {
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

class FrontendAuthRepository {
  const FrontendAuthRepository({
    this.httpClient,
    this.store = const FrontendAuthStore(),
    this.apiBaseUrl,
  });

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 8);
  static const _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '219689188237-jprruujk8knn7noafs2nbvdgnuc67mbe.apps.googleusercontent.com',
  );
  static const _googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '219689188237-nujlogsppna6kq2g3m3vjdlp0gfgvgmj.apps.googleusercontent.com',
  );
  static const _appleServiceId = String.fromEnvironment(
    'APPLE_SERVICE_ID',
    defaultValue: 'com.pateez.pateezcom.web',
  );
  static Future<void>? _googleInitializeFuture;

  final http.Client? httpClient;
  final FrontendAuthStore store;
  final String? apiBaseUrl;

  Future<FrontendAuthState?> restoreSession() async {
    final cachedSession = await store.readSession();
    if (cachedSession == null || cachedSession.accessToken.isEmpty) {
      return null;
    }

    final cachedProfile = await _cachedProfile();

    // Sunucudan taze oturum/profil almayı dener. Token süresi dolmuş, ağ yok ya
    // da sunucu yanıt vermiyor olsa bile kullanıcı ASLA otomatik çıkış
    // yaptırılmaz; önbellekteki oturumla devam edilir. Oturum yalnızca kullanıcı
    // açıkça [signOut] çağırınca kapanır.
    try {
      final result = await _postJson('/api/app/auth', {
        'action': 'getSession',
        'token': cachedSession.accessToken,
      });
      final freshSession = _sessionFromResult(result);
      final freshProfile = _profileFromResult(result);
      final session =
          (freshSession != null && freshSession.accessToken.isNotEmpty)
          ? freshSession
          : cachedSession;
      final profile = freshProfile ?? cachedProfile;
      await store.saveSession(session);
      if (profile != null) await store.saveProfileCache(profile);
      return FrontendAuthState(session: session, profile: profile);
    } catch (_) {
      // Ağ/sunucu hatasında bile önbellekteki oturumla açık kal.
      return FrontendAuthState(session: cachedSession, profile: cachedProfile);
    }
  }

  Future<FrontendAuthState> signInWithPassword({
    required String identifier,
    required String password,
  }) async {
    final result = await _postJson('/api/app/auth', {
      'action': 'signInWithPassword',
      'identifier': identifier.trim(),
      'password': password,
    });
    _throwIfApiError(result, fallbackMessage: 'Giriş yapılamadı');
    final session = _sessionFromResult(result);
    if (session == null || session.accessToken.isEmpty) {
      throw const FrontendAuthException('Giriş oturumu alınamadı');
    }

    final profile = _profileFromResult(result);
    await store.saveSession(session);
    if (profile != null) {
      await store.saveProfileCache(profile);
    } else {
      await store.clearProfileCache();
    }
    return FrontendAuthState(session: session, profile: profile);
  }

  Future<FrontendAuthState> signUpWithPassword({
    required String fullName,
    required String email,
    required String password,
    required String passwordAgain,
    required String city,
  }) async {
    final result = await _postJson('/api/app/auth', {
      'action': 'signUpWithPassword',
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'passwordAgain': passwordAgain,
      'city': city.trim(),
    });
    _throwIfApiError(result, fallbackMessage: 'Kayıt oluşturulamadı');
    final session = _sessionFromResult(result);
    if (session == null || session.accessToken.isEmpty) {
      throw const FrontendAuthException('Kayıt oturumu alınamadı');
    }

    final profile = _profileFromResult(result);
    await store.saveSession(session);
    if (profile != null) {
      await store.saveProfileCache(profile);
    } else {
      await store.clearProfileCache();
    }
    return FrontendAuthState(session: session, profile: profile);
  }

  Future<FrontendAuthState> signInWithOAuth({
    required FrontendSocialAuthProvider provider,
    required String redirectTo,
  }) async {
    return switch (provider) {
      FrontendSocialAuthProvider.google => _signInWithGoogle(),
      FrontendSocialAuthProvider.apple => _signInWithApple(),
      FrontendSocialAuthProvider.facebook => _signInWithBrowserProvider(
        path: 'meta',
        redirectTo: redirectTo,
      ),
      FrontendSocialAuthProvider.x => _signInWithBrowserProvider(
        path: 'x',
        redirectTo: redirectTo,
      ),
    };
  }

  Future<FrontendAuthState> _signInWithGoogle() async {
    await _initializeGoogleSignIn();
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: const ['openid', 'email', 'profile'],
    );
    final idToken = account.authentication.idToken ?? '';
    var accessToken = '';
    if (idToken.isEmpty) {
      final headers = await account.authorizationClient.authorizationHeaders(
        const ['openid', 'email', 'profile'],
        promptIfNecessary: true,
      );
      accessToken =
          headers?['Authorization']?.replaceFirst(RegExp(r'^Bearer\s+'), '') ??
          '';
    }
    if (idToken.isEmpty && accessToken.isEmpty) {
      throw const FrontendAuthException('Google kimlik tokenı alınamadı');
    }
    return _completeSocialToken(
      provider: 'google',
      idToken: idToken,
      accessToken: accessToken,
      fullName: account.displayName ?? '',
      email: account.email,
    );
  }

  Future<void> _initializeGoogleSignIn() {
    _googleInitializeFuture ??= GoogleSignIn.instance.initialize(
      clientId: kIsWeb
          ? _googleWebClientId
          : defaultTargetPlatform == TargetPlatform.iOS
          ? _googleIosClientId
          : null,
      serverClientId: _googleWebClientId,
    );
    return _googleInitializeFuture!;
  }

  Future<FrontendAuthState> _signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      webAuthenticationOptions:
          !kIsWeb &&
              defaultTargetPlatform != TargetPlatform.iOS &&
              defaultTargetPlatform != TargetPlatform.macOS
          ? WebAuthenticationOptions(
              clientId: _appleServiceId,
              redirectUri: _uri('/auth/apple/callback'),
            )
          : null,
    );
    final idToken = credential.identityToken ?? '';
    if (idToken.isEmpty) {
      throw const FrontendAuthException('Apple kimlik tokenı alınamadı');
    }
    final fullName = [credential.givenName, credential.familyName]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');
    return _completeSocialToken(
      provider: 'apple',
      idToken: idToken,
      fullName: fullName,
      email: credential.email ?? '',
    );
  }

  Future<FrontendAuthState> _signInWithBrowserProvider({
    required String path,
    required String redirectTo,
  }) async {
    final callbackUri = Uri.parse(redirectTo);
    if (callbackUri.scheme.isEmpty || callbackUri.host.isEmpty) {
      throw const FrontendAuthException('Mobil yönlendirme ayarı eksik');
    }
    final startUri = _uri('/auth/$path/start').replace(
      queryParameters: {
        'mode': 'mobile',
        'scheme': callbackUri.scheme,
        'host': callbackUri.host,
      },
    );
    final callback = await _launchAndWaitForCallback(startUri, callbackUri);
    final error = callback.queryParameters['error']?.trim() ?? '';
    if (error.isNotEmpty) throw FrontendAuthException(_friendlyError(error));
    final payload = callback.queryParameters['payload']?.trim() ?? '';
    if (payload.isEmpty) {
      throw const FrontendAuthException('Sosyal giriş oturumu alınamadı');
    }
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(payload))),
    );
    if (decoded is! Map) {
      throw const FrontendAuthException('Geçersiz sosyal giriş yanıtı');
    }
    return _authStateFromResult({
      'data': _asStringMap(decoded),
    }, fallbackMessage: 'Sosyal giriş tamamlanamadı');
  }

  Future<Uri> _launchAndWaitForCallback(Uri startUri, Uri callbackUri) async {
    final appLinks = AppLinks();
    final completer = Completer<Uri>();
    late final StreamSubscription<Uri> subscription;
    subscription = appLinks.uriLinkStream.listen(
      (uri) {
        if (uri.scheme == callbackUri.scheme &&
            uri.host == callbackUri.host &&
            !completer.isCompleted) {
          completer.complete(uri);
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    try {
      final launched = await launchUrl(
        startUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const FrontendAuthException('Sosyal giriş penceresi açılamadı');
      }
      return await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          throw const FrontendAuthException(
            'Sosyal giriş tamamlanamadı. Lütfen tekrar dene.',
          );
        },
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<FrontendAuthState> _completeSocialToken({
    required String provider,
    String idToken = '',
    String accessToken = '',
    String fullName = '',
    String email = '',
  }) async {
    final result = await _postJson('/api/app/auth', {
      'action': 'signInWithSocialToken',
      'provider': provider,
      'idToken': idToken,
      'accessToken': accessToken,
      'fullName': fullName,
      'email': email,
    });
    return _authStateFromResult(
      result,
      fallbackMessage: 'Sosyal giriş tamamlanamadı',
    );
  }

  Future<void> signOut() async {
    await store.clearAuth();
  }

  Future<FrontendProfile?> _cachedProfile() {
    return store.readProfileCache(_resolveAvatarUrl);
  }

  Future<FrontendAuthState> _authStateFromResult(
    Map<String, Object?> result, {
    required String fallbackMessage,
  }) async {
    _throwIfApiError(result, fallbackMessage: fallbackMessage);
    final session = _sessionFromResult(result);
    if (session == null || session.accessToken.isEmpty) {
      throw const FrontendAuthException('Giriş oturumu alınamadı');
    }
    final profile = _profileFromResult(result);
    await store.saveSession(session);
    if (profile != null) {
      await store.saveProfileCache(profile);
    } else {
      await store.clearProfileCache();
    }
    return FrontendAuthState(session: session, profile: profile);
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final client = httpClient ?? sharedFrontendClient;
    try {
      final response = await client
          .post(
            _uri(path),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      final decoded = response.bodyBytes.isEmpty
          ? <String, Object?>{}
          : jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw const FrontendAuthException('Geçersiz sunucu yanıtı');
      }
      final result = _asStringMap(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _throwIfApiError(result, fallbackMessage: 'Sunucu isteği başarısız');
      }
      return result;
    } finally {
      // Shared frontend client is not closed.
    }
  }

  Uri _uri(String path) {
    return frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);
  }

  String _resolveAvatarUrl(String value) {
    final input = value.trim();
    if (input.isEmpty) return '';
    final uri = Uri.tryParse(input);
    if (uri != null && (uri.hasScheme || input.startsWith('data:'))) {
      return input;
    }
    if (input.startsWith('/')) return _uri(input).toString();
    if (input.startsWith('profile/')) {
      return _uri('/api/storage/file/$input').toString();
    }
    return _uri('/api/storage/file/profile/$input').toString();
  }

  FrontendAuthSession? _sessionFromResult(Map<String, Object?> result) {
    final data = result['data'];
    if (data is! Map) return null;
    final session = data['session'];
    if (session is! Map) return null;
    return FrontendAuthSession.fromJson(_asStringMap(session));
  }

  FrontendProfile? _profileFromResult(Map<String, Object?> result) {
    final data = result['data'];
    if (data is! Map) return null;
    final profile = data['profile'];
    if (profile is! Map) return null;
    return FrontendProfile.fromJson(_asStringMap(profile), _resolveAvatarUrl);
  }

  void _throwIfApiError(
    Map<String, Object?> result, {
    required String fallbackMessage,
  }) {
    final error = result['error'];
    if (error == null) return;
    if (error is Map) {
      final message = error['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        throw FrontendAuthException(_friendlyError(message));
      }
    }
    throw FrontendAuthException(fallbackMessage);
  }

  String _friendlyError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login') ||
        normalized.contains('invalid credentials')) {
      return 'Kullanıcı adı veya şifre hatalı';
    }
    if (normalized.contains('blocked')) {
      return 'Bu hesap şu anda girişe kapalı';
    }
    return message;
  }
}

Map<String, Object?> _asStringMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, nestedValue) => MapEntry('$key', nestedValue));
  }
  return const {};
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
