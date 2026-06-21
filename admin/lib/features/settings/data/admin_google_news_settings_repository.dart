import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';
import 'package:pateeznews_admin/shared/data/admin_request_retry.dart';

import '../../auth/data/admin_auth_models.dart';

class GoogleNewsSettingsData {
  const GoogleNewsSettingsData({
    required this.languageCode,
    required this.enabled,
    required this.publicationName,
    required this.rssContentMode,
    required this.feedLimit,
  });

  factory GoogleNewsSettingsData.empty(String languageCode) {
    return GoogleNewsSettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      enabled: true,
      publicationName: 'Pateez',
      rssContentMode: GoogleNewsRssContentMode.full,
      feedLimit: 50,
    );
  }

  factory GoogleNewsSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    final siteName = _string(json['site_name'], fallback: 'Pateez');
    final organizationName = _string(json['organization_legal_name']);
    final fallbackName = siteName.trim().isNotEmpty
        ? siteName.trim()
        : organizationName.trim().isNotEmpty
        ? organizationName.trim()
        : 'Pateez';
    return GoogleNewsSettingsData(
      languageCode: _cleanLanguageCode(
        _string(json['language_code'], fallback: languageCode),
      ),
      enabled: _bool(json['google_news_enabled'], fallback: true),
      publicationName: _string(
        json['google_news_publication_name'],
        fallback: fallbackName,
      ),
      rssContentMode: GoogleNewsRssContentMode.normalize(
        _string(json['google_news_rss_content_mode']),
      ),
      feedLimit: _int(
        json['google_news_feed_limit'],
        fallback: 50,
      ).clamp(1, 100),
    );
  }

  final String languageCode;
  final bool enabled;
  final String publicationName;
  final String rssContentMode;
  final int feedLimit;

  Map<String, Object?> toJson() {
    return {
      'language_code': _cleanLanguageCode(languageCode),
      'google_news_enabled': enabled,
      'google_news_publication_name': publicationName.trim().isEmpty
          ? 'Pateez'
          : publicationName.trim(),
      'google_news_rss_content_mode': GoogleNewsRssContentMode.normalize(
        rssContentMode,
      ),
      'google_news_feed_limit': feedLimit.clamp(1, 100),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class GoogleNewsRssContentMode {
  const GoogleNewsRssContentMode._();

  static const full = 'full';
  static const summary = 'summary';

  static String normalize(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == summary ? summary : full;
  }
}

abstract class AdminGoogleNewsSettingsRepository {
  Future<GoogleNewsSettingsData> fetchSettings(String languageCode);

  Future<GoogleNewsSettingsData> saveSettings({
    required AdminSession session,
    required GoogleNewsSettingsData settings,
  });
}

class SupabaseAdminGoogleNewsSettingsRepository
    implements AdminGoogleNewsSettingsRepository {
  const SupabaseAdminGoogleNewsSettingsRepository({
    this.httpClient,
    this.apiBaseUrl,
  });

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<GoogleNewsSettingsData> fetchSettings(String languageCode) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final result = await withAdminRetry(
      () => _postJson('/api/admin/query', {
        'table': 'site_settings',
        'method': 'select',
        'select': _settingsSelect,
        'filters': [
          {
            'type': 'comparison',
            'op': 'eq',
            'column': 'language_code',
            'value': normalizedCode,
          },
        ],
        'single': 'maybeSingle',
      }),
    );
    _throwIfApiError(result, fallbackMessage: 'Google News ayarları alınamadı');
    final data = result['data'];
    if (data is! Map) return GoogleNewsSettingsData.empty(normalizedCode);
    return GoogleNewsSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedCode,
    );
  }

  @override
  Future<GoogleNewsSettingsData> saveSettings({
    required AdminSession session,
    required GoogleNewsSettingsData settings,
  }) async {
    final normalizedSettings = GoogleNewsSettingsData(
      languageCode: _cleanLanguageCode(settings.languageCode),
      enabled: settings.enabled,
      publicationName: settings.publicationName,
      rssContentMode: settings.rssContentMode,
      feedLimit: settings.feedLimit,
    );
    final result = await withAdminRetry(
      () => _postJson('/api/admin/query', {
        'table': 'site_settings',
        'method': 'upsert',
        'values': normalizedSettings.toJson(),
        'options': {'onConflict': 'language_code'},
        'single': 'maybeSingle',
      }, session: session),
    );
    _throwIfApiError(
      result,
      fallbackMessage: 'Google News ayarları kaydedilemedi',
    );
    final data = result['data'];
    if (data is! Map) return normalizedSettings;
    return GoogleNewsSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedSettings.languageCode,
    );
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body, {
    AdminSession? session,
  }) async {
    final response =
        await (httpClient?.post(
                  _uri(path),
                  headers: await adminJsonHeaders(token: session?.accessToken),
                  body: jsonEncode(body),
                ) ??
                adminHttpClient.post(
                  _uri(path),
                  headers: await adminJsonHeaders(token: session?.accessToken),
                  body: jsonEncode(body),
                ))
            .timeout(_requestTimeout);

    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminGoogleNewsSettingsException('Geçersiz sunucu yanıtı');
    }
    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfApiError(result, fallbackMessage: 'Sunucu isteği başarısız');
    }
    return result;
  }

  Uri _uri(String path) {
    final baseUrl = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (baseUrl.isNotEmpty) return Uri.parse(baseUrl).resolve(path);
    if (!kIsWeb) return _defaultLocalApiBaseUrl().resolve(path);
    return Uri.base.resolve(path);
  }

  Uri _defaultLocalApiBaseUrl() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse('http://10.0.2.2:4321'),
      _ => Uri.parse('http://127.0.0.1:4321'),
    };
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
        throw AdminGoogleNewsSettingsException(message);
      }
    }
    throw AdminGoogleNewsSettingsException(fallbackMessage);
  }
}

class AdminGoogleNewsSettingsException implements Exception {
  const AdminGoogleNewsSettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _settingsSelect =
    'language_code,site_name,organization_legal_name,'
    'google_news_enabled,google_news_publication_name,'
    'google_news_rss_content_mode,google_news_feed_limit';

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

String _cleanLanguageCode(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.isEmpty ? 'tr' : normalized;
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  if (text == null) return fallback;
  final trimmed = text.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

bool _bool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return fallback;
}

int _int(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
