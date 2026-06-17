import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/frontend_http_client.dart';
import '../../../core/network/local_api_base_url.dart';

class FrontendNotificationsException implements Exception {
  const FrontendNotificationsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FrontendNotificationItem {
  const FrontendNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.campaignId = '',
    this.outboxId = '',
    this.imageUrl = '',
    this.deepLink = '',
    this.readAt,
  });

  final String id;
  final String campaignId;
  final String outboxId;
  final String title;
  final String body;
  final String imageUrl;
  final String deepLink;
  final DateTime createdAt;
  final DateTime? readAt;

  factory FrontendNotificationItem.fromJson(Map<String, Object?> json) {
    return FrontendNotificationItem(
      id: json['id']?.toString() ?? '',
      campaignId: json['campaign_id']?.toString() ?? '',
      outboxId: json['outbox_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      deepLink: json['deep_link']?.toString() ?? '',
      createdAt: _date(json['created_at']) ?? DateTime.now(),
      readAt: _date(json['read_at']),
    );
  }
}

class FrontendNotificationsPage {
  const FrontendNotificationsPage({
    required this.items,
    required this.total,
    required this.unread,
  });

  final List<FrontendNotificationItem> items;
  final int total;
  final int unread;
}

class FrontendNotificationsRepository {
  const FrontendNotificationsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<String> registerDeviceToken({
    required String fcmToken,
    required String platform,
    required String appSurface,
    String? authToken,
    String languageCode = 'tr',
    String countryCode = '',
    String timezone = '',
    String appVersion = '',
    String deviceId = '',
    String deviceModel = '',
    String permissionStatus = 'unknown',
    List<String> topics = const <String>[],
  }) async {
    final result = await _postJson('/api/app/notifications/register', {
      'fcm_token': fcmToken,
      'platform': platform,
      'app_surface': appSurface,
      'language_code': languageCode,
      'country_code': countryCode,
      'timezone': timezone,
      'app_version': appVersion,
      'device_id': deviceId,
      'device_model': deviceModel,
      'permission_status': permissionStatus,
      'topics': topics,
    }, token: authToken);
    return result['deviceTokenId']?.toString() ?? '';
  }

  Future<FrontendNotificationsPage> fetchInbox({
    required String authToken,
    int limit = 25,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    final result = await _getJson('/api/app/notifications/inbox', {
      'limit': '$limit',
      'offset': '$offset',
      if (unreadOnly) 'unread': 'true',
    }, token: authToken);
    final rows = result['items'];
    return FrontendNotificationsPage(
      items: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) => FrontendNotificationItem.fromJson(_asStringMap(row)),
                )
                .toList(growable: false)
          : const <FrontendNotificationItem>[],
      total: _int(result['total']),
      unread: _int(result['unread']),
    );
  }

  Future<void> markInboxItem({
    required String authToken,
    required String id,
    String action = 'read',
  }) async {
    await _patchJson('/api/app/notifications/inbox', {
      'id': id,
      'action': action,
    }, token: authToken);
  }

  Future<void> recordEvent({
    String? authToken,
    String eventType = 'open',
    String campaignId = '',
    String outboxId = '',
    String inboxId = '',
  }) async {
    await _postJson('/api/app/notifications/event', {
      'event_type': eventType,
      'campaign_id': campaignId,
      'outbox_id': outboxId,
      'inbox_id': inboxId,
    }, token: authToken);
  }

  Future<Map<String, Object?>> _getJson(
    String path,
    Map<String, String> query, {
    String? token,
  }) async {
    final response = await (httpClient ?? sharedFrontendClient)
        .get(_uri(path, query), headers: _headers(token))
        .timeout(_timeout);
    return _decodeResponse(response);
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body, {
    String? token,
  }) async {
    final response = await (httpClient ?? sharedFrontendClient)
        .post(
          _uri(path),
          headers: _headers(token, json: true),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decodeResponse(response);
  }

  Future<Map<String, Object?>> _patchJson(
    String path,
    Map<String, Object?> body, {
    String? token,
  }) async {
    final response = await (httpClient ?? sharedFrontendClient)
        .patch(
          _uri(path),
          headers: _headers(token, json: true),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decodeResponse(response);
  }

  Map<String, String> _headers(String? token, {bool json = false}) {
    final authToken = token?.trim() ?? '';
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json; charset=UTF-8',
      if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
    };
  }

  Map<String, Object?> _decodeResponse(http.Response response) {
    final decoded = response.bodyBytes.isEmpty
        ? <String, Object?>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FrontendNotificationsException('Geçersiz sunucu yanıtı');
    }
    final result = _asStringMap(decoded);
    final error = result['error'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        error != null) {
      if (error is Map) {
        final message = error['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          throw FrontendNotificationsException(message);
        }
      }
      throw const FrontendNotificationsException('Bildirim isteği başarısız');
    }
    return result;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = frontendApiUri(
      path,
      configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl,
    );
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }
}

Map<String, Object?> _asStringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
