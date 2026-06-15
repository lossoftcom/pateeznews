import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

enum AdminMailProviderMode { smtp, api, sendmail, oauth }

extension AdminMailProviderModeData on AdminMailProviderMode {
  String get labelKey {
    return switch (this) {
      AdminMailProviderMode.smtp => 'mail.settings.mode.smtp',
      AdminMailProviderMode.api => 'mail.settings.mode.api',
      AdminMailProviderMode.sendmail => 'mail.settings.mode.sendmail',
      AdminMailProviderMode.oauth => 'mail.settings.mode.oauth',
    };
  }
}

enum AdminMailSecurity { tls, ssl, none }

extension AdminMailSecurityData on AdminMailSecurity {
  String get labelKey {
    return switch (this) {
      AdminMailSecurity.tls => 'mail.settings.security.tls',
      AdminMailSecurity.ssl => 'mail.settings.security.ssl',
      AdminMailSecurity.none => 'mail.settings.security.none',
    };
  }
}

class AdminMailProviderPreset {
  const AdminMailProviderPreset({
    required this.id,
    required this.name,
    required this.mode,
    required this.easySetup,
    required this.icon,
    required this.color,
    this.badgeKey,
    this.smtpHost = '',
    this.smtpPort = 587,
    this.security = AdminMailSecurity.tls,
    this.apiBaseUrl = '',
    this.supportsImap = false,
    this.imapHost = '',
    this.imapPort = 993,
  });

  final String id;
  final String name;
  final AdminMailProviderMode mode;
  final bool easySetup;
  final IconData icon;
  final Color color;
  final String? badgeKey;
  final String smtpHost;
  final int smtpPort;
  final AdminMailSecurity security;
  final String apiBaseUrl;
  final bool supportsImap;
  final String imapHost;
  final int imapPort;
}

const adminMailProviderPresets = <AdminMailProviderPreset>[
  AdminMailProviderPreset(
    id: 'amazon_ses_smtp',
    name: 'Amazon SES (SMTP)',
    mode: AdminMailProviderMode.smtp,
    easySetup: false,
    icon: Symbols.cloud_queue_outlined,
    color: Color(0xFF2F80ED),
    badgeKey: 'mail.settings.badge.highVolume',
    smtpHost: 'email-smtp.us-east-1.amazonaws.com',
  ),
  AdminMailProviderPreset(
    id: 'amazon_ses_api',
    name: 'Amazon SES (API)',
    mode: AdminMailProviderMode.api,
    easySetup: false,
    icon: Symbols.api_outlined,
    color: Color(0xFF2F80ED),
    badgeKey: 'mail.settings.badge.recommended',
  ),
  AdminMailProviderPreset(
    id: 'sendgrid_smtp',
    name: 'SendGrid (SMTP)',
    mode: AdminMailProviderMode.smtp,
    easySetup: false,
    icon: Symbols.send_outlined,
    color: Color(0xFF1769AA),
    smtpHost: 'smtp.sendgrid.net',
  ),
  AdminMailProviderPreset(
    id: 'sendgrid_api',
    name: 'SendGrid (API)',
    mode: AdminMailProviderMode.api,
    easySetup: false,
    icon: Symbols.api_outlined,
    color: Color(0xFF1769AA),
  ),
  AdminMailProviderPreset(
    id: 'mailgun_api',
    name: 'Mailgun (API)',
    mode: AdminMailProviderMode.api,
    easySetup: false,
    icon: Symbols.hub_outlined,
    color: Color(0xFFF39C12),
  ),
  AdminMailProviderPreset(
    id: 'mailgun_smtp',
    name: 'Mailgun (SMTP)',
    mode: AdminMailProviderMode.smtp,
    easySetup: false,
    icon: Symbols.outgoing_mail,
    color: Color(0xFFF39C12),
    smtpHost: 'smtp.mailgun.org',
  ),
  AdminMailProviderPreset(
    id: 'elastic_api',
    name: 'Elastic Email (API)',
    mode: AdminMailProviderMode.api,
    easySetup: false,
    icon: Symbols.bolt_outlined,
    color: Color(0xFF8E44AD),
  ),
  AdminMailProviderPreset(
    id: 'elastic_smtp',
    name: 'Elastic Email (SMTP)',
    mode: AdminMailProviderMode.smtp,
    easySetup: false,
    icon: Symbols.bolt_outlined,
    color: Color(0xFF8E44AD),
    smtpHost: 'smtp.elasticemail.com',
    smtpPort: 2525,
  ),
  AdminMailProviderPreset(
    id: 'sparkpost_api',
    name: 'SparkPost (API)',
    mode: AdminMailProviderMode.api,
    easySetup: false,
    icon: Symbols.local_fire_department_outlined,
    color: Color(0xFFE67E22),
  ),
  AdminMailProviderPreset(
    id: 'sparkpost_smtp',
    name: 'SparkPost (SMTP)',
    mode: AdminMailProviderMode.smtp,
    easySetup: false,
    icon: Symbols.local_fire_department_outlined,
    color: Color(0xFFE67E22),
    smtpHost: 'smtp.sparkpostmail.com',
  ),
  AdminMailProviderPreset(
    id: 'smtp_generic',
    name: 'Özel SMTP',
    mode: AdminMailProviderMode.smtp,
    easySetup: false,
    icon: Symbols.settings_input_component_outlined,
    color: AppColors.deepOcean,
  ),
  AdminMailProviderPreset(
    id: 'sendmail',
    name: 'Sendmail',
    mode: AdminMailProviderMode.sendmail,
    easySetup: false,
    icon: Symbols.terminal_outlined,
    color: AppColors.deepOcean,
  ),
  AdminMailProviderPreset(
    id: 'gmail_oauth',
    name: 'Gmail (OAuth)',
    mode: AdminMailProviderMode.oauth,
    easySetup: false,
    icon: Symbols.lock_outline,
    color: Color(0xFFEA4335),
    smtpHost: 'smtp.gmail.com',
    imapHost: 'imap.gmail.com',
    supportsImap: true,
  ),
  AdminMailProviderPreset(
    id: 'purelymail_smtp',
    name: 'Purelymail',
    mode: AdminMailProviderMode.smtp,
    easySetup: true,
    icon: Symbols.mark_email_read_outlined,
    color: Color(0xFFF39C12),
    badgeKey: 'mail.settings.badge.smtpRequired',
    smtpHost: 'smtp.purelymail.com',
    smtpPort: 465,
    security: AdminMailSecurity.ssl,
    imapHost: 'imap.purelymail.com',
    supportsImap: true,
  ),
  AdminMailProviderPreset(
    id: 'postmark',
    name: 'Postmark',
    mode: AdminMailProviderMode.api,
    easySetup: true,
    icon: Symbols.inventory_2_outlined,
    color: Color(0xFF2F80ED),
    badgeKey: 'mail.settings.badge.delivery',
  ),
  AdminMailProviderPreset(
    id: 'resend',
    name: 'Resend',
    mode: AdminMailProviderMode.api,
    easySetup: true,
    icon: Symbols.redo_outlined,
    color: AppColors.deepOcean,
  ),
  AdminMailProviderPreset(
    id: 'mailtrap',
    name: 'Mailtrap',
    mode: AdminMailProviderMode.api,
    easySetup: true,
    icon: Symbols.bug_report_outlined,
    color: Color(0xFF16A085),
  ),
  AdminMailProviderPreset(
    id: 'brevo',
    name: 'Brevo',
    mode: AdminMailProviderMode.api,
    easySetup: true,
    icon: Symbols.campaign_outlined,
    color: Color(0xFF2F80ED),
  ),
  AdminMailProviderPreset(
    id: 'mailersend',
    name: 'MailerSend',
    mode: AdminMailProviderMode.api,
    easySetup: true,
    icon: Symbols.near_me_outlined,
    color: Color(0xFF198754),
  ),
];

AdminMailProviderPreset adminMailProviderById(String id) {
  return adminMailProviderPresets.firstWhere(
    (preset) => preset.id == id,
    orElse: () => adminMailProviderPresets.first,
  );
}

class AdminMailAccount {
  const AdminMailAccount({
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
    this.smtpPassword = '',
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
  final AdminMailProviderMode mode;
  final String smtpHost;
  final int smtpPort;
  final AdminMailSecurity security;
  final String smtpUser;
  final String smtpPassword;
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

  AdminMailAccount copyWith({
    String? accountName,
    String? senderName,
    String? senderEmail,
    String? domain,
    String? providerId,
    String? serviceName,
    AdminMailProviderMode? mode,
    String? smtpHost,
    int? smtpPort,
    AdminMailSecurity? security,
    String? smtpUser,
    String? smtpPassword,
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
    return AdminMailAccount(
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
      smtpPassword: smtpPassword ?? this.smtpPassword,
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
