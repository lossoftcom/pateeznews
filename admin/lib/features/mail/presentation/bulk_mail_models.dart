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
    this.accountId = '',
    this.templateId = '',
    this.contactListId = '',
    required this.name,
    required this.subject,
    required this.preview,
    this.contentHtml = '',
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
  final String contentHtml;
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
    String? accountId,
    String? templateId,
    String? contactListId,
    String? name,
    String? subject,
    String? preview,
    String? contentHtml,
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
      accountId: accountId ?? this.accountId,
      templateId: templateId ?? this.templateId,
      contactListId: contactListId ?? this.contactListId,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      preview: preview ?? this.preview,
      contentHtml: contentHtml ?? this.contentHtml,
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
