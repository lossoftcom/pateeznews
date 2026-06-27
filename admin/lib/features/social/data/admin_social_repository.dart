import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';
import '../presentation/social_platform_data.dart';
import '../presentation/social_settings_models.dart';

class AdminSocialException implements Exception {
  const AdminSocialException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminSocialConnectedAccount {
  const AdminSocialConnectedAccount({
    required this.id,
    required this.socialAccountId,
    required this.platform,
    required this.platformType,
    required this.accountName,
    required this.displayName,
    required this.username,
    required this.channelId,
    required this.channelName,
    required this.status,
    this.bundleSocialAccountId = '',
    this.avatarUrl = '',
    this.teamId = '',
    this.twitterSubType = '',
    this.rawJson = const <String, Object?>{},
    this.connectedAt,
  });

  final int id;
  final int socialAccountId;
  final String bundleSocialAccountId;
  final SocialPlatform platform;
  final String platformType;
  final String accountName;
  final String displayName;
  final String username;
  final String avatarUrl;
  final String channelId;
  final String channelName;
  final String status;
  final String teamId;
  final String twitterSubType;
  final Map<String, Object?> rawJson;
  final DateTime? connectedAt;

  String get resolvedDisplayName {
    final direct = displayName.trim();
    if (direct.isNotEmpty) return direct;
    final channel = channelName.trim();
    if (channel.isNotEmpty) return channel;
    final user = username.trim();
    if (user.isNotEmpty) return user.replaceFirst(RegExp(r'^@'), '');
    return accountName.trim().isEmpty ? 'Pateez' : accountName.trim();
  }

  String get resolvedUsername {
    final user = username.trim();
    if (user.isNotEmpty) return user.replaceFirst(RegExp(r'^@'), '');
    final channel = channelName.trim();
    if (channel.isNotEmpty) return channel.replaceFirst(RegExp(r'^@'), '');
    return resolvedDisplayName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  bool get isTwitterPremium {
    final subtype = twitterSubType.trim().toLowerCase();
    return subtype == 'premium' || subtype == 'premium_plus';
  }

  int get effectiveTwitterCharLimit => isTwitterPremium ? 25000 : 280;

  String get twitterTierLabel {
    final subtype = twitterSubType.trim().toLowerCase();
    return switch (subtype) {
      'premium_plus' => 'Premium+',
      'premium' => 'Premium',
      'basic' => 'Basic',
      'none' => 'Free',
      _ => '',
    };
  }
}

class AdminSocialPublishResult {
  const AdminSocialPublishResult({
    required this.id,
    required this.bundlePostId,
    required this.status,
  });

  final String id;
  final String bundlePostId;
  final String status;
}

abstract class AdminSocialRepository {
  Future<List<AdminSocialAccount>> fetchSettings(AdminSession session);

  Future<AdminSocialAccount> saveSetting(
    AdminSession session, {
    int? id,
    required AdminSocialAccount account,
    String apiKey = '',
    String clientSecret = '',
  });

  Future<AdminSocialAccount> updateSetting(
    AdminSession session,
    AdminSocialAccount account,
    Map<String, Object?> values,
  );

  Future<AdminSocialAccount> checkSetting(AdminSession session, int accountId);

  Future<void> deleteSettings(AdminSession session, Iterable<int> ids);

  Future<List<AdminSocialConnectedAccount>> fetchConnectedAccounts(
    AdminSession session,
  );

  Future<AdminSocialConnectedAccount> updateConnectedAccount(
    AdminSession session,
    AdminSocialConnectedAccount account,
    Map<String, Object?> values,
  );

  Future<void> deleteConnectedAccount(
    AdminSession session,
    AdminSocialConnectedAccount account,
  );

  Future<String> createPortalLink(
    AdminSession session, {
    int? socialAccountId,
    required Iterable<SocialPlatform> platforms,
    String? redirectUrl,
  });

  Future<AdminSocialPublishResult> publishPost(
    AdminSession session, {
    int? socialAccountId,
    required SocialPublishData data,
    DateTime? scheduledAt,
  });
}

class SupabaseAdminSocialRepository implements AdminSocialRepository {
  const SupabaseAdminSocialRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 30);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<List<AdminSocialAccount>> fetchSettings(AdminSession session) async {
    final result = await _getJson('/api/admin/social/settings', session);
    final rows = result['accounts'];
    return rows is List
        ? rows.whereType<Map>().map(_settingFromJson).toList(growable: false)
        : const <AdminSocialAccount>[];
  }

  @override
  Future<AdminSocialAccount> saveSetting(
    AdminSession session, {
    int? id,
    required AdminSocialAccount account,
    String apiKey = '',
    String clientSecret = '',
  }) async {
    final body = _settingPayload(
      account,
      apiKey: apiKey,
      clientSecret: clientSecret,
    );
    final result = id == null
        ? await _requestJson(
            'POST',
            '/api/admin/social/settings',
            session,
            body,
          )
        : await _requestJson('PATCH', '/api/admin/social/settings', session, {
            'id': id,
            ...body,
          });
    final row = result['account'];
    if (row is Map) return _settingFromJson(row);
    throw const AdminSocialException('Sosyal medya ayarı kaydedilemedi');
  }

  @override
  Future<AdminSocialAccount> updateSetting(
    AdminSession session,
    AdminSocialAccount account,
    Map<String, Object?> values,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/social/settings',
      session,
      {'id': account.id, ...values},
    );
    final row = result['account'];
    if (row is Map) return _settingFromJson(row);
    throw const AdminSocialException('Sosyal medya ayarı güncellenemedi');
  }

  @override
  Future<AdminSocialAccount> checkSetting(
    AdminSession session,
    int accountId,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/social/settings',
      session,
      {'id': accountId, 'action': 'connection-check'},
    );
    final row = result['account'];
    if (row is Map) return _settingFromJson(row);
    throw const AdminSocialException(
      'Sosyal medya bağlantısı kontrol edilemedi',
    );
  }

  @override
  Future<void> deleteSettings(AdminSession session, Iterable<int> ids) async {
    for (final id in ids) {
      await _requestJson('DELETE', '/api/admin/social/settings', session, {
        'id': id,
      });
    }
  }

  @override
  Future<List<AdminSocialConnectedAccount>> fetchConnectedAccounts(
    AdminSession session,
  ) async {
    final result = await _getJson('/api/admin/social/accounts', session);
    final rows = result['accounts'];
    return rows is List
        ? rows
              .whereType<Map>()
              .map(_connectedAccountFromJson)
              .toList(growable: false)
        : const <AdminSocialConnectedAccount>[];
  }

  @override
  Future<AdminSocialConnectedAccount> updateConnectedAccount(
    AdminSession session,
    AdminSocialConnectedAccount account,
    Map<String, Object?> values,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/social/accounts',
      session,
      {'id': account.id, ...values},
    );
    final row = result['account'];
    if (row is Map) return _connectedAccountFromJson(row);
    throw const AdminSocialException('Sosyal medya hesabı güncellenemedi');
  }

  @override
  Future<void> deleteConnectedAccount(
    AdminSession session,
    AdminSocialConnectedAccount account,
  ) async {
    await _requestJson('DELETE', '/api/admin/social/accounts', session, {
      'id': account.id,
    });
  }

  @override
  Future<String> createPortalLink(
    AdminSession session, {
    int? socialAccountId,
    required Iterable<SocialPlatform> platforms,
    String? redirectUrl,
  }) async {
    final result =
        await _requestJson('POST', '/api/admin/social/accounts', session, {
          'social_account_id': socialAccountId,
          if (redirectUrl != null && redirectUrl.trim().isNotEmpty)
            'redirect_url': redirectUrl.trim(),
          'social_account_types': platforms
              .map((platform) => platform.bundleSocialType)
              .toList(growable: false),
        });
    final url = result['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw const AdminSocialException(
        'Bundle Social bağlantı adresi alınamadı',
      );
    }
    return url;
  }

  @override
  Future<AdminSocialPublishResult> publishPost(
    AdminSession session, {
    int? socialAccountId,
    required SocialPublishData data,
    DateTime? scheduledAt,
  }) async {
    final selectedAccountIds = <String, String>{
      for (final entry in data.selectedConnectedAccountIds.entries)
        if (data.selectedPlatforms.contains(entry.key))
          entry.key.bundleSocialType: entry.value.toString(),
    };
    final platformOptions = data.platformOptions.toPayload();
    final body = {
      'social_account_id': socialAccountId,
      'title': data.campaignName.trim().isEmpty
          ? (data.newsTitle.trim().isEmpty
                ? 'Pateez social post'
                : data.newsTitle.trim())
          : data.campaignName.trim(),
      'caption': data.displayCaption,
      'link_url': data.effectiveLink,
      'media_urls': data.effectiveImages,
      'post_type': data.postType.name,
      if (scheduledAt != null)
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'social_account_types': data.selectedPlatforms
          .map((platform) => platform.bundleSocialType)
          .toList(growable: false),
      if (selectedAccountIds.isNotEmpty)
        'selected_connected_account_ids': selectedAccountIds,
      if (platformOptions.isNotEmpty) 'platform_options': platformOptions,
    };
    final result = await _requestJson(
      'POST',
      '/api/admin/social/publish',
      session,
      body,
    );
    final post = result['post'];
    if (post is Map) {
      return AdminSocialPublishResult(
        id: _decodeText(post['id']),
        bundlePostId: _decodeText(post['bundle_post_id']),
        status: _decodeText(post['status']),
      );
    }
    throw const AdminSocialException('Bundle Social gönderisi oluşturulamadı');
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
      throw const AdminSocialException('Sunucu yanıtı zaman aşımına uğradı');
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
      final headers = await adminJsonHeaders(token: session.accessToken);
      final request = http.Request(method, _uri(path))
        ..headers.addAll(headers)
        ..body = jsonEncode(body);
      final streamed = await client.send(request).timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamed);
      return _decodeResponse(response);
    } on TimeoutException {
      throw const AdminSocialException('Sunucu yanıtı zaman aşımına uğradı');
    } finally {
      if (closeClient) client.close();
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminSocialException('Geçersiz sunucu yanıtı');
    }
    final result = decoded.map((key, value) => MapEntry(key.toString(), value));
    final error = result['error'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        error != null) {
      if (error is Map) {
        final message = error['message']?.toString();
        if (message != null && message.isNotEmpty) {
          throw AdminSocialException(message);
        }
      }
      throw const AdminSocialException('Sosyal medya isteği başarısız oldu');
    }
    return result;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final configured = (apiBaseUrl ?? _apiBaseUrl).trim();
    final base = configured.isNotEmpty && !isLocalAdminApiBaseUrl(configured)
        ? Uri.parse(configured)
        : Uri.parse('https://pateez.com');
    final uri = base.resolve(path);
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  Map<String, Object?> _settingPayload(
    AdminSocialAccount account, {
    String apiKey = '',
    String clientSecret = '',
  }) {
    return {
      'account_name': account.accountName,
      'workspace_name': account.workspaceName,
      'platforms': account.platforms,
      'provider_id': 'bundle_social',
      'provider_name': 'Bundle.social',
      'connection_mode': 'bundle',
      'api_base_url': account.apiBaseUrl,
      'team_id': account.teamId,
      'redirect_url': account.redirectUrl,
      'webhook_url': account.webhookUrl,
      'scopes': account.scopes,
      'daily_limit': account.dailyLimit,
      'monthly_limit': account.monthlyLimit,
      'hourly_limit': account.hourlyLimit,
      'is_active': account.active,
      'requires_approval': false,
      if (apiKey.trim().isNotEmpty) 'api_key': apiKey.trim(),
      if (clientSecret.trim().isNotEmpty) 'client_secret': clientSecret.trim(),
    };
  }

  AdminSocialAccount _settingFromJson(Map<dynamic, dynamic> json) {
    return AdminSocialAccount(
      id: _asInt(json['id']),
      accountName: _decodeText(json['account_name']),
      workspaceName: _decodeText(json['workspace_name']),
      platforms: _decodeText(json['platforms']),
      providerId: _decodeText(json['provider_id']).isEmpty
          ? 'bundle_social'
          : _decodeText(json['provider_id']),
      providerName: _decodeText(json['provider_name']).isEmpty
          ? 'Bundle.social'
          : _decodeText(json['provider_name']),
      mode: AdminSocialConnectionMode.bundle,
      apiBaseUrl: _decodeText(json['api_base_url']).isEmpty
          ? 'https://api.bundle.social/api/v1'
          : _decodeText(json['api_base_url']),
      teamId: _decodeText(json['team_id']),
      clientId: '',
      redirectUrl: _decodeText(json['redirect_url']),
      webhookUrl: _decodeText(json['webhook_url']),
      scopes: _decodeText(json['scopes']),
      dailyLimit: _asInt(json['daily_limit'], fallback: 10000),
      monthlyLimit: _asInt(json['monthly_limit'], fallback: 100000),
      hourlyLimit: _asInt(json['hourly_limit'], fallback: 700),
      sentToday: _asInt(json['sent_today']),
      apiReady: _asBool(json['api_verified']),
      oauthReady: _asBool(json['oauth_verified']),
      webhookReady: _asBool(json['webhook_verified']),
      requiresApproval: _asBool(json['requires_approval']),
      active: _asBool(json['is_active'], fallback: true),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      hasApiKey: _asBool(json['has_api_key']),
      hasClientSecret: _asBool(json['has_client_secret']),
      serverApiKeyConfigured: _asBool(json['server_api_key_configured']),
      connectionStatus: _decodeText(json['connection_status']),
      lastErrorMessage: _decodeText(json['last_error_message']),
      lastSyncAt: _parseDate(json['last_sync_at']),
    );
  }

  AdminSocialConnectedAccount _connectedAccountFromJson(
    Map<dynamic, dynamic> json,
  ) {
    final rawJson = _decodeMap(json['raw_json']);
    return AdminSocialConnectedAccount(
      id: _asInt(json['id']),
      socialAccountId: _asInt(json['social_account_id']),
      bundleSocialAccountId: _decodeText(json['bundle_social_account_id']),
      platform: socialPlatformFromBundleType(
        _decodeText(json['platform_type']),
      ),
      platformType: _decodeText(json['platform_type']),
      accountName: _decodeText(json['account_name']),
      displayName: _decodeText(json['display_name']),
      username: _decodeText(json['username']),
      avatarUrl: _decodeText(json['avatar_url']),
      channelId: _decodeText(json['channel_id']),
      channelName: _decodeText(json['channel_name']),
      status: _decodeText(json['status']),
      teamId: _decodeText(json['team_id']),
      twitterSubType: _firstText([
        json['twitter_sub_type'],
        json['twitterSubType'],
        rawJson['twitterSubType'],
        rawJson['twitter_sub_type'],
      ]),
      rawJson: rawJson,
      connectedAt: _parseDate(json['connected_at']),
    );
  }

  String _decodeText(Object? value) => value?.toString() ?? '';

  String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = _decodeText(value).trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Map<String, Object?> _decodeMap(Object? value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } on FormatException {
        return const <String, Object?>{};
      }
    }
    return const <String, Object?>{};
  }

  int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _asBool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    final text = value?.toString().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return fallback;
  }

  DateTime? _parseDate(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}
