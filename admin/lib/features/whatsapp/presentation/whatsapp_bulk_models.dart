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
    this.accountId = '',
    this.templateId = '',
    this.contactListId = '',
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
  final String accountId;
  final String templateId;
  final String contactListId;
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
    String? accountId,
    String? templateId,
    String? contactListId,
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
      accountId: accountId ?? this.accountId,
      templateId: templateId ?? this.templateId,
      contactListId: contactListId ?? this.contactListId,
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
