import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'social_platform_data.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

enum AdminSocialConnectionMode { bundle, directApi, webhook }

extension AdminSocialConnectionModeData on AdminSocialConnectionMode {
  String get labelKey {
    return switch (this) {
      AdminSocialConnectionMode.bundle => 'social.settings.mode.bundle',
      AdminSocialConnectionMode.directApi => 'social.settings.mode.directApi',
      AdminSocialConnectionMode.webhook => 'social.settings.mode.webhook',
    };
  }
}

class AdminSocialProviderPreset {
  const AdminSocialProviderPreset({
    required this.id,
    required this.name,
    required this.mode,
    required this.color,
    required this.categoryKey,
    required this.apiBaseUrl,
    required this.defaultScopes,
    this.badgeKey,
    this.platform,
    this.fallbackIcon,
  });

  final String id;
  final String name;
  final AdminSocialConnectionMode mode;
  final Color color;
  final String categoryKey;
  final String apiBaseUrl;
  final String defaultScopes;
  final String? badgeKey;
  final SocialPlatform? platform;
  final IconData? fallbackIcon;
}

const adminSocialProviderPresets = <AdminSocialProviderPreset>[
  AdminSocialProviderPreset(
    id: 'bundle_social',
    name: 'Bundle.social',
    mode: AdminSocialConnectionMode.bundle,
    color: AppColors.actionRed,
    categoryKey: 'social.settings.providerDialog.category.unified',
    badgeKey: 'social.settings.badge.recommended',
    apiBaseUrl: 'https://api.bundle.social/api/v1',
    defaultScopes:
        'Instagram, Facebook, X, TikTok, LinkedIn, YouTube, Pinterest, Reddit, Threads, Bluesky, Mastodon, Google Business, Discord, Slack',
    fallbackIcon: Symbols.hub_outlined,
  ),
];

AdminSocialProviderPreset adminSocialProviderById(String id) {
  return adminSocialProviderPresets.firstWhere(
    (preset) => preset.id == id,
    orElse: () => adminSocialProviderPresets.first,
  );
}

class AdminSocialAccount {
  const AdminSocialAccount({
    required this.id,
    required this.accountName,
    required this.workspaceName,
    required this.platforms,
    required this.providerId,
    required this.providerName,
    required this.mode,
    required this.apiBaseUrl,
    required this.teamId,
    required this.clientId,
    this.clientSecret = '',
    required this.redirectUrl,
    required this.webhookUrl,
    required this.scopes,
    required this.dailyLimit,
    required this.monthlyLimit,
    required this.hourlyLimit,
    required this.sentToday,
    required this.apiReady,
    required this.oauthReady,
    required this.webhookReady,
    required this.requiresApproval,
    required this.active,
    required this.createdAt,
    this.hasApiKey = false,
    this.hasClientSecret = false,
    this.serverApiKeyConfigured = false,
    this.connectionStatus = '',
    this.lastErrorMessage = '',
    this.lastSyncAt,
  });

  final int id;
  final String accountName;
  final String workspaceName;
  final String platforms;
  final String providerId;
  final String providerName;
  final AdminSocialConnectionMode mode;
  final String apiBaseUrl;
  final String teamId;
  final String clientId;
  final String clientSecret;
  final String redirectUrl;
  final String webhookUrl;
  final String scopes;
  final int dailyLimit;
  final int monthlyLimit;
  final int hourlyLimit;
  final int sentToday;
  final bool apiReady;
  final bool oauthReady;
  final bool webhookReady;
  final bool requiresApproval;
  final bool active;
  final DateTime createdAt;
  final bool hasApiKey;
  final bool hasClientSecret;
  final bool serverApiKeyConfigured;
  final String connectionStatus;
  final String lastErrorMessage;
  final DateTime? lastSyncAt;

  bool get connectionReady => apiReady && oauthReady && webhookReady;

  AdminSocialAccount copyWith({
    String? accountName,
    String? workspaceName,
    String? platforms,
    String? providerId,
    String? providerName,
    AdminSocialConnectionMode? mode,
    String? apiBaseUrl,
    String? teamId,
    String? clientId,
    String? clientSecret,
    String? redirectUrl,
    String? webhookUrl,
    String? scopes,
    int? dailyLimit,
    int? monthlyLimit,
    int? hourlyLimit,
    int? sentToday,
    bool? apiReady,
    bool? oauthReady,
    bool? webhookReady,
    bool? requiresApproval,
    bool? active,
    DateTime? createdAt,
    bool? hasApiKey,
    bool? hasClientSecret,
    bool? serverApiKeyConfigured,
    String? connectionStatus,
    String? lastErrorMessage,
    DateTime? lastSyncAt,
  }) {
    return AdminSocialAccount(
      id: id,
      accountName: accountName ?? this.accountName,
      workspaceName: workspaceName ?? this.workspaceName,
      platforms: platforms ?? this.platforms,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      mode: mode ?? this.mode,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      teamId: teamId ?? this.teamId,
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      scopes: scopes ?? this.scopes,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      hourlyLimit: hourlyLimit ?? this.hourlyLimit,
      sentToday: sentToday ?? this.sentToday,
      apiReady: apiReady ?? this.apiReady,
      oauthReady: oauthReady ?? this.oauthReady,
      webhookReady: webhookReady ?? this.webhookReady,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      hasClientSecret: hasClientSecret ?? this.hasClientSecret,
      serverApiKeyConfigured:
          serverApiKeyConfigured ?? this.serverApiKeyConfigured,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}
