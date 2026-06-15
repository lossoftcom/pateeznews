import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

enum AdminSmsTemplateCategory { campaign, info, invitation, order, quote }

extension AdminSmsTemplateCategoryData on AdminSmsTemplateCategory {
  String get value {
    return switch (this) {
      AdminSmsTemplateCategory.campaign => 'campaign',
      AdminSmsTemplateCategory.info => 'info',
      AdminSmsTemplateCategory.invitation => 'invitation',
      AdminSmsTemplateCategory.order => 'order',
      AdminSmsTemplateCategory.quote => 'quote',
    };
  }

  String get labelKey {
    return switch (this) {
      AdminSmsTemplateCategory.campaign => 'sms.template.category.campaign',
      AdminSmsTemplateCategory.info => 'sms.template.category.info',
      AdminSmsTemplateCategory.invitation => 'sms.template.category.invitation',
      AdminSmsTemplateCategory.order => 'sms.template.category.order',
      AdminSmsTemplateCategory.quote => 'sms.template.category.quote',
    };
  }
}

class AdminSmsTemplateVariable {
  const AdminSmsTemplateVariable({
    required this.token,
    required this.labelKey,
    this.icon = Symbols.data_object_outlined,
  });

  final String token;
  final String labelKey;
  final IconData icon;
}

class AdminSmsTemplate {
  const AdminSmsTemplate({
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
  final AdminSmsTemplateCategory category;
  final int variableCount;
  final bool ready;
  final bool active;
  final DateTime updatedAt;
  final String subject;
  final String previewText;
  final String body;

  AdminSmsTemplate copyWith({
    String? nameKey,
    AdminSmsTemplateCategory? category,
    int? variableCount,
    bool? ready,
    bool? active,
    DateTime? updatedAt,
    String? subject,
    String? previewText,
    String? body,
  }) {
    return AdminSmsTemplate(
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

const smsTemplateFilterAll = 'all';

const adminSmsTemplateMemberVariables = <AdminSmsTemplateVariable>[
  AdminSmsTemplateVariable(
    token: '{{uye_adi}}',
    labelKey: 'sms.template.variable.memberName',
    icon: Symbols.person_outline,
  ),
  AdminSmsTemplateVariable(
    token: '{{uye_kullanici_adi}}',
    labelKey: 'sms.template.variable.username',
    icon: Symbols.alternate_email,
  ),
  AdminSmsTemplateVariable(
    token: '{{uye_eposta}}',
    labelKey: 'sms.template.variable.email',
    icon: Symbols.mail_outline,
  ),
  AdminSmsTemplateVariable(
    token: '{{uye_telefon}}',
    labelKey: 'sms.template.variable.phone',
    icon: Symbols.phone_outlined,
  ),
  AdminSmsTemplateVariable(
    token: '{{uye_rol}}',
    labelKey: 'sms.template.variable.role',
    icon: Symbols.verified_user_outlined,
  ),
  AdminSmsTemplateVariable(
    token: '{{uye_kayit_tarihi}}',
    labelKey: 'sms.template.variable.registerDate',
    icon: Symbols.calendar_today_outlined,
  ),
  AdminSmsTemplateVariable(
    token: '{{uye_son_giris}}',
    labelKey: 'sms.template.variable.lastLogin',
    icon: Symbols.schedule_outlined,
  ),
  AdminSmsTemplateVariable(
    token: '{{uye_profil_linki}}',
    labelKey: 'sms.template.variable.profileUrl',
    icon: Symbols.link_outlined,
  ),
  AdminSmsTemplateVariable(
    token: '{{uye_avatar}}',
    labelKey: 'sms.template.variable.avatar',
    icon: Symbols.image_outlined,
  ),
  AdminSmsTemplateVariable(
    token: '{{uye_onay_durumu}}',
    labelKey: 'sms.template.variable.approvalStatus',
    icon: Symbols.fact_check_outlined,
  ),
  AdminSmsTemplateVariable(
    token: '{{uye_odul_puani}}',
    labelKey: 'sms.template.variable.rewardPoint',
    icon: Symbols.workspace_premium_outlined,
  ),
  AdminSmsTemplateVariable(
    token: '{{uye_abonelik_durumu}}',
    labelKey: 'sms.template.variable.subscriptionStatus',
    icon: Symbols.notifications_active_outlined,
  ),
];

Color adminSmsTemplateCategoryAccent(AdminSmsTemplateCategory category) {
  return switch (category) {
    AdminSmsTemplateCategory.campaign => AppColors.warmHorizon,
    AdminSmsTemplateCategory.info => AppColors.deepOcean,
    AdminSmsTemplateCategory.invitation => const Color(0xFF3B82F6),
    AdminSmsTemplateCategory.order => const Color(0xFF198754),
    AdminSmsTemplateCategory.quote => AppColors.actionRed,
  };
}
