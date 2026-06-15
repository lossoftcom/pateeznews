import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

enum AdminWhatsappProviderMode { smtp, api, sendmail, oauth }

extension AdminWhatsappProviderModeData on AdminWhatsappProviderMode {
  String get labelKey {
    return switch (this) {
      AdminWhatsappProviderMode.smtp => 'whatsapp.settings.mode.smtp',
      AdminWhatsappProviderMode.api => 'whatsapp.settings.mode.api',
      AdminWhatsappProviderMode.sendmail => 'whatsapp.settings.mode.sendmail',
      AdminWhatsappProviderMode.oauth => 'whatsapp.settings.mode.oauth',
    };
  }
}

enum AdminWhatsappSecurity { tls, ssl, none }

extension AdminWhatsappSecurityData on AdminWhatsappSecurity {
  String get labelKey {
    return switch (this) {
      AdminWhatsappSecurity.tls => 'whatsapp.settings.security.tls',
      AdminWhatsappSecurity.ssl => 'whatsapp.settings.security.ssl',
      AdminWhatsappSecurity.none => 'whatsapp.settings.security.none',
    };
  }
}

class AdminWhatsappProviderPreset {
  const AdminWhatsappProviderPreset({
    required this.id,
    required this.name,
    required this.mode,
    required this.easySetup,
    required this.icon,
    required this.color,
    this.badgeKey,
    this.smtpHost = '',
    this.smtpPort = 587,
    this.security = AdminWhatsappSecurity.tls,
    this.apiBaseUrl = '',
    this.supportsImap = false,
    this.imapHost = '',
    this.imapPort = 993,
  });

  final String id;
  final String name;
  final AdminWhatsappProviderMode mode;
  final bool easySetup;
  final IconData icon;
  final Color color;
  final String? badgeKey;
  final String smtpHost;
  final int smtpPort;
  final AdminWhatsappSecurity security;
  final String apiBaseUrl;
  final bool supportsImap;
  final String imapHost;
  final int imapPort;
}

const adminWhatsappProviderPresets = <AdminWhatsappProviderPreset>[
  AdminWhatsappProviderPreset(
    id: 'meta_cloud_api',
    name: 'Meta Cloud API',
    mode: AdminWhatsappProviderMode.api,
    easySetup: false,
    icon: Symbols.cloud_queue_outlined,
    color: Color(0xFF198754),
    badgeKey: 'whatsapp.settings.badge.recommended',
    apiBaseUrl: 'https://graph.facebook.com/v25.0/{phone_number_id}/messages',
  ),
  AdminWhatsappProviderPreset(
    id: 'twilio_whatsapp',
    name: 'Twilio WhatsApp',
    mode: AdminWhatsappProviderMode.api,
    easySetup: false,
    icon: Symbols.api_outlined,
    color: Color(0xFFEA4335),
    apiBaseUrl:
        'https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json',
  ),
  AdminWhatsappProviderPreset(
    id: 'dialog360',
    name: '360dialog',
    mode: AdminWhatsappProviderMode.api,
    easySetup: false,
    icon: Symbols.hub_outlined,
    color: Color(0xFF2F80ED),
    badgeKey: 'whatsapp.settings.badge.highVolume',
    apiBaseUrl: 'https://waba-v2.360dialog.io/messages',
  ),
  AdminWhatsappProviderPreset(
    id: 'gupshup',
    name: 'Gupshup',
    mode: AdminWhatsappProviderMode.api,
    easySetup: false,
    icon: Symbols.bolt_outlined,
    color: Color(0xFFF39C12),
    apiBaseUrl: 'https://api.gupshup.io/wa/api/v1/msg',
  ),
  AdminWhatsappProviderPreset(
    id: 'bird_whatsapp',
    name: 'Bird WhatsApp',
    mode: AdminWhatsappProviderMode.api,
    easySetup: false,
    icon: Symbols.forum_outlined,
    color: Color(0xFF1769AA),
  ),
  AdminWhatsappProviderPreset(
    id: 'vonage_whatsapp',
    name: 'Vonage WhatsApp',
    mode: AdminWhatsappProviderMode.api,
    easySetup: false,
    icon: Symbols.near_me_outlined,
    color: Color(0xFF8E44AD),
  ),
  AdminWhatsappProviderPreset(
    id: 'wati',
    name: 'WATI',
    mode: AdminWhatsappProviderMode.api,
    easySetup: true,
    icon: Symbols.chat_bubble_outline,
    color: Color(0xFF198754),
    badgeKey: 'whatsapp.settings.badge.delivery',
  ),
  AdminWhatsappProviderPreset(
    id: 'aisensy',
    name: 'AiSensy',
    mode: AdminWhatsappProviderMode.api,
    easySetup: true,
    icon: Symbols.smart_toy_outlined,
    color: Color(0xFF2F80ED),
  ),
  AdminWhatsappProviderPreset(
    id: 'respond_io',
    name: 'Respond.io',
    mode: AdminWhatsappProviderMode.api,
    easySetup: true,
    icon: Symbols.support_agent_outlined,
    color: Color(0xFF16A085),
  ),
  AdminWhatsappProviderPreset(
    id: 'brevo_whatsapp',
    name: 'Brevo WhatsApp',
    mode: AdminWhatsappProviderMode.api,
    easySetup: true,
    icon: Symbols.campaign_outlined,
    color: Color(0xFF2F80ED),
  ),
  AdminWhatsappProviderPreset(
    id: 'custom_bsp',
    name: 'Özel WhatsApp API',
    mode: AdminWhatsappProviderMode.api,
    easySetup: true,
    icon: Symbols.settings_input_component_outlined,
    color: AppColors.deepOcean,
  ),
];
AdminWhatsappProviderPreset adminWhatsappProviderById(String id) {
  return adminWhatsappProviderPresets.firstWhere(
    (preset) => preset.id == id,
    orElse: () => adminWhatsappProviderPresets.first,
  );
}

class AdminWhatsappAccount {
  const AdminWhatsappAccount({
    required this.id,
    required this.accountName,
    required this.senderName,
    required this.senderEmail,
    required this.domain,
    required this.providerId,
    required this.serviceName,
    required this.mode,
    required this.smtpHost,
    required this.smtpPort,
    required this.security,
    required this.smtpUser,
    required this.apiBaseUrl,
    this.apiKey = '',
    this.apiSecret = '',
    required this.dailyLimit,
    required this.monthlyLimit,
    required this.hourlyLimit,
    required this.sentToday,
    required this.spfReady,
    required this.dkimReady,
    required this.dmarcReady,
    required this.trackingDomain,
    required this.active,
    required this.createdAt,
  });

  final int id;
  final String accountName;
  final String senderName;
  final String senderEmail;
  final String domain;
  final String providerId;
  final String serviceName;
  final AdminWhatsappProviderMode mode;
  final String smtpHost;
  final int smtpPort;
  final AdminWhatsappSecurity security;
  final String smtpUser;
  final String apiBaseUrl;
  final String apiKey;
  final String apiSecret;
  final int dailyLimit;
  final int monthlyLimit;
  final int hourlyLimit;
  final int sentToday;
  final bool spfReady;
  final bool dkimReady;
  final bool dmarcReady;
  final String trackingDomain;
  final bool active;
  final DateTime createdAt;

  bool get dnsReady => spfReady && dkimReady && dmarcReady;

  AdminWhatsappAccount copyWith({
    String? accountName,
    String? senderName,
    String? senderEmail,
    String? domain,
    String? providerId,
    String? serviceName,
    AdminWhatsappProviderMode? mode,
    String? smtpHost,
    int? smtpPort,
    AdminWhatsappSecurity? security,
    String? smtpUser,
    String? apiBaseUrl,
    String? apiKey,
    String? apiSecret,
    int? dailyLimit,
    int? monthlyLimit,
    int? hourlyLimit,
    int? sentToday,
    bool? spfReady,
    bool? dkimReady,
    bool? dmarcReady,
    String? trackingDomain,
    bool? active,
    DateTime? createdAt,
  }) {
    return AdminWhatsappAccount(
      id: id,
      accountName: accountName ?? this.accountName,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      domain: domain ?? this.domain,
      providerId: providerId ?? this.providerId,
      serviceName: serviceName ?? this.serviceName,
      mode: mode ?? this.mode,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      security: security ?? this.security,
      smtpUser: smtpUser ?? this.smtpUser,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      hourlyLimit: hourlyLimit ?? this.hourlyLimit,
      sentToday: sentToday ?? this.sentToday,
      spfReady: spfReady ?? this.spfReady,
      dkimReady: dkimReady ?? this.dkimReady,
      dmarcReady: dmarcReady ?? this.dmarcReady,
      trackingDomain: trackingDomain ?? this.trackingDomain,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
