import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

class AdminStorageSettingsData {
  const AdminStorageSettingsData({
    required this.activeStorageKey,
    required this.selectedProviderId,
    required this.providers,
    this.localBackupEnabled = false,
    this.localMediaCount = 0,
    this.localMediaByType = const <String, int>{},
  });

  factory AdminStorageSettingsData.empty() {
    return const AdminStorageSettingsData(
      activeStorageKey: 'storageSettings.option.localStorage',
      selectedProviderId: 'awsS3',
      providers: <String, Map<String, String>>{},
      localBackupEnabled: false,
      localMediaCount: 0,
      localMediaByType: <String, int>{},
    );
  }

  factory AdminStorageSettingsData.fromJson(
    Map<dynamic, dynamic> json, {
    Object? localMedia,
  }) {
    return AdminStorageSettingsData(
      activeStorageKey: _activeStorageKey(json['activeStorage']),
      selectedProviderId: _providerId(json['selectedProvider']),
      providers: _providerMap(json['providers']),
      localBackupEnabled: json['localBackupEnabled'] == true,
      localMediaCount: _localMediaCount(localMedia),
      localMediaByType: _localMediaByType(localMedia),
    );
  }

  final String activeStorageKey;
  final String selectedProviderId;
  final Map<String, Map<String, String>> providers;
  final bool localBackupEnabled;
  final int localMediaCount;
  final Map<String, int> localMediaByType;

  Map<String, Object?> toJson() {
    return {
      'activeStorage': _activeStorageId(activeStorageKey),
      'selectedProvider': selectedProviderId,
      'providers': providers,
      'localBackupEnabled': localBackupEnabled,
    };
  }
}

abstract class AdminStorageSettingsRepository {
  Future<AdminStorageSettingsData> fetchSettings();

  Future<AdminStorageSettingsData> saveSettings(
    AdminStorageSettingsData settings, {
    bool migrateLocalMedia = false,
  });
}

class SupabaseAdminStorageSettingsRepository
    implements AdminStorageSettingsRepository {
  const SupabaseAdminStorageSettingsRepository({
    this.httpClient,
    this.apiBaseUrl,
  });

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 18);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminStorageSettingsData> fetchSettings() async {
    final response = await _get(_uri('/api/admin/storage-settings'));
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AdminStorageSettingsException(
        _errorMessage(decoded, 'Depo ayarları alınamadı'),
      );
    }
    if (decoded is! Map) return AdminStorageSettingsData.empty();
    final data = decoded['data'];
    if (data is! Map) return AdminStorageSettingsData.empty();
    return AdminStorageSettingsData.fromJson(
      data,
      localMedia: decoded['localMedia'],
    );
  }

  @override
  Future<AdminStorageSettingsData> saveSettings(
    AdminStorageSettingsData settings, {
    bool migrateLocalMedia = false,
  }) async {
    final response = await _post(
      _uri('/api/admin/storage-settings'),
      jsonEncode({
        'values': settings.toJson(),
        if (migrateLocalMedia) 'migrateLocalMedia': true,
      }),
    );
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AdminStorageSettingsException(
        _errorMessage(decoded, 'Depo ayarları kaydedilemedi'),
      );
    }
    if (decoded is! Map) return settings;
    final data = decoded['data'];
    if (data is! Map) return settings;
    return AdminStorageSettingsData.fromJson(
      data,
      localMedia: decoded['localMedia'],
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
    if (baseUrl.isNotEmpty) return Uri.parse(baseUrl).resolve(path);
    if (kIsWeb) return Uri.base.resolve(path);
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse('http://10.0.2.2:4321').resolve(path),
      _ => Uri.parse('http://127.0.0.1:4321').resolve(path),
    };
  }
}

class AdminStorageSettingsException implements Exception {
  const AdminStorageSettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _activeStorageId(String optionKey) {
  return switch (optionKey) {
    'storageSettings.option.awsS3' => 'awsS3',
    'storageSettings.option.cloudflareR2' => 'cloudflareR2',
    'storageSettings.option.backblazeB2' => 'backblazeB2',
    'storageSettings.option.bunnyNet' => 'bunnyNet',
    'storageSettings.option.googleDrive' => 'googleDrive',
    _ => 'localStorage',
  };
}

String _activeStorageKey(Object? value) {
  return switch (value?.toString()) {
    'awsS3' || 'storageSettings.option.awsS3' => 'storageSettings.option.awsS3',
    'cloudflareR2' || 'storageSettings.option.cloudflareR2' =>
      'storageSettings.option.cloudflareR2',
    'backblazeB2' || 'storageSettings.option.backblazeB2' =>
      'storageSettings.option.backblazeB2',
    'bunnyNet' ||
    'storageSettings.option.bunnyNet' => 'storageSettings.option.bunnyNet',
    'googleDrive' || 'storageSettings.option.googleDrive' =>
      'storageSettings.option.googleDrive',
    _ => 'storageSettings.option.localStorage',
  };
}

String _providerId(Object? value) {
  return switch (value?.toString()) {
    'cloudflareR2' => 'cloudflareR2',
    'backblazeB2' => 'backblazeB2',
    'bunnyNet' => 'bunnyNet',
    'googleDrive' => 'googleDrive',
    _ => 'awsS3',
  };
}

Map<String, Map<String, String>> _providerMap(Object? value) {
  if (value is! Map) return <String, Map<String, String>>{};
  return {
    for (final entry in value.entries)
      _providerId(entry.key): entry.value is Map
          ? _stringMap(entry.value as Map)
          : <String, String>{},
  };
}

Map<String, String> _stringMap(Map<dynamic, dynamic> value) {
  return {
    for (final entry in value.entries)
      entry.key.toString(): entry.value?.toString() ?? '',
  };
}

int _localMediaCount(Object? value) {
  if (value is! Map) return 0;
  final total = value['total'];
  return total is num ? total.toInt() : 0;
}

Map<String, int> _localMediaByType(Object? value) {
  if (value is! Map) return <String, int>{};
  final byType = value['byType'];
  if (byType is! Map) return <String, int>{};
  return {
    for (final entry in byType.entries)
      entry.key.toString(): entry.value is num
          ? (entry.value as num).toInt()
          : int.tryParse(entry.value?.toString() ?? '') ?? 0,
  };
}

String _errorMessage(Object? decoded, String fallback) {
  if (decoded is Map) {
    final error = decoded['error'];
    if (error is Map && error['message'] != null) {
      return error['message'].toString();
    }
    if (decoded['message'] != null) return decoded['message'].toString();
  }
  return fallback;
}
