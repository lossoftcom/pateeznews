import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';

class WeatherSettingsData {
  const WeatherSettingsData({
    required this.languageCode,
    required this.enabled,
    required this.locationName,
    required this.locationCountry,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.updateIntervalMinutes,
  });

  factory WeatherSettingsData.empty(String languageCode) {
    return WeatherSettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      enabled: true,
      locationName: 'Niğde',
      locationCountry: 'Türkiye',
      latitude: 37.96583,
      longitude: 34.67935,
      timezone: 'Europe/Istanbul',
      updateIntervalMinutes: 30,
    );
  }

  factory WeatherSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    final fallback = WeatherSettingsData.empty(languageCode);
    return WeatherSettingsData(
      languageCode: _string(
        json['language_code'],
        fallback: fallback.languageCode,
      ),
      enabled: json['weather_enabled'] != false,
      locationName: _string(
        json['weather_location_name'],
        fallback: fallback.locationName,
      ),
      locationCountry: _string(
        json['weather_location_country'],
        fallback: fallback.locationCountry,
      ),
      latitude: _number(json['weather_latitude'], fallback.latitude),
      longitude: _number(json['weather_longitude'], fallback.longitude),
      timezone: _string(json['weather_timezone'], fallback: fallback.timezone),
      updateIntervalMinutes: _int(
        json['weather_update_interval_minutes'],
        fallback.updateIntervalMinutes,
      ),
    );
  }

  final String languageCode;
  final bool enabled;
  final String locationName;
  final String locationCountry;
  final double latitude;
  final double longitude;
  final String timezone;
  final int updateIntervalMinutes;

  Map<String, Object?> toJson() {
    return {
      'language_code': _cleanLanguageCode(languageCode),
      'weather_enabled': enabled,
      'weather_location_name': locationName.trim().isEmpty
          ? 'Niğde'
          : locationName.trim(),
      'weather_location_country': locationCountry.trim(),
      'weather_latitude': latitude,
      'weather_longitude': longitude,
      'weather_timezone': timezone.trim().isEmpty
          ? 'Europe/Istanbul'
          : timezone.trim(),
      'weather_update_interval_minutes': updateIntervalMinutes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class WeatherLocationSearchResult {
  const WeatherLocationSearchResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.timezone = 'Europe/Istanbul',
    this.country = '',
    this.admin1 = '',
  });

  factory WeatherLocationSearchResult.fromJson(Map<String, Object?> json) {
    return WeatherLocationSearchResult(
      name: _string(json['name']),
      latitude: _number(json['latitude'], 0),
      longitude: _number(json['longitude'], 0),
      timezone: _string(json['timezone'], fallback: 'Europe/Istanbul'),
      country: _string(json['country']),
      admin1: _string(json['admin1']),
    );
  }

  final String name;
  final double latitude;
  final double longitude;
  final String timezone;
  final String country;
  final String admin1;
}

class ModuleCacheInfo {
  const ModuleCacheInfo({
    required this.source,
    required this.hit,
    required this.stale,
  });

  factory ModuleCacheInfo.fromJson(Object? value) {
    if (value is! Map) {
      return const ModuleCacheInfo(
        source: 'database',
        hit: false,
        stale: false,
      );
    }
    return ModuleCacheInfo(
      source: _string(value['source'], fallback: 'database'),
      hit: value['hit'] == true,
      stale: value['stale'] == true,
    );
  }

  final String source;
  final bool hit;
  final bool stale;
}

class DutyPharmacyPreviewData {
  const DutyPharmacyPreviewData({
    required this.city,
    required this.source,
    required this.sourceUrl,
    required this.serviceDateLabel,
    required this.updateIntervalMinutes,
    required this.districts,
    required this.pharmacies,
    required this.total,
    required this.cache,
  });

  factory DutyPharmacyPreviewData.fromJson(Map<String, Object?> json) {
    return DutyPharmacyPreviewData(
      city: _string(json['city'], fallback: 'Niğde'),
      source: _string(json['source'], fallback: 'Niğde Eczacı Odası'),
      sourceUrl: _string(
        json['sourceUrl'],
        fallback: 'https://www.neo.org.tr/nobetci-eczaneler',
      ),
      serviceDateLabel: _string(json['serviceDateLabel']),
      updateIntervalMinutes: _int(json['updateIntervalMinutes'], 15),
      districts: _stringList(json['districts']),
      pharmacies: [
        for (final row
            in (json['pharmacies'] is List
                ? json['pharmacies'] as List
                : const []))
          if (row is Map) DutyPharmacyItem.fromJson(_asStringKeyMap(row)),
      ],
      total: _int(
        json['meta'] is Map ? (json['meta'] as Map)['total'] : null,
        0,
      ),
      cache: ModuleCacheInfo.fromJson(json['cache']),
    );
  }

  final String city;
  final String source;
  final String sourceUrl;
  final String serviceDateLabel;
  final int updateIntervalMinutes;
  final List<String> districts;
  final List<DutyPharmacyItem> pharmacies;
  final int total;
  final ModuleCacheInfo cache;
}

class DutyPharmacyItem {
  const DutyPharmacyItem({
    required this.id,
    required this.name,
    required this.district,
    required this.address,
    required this.phone,
    required this.directionUrl,
    this.note = '',
  });

  factory DutyPharmacyItem.fromJson(Map<String, Object?> json) {
    return DutyPharmacyItem(
      id: _string(json['id']),
      name: _string(json['name']),
      district: _string(json['district']),
      address: _string(json['address']),
      phone: _string(json['phone']),
      directionUrl: _string(json['directionUrl']),
      note: _string(json['note']),
    );
  }

  final String id;
  final String name;
  final String district;
  final String address;
  final String phone;
  final String directionUrl;
  final String note;
}

class DeathNoticePreviewData {
  const DeathNoticePreviewData({
    required this.city,
    required this.source,
    required this.sourceUrl,
    required this.serviceDateLabel,
    required this.updateIntervalMinutes,
    required this.notices,
    required this.total,
    required this.cache,
  });

  factory DeathNoticePreviewData.fromJson(Map<String, Object?> json) {
    return DeathNoticePreviewData(
      city: _string(json['city'], fallback: 'Niğde'),
      source: _string(json['source'], fallback: 'Niğde Belediyesi'),
      sourceUrl: _string(
        json['sourceUrl'],
        fallback: 'https://nigde.bel.tr/vefat-edenler',
      ),
      serviceDateLabel: _string(json['serviceDateLabel']),
      updateIntervalMinutes: _int(json['updateIntervalMinutes'], 30),
      notices: [
        for (final row
            in (json['notices'] is List ? json['notices'] as List : const []))
          if (row is Map) DeathNoticeItem.fromJson(_asStringKeyMap(row)),
      ],
      total: _int(
        json['meta'] is Map ? (json['meta'] as Map)['total'] : null,
        0,
      ),
      cache: ModuleCacheInfo.fromJson(json['cache']),
    );
  }

  final String city;
  final String source;
  final String sourceUrl;
  final String serviceDateLabel;
  final int updateIntervalMinutes;
  final List<DeathNoticeItem> notices;
  final int total;
  final ModuleCacheInfo cache;
}

class DeathNoticeItem {
  const DeathNoticeItem({
    required this.id,
    required this.name,
    required this.deathDateLabel,
    required this.prayerTime,
    required this.burialPlace,
    required this.description,
  });

  factory DeathNoticeItem.fromJson(Map<String, Object?> json) {
    return DeathNoticeItem(
      id: _string(json['id']),
      name: _string(json['name']),
      deathDateLabel: _string(json['deathDateLabel']),
      prayerTime: _string(json['prayerTime']),
      burialPlace: _string(json['burialPlace']),
      description: _string(json['description']),
    );
  }

  final String id;
  final String name;
  final String deathDateLabel;
  final String prayerTime;
  final String burialPlace;
  final String description;
}

abstract class AdminModuleSettingsRepository {
  Future<WeatherSettingsData> fetchWeatherSettings(String languageCode);

  Future<WeatherSettingsData> saveWeatherSettings({
    required AdminSession session,
    required WeatherSettingsData settings,
  });

  Future<List<WeatherLocationSearchResult>> searchWeatherLocations({
    required String query,
    required String languageCode,
  });

  Future<DutyPharmacyPreviewData> fetchDutyPharmacyPreview({
    bool forceRefresh = false,
  });

  Future<DeathNoticePreviewData> fetchDeathNoticePreview({
    bool forceRefresh = false,
  });
}

class SupabaseAdminModuleSettingsRepository
    implements AdminModuleSettingsRepository {
  const SupabaseAdminModuleSettingsRepository({
    this.httpClient,
    this.apiBaseUrl,
  });

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 18);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<WeatherSettingsData> fetchWeatherSettings(String languageCode) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'select',
      'select':
          'language_code,weather_enabled,weather_location_name,weather_location_country,weather_latitude,weather_longitude,weather_timezone,weather_update_interval_minutes',
      'filters': [
        {
          'type': 'comparison',
          'op': 'eq',
          'column': 'language_code',
          'value': normalizedCode,
        },
      ],
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'Hava durumu ayarları alınamadı');
    final data = result['data'];
    if (data is! Map) return WeatherSettingsData.empty(normalizedCode);
    return WeatherSettingsData.fromJson(_asStringKeyMap(data), normalizedCode);
  }

  @override
  Future<WeatherSettingsData> saveWeatherSettings({
    required AdminSession session,
    required WeatherSettingsData settings,
  }) async {
    final normalizedSettings = WeatherSettingsData(
      languageCode: _cleanLanguageCode(settings.languageCode),
      enabled: settings.enabled,
      locationName: settings.locationName,
      locationCountry: settings.locationCountry,
      latitude: settings.latitude,
      longitude: settings.longitude,
      timezone: settings.timezone,
      updateIntervalMinutes: settings.updateIntervalMinutes,
    );
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'upsert',
      'values': normalizedSettings.toJson(),
      'options': {'onConflict': 'language_code'},
      'single': 'maybeSingle',
    });
    _throwIfApiError(
      result,
      fallbackMessage: 'Hava durumu ayarları kaydedilemedi',
    );
    await _deleteCacheKey('sidebar:${normalizedSettings.languageCode}');
    final data = result['data'];
    if (data is! Map) return normalizedSettings;
    return WeatherSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedSettings.languageCode,
    );
  }

  @override
  Future<List<WeatherLocationSearchResult>> searchWeatherLocations({
    required String query,
    required String languageCode,
  }) async {
    final term = query.trim();
    if (term.length < 2) return const [];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': term,
      'count': '8',
      'format': 'json',
      'language': _cleanLanguageCode(languageCode),
    });
    final decoded = await _getExternalJson(uri);
    final results = decoded['results'];
    if (results is! List) return const [];
    return [
      for (final item in results)
        if (item is Map)
          WeatherLocationSearchResult.fromJson(_asStringKeyMap(item)),
    ];
  }

  @override
  Future<DutyPharmacyPreviewData> fetchDutyPharmacyPreview({
    bool forceRefresh = false,
  }) async {
    final uri = _uri(
      '/api/app/duty-pharmacies?city=nigde${forceRefresh ? '&refresh=1' : ''}',
    );
    final decoded = await _getJson(uri);
    return DutyPharmacyPreviewData.fromJson(decoded);
  }

  @override
  Future<DeathNoticePreviewData> fetchDeathNoticePreview({
    bool forceRefresh = false,
  }) async {
    final uri = _uri(
      '/api/app/death-notices?city=nigde${forceRefresh ? '&refresh=1' : ''}',
    );
    final decoded = await _getJson(uri);
    return DeathNoticePreviewData.fromJson(decoded);
  }

  Future<void> _deleteCacheKey(String key) async {
    try {
      final result = await _postJson('/api/admin/query', {
        'table': 'app_cache',
        'method': 'delete',
        'filters': [
          {'type': 'comparison', 'op': 'eq', 'column': 'key', 'value': key},
        ],
      });
      _throwIfApiError(result, fallbackMessage: 'Cache temizlenemedi');
    } catch (_) {
      // The next frontend request can rebuild the cache if cleanup fails.
    }
  }

  Future<Map<String, Object?>> _getExternalJson(Uri uri) async {
    final response =
        await (httpClient?.get(
                  uri,
                  headers: const {'Accept': 'application/json'},
                ) ??
                http.get(uri, headers: const {'Accept': 'application/json'}))
            .timeout(_requestTimeout);
    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminModuleSettingsException('Geçersiz servis yanıtı');
    }
    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _string(
        result['reason'],
        fallback: 'Servis isteği başarısız',
      );
      throw AdminModuleSettingsException(message);
    }
    return result;
  }

  Future<Map<String, Object?>> _getJson(Uri uri) async {
    final response =
        await (httpClient?.get(
                  uri,
                  headers: const {'Accept': 'application/json'},
                ) ??
                http.get(uri, headers: const {'Accept': 'application/json'}))
            .timeout(_requestTimeout);
    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminModuleSettingsException('Geçersiz sunucu yanıtı');
    }
    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = result['error'];
      throw AdminModuleSettingsException(
        error?.toString() ?? 'Sunucu isteği başarısız',
      );
    }
    return result;
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final response =
        await (httpClient?.post(
                  _uri(path),
                  headers: await adminJsonHeaders(),
                  body: jsonEncode(body),
                ) ??
                adminHttpClient.post(
                  _uri(path),
                  headers: await adminJsonHeaders(),
                  body: jsonEncode(body),
                ))
            .timeout(_requestTimeout);
    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminModuleSettingsException('Geçersiz sunucu yanıtı');
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
      _ => Uri.parse('http://localhost:4321'),
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
        throw AdminModuleSettingsException(message);
      }
    }
    throw AdminModuleSettingsException(fallbackMessage);
  }
}

class AdminModuleSettingsException implements Exception {
  const AdminModuleSettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

double _number(Object? value, double fallback) {
  final number = NumberFormatHelper.parse(value);
  return number ?? fallback;
}

int _int(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item != null && item.toString().trim().isNotEmpty)
        item.toString().trim(),
  ];
}

String _cleanLanguageCode(String value) {
  final code = value.trim().toLowerCase().replaceAll('_', '-');
  return code.isEmpty ? 'tr' : code;
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}

class NumberFormatHelper {
  const NumberFormatHelper._();

  static double? parse(Object? value) {
    if (value is num) return value.toDouble();
    final text = value?.toString().replaceAll(',', '.').trim() ?? '';
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }
}
