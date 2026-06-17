import 'dart:convert';

enum AdminNotificationSection { campaigns, templates, devices, settings }

enum AdminNotificationStatus {
  draft,
  scheduled,
  sending,
  paused,
  completed,
  failed,
  cancelled,
}

AdminNotificationStatus notificationStatusFromText(Object? value) {
  final text = _text(value).toLowerCase();
  return AdminNotificationStatus.values.firstWhere(
    (status) => status.name == text,
    orElse: () => AdminNotificationStatus.draft,
  );
}

String notificationStatusLabelKey(AdminNotificationStatus status) {
  return 'notifications.status.${status.name}';
}

class AdminNotificationStats {
  const AdminNotificationStats({
    this.total = 0,
    this.active = 0,
    this.ready = 0,
    this.sending = 0,
    this.scheduled = 0,
    this.completed = 0,
    this.sent = 0,
    this.failed = 0,
    this.invalid = 0,
    this.android = 0,
    this.ios = 0,
    this.web = 0,
  });

  final int total;
  final int active;
  final int ready;
  final int sending;
  final int scheduled;
  final int completed;
  final int sent;
  final int failed;
  final int invalid;
  final int android;
  final int ios;
  final int web;

  factory AdminNotificationStats.fromJson(Object? value) {
    final json = _map(value);
    return AdminNotificationStats(
      total: _int(json['total']),
      active: _int(json['active']),
      ready: _int(json['ready']),
      sending: _int(json['sending']),
      scheduled: _int(json['scheduled']),
      completed: _int(json['completed']),
      sent: _int(json['sent']),
      failed: _int(json['failed']),
      invalid: _int(json['invalid']),
      android: _int(json['android']),
      ios: _int(json['ios']),
      web: _int(json['web']),
    );
  }
}

class AdminNotificationPage<T> {
  const AdminNotificationPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.stats,
  });

  final List<T> items;
  final int total;
  final int limit;
  final int offset;
  final AdminNotificationStats stats;
}

class AdminNotificationCampaign {
  const AdminNotificationCampaign({
    required this.id,
    required this.name,
    required this.title,
    required this.body,
    required this.targetType,
    required this.status,
    required this.priority,
    required this.recipientCount,
    required this.queuedCount,
    required this.sentCount,
    required this.failedCount,
    required this.openedCount,
    required this.clickedCount,
    required this.createdAt,
    this.templateId = 0,
    this.templateName = '',
    this.imageUrl = '',
    this.deepLink = '',
    this.targetPlatforms = const <String>[],
    this.targetTopics = const <String>[],
    this.ttlSeconds = 3600,
    this.channelId = 'pateez_general',
    this.scheduledStartAt,
  });

  final int id;
  final int templateId;
  final String templateName;
  final String name;
  final String title;
  final String body;
  final String targetType;
  final List<String> targetPlatforms;
  final List<String> targetTopics;
  final String imageUrl;
  final String deepLink;
  final AdminNotificationStatus status;
  final String priority;
  final int ttlSeconds;
  final String channelId;
  final int recipientCount;
  final int queuedCount;
  final int sentCount;
  final int failedCount;
  final int openedCount;
  final int clickedCount;
  final DateTime? scheduledStartAt;
  final DateTime createdAt;

  factory AdminNotificationCampaign.fromJson(Map<dynamic, dynamic> json) {
    return AdminNotificationCampaign(
      id: _int(json['id']),
      templateId: _int(json['template_id']),
      templateName: _text(json['template_name']),
      name: _text(json['campaign_name']),
      title: _text(json['title']),
      body: _text(json['body']),
      targetType: _text(json['target_type'], 'all'),
      targetPlatforms: _stringList(json['target_platforms']),
      targetTopics: _stringList(json['target_topics']),
      imageUrl: _text(json['image_url']),
      deepLink: _text(json['deep_link']),
      status: notificationStatusFromText(json['status']),
      priority: _text(json['priority'], 'normal'),
      ttlSeconds: _int(json['ttl_seconds'], 3600),
      channelId: _text(json['channel_id'], 'pateez_general'),
      recipientCount: _int(json['recipient_count']),
      queuedCount: _int(json['queued_count']),
      sentCount: _int(json['sent_count']),
      failedCount: _int(json['failed_count']),
      openedCount: _int(json['opened_count']),
      clickedCount: _int(json['clicked_count']),
      scheduledStartAt: _date(json['scheduled_start_at']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, Object?> toPayload() {
    return {
      'campaign_name': name,
      'template_id': templateId == 0 ? null : templateId,
      'target_type': targetType,
      'target_platforms': targetPlatforms,
      'target_topics': targetTopics,
      'title': title,
      'body': body,
      'image_url': imageUrl,
      'deep_link': deepLink,
      'priority': priority,
      'ttl_seconds': ttlSeconds,
      'channel_id': channelId,
      'status': status.name,
      if (scheduledStartAt != null)
        'scheduled_start_at': scheduledStartAt!.toUtc().toIso8601String(),
    };
  }
}

class AdminNotificationTemplate {
  const AdminNotificationTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.title,
    required this.body,
    required this.languageCode,
    required this.priority,
    required this.ready,
    required this.active,
    required this.createdAt,
    this.imageUrl = '',
    this.deepLink = '',
    this.ttlSeconds = 3600,
    this.channelId = 'pateez_general',
  });

  final int id;
  final String name;
  final String category;
  final String title;
  final String body;
  final String imageUrl;
  final String deepLink;
  final String languageCode;
  final String priority;
  final int ttlSeconds;
  final String channelId;
  final bool ready;
  final bool active;
  final DateTime createdAt;

  factory AdminNotificationTemplate.fromJson(Map<dynamic, dynamic> json) {
    return AdminNotificationTemplate(
      id: _int(json['id']),
      name: _text(json['template_name']),
      category: _text(json['category'], 'general'),
      title: _text(json['title']),
      body: _text(json['body']),
      imageUrl: _text(json['image_url']),
      deepLink: _text(json['deep_link']),
      languageCode: _text(json['language_code'], 'tr'),
      priority: _text(json['priority'], 'normal'),
      ttlSeconds: _int(json['ttl_seconds'], 3600),
      channelId: _text(json['channel_id'], 'pateez_general'),
      ready: _bool(json['is_ready'], fallback: true),
      active: _bool(json['is_active'], fallback: true),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, Object?> toPayload() {
    return {
      'template_name': name,
      'category': category,
      'title': title,
      'body': body,
      'image_url': imageUrl,
      'deep_link': deepLink,
      'language_code': languageCode,
      'priority': priority,
      'ttl_seconds': ttlSeconds,
      'channel_id': channelId,
      'is_ready': ready,
      'is_active': active,
    };
  }
}

class AdminNotificationDevice {
  const AdminNotificationDevice({
    required this.id,
    required this.fcmToken,
    required this.platform,
    required this.appSurface,
    required this.languageCode,
    required this.permissionStatus,
    required this.active,
    required this.lastSeenAt,
    this.userId = '',
    this.countryCode = '',
    this.timezone = '',
    this.appVersion = '',
    this.deviceModel = '',
    this.topics = const <String>[],
    this.invalidReason = '',
  });

  final int id;
  final String userId;
  final String fcmToken;
  final String platform;
  final String appSurface;
  final String languageCode;
  final String countryCode;
  final String timezone;
  final String appVersion;
  final String deviceModel;
  final String permissionStatus;
  final List<String> topics;
  final bool active;
  final String invalidReason;
  final DateTime lastSeenAt;

  factory AdminNotificationDevice.fromJson(Map<dynamic, dynamic> json) {
    return AdminNotificationDevice(
      id: _int(json['id']),
      userId: _text(json['user_id']),
      fcmToken: _text(json['fcm_token']),
      platform: _text(json['platform'], 'web'),
      appSurface: _text(json['app_surface'], 'astro_web'),
      languageCode: _text(json['language_code'], 'tr'),
      countryCode: _text(json['country_code']),
      timezone: _text(json['timezone']),
      appVersion: _text(json['app_version']),
      deviceModel: _text(json['device_model']),
      permissionStatus: _text(json['permission_status'], 'unknown'),
      topics: _stringList(json['topics']),
      active: _bool(json['is_active'], fallback: true),
      invalidReason: _text(json['invalid_reason']),
      lastSeenAt: _date(json['last_seen_at']) ?? DateTime.now(),
    );
  }
}

class AdminNotificationSettings {
  const AdminNotificationSettings({
    required this.id,
    required this.projectId,
    required this.clientEmail,
    required this.webVapidKey,
    required this.apiBaseUrl,
    required this.defaultLanguageCode,
    required this.dailyLimit,
    required this.monthlyLimit,
    required this.hourlyLimit,
    required this.batchSize,
    required this.androidEnabled,
    required this.iosEnabled,
    required this.flutterWebEnabled,
    required this.astroWebEnabled,
    required this.tokenVerified,
    required this.active,
    required this.connectionStatus,
    required this.hasPrivateKey,
    required this.serverCredentialsConfigured,
    this.lastErrorMessage = '',
  });

  final int id;
  final String projectId;
  final String clientEmail;
  final String webVapidKey;
  final String apiBaseUrl;
  final String defaultLanguageCode;
  final int dailyLimit;
  final int monthlyLimit;
  final int hourlyLimit;
  final int batchSize;
  final bool androidEnabled;
  final bool iosEnabled;
  final bool flutterWebEnabled;
  final bool astroWebEnabled;
  final bool tokenVerified;
  final bool active;
  final String connectionStatus;
  final bool hasPrivateKey;
  final bool serverCredentialsConfigured;
  final String lastErrorMessage;

  factory AdminNotificationSettings.fromJson(Map<dynamic, dynamic> json) {
    return AdminNotificationSettings(
      id: _int(json['id']),
      projectId: _text(json['project_id']),
      clientEmail: _text(json['client_email']),
      webVapidKey: _text(json['web_vapid_key']),
      apiBaseUrl: _text(json['api_base_url'], 'https://fcm.googleapis.com/v1'),
      defaultLanguageCode: _text(json['default_language_code'], 'tr'),
      dailyLimit: _int(json['daily_limit'], 100000),
      monthlyLimit: _int(json['monthly_limit'], 3000000),
      hourlyLimit: _int(json['hourly_limit'], 10000),
      batchSize: _int(json['batch_size'], 100),
      androidEnabled: _bool(json['android_enabled'], fallback: true),
      iosEnabled: _bool(json['ios_enabled'], fallback: true),
      flutterWebEnabled: _bool(json['flutter_web_enabled'], fallback: true),
      astroWebEnabled: _bool(json['astro_web_enabled'], fallback: true),
      tokenVerified: _bool(json['token_verified']),
      active: _bool(json['is_active'], fallback: true),
      connectionStatus: _text(json['connection_status'], 'pending'),
      hasPrivateKey: _bool(json['has_private_key']),
      serverCredentialsConfigured: _bool(json['server_credentials_configured']),
      lastErrorMessage: _text(json['last_error_message']),
    );
  }

  Map<String, Object?> toPayload({String privateKey = ''}) {
    return {
      'project_id': projectId,
      'client_email': clientEmail,
      'web_vapid_key': webVapidKey,
      'api_base_url': apiBaseUrl,
      'default_language_code': defaultLanguageCode,
      'daily_limit': dailyLimit,
      'monthly_limit': monthlyLimit,
      'hourly_limit': hourlyLimit,
      'batch_size': batchSize,
      'android_enabled': androidEnabled,
      'ios_enabled': iosEnabled,
      'flutter_web_enabled': flutterWebEnabled,
      'astro_web_enabled': astroWebEnabled,
      'is_active': active,
      if (privateKey.trim().isNotEmpty) 'private_key': privateKey.trim(),
    };
  }
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? fallback : text;
}

int _int(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _bool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return fallback;
}

DateTime? _date(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, Object?>{};
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(value);
      if (parsed is List) {
        return parsed
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    } on FormatException {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
  }
  return const <String>[];
}
