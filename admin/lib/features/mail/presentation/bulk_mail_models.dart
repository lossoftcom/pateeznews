import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum AdminBulkMailStatus {
  draft,
  sending,
  completed,
  scheduled,
  paused,
  cancelled,
}

extension AdminBulkMailStatusLabel on AdminBulkMailStatus {
  String get value {
    return switch (this) {
      AdminBulkMailStatus.draft => 'draft',
      AdminBulkMailStatus.sending => 'sending',
      AdminBulkMailStatus.completed => 'completed',
      AdminBulkMailStatus.scheduled => 'scheduled',
      AdminBulkMailStatus.paused => 'paused',
      AdminBulkMailStatus.cancelled => 'cancelled',
    };
  }

  String get labelKey {
    return switch (this) {
      AdminBulkMailStatus.draft => 'mail.campaign.status.draft',
      AdminBulkMailStatus.sending => 'mail.campaign.status.sending',
      AdminBulkMailStatus.completed => 'mail.campaign.status.completed',
      AdminBulkMailStatus.scheduled => 'mail.campaign.status.scheduled',
      AdminBulkMailStatus.paused => 'mail.campaign.status.paused',
      AdminBulkMailStatus.cancelled => 'mail.campaign.status.cancelled',
    };
  }

  Color get dotColor {
    return switch (this) {
      AdminBulkMailStatus.draft => AppColors.support,
      AdminBulkMailStatus.sending => const Color(0xFF3B82F6),
      AdminBulkMailStatus.completed => const Color(0xFF198754),
      AdminBulkMailStatus.scheduled => AppColors.warmHorizon,
      AdminBulkMailStatus.paused => const Color(0xFFF59E0B),
      AdminBulkMailStatus.cancelled => AppColors.actionRed,
    };
  }

  Color get backgroundColor => dotColor.withValues(alpha: 0.12);

  bool get canStart =>
      this == AdminBulkMailStatus.draft ||
      this == AdminBulkMailStatus.scheduled;

  bool get canPause => this == AdminBulkMailStatus.sending;

  bool get canResume => this == AdminBulkMailStatus.paused;

  bool get canSchedule =>
      this == AdminBulkMailStatus.draft ||
      this == AdminBulkMailStatus.scheduled;
}

class AdminBulkMailCampaign {
  const AdminBulkMailCampaign({
    required this.id,
    required this.name,
    required this.subject,
    required this.preview,
    required this.templateName,
    required this.templateCategory,
    required this.senderAccount,
    required this.senderEmail,
    required this.recipientList,
    required this.recipientCount,
    required this.sentCount,
    required this.openCount,
    required this.clickCount,
    required this.bounceCount,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.scheduledAt,
  });

  final int id;
  final String name;
  final String subject;
  final String preview;
  final String templateName;
  final String templateCategory;
  final String senderAccount;
  final String senderEmail;
  final String recipientList;
  final int recipientCount;
  final int sentCount;
  final int openCount;
  final int clickCount;
  final int bounceCount;
  final AdminBulkMailStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? scheduledAt;

  double get progress {
    if (recipientCount <= 0) return 0;
    return (sentCount / recipientCount).clamp(0, 1).toDouble();
  }

  double get openRate => sentCount == 0 ? 0 : openCount / sentCount;

  double get clickRate => sentCount == 0 ? 0 : clickCount / sentCount;

  double get bounceRate => sentCount == 0 ? 0 : bounceCount / sentCount;

  int get remainingCount {
    final remaining = recipientCount - sentCount;
    return remaining < 0 ? 0 : remaining;
  }

  DateTime get tableDate => scheduledAt ?? startedAt ?? createdAt;

  AdminBulkMailCampaign copyWith({
    String? name,
    String? subject,
    String? preview,
    String? templateName,
    String? templateCategory,
    String? senderAccount,
    String? senderEmail,
    String? recipientList,
    int? recipientCount,
    int? sentCount,
    int? openCount,
    int? clickCount,
    int? bounceCount,
    AdminBulkMailStatus? status,
    DateTime? startedAt,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
  }) {
    return AdminBulkMailCampaign(
      id: id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      preview: preview ?? this.preview,
      templateName: templateName ?? this.templateName,
      templateCategory: templateCategory ?? this.templateCategory,
      senderAccount: senderAccount ?? this.senderAccount,
      senderEmail: senderEmail ?? this.senderEmail,
      recipientList: recipientList ?? this.recipientList,
      recipientCount: recipientCount ?? this.recipientCount,
      sentCount: sentCount ?? this.sentCount,
      openCount: openCount ?? this.openCount,
      clickCount: clickCount ?? this.clickCount,
      bounceCount: bounceCount ?? this.bounceCount,
      status: status ?? this.status,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      scheduledAt: clearScheduledAt ? null : scheduledAt ?? this.scheduledAt,
    );
  }
}

const bulkMailFilterAll = 'all';

final List<AdminBulkMailCampaign> sampleAdminBulkMailCampaigns = [
  AdminBulkMailCampaign(
    id: 301,
    name: 'Haftalik Haber Bulteni',
    subject: 'Bu haftanin one cikan Pateez haberleri',
    preview: 'Bolgenin gundemini ve en cok okunan haberlerini derledik.',
    templateName: 'Haftalik Bulten',
    templateCategory: 'Kampanya',
    senderAccount: 'Pateez Ana Mail',
    senderEmail: 'haber@pateez.com',
    recipientList: 'Aktif Okurlar',
    recipientCount: 1280,
    sentCount: 1280,
    openCount: 612,
    clickCount: 184,
    bounceCount: 18,
    status: AdminBulkMailStatus.completed,
    createdAt: DateTime(2026, 5, 19, 9, 15),
    startedAt: DateTime(2026, 5, 19, 10),
  ),
  AdminBulkMailCampaign(
    id: 302,
    name: 'Yerel Etkinlik Duyurusu',
    subject: 'Nigde kultur sanat etkinlikleri basliyor',
    preview: 'Hafta sonu etkinliklerini kacirmayin.',
    templateName: 'Etkinlik Duyurusu',
    templateCategory: 'Kampanya',
    senderAccount: 'Iletisim Mail',
    senderEmail: 'iletisim@pateez.com',
    recipientList: 'Etkinlik Takipcileri',
    recipientCount: 740,
    sentCount: 260,
    openCount: 91,
    clickCount: 28,
    bounceCount: 4,
    status: AdminBulkMailStatus.sending,
    createdAt: DateTime(2026, 5, 23, 8, 45),
    startedAt: DateTime(2026, 5, 23, 12, 10),
  ),
  AdminBulkMailCampaign(
    id: 303,
    name: 'Reklam Bilgilendirme',
    subject: 'Mayis reklam paketleri ve yayin alanlari',
    preview: 'Sponsorlu icerik ve banner alanlari icin guncel bilgiler.',
    templateName: 'Reklam Teklifi',
    templateCategory: 'Kurumsal',
    senderAccount: 'Pateez Ana Mail',
    senderEmail: 'reklam@pateez.com',
    recipientList: 'Reklamverenler',
    recipientCount: 96,
    sentCount: 0,
    openCount: 0,
    clickCount: 0,
    bounceCount: 0,
    status: AdminBulkMailStatus.draft,
    createdAt: DateTime(2026, 5, 22, 14, 30),
  ),
  AdminBulkMailCampaign(
    id: 304,
    name: 'Sabah Ozet Bulteni',
    subject: 'Gune baslarken bilmeniz gerekenler',
    preview: 'Sabah ozet bulteni belirlenen saatte gonderilecek.',
    templateName: 'Sabah Ozeti',
    templateCategory: 'Bulten',
    senderAccount: 'Pateez Ana Mail',
    senderEmail: 'bulten@pateez.com',
    recipientList: 'Gunluk Bulten',
    recipientCount: 2100,
    sentCount: 0,
    openCount: 0,
    clickCount: 0,
    bounceCount: 0,
    status: AdminBulkMailStatus.scheduled,
    createdAt: DateTime(2026, 5, 23, 7, 20),
    scheduledAt: DateTime(2026, 5, 24, 8),
  ),
];
