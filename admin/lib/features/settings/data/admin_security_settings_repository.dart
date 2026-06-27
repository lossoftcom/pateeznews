import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';

class AdminSecuritySettingsData {
  const AdminSecuritySettingsData({
    required this.languageCode,
    required this.maxLoginAttempts,
    required this.lockoutMinutes,
    required this.passwordMinLength,
    required this.passwordComplexityRequired,
    required this.spamPostPolicy,
    required this.spamInteractionPolicy,
    required this.captchaEnabled,
    required this.captchaProvider,
    required this.captchaSiteKey,
    required this.captchaSecretConfigured,
    this.captchaSecretKey = '',
  });

  static const secretMask = '******';

  factory AdminSecuritySettingsData.defaults(String languageCode) {
    return AdminSecuritySettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      maxLoginAttempts: 5,
      lockoutMinutes: 5,
      passwordMinLength: 6,
      passwordComplexityRequired: false,
      spamPostPolicy: 'nofollow',
      spamInteractionPolicy: 'remove_links',
      captchaEnabled: false,
      captchaProvider: 'cloudflare_turnstile',
      captchaSiteKey: '',
      captchaSecretConfigured: false,
    );
  }

  factory AdminSecuritySettingsData.fromJson(
    Map<dynamic, dynamic> json,
    String languageCode,
  ) {
    final fallback = AdminSecuritySettingsData.defaults(languageCode);
    return AdminSecuritySettingsData(
      languageCode: _string(
        json['languageCode'],
        fallback: fallback.languageCode,
      ),
      maxLoginAttempts: _intRange(
        json['maxLoginAttempts'],
        fallback: fallback.maxLoginAttempts,
        min: 1,
        max: 20,
      ),
      lockoutMinutes: _intRange(
        json['lockoutMinutes'],
        fallback: fallback.lockoutMinutes,
        min: 1,
        max: 1440,
      ),
      passwordMinLength: _intRange(
        json['passwordMinLength'],
        fallback: fallback.passwordMinLength,
        min: 4,
        max: 128,
      ),
      passwordComplexityRequired: json['passwordComplexityRequired'] == true,
      spamPostPolicy: _postPolicy(
        json['spamPostPolicy'],
        fallback: fallback.spamPostPolicy,
      ),
      spamInteractionPolicy: _interactionPolicy(
        json['spamInteractionPolicy'],
        fallback: fallback.spamInteractionPolicy,
      ),
      captchaEnabled: json['captchaEnabled'] == true,
      captchaProvider: _captchaProvider(
        json['captchaProvider'],
        fallback: fallback.captchaProvider,
      ),
      captchaSiteKey: _string(json['captchaSiteKey']),
      captchaSecretConfigured: json['captchaSecretConfigured'] == true,
    );
  }

  final String languageCode;
  final int maxLoginAttempts;
  final int lockoutMinutes;
  final int passwordMinLength;
  final bool passwordComplexityRequired;
  final String spamPostPolicy;
  final String spamInteractionPolicy;
  final bool captchaEnabled;
  final String captchaProvider;
  final String captchaSiteKey;
  final bool captchaSecretConfigured;
  final String captchaSecretKey;

  Map<String, Object?> toJson({bool includeSecretKey = false}) {
    return {
      'maxLoginAttempts': _clamp(maxLoginAttempts, 1, 20),
      'lockoutMinutes': _clamp(lockoutMinutes, 1, 1440),
      'passwordMinLength': _clamp(passwordMinLength, 4, 128),
      'passwordComplexityRequired': passwordComplexityRequired,
      'spamPostPolicy': _postPolicy(spamPostPolicy),
      'spamInteractionPolicy': _interactionPolicy(spamInteractionPolicy),
      'captchaEnabled': captchaEnabled,
      'captchaProvider': _captchaProvider(captchaProvider),
      'captchaSiteKey': captchaSiteKey.trim(),
      if (includeSecretKey) 'captchaSecretKey': captchaSecretKey.trim(),
    };
  }

  AdminSecuritySettingsData copyWith({
    String? languageCode,
    int? maxLoginAttempts,
    int? lockoutMinutes,
    int? passwordMinLength,
    bool? passwordComplexityRequired,
    String? spamPostPolicy,
    String? spamInteractionPolicy,
    bool? captchaEnabled,
    String? captchaProvider,
    String? captchaSiteKey,
    bool? captchaSecretConfigured,
    String? captchaSecretKey,
  }) {
    return AdminSecuritySettingsData(
      languageCode: languageCode ?? this.languageCode,
      maxLoginAttempts: maxLoginAttempts ?? this.maxLoginAttempts,
      lockoutMinutes: lockoutMinutes ?? this.lockoutMinutes,
      passwordMinLength: passwordMinLength ?? this.passwordMinLength,
      passwordComplexityRequired:
          passwordComplexityRequired ?? this.passwordComplexityRequired,
      spamPostPolicy: spamPostPolicy ?? this.spamPostPolicy,
      spamInteractionPolicy:
          spamInteractionPolicy ?? this.spamInteractionPolicy,
      captchaEnabled: captchaEnabled ?? this.captchaEnabled,
      captchaProvider: captchaProvider ?? this.captchaProvider,
      captchaSiteKey: captchaSiteKey ?? this.captchaSiteKey,
      captchaSecretConfigured:
          captchaSecretConfigured ?? this.captchaSecretConfigured,
      captchaSecretKey: captchaSecretKey ?? this.captchaSecretKey,
    );
  }
}

abstract class AdminSecuritySettingsRepository {
  Future<AdminSecuritySettingsData> fetchSettings(String languageCode);

  Future<AdminSecuritySettingsData> saveSettings({
    required AdminSession session,
    required AdminSecuritySettingsData settings,
    required bool includeSecretKey,
  });
}

class SupabaseAdminSecuritySettingsRepository
    implements AdminSecuritySettingsRepository {
  const SupabaseAdminSecuritySettingsRepository({
    this.httpClient,
    this.apiBaseUrl,
  });

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 12);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminSecuritySettingsData> fetchSettings(String languageCode) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final uri = _uri(
      '/api/admin/security-settings?language_code=$normalizedCode',
    );
    final response = await _get(uri);
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AdminSecuritySettingsException(
        _errorMessage(decoded, 'Güvenlik ayarları alınamadı'),
      );
    }
    if (decoded is! Map || decoded['data'] is! Map) {
      return AdminSecuritySettingsData.defaults(normalizedCode);
    }
    return AdminSecuritySettingsData.fromJson(
      decoded['data'] as Map,
      normalizedCode,
    );
  }

  @override
  Future<AdminSecuritySettingsData> saveSettings({
    required AdminSession session,
    required AdminSecuritySettingsData settings,
    required bool includeSecretKey,
  }) async {
    final normalizedSettings = settings.copyWith(
      languageCode: _cleanLanguageCode(settings.languageCode),
    );
    final response = await _post(
      _uri('/api/admin/security-settings'),
      jsonEncode({
        'language_code': normalizedSettings.languageCode,
        'values': normalizedSettings.toJson(includeSecretKey: includeSecretKey),
      }),
    );
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AdminSecuritySettingsException(
        _errorMessage(decoded, 'Güvenlik ayarları kaydedilemedi'),
      );
    }
    if (decoded is! Map || decoded['data'] is! Map) return normalizedSettings;
    return AdminSecuritySettingsData.fromJson(
      decoded['data'] as Map,
      normalizedSettings.languageCode,
    );
  }

  Future<http.Response> _get(Uri uri) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      return await client
          .get(uri, headers: await adminAuthHeaders())
          .timeout(_requestTimeout);
    } finally {
      if (closeClient) client.close();
    }
  }

  Future<http.Response> _post(Uri uri, String body) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      return await client
          .post(uri, headers: await adminJsonHeaders(), body: body)
          .timeout(_requestTimeout);
    } finally {
      if (closeClient) client.close();
    }
  }

  Uri _uri(String path) {
    final baseUrl = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (baseUrl.isNotEmpty && !isLocalAdminApiBaseUrl(baseUrl)) {
      return Uri.parse(baseUrl).resolve(path);
    }
    return Uri.parse('https://pateez.com').resolve(path);
  }
}

class AdminSecuritySettingsException implements Exception {
  const AdminSecuritySettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _cleanLanguageCode(String value) {
  final code = value.trim().toLowerCase().replaceAll('_', '-');
  return code.isEmpty ? 'tr' : code;
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _intRange(
  Object? value, {
  required int fallback,
  required int min,
  required int max,
}) {
  final parsed = value is num ? value.toInt() : int.tryParse('${value ?? ''}');
  if (parsed == null) return fallback;
  return _clamp(parsed, min, max);
}

int _clamp(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

String _postPolicy(Object? value, {String fallback = 'nofollow'}) {
  final text = value?.toString().trim() ?? '';
  return switch (text) {
    'sanitize_html' || 'allow_trusted' => text,
    'nofollow' => 'nofollow',
    _ => fallback,
  };
}

String _interactionPolicy(Object? value, {String fallback = 'remove_links'}) {
  final text = value?.toString().trim() ?? '';
  return switch (text) {
    'nofollow' || 'sanitize_html' => text,
    'remove_links' => 'remove_links',
    _ => fallback,
  };
}

String _captchaProvider(
  Object? value, {
  String fallback = 'cloudflare_turnstile',
}) {
  final text = value?.toString().trim() ?? '';
  return switch (text) {
    'google_recaptcha' => 'google_recaptcha',
    'cloudflare_turnstile' => 'cloudflare_turnstile',
    _ => fallback,
  };
}

String _errorMessage(Object? decoded, String fallback) {
  if (decoded is Map) {
    final error = decoded['error'];
    if (error is Map) {
      final message = error['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
  }
  return fallback;
}
