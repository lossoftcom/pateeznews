import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

enum AdminMailTemplateCategory { campaign, info, invitation, order, quote }

extension AdminMailTemplateCategoryData on AdminMailTemplateCategory {
  String get value {
    return switch (this) {
      AdminMailTemplateCategory.campaign => 'campaign',
      AdminMailTemplateCategory.info => 'info',
      AdminMailTemplateCategory.invitation => 'invitation',
      AdminMailTemplateCategory.order => 'order',
      AdminMailTemplateCategory.quote => 'quote',
    };
  }

  String get labelKey {
    return switch (this) {
      AdminMailTemplateCategory.campaign => 'mail.template.category.campaign',
      AdminMailTemplateCategory.info => 'mail.template.category.info',
      AdminMailTemplateCategory.invitation =>
        'mail.template.category.invitation',
      AdminMailTemplateCategory.order => 'mail.template.category.order',
      AdminMailTemplateCategory.quote => 'mail.template.category.quote',
    };
  }
}

class AdminMailTemplateVariable {
  const AdminMailTemplateVariable({
    required this.token,
    required this.labelKey,
    this.icon = Symbols.data_object_outlined,
  });

  final String token;
  final String labelKey;
  final IconData icon;
}

class AdminMailTemplate {
  const AdminMailTemplate({
    required this.id,
    required this.nameKey,
    required this.category,
    required this.variableCount,
    required this.ready,
    required this.active,
    required this.updatedAt,
    required this.subject,
    required this.previewText,
    required this.body,
  });

  final int id;
  final String nameKey;
  final AdminMailTemplateCategory category;
  final int variableCount;
  final bool ready;
  final bool active;
  final DateTime updatedAt;
  final String subject;
  final String previewText;
  final String body;

  AdminMailTemplate copyWith({
    String? nameKey,
    AdminMailTemplateCategory? category,
    int? variableCount,
    bool? ready,
    bool? active,
    DateTime? updatedAt,
    String? subject,
    String? previewText,
    String? body,
  }) {
    return AdminMailTemplate(
      id: id,
      nameKey: nameKey ?? this.nameKey,
      category: category ?? this.category,
      variableCount: variableCount ?? this.variableCount,
      ready: ready ?? this.ready,
      active: active ?? this.active,
      updatedAt: updatedAt ?? this.updatedAt,
      subject: subject ?? this.subject,
      previewText: previewText ?? this.previewText,
      body: body ?? this.body,
    );
  }
}

const mailTemplateFilterAll = 'all';

const adminMailTemplateMemberVariables = <AdminMailTemplateVariable>[
  AdminMailTemplateVariable(
    token: '{{uye_adi}}',
    labelKey: 'mail.template.variable.memberName',
    icon: Symbols.person_outline,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_kullanici_adi}}',
    labelKey: 'mail.template.variable.username',
    icon: Symbols.alternate_email,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_eposta}}',
    labelKey: 'mail.template.variable.email',
    icon: Symbols.mail_outline,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_telefon}}',
    labelKey: 'mail.template.variable.phone',
    icon: Symbols.phone_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_rol}}',
    labelKey: 'mail.template.variable.role',
    icon: Symbols.verified_user_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_kayit_tarihi}}',
    labelKey: 'mail.template.variable.registerDate',
    icon: Symbols.calendar_today_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_son_giris}}',
    labelKey: 'mail.template.variable.lastLogin',
    icon: Symbols.schedule_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_profil_linki}}',
    labelKey: 'mail.template.variable.profileUrl',
    icon: Symbols.link_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_avatar}}',
    labelKey: 'mail.template.variable.avatar',
    icon: Symbols.image_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_onay_durumu}}',
    labelKey: 'mail.template.variable.approvalStatus',
    icon: Symbols.fact_check_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_odul_puani}}',
    labelKey: 'mail.template.variable.rewardPoint',
    icon: Symbols.workspace_premium_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_abonelik_durumu}}',
    labelKey: 'mail.template.variable.subscriptionStatus',
    icon: Symbols.notifications_active_outlined,
  ),
];

Color adminMailTemplateCategoryAccent(AdminMailTemplateCategory category) {
  return switch (category) {
    AdminMailTemplateCategory.campaign => AppColors.warmHorizon,
    AdminMailTemplateCategory.info => AppColors.deepOcean,
    AdminMailTemplateCategory.invitation => const Color(0xFF3B82F6),
    AdminMailTemplateCategory.order => const Color(0xFF198754),
    AdminMailTemplateCategory.quote => AppColors.actionRed,
  };
}
