import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../network/frontend_http_client.dart';
import '../network/local_api_base_url.dart';

class FrontendPushNotificationService {
  FrontendPushNotificationService({this.httpClient, this.apiBaseUrl});

  static const _configuredApiBaseUrl = String.fromEnvironment(
    'PATEEZNEWS_API_BASE_URL',
  );
  static const _webVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
    defaultValue:
        'BLK4FyGCmz6MUPSmCQmWX7JYVFJNW7GRq5J1VnRIKFif093p4W8rpF9fhs7U9N_m6UnOiiermjIJJDRLT76e6q8',
  );
  static const _deviceIdKey = 'pateez_fcm_device_id';
  static const _timeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final String? apiBaseUrl;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  String _currentAuthToken = '';
  String _lastRegistrationKey = '';
  Future<void>? _pendingRegistration;

  Future<void> configure({String? authToken}) async {
    _currentAuthToken = authToken?.trim() ?? '';
    _pendingRegistration ??= _configure(authToken: _currentAuthToken)
        .catchError((Object error) {
          debugPrint('Pateez push registration failed: $error');
        })
        .whenComplete(() => _pendingRegistration = null);
    return _pendingRegistration!;
  }

  void dispose() {
    unawaited(_tokenRefreshSubscription?.cancel());
    unawaited(_messageOpenedSubscription?.cancel());
  }

  Future<void> _configure({required String authToken}) async {
    final messaging = FirebaseMessaging.instance;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    final permissionStatus = settings.authorizationStatus.name;
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final fcmToken = await messaging.getToken(
      vapidKey: kIsWeb ? _webVapidKey : null,
    );
    if (fcmToken == null || fcmToken.trim().isEmpty) return;
    await _registerToken(
      fcmToken: fcmToken,
      permissionStatus: permissionStatus,
      authToken: authToken,
    );

    _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen((
      refreshedToken,
    ) {
      unawaited(
        _registerToken(
          fcmToken: refreshedToken,
          permissionStatus: permissionStatus,
          authToken: _currentAuthToken,
        ).catchError((Object error) {
          debugPrint('Pateez push token refresh failed: $error');
        }),
      );
    });

    _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      unawaited(
        recordMessageEvent(
          message,
          eventType: 'open',
          authToken: _currentAuthToken,
        ),
      );
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      unawaited(
        recordMessageEvent(
          initialMessage,
          eventType: 'open',
          authToken: authToken,
        ),
      );
    }
  }

  Future<void> _registerToken({
    required String fcmToken,
    required String permissionStatus,
    required String authToken,
  }) async {
    final registrationKey =
        '$fcmToken|$permissionStatus|${authToken.isEmpty ? 'anon' : authToken}';
    if (_lastRegistrationKey == registrationKey) return;

    final body = <String, Object?>{
      'fcm_token': fcmToken,
      'platform': _platform,
      'app_surface': kIsWeb ? 'flutter_web' : 'flutter_mobile',
      'language_code': 'tr',
      'country_code': 'TR',
      'timezone': DateTime.now().timeZoneName,
      'app_version': const String.fromEnvironment(
        'PATEEZ_APP_VERSION',
        defaultValue: '1.0.0+1',
      ),
      'device_id': await _deviceId(),
      'device_model': _deviceModel,
      'permission_status': permissionStatus,
      'topics': const ['general'],
    };

    await _postJson('/api/app/notifications/register', body, authToken);
    _lastRegistrationKey = registrationKey;
  }

  Future<void> recordMessageEvent(
    RemoteMessage message, {
    required String eventType,
    String? authToken,
  }) async {
    final data = message.data;
    final campaignId = _firstText(data, const ['campaign_id', 'campaignId']);
    final outboxId = _firstText(data, const [
      'outbox_id',
      'outboxId',
      'notification_id',
      'notificationId',
    ]);
    final deviceTokenId = _firstText(data, const [
      'device_token_id',
      'deviceTokenId',
    ]);
    if (campaignId.isEmpty && outboxId.isEmpty && deviceTokenId.isEmpty) {
      return;
    }
    await _postJson('/api/app/notifications/event', {
      'event_type': eventType,
      'campaign_id': campaignId,
      'outbox_id': outboxId,
      'device_token_id': deviceTokenId,
      'metadata': {'message_id': message.messageId, 'source': 'flutter_fcm'},
    }, authToken?.trim() ?? _currentAuthToken);
  }

  Future<void> _postJson(
    String path,
    Map<String, Object?> body,
    String authToken,
  ) async {
    final token = authToken.trim();
    final response = await (httpClient ?? sharedFrontendClient)
        .post(
          _uri(path),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json; charset=UTF-8',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final decoded = response.bodyBytes.isEmpty
        ? <String, Object?>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map && decoded['error'] is Map) {
      throw Exception((decoded['error'] as Map)['message'] ?? 'Push failed');
    }
    throw Exception('Push request failed (${response.statusCode})');
  }

  Uri _uri(String path) {
    return frontendApiUri(
      path,
      configuredBaseUrl: apiBaseUrl ?? _configuredApiBaseUrl,
    );
  }

  String get _platform {
    if (kIsWeb) return 'flutter_web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'web',
    };
  }

  String get _deviceModel {
    final target = kIsWeb ? 'web' : defaultTargetPlatform.name;
    return 'flutter:$target';
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey)?.trim() ?? '';
    if (existing.isNotEmpty) return existing;
    final created = _newDeviceId();
    await prefs.setString(_deviceIdKey, created);
    return created;
  }

  String _newDeviceId() {
    try {
      final random = Random.secure();
      final bytes = List<int>.generate(18, (_) => random.nextInt(256));
      return 'flutter-${base64UrlEncode(bytes).replaceAll('=', '')}';
    } catch (_) {
      return 'flutter-${DateTime.now().microsecondsSinceEpoch}';
    }
  }

  String _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}
