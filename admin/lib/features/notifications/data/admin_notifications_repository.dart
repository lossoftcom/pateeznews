import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';
import '../presentation/notification_models.dart';

class AdminNotificationsException implements Exception {
  const AdminNotificationsException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AdminNotificationsRepository {
  Future<AdminNotificationPage<AdminNotificationCampaign>> fetchCampaigns(
    AdminSession session, {
    int limit = 25,
    int offset = 0,
    String search = '',
  });

  Future<AdminNotificationCampaign> saveCampaign(
    AdminSession session, {
    int? id,
    required AdminNotificationCampaign campaign,
  });

  Future<AdminNotificationCampaign> updateCampaignAction(
    AdminSession session,
    AdminNotificationCampaign campaign,
    String action,
  );

  Future<void> deleteCampaigns(AdminSession session, Iterable<int> ids);

  Future<AdminNotificationPage<AdminNotificationTemplate>> fetchTemplates(
    AdminSession session, {
    int limit = 25,
    int offset = 0,
    String search = '',
  });

  Future<AdminNotificationTemplate> saveTemplate(
    AdminSession session, {
    int? id,
    required AdminNotificationTemplate template,
  });

  Future<void> deleteTemplates(AdminSession session, Iterable<int> ids);

  Future<AdminNotificationPage<AdminNotificationDevice>> fetchDevices(
    AdminSession session, {
    int limit = 25,
    int offset = 0,
    String search = '',
  });

  Future<AdminNotificationDevice> updateDeviceAction(
    AdminSession session,
    AdminNotificationDevice device,
    String action,
  );

  Future<void> deleteDevices(AdminSession session, Iterable<int> ids);

  Future<AdminNotificationSettings?> fetchSettings(AdminSession session);

  Future<AdminNotificationSettings> saveSettings(
    AdminSession session, {
    required AdminNotificationSettings settings,
    String privateKey = '',
  });

  Future<AdminNotificationSettings> checkSettings(
    AdminSession session,
    AdminNotificationSettings settings,
  );
}

class SupabaseAdminNotificationsRepository
    implements AdminNotificationsRepository {
  const SupabaseAdminNotificationsRepository({
    this.httpClient,
    this.apiBaseUrl,
  });

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 30);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminNotificationPage<AdminNotificationCampaign>> fetchCampaigns(
    AdminSession session, {
    int limit = 25,
    int offset = 0,
    String search = '',
  }) async {
    final result =
        await _getJson('/api/admin/notifications/campaigns', session, {
          'limit': '$limit',
          'offset': '$offset',
          if (search.trim().isNotEmpty) 'search': search.trim(),
        });
    return _page(result, (json) => AdminNotificationCampaign.fromJson(json));
  }

  @override
  Future<AdminNotificationCampaign> saveCampaign(
    AdminSession session, {
    int? id,
    required AdminNotificationCampaign campaign,
  }) async {
    final payload = campaign.toPayload();
    if (id != null) payload['id'] = id;
    final result = await _requestJson(
      id == null ? 'POST' : 'PATCH',
      '/api/admin/notifications/campaigns',
      session,
      payload,
    );
    final row = result['campaign'];
    if (row is Map) return AdminNotificationCampaign.fromJson(row);
    throw const AdminNotificationsException(
      'Bildirim kampanyası kaydedilemedi',
    );
  }

  @override
  Future<AdminNotificationCampaign> updateCampaignAction(
    AdminSession session,
    AdminNotificationCampaign campaign,
    String action,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/notifications/campaigns',
      session,
      {'id': campaign.id, 'action': action},
    );
    final row = result['campaign'];
    if (row is Map) return AdminNotificationCampaign.fromJson(row);
    throw const AdminNotificationsException(
      'Bildirim kampanyası güncellenemedi',
    );
  }

  @override
  Future<void> deleteCampaigns(AdminSession session, Iterable<int> ids) async {
    for (final id in ids) {
      await _requestJson(
        'DELETE',
        '/api/admin/notifications/campaigns',
        session,
        {'id': id},
      );
    }
  }

  @override
  Future<AdminNotificationPage<AdminNotificationTemplate>> fetchTemplates(
    AdminSession session, {
    int limit = 25,
    int offset = 0,
    String search = '',
  }) async {
    final result =
        await _getJson('/api/admin/notifications/templates', session, {
          'limit': '$limit',
          'offset': '$offset',
          if (search.trim().isNotEmpty) 'search': search.trim(),
        });
    return _page(result, (json) => AdminNotificationTemplate.fromJson(json));
  }

  @override
  Future<AdminNotificationTemplate> saveTemplate(
    AdminSession session, {
    int? id,
    required AdminNotificationTemplate template,
  }) async {
    final payload = template.toPayload();
    if (id != null) payload['id'] = id;
    final result = await _requestJson(
      id == null ? 'POST' : 'PATCH',
      '/api/admin/notifications/templates',
      session,
      payload,
    );
    final row = result['template'];
    if (row is Map) return AdminNotificationTemplate.fromJson(row);
    throw const AdminNotificationsException('Bildirim şablonu kaydedilemedi');
  }

  @override
  Future<void> deleteTemplates(AdminSession session, Iterable<int> ids) async {
    for (final id in ids) {
      await _requestJson(
        'DELETE',
        '/api/admin/notifications/templates',
        session,
        {'id': id},
      );
    }
  }

  @override
  Future<AdminNotificationPage<AdminNotificationDevice>> fetchDevices(
    AdminSession session, {
    int limit = 25,
    int offset = 0,
    String search = '',
  }) async {
    final result = await _getJson('/api/admin/notifications/devices', session, {
      'limit': '$limit',
      'offset': '$offset',
      if (search.trim().isNotEmpty) 'search': search.trim(),
    });
    return _page(result, (json) => AdminNotificationDevice.fromJson(json));
  }

  @override
  Future<AdminNotificationDevice> updateDeviceAction(
    AdminSession session,
    AdminNotificationDevice device,
    String action,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/notifications/devices',
      session,
      {'id': device.id, 'action': action},
    );
    final row = result['device'];
    if (row is Map) return AdminNotificationDevice.fromJson(row);
    throw const AdminNotificationsException(
      'Cihaz token durumu güncellenemedi',
    );
  }

  @override
  Future<void> deleteDevices(AdminSession session, Iterable<int> ids) async {
    for (final id in ids) {
      await _requestJson(
        'DELETE',
        '/api/admin/notifications/devices',
        session,
        {'id': id},
      );
    }
  }

  @override
  Future<AdminNotificationSettings?> fetchSettings(AdminSession session) async {
    final result = await _getJson('/api/admin/notifications/settings', session);
    final row = result['settings'];
    return row is Map ? AdminNotificationSettings.fromJson(row) : null;
  }

  @override
  Future<AdminNotificationSettings> saveSettings(
    AdminSession session, {
    required AdminNotificationSettings settings,
    String privateKey = '',
  }) async {
    final result = await _requestJson(
      settings.id == 0 ? 'POST' : 'PATCH',
      '/api/admin/notifications/settings',
      session,
      {
        if (settings.id != 0) 'id': settings.id,
        ...settings.toPayload(privateKey: privateKey),
      },
    );
    final row = result['settings'];
    if (row is Map) return AdminNotificationSettings.fromJson(row);
    throw const AdminNotificationsException('Bildirim ayarları kaydedilemedi');
  }

  @override
  Future<AdminNotificationSettings> checkSettings(
    AdminSession session,
    AdminNotificationSettings settings,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/notifications/settings',
      session,
      {'id': settings.id, 'action': 'connection-check'},
    );
    final row = result['settings'];
    if (row is Map) return AdminNotificationSettings.fromJson(row);
    throw const AdminNotificationsException(
      'Firebase bağlantısı kontrol edilemedi',
    );
  }

  AdminNotificationPage<T> _page<T>(
    Map<String, dynamic> result,
    T Function(Map<dynamic, dynamic>) builder,
  ) {
    final rows = result['items'];
    return AdminNotificationPage<T>(
      items: rows is List
          ? rows.whereType<Map>().map(builder).toList(growable: false)
          : const [],
      total: _asInt(result['total']),
      limit: _asInt(result['limit'], 25),
      offset: _asInt(result['offset']),
      stats: AdminNotificationStats.fromJson(result['stats']),
    );
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    AdminSession session, [
    Map<String, String>? query,
  ]) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      final response = await client
          .get(
            _uri(path, query),
            headers: await adminAuthHeaders(token: session.accessToken),
          )
          .timeout(_requestTimeout);
      return _decodeResponse(response);
    } on TimeoutException {
      throw const AdminNotificationsException(
        'Sunucu yanıtı zaman aşımına uğradı',
      );
    } finally {
      if (closeClient) client.close();
    }
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path,
    AdminSession session,
    Map<String, Object?> body,
  ) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      final request = http.Request(method, _uri(path))
        ..headers.addAll(await adminJsonHeaders(token: session.accessToken))
        ..body = jsonEncode(body);
      final streamed = await client.send(request).timeout(_requestTimeout);
      return _decodeResponse(await http.Response.fromStream(streamed));
    } on TimeoutException {
      throw const AdminNotificationsException(
        'Sunucu yanıtı zaman aşımına uğradı',
      );
    } finally {
      if (closeClient) client.close();
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminNotificationsException('Geçersiz sunucu yanıtı');
    }
    final result = decoded.map((key, value) => MapEntry(key.toString(), value));
    final error = result['error'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        error != null) {
      if (error is Map) {
        final message = error['message']?.toString();
        if (message != null && message.isNotEmpty) {
          throw AdminNotificationsException(message);
        }
      }
      throw const AdminNotificationsException('Bildirim isteği başarısız oldu');
    }
    return result;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final configured = (apiBaseUrl ?? _apiBaseUrl).trim();
    final base = configured.isNotEmpty
        ? Uri.parse(configured)
        : !kIsWeb
        ? Uri.parse(
            defaultTargetPlatform == TargetPlatform.android
                ? 'https://pateez.com'
                : 'https://pateez.com',
          )
        : Uri.base;
    final uri = base.resolve(path);
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  int _asInt(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
