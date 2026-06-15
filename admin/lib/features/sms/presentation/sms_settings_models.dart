import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

enum AdminSmsProviderMode { smtp, api, sendmail, oauth }

extension AdminSmsProviderModeData on AdminSmsProviderMode {
  String get labelKey {
    return switch (this) {
      AdminSmsProviderMode.smtp => 'sms.settings.mode.smtp',
      AdminSmsProviderMode.api => 'sms.settings.mode.api',
      AdminSmsProviderMode.sendmail => 'sms.settings.mode.sendmail',
      AdminSmsProviderMode.oauth => 'sms.settings.mode.oauth',
    };
  }
}

enum AdminSmsSecurity { tls, ssl, none }

extension AdminSmsSecurityData on AdminSmsSecurity {
  String get labelKey {
    return switch (this) {
      AdminSmsSecurity.tls => 'sms.settings.security.tls',
      AdminSmsSecurity.ssl => 'sms.settings.security.ssl',
      AdminSmsSecurity.none => 'sms.settings.security.none',
    };
  }
}

class AdminSmsProviderPreset {
  const AdminSmsProviderPreset({
    required this.id,
    required this.name,
    required this.mode,
    required this.easySetup,
    required this.icon,
    required this.color,
    this.badgeKey,
    this.smtpHost = '',
    this.smtpPort = 587,
    this.security = AdminSmsSecurity.tls,
    this.apiBaseUrl = '',
    this.supportsImap = false,
    this.imapHost = '',
    this.imapPort = 993,
  });

  final String id;
  final String name;
  final AdminSmsProviderMode mode;
  final bool easySetup;
  final IconData icon;
  final Color color;
  final String? badgeKey;
  final String smtpHost;
  final int smtpPort;
  final AdminSmsSecurity security;
  final String apiBaseUrl;
  final bool supportsImap;
  final String imapHost;
  final int imapPort;
}

const adminSmsProviderPresets = <AdminSmsProviderPreset>[
  AdminSmsProviderPreset(
    id: 'iletimerkezi',
    name: 'İletimerkezi',
    mode: AdminSmsProviderMode.api,
    easySetup: false,
    icon: Symbols.cloud_queue_outlined,
    color: Color(0xFF198754),
    badgeKey: 'sms.settings.badge.recommended',
    apiBaseUrl: 'https://api.iletimerkezi.com/v1/send-sms/json',
  ),
  AdminSmsProviderPreset(
    id: 'netgsm',
    name: 'NetGSM',
    mode: AdminSmsProviderMode.api,
    easySetup: false,
    icon: Symbols.api_outlined,
    color: Color(0xFF2F80ED),
    badgeKey: 'sms.settings.badge.highVolume',
    apiBaseUrl: 'https://api.netgsm.com.tr',
  ),
  AdminSmsProviderPreset(
    id: 'mobildev',
    name: 'Mobildev',
    mode: AdminSmsProviderMode.api,
    easySetup: false,
    icon: Symbols.hub_outlined,
    color: Color(0xFFF39C12),
    apiBaseUrl: 'https://api.mobildev.com',
  ),
  AdminSmsProviderPreset(
    id: 'vatansms',
    name: 'VatanSMS',
    mode: AdminSmsProviderMode.api,
    easySetup: false,
    icon: Symbols.bolt_outlined,
    color: Color(0xFFE67E22),
    apiBaseUrl: 'https://api.vatansms.net',
  ),
  AdminSmsProviderPreset(
    id: 'mesajgo',
    name: 'MesajGo',
    mode: AdminSmsProviderMode.api,
    easySetup: false,
    icon: Symbols.near_me_outlined,
    color: Color(0xFF8E44AD),
    apiBaseUrl: 'https://api.mesajgo.com',
  ),
  AdminSmsProviderPreset(
    id: 'bulutsms',
    name: 'BulutSMS',
    mode: AdminSmsProviderMode.api,
    easySetup: true,
    icon: Symbols.cloud_done_outlined,
    color: Color(0xFF16A085),
    badgeKey: 'sms.settings.badge.delivery',
    apiBaseUrl: 'https://api.bulutsms.com',
  ),
  AdminSmsProviderPreset(
    id: 'twilio_sms',
    name: 'Twilio SMS',
    mode: AdminSmsProviderMode.api,
    easySetup: false,
    icon: Symbols.sms_outlined,
    color: Color(0xFFEA4335),
    apiBaseUrl:
        'https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json',
  ),
  AdminSmsProviderPreset(
    id: 'vonage_sms',
    name: 'Vonage SMS',
    mode: AdminSmsProviderMode.api,
    easySetup: false,
    icon: Symbols.near_me_outlined,
    color: Color(0xFF8E44AD),
    apiBaseUrl: 'https://rest.nexmo.com/sms/json',
  ),
  AdminSmsProviderPreset(
    id: 'infobip_sms',
    name: 'Infobip SMS',
    mode: AdminSmsProviderMode.api,
    easySetup: true,
    icon: Symbols.public_outlined,
    color: Color(0xFF2F80ED),
    apiBaseUrl: 'https://api.infobip.com/sms/3/messages',
  ),
  AdminSmsProviderPreset(
    id: 'custom_sms_api',
    name: 'Özel SMS API',
    mode: AdminSmsProviderMode.api,
    easySetup: true,
    icon: Symbols.settings_input_component_outlined,
    color: AppColors.deepOcean,
  ),
];
AdminSmsProviderPreset adminSmsProviderById(String id) {
  return adminSmsProviderPresets.firstWhere(
    (preset) => preset.id == id,
    orElse: () => adminSmsProviderPresets.first,
  );
}

class AdminSmsAccount {
  const AdminSmsAccount({
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
  final AdminSmsProviderMode mode;
  final String smtpHost;
  final int smtpPort;
  final AdminSmsSecurity security;
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

  AdminSmsAccount copyWith({
    String? accountName,
    String? senderName,
    String? senderEmail,
    String? domain,
    String? providerId,
    String? serviceName,
    AdminSmsProviderMode? mode,
    String? smtpHost,
    int? smtpPort,
    AdminSmsSecurity? security,
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
    return AdminSmsAccount(
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
