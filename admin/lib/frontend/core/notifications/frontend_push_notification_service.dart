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
  FrontendPushNotificationService({
    this.httpClient,
    this.apiBaseUrl,
    this.onDeepLink,
    this.onOpen,
  });

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
  final FutureOr<void> Function(String deepLink)? onDeepLink;
  final FutureOr<void> Function(FrontendPushOpenAction action)? onOpen;
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
      unawaited(_handleMessageOpen(message, authToken: _currentAuthToken));
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      unawaited(_handleMessageOpen(initialMessage, authToken: authToken));
    }
  }

  Future<void> _handleMessageOpen(
    RemoteMessage message, {
    required String authToken,
  }) async {
    try {
      await recordMessageEvent(
        message,
        eventType: 'open',
        authToken: authToken,
      );
    } catch (error) {
      debugPrint('Pateez push open event failed: $error');
    }

    final action = FrontendPushOpenAction.fromMessageData(message.data);
    if (action.isAdminOnly) {
      try {
        await onOpen?.call(action);
      } catch (error) {
        debugPrint('Pateez push admin open failed: $error');
      }
      return;
    }

    final deepLink = action.deepLink.isNotEmpty
        ? action.deepLink
        : _firstText(message.data, const [
            'deepLink',
            'deep_link',
            'click_action',
            'link',
            'url',
          ]);
    if (deepLink.isEmpty) return;
    try {
      await onDeepLink?.call(deepLink);
    } catch (error) {
      debugPrint('Pateez push deep link failed: $error');
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
}

class FrontendPushOpenAction {
  const FrontendPushOpenAction({
    required this.data,
    required this.deepLink,
    required this.type,
    required this.adminPage,
    required this.isAdminOnly,
  });

  final Map<String, String> data;
  final String deepLink;
  final String type;
  final String adminPage;
  final bool isAdminOnly;

  factory FrontendPushOpenAction.fromMessageData(Map<String, dynamic> source) {
    final data = <String, String>{
      for (final entry in source.entries)
        entry.key: entry.value?.toString().trim() ?? '',
    };
    final type = _firstText(data, const ['type']);
    final explicitAdminPage = _firstText(data, const [
      'adminPage',
      'admin_page',
      'adminRoute',
      'admin_route',
    ]);
    final adminPage = explicitAdminPage.isNotEmpty
        ? explicitAdminPage
        : _adminPageForType(type);
    return FrontendPushOpenAction(
      data: data,
      deepLink: _firstText(data, const [
        'deepLink',
        'deep_link',
        'click_action',
        'link',
        'url',
      ]),
      type: type,
      adminPage: adminPage,
      isAdminOnly:
          _truthy(_firstText(data, const ['adminOnly', 'admin_only'])) ||
          adminPage.isNotEmpty,
    );
  }
}

String _adminPageForType(String type) {
  return switch (type.trim()) {
    'comment_created' => 'comments',
    'user_signup' => 'users',
    'newsletter_subscriber' => 'subscribers',
    'automatic_news' => 'automaticNews',
    _ => '',
  };
}

bool _truthy(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

String _firstText(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}
