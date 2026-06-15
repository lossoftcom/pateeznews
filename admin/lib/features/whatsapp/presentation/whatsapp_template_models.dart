import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

enum AdminWhatsappTemplateCategory { campaign, info, invitation, order, quote }

extension AdminWhatsappTemplateCategoryData on AdminWhatsappTemplateCategory {
  String get value {
    return switch (this) {
      AdminWhatsappTemplateCategory.campaign => 'campaign',
      AdminWhatsappTemplateCategory.info => 'info',
      AdminWhatsappTemplateCategory.invitation => 'invitation',
      AdminWhatsappTemplateCategory.order => 'order',
      AdminWhatsappTemplateCategory.quote => 'quote',
    };
  }

  String get labelKey {
    return switch (this) {
      AdminWhatsappTemplateCategory.campaign =>
        'whatsapp.template.category.campaign',
      AdminWhatsappTemplateCategory.info => 'whatsapp.template.category.info',
      AdminWhatsappTemplateCategory.invitation =>
        'whatsapp.template.category.invitation',
      AdminWhatsappTemplateCategory.order => 'whatsapp.template.category.order',
      AdminWhatsappTemplateCategory.quote => 'whatsapp.template.category.quote',
    };
  }
}

class AdminWhatsappTemplateVariable {
  const AdminWhatsappTemplateVariable({
    required this.token,
    required this.labelKey,
    this.icon = Symbols.data_object_outlined,
  });

  final String token;
  final String labelKey;
  final IconData icon;
}

class AdminWhatsappTemplate {
  const AdminWhatsappTemplate({
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
  final AdminWhatsappTemplateCategory category;
  final int variableCount;
  final bool ready;
  final bool active;
  final DateTime updatedAt;
  final String subject;
  final String previewText;
  final String body;

  AdminWhatsappTemplate copyWith({
    String? nameKey,
    AdminWhatsappTemplateCategory? category,
    int? variableCount,
    bool? ready,
    bool? active,
    DateTime? updatedAt,
    String? subject,
    String? previewText,
    String? body,
  }) {
    return AdminWhatsappTemplate(
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

const whatsappTemplateFilterAll = 'all';

const adminWhatsappTemplateMemberVariables = <AdminWhatsappTemplateVariable>[
  AdminWhatsappTemplateVariable(
    token: '{{uye_adi}}',
    labelKey: 'whatsapp.template.variable.memberName',
    icon: Symbols.person_outline,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_kullanici_adi}}',
    labelKey: 'whatsapp.template.variable.username',
    icon: Symbols.alternate_email,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_eposta}}',
    labelKey: 'whatsapp.template.variable.email',
    icon: Symbols.mail_outline,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_telefon}}',
    labelKey: 'whatsapp.template.variable.phone',
    icon: Symbols.phone_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_rol}}',
    labelKey: 'whatsapp.template.variable.role',
    icon: Symbols.verified_user_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_kayit_tarihi}}',
    labelKey: 'whatsapp.template.variable.registerDate',
    icon: Symbols.calendar_today_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_son_giris}}',
    labelKey: 'whatsapp.template.variable.lastLogin',
    icon: Symbols.schedule_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_profil_linki}}',
    labelKey: 'whatsapp.template.variable.profileUrl',
    icon: Symbols.link_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_avatar}}',
    labelKey: 'whatsapp.template.variable.avatar',
    icon: Symbols.image_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_onay_durumu}}',
    labelKey: 'whatsapp.template.variable.approvalStatus',
    icon: Symbols.fact_check_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_odul_puani}}',
    labelKey: 'whatsapp.template.variable.rewardPoint',
    icon: Symbols.workspace_premium_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_abonelik_durumu}}',
    labelKey: 'whatsapp.template.variable.subscriptionStatus',
    icon: Symbols.notifications_active_outlined,
  ),
];

Color adminWhatsappTemplateCategoryAccent(
  AdminWhatsappTemplateCategory category,
) {
  return switch (category) {
    AdminWhatsappTemplateCategory.campaign => AppColors.warmHorizon,
    AdminWhatsappTemplateCategory.info => AppColors.deepOcean,
    AdminWhatsappTemplateCategory.invitation => const Color(0xFF3B82F6),
    AdminWhatsappTemplateCategory.order => const Color(0xFF198754),
    AdminWhatsappTemplateCategory.quote => AppColors.actionRed,
  };
}
