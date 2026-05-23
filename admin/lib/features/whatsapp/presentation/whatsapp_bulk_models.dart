import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum AdminWhatsappBulkStatus {
  draft,
  sending,
  completed,
  scheduled,
  paused,
  cancelled,
}

extension AdminWhatsappBulkStatusLabel on AdminWhatsappBulkStatus {
  String get value {
    return switch (this) {
      AdminWhatsappBulkStatus.draft => 'draft',
      AdminWhatsappBulkStatus.sending => 'sending',
      AdminWhatsappBulkStatus.completed => 'completed',
      AdminWhatsappBulkStatus.scheduled => 'scheduled',
      AdminWhatsappBulkStatus.paused => 'paused',
      AdminWhatsappBulkStatus.cancelled => 'cancelled',
    };
  }

  String get labelKey {
    return switch (this) {
      AdminWhatsappBulkStatus.draft => 'whatsapp.bulk.status.draft',
      AdminWhatsappBulkStatus.sending => 'whatsapp.bulk.status.sending',
      AdminWhatsappBulkStatus.completed => 'whatsapp.bulk.status.completed',
      AdminWhatsappBulkStatus.scheduled => 'whatsapp.bulk.status.scheduled',
      AdminWhatsappBulkStatus.paused => 'whatsapp.bulk.status.paused',
      AdminWhatsappBulkStatus.cancelled => 'whatsapp.bulk.status.cancelled',
    };
  }

  Color get dotColor {
    return switch (this) {
      AdminWhatsappBulkStatus.draft => AppColors.support,
      AdminWhatsappBulkStatus.sending => const Color(0xFF3B82F6),
      AdminWhatsappBulkStatus.completed => const Color(0xFF198754),
      AdminWhatsappBulkStatus.scheduled => AppColors.warmHorizon,
      AdminWhatsappBulkStatus.paused => const Color(0xFFF59E0B),
      AdminWhatsappBulkStatus.cancelled => AppColors.actionRed,
    };
  }

  Color get backgroundColor => dotColor.withValues(alpha: 0.12);

  bool get canStart =>
      this == AdminWhatsappBulkStatus.draft ||
      this == AdminWhatsappBulkStatus.scheduled;

  bool get canPause => this == AdminWhatsappBulkStatus.sending;

  bool get canResume => this == AdminWhatsappBulkStatus.paused;

  bool get canSchedule =>
      this == AdminWhatsappBulkStatus.draft ||
      this == AdminWhatsappBulkStatus.scheduled;
}

class AdminWhatsappBulkCampaign {
  const AdminWhatsappBulkCampaign({
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
  final AdminWhatsappBulkStatus status;
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

  AdminWhatsappBulkCampaign copyWith({
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
    AdminWhatsappBulkStatus? status,
    DateTime? startedAt,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
  }) {
    return AdminWhatsappBulkCampaign(
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

const whatsappBulkFilterAll = 'all';

final List<AdminWhatsappBulkCampaign> sampleAdminWhatsappBulkCampaigns = [
  AdminWhatsappBulkCampaign(
    id: 301,
    name: 'Haftalik WhatsApp Bulteni',
    subject: 'haftalik_haber_ozeti',
    preview: 'Bolgenin gundemini WhatsApp sablonu ile gonder.',
    templateName: 'Haftalik Haber Ozeti',
    templateCategory: 'Kampanya',
    senderAccount: 'Pateez Ana WhatsApp',
    senderEmail: '+90 555 010 2026',
    recipientList: 'Aktif Okurlar',
    recipientCount: 1280,
    sentCount: 1280,
    openCount: 612,
    clickCount: 184,
    bounceCount: 18,
    status: AdminWhatsappBulkStatus.completed,
    createdAt: DateTime(2026, 5, 19, 9, 15),
    startedAt: DateTime(2026, 5, 19, 10),
  ),
  AdminWhatsappBulkCampaign(
    id: 302,
    name: 'Yerel Etkinlik WhatsApp Duyurusu',
    subject: 'yerel_etkinlik_duyurusu',
    preview: 'Hafta sonu etkinliklerini WhatsApp uzerinden bildir.',
    templateName: 'Etkinlik Duyurusu',
    templateCategory: 'Kampanya',
    senderAccount: 'Pateez Destek WhatsApp',
    senderEmail: '+90 555 010 2027',
    recipientList: 'Etkinlik Takipcileri',
    recipientCount: 740,
    sentCount: 260,
    openCount: 91,
    clickCount: 28,
    bounceCount: 4,
    status: AdminWhatsappBulkStatus.sending,
    createdAt: DateTime(2026, 5, 23, 8, 45),
    startedAt: DateTime(2026, 5, 23, 12, 10),
  ),
  AdminWhatsappBulkCampaign(
    id: 303,
    name: 'Reklam WhatsApp Bilgilendirme',
    subject: 'reklam_paket_bilgilendirme',
    preview: 'Sponsorlu icerik ve reklam paketlerini onayli sablonla duyur.',
    templateName: 'Reklam Teklifi',
    templateCategory: 'Kurumsal',
    senderAccount: 'Reklam WhatsApp',
    senderEmail: '+90 555 010 2028',
    recipientList: 'Reklamverenler',
    recipientCount: 96,
    sentCount: 0,
    openCount: 0,
    clickCount: 0,
    bounceCount: 0,
    status: AdminWhatsappBulkStatus.draft,
    createdAt: DateTime(2026, 5, 22, 14, 30),
  ),
  AdminWhatsappBulkCampaign(
    id: 304,
    name: 'Sabah WhatsApp Ozeti',
    subject: 'sabah_haber_ozeti',
    preview: 'Sabah ozet mesajlari belirlenen saatte gonderilecek.',
    templateName: 'Sabah Ozeti',
    templateCategory: 'Bulten',
    senderAccount: 'Pateez Ana WhatsApp',
    senderEmail: '+90 555 010 2026',
    recipientList: 'Gunluk Bulten',
    recipientCount: 2100,
    sentCount: 0,
    openCount: 0,
    clickCount: 0,
    bounceCount: 0,
    status: AdminWhatsappBulkStatus.scheduled,
    createdAt: DateTime(2026, 5, 23, 7, 20),
    scheduledAt: DateTime(2026, 5, 24, 8),
  ),
];
