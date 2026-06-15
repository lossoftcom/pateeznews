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
    this.isImage = false,
  });

  final String token;
  final String labelKey;
  final IconData icon;

  /// Görsel değişkeni mi? (editöre `mj-image src="{{...}}"` olarak eklenir)
  final bool isImage;
}

/// Editör sol panelinde bir başlık altında gruplanan değişken kümesi.
class AdminMailTemplateVariableGroup {
  const AdminMailTemplateVariableGroup({
    required this.titleKey,
    required this.icon,
    required this.accent,
    required this.variables,
  });

  final String titleKey;
  final IconData icon;
  final Color accent;
  final List<AdminMailTemplateVariable> variables;
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
    this.contentMjml = '',
    this.designJson = '',
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
  final String contentMjml;
  final String designJson;

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
    String? contentMjml,
    String? designJson,
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
      contentMjml: contentMjml ?? this.contentMjml,
      designJson: designJson ?? this.designJson,
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
    isImage: true,
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

/// Aboneler modülü alanları (bülten/haber özeti mailleri için).
const adminMailTemplateSubscriberVariables = <AdminMailTemplateVariable>[
  AdminMailTemplateVariable(
    token: '{{abone_adi}}',
    labelKey: 'mail.template.variable.subscriberName',
    icon: Symbols.person_outline,
  ),
  AdminMailTemplateVariable(
    token: '{{abone_eposta}}',
    labelKey: 'mail.template.variable.subscriberEmail',
    icon: Symbols.mail_outline,
  ),
  AdminMailTemplateVariable(
    token: '{{abone_telefon}}',
    labelKey: 'mail.template.variable.subscriberPhone',
    icon: Symbols.phone_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{abone_durumu}}',
    labelKey: 'mail.template.variable.subscriberStatus',
    icon: Symbols.notifications_active_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{abone_kayit_tarihi}}',
    labelKey: 'mail.template.variable.subscriberDate',
    icon: Symbols.calendar_today_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{abone_sehir}}',
    labelKey: 'mail.template.variable.subscriberCity',
    icon: Symbols.location_on_rounded,
  ),
  AdminMailTemplateVariable(
    token: '{{abone_dil}}',
    labelKey: 'mail.template.variable.subscriberLanguage',
    icon: Symbols.language,
  ),
  AdminMailTemplateVariable(
    token: '{{abone_kaynak}}',
    labelKey: 'mail.template.variable.subscriberSource',
  ),
];

/// Bülten & sistem alanları (kod, link, logo, tarih vb. — tüm mailler).
const adminMailTemplateSystemVariables = <AdminMailTemplateVariable>[
  AdminMailTemplateVariable(
    token: '{{site_adi}}',
    labelKey: 'mail.template.variable.siteName',
    icon: Symbols.newspaper,
  ),
  AdminMailTemplateVariable(
    token: '{{site_logo}}',
    labelKey: 'mail.template.variable.siteLogo',
    icon: Symbols.image_outlined,
    isImage: true,
  ),
  AdminMailTemplateVariable(
    token: '{{site_url}}',
    labelKey: 'mail.template.variable.siteUrl',
    icon: Symbols.link_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{dogrulama_kodu}}',
    labelKey: 'mail.template.variable.verificationCode',
    icon: Symbols.verified_user_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{kod_gecerlilik}}',
    labelKey: 'mail.template.variable.codeValidity',
    icon: Symbols.schedule_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{sifre_sifirlama_linki}}',
    labelKey: 'mail.template.variable.resetLink',
    icon: Symbols.link_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{giris_linki}}',
    labelKey: 'mail.template.variable.loginLink',
    icon: Symbols.link_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{abonelikten_cik}}',
    labelKey: 'mail.template.variable.unsubscribeLink',
    icon: Symbols.link_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{destek_eposta}}',
    labelKey: 'mail.template.variable.supportEmail',
    icon: Symbols.support_agent_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{tarih}}',
    labelKey: 'mail.template.variable.currentDate',
    icon: Symbols.today_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{yil}}',
    labelKey: 'mail.template.variable.currentYear',
    icon: Symbols.calendar_today_outlined,
  ),
];

/// Haber içeriği alanları (haber özeti maillerinde kart oluşturmak için).
const adminMailTemplateNewsVariables = <AdminMailTemplateVariable>[
  AdminMailTemplateVariable(
    token: '{{haber_kategori}}',
    labelKey: 'mail.template.variable.newsCategory',
    icon: Symbols.campaign_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{haber_basligi}}',
    labelKey: 'mail.template.variable.newsTitle',
    icon: Symbols.newspaper,
  ),
  AdminMailTemplateVariable(
    token: '{{haber_ozeti}}',
    labelKey: 'mail.template.variable.newsSummary',
    icon: Symbols.article,
  ),
  AdminMailTemplateVariable(
    token: '{{haber_gorseli}}',
    labelKey: 'mail.template.variable.newsImage',
    icon: Symbols.image_outlined,
    isImage: true,
  ),
  AdminMailTemplateVariable(
    token: '{{haber_linki}}',
    labelKey: 'mail.template.variable.newsLink',
    icon: Symbols.link_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{haber_tarihi}}',
    labelKey: 'mail.template.variable.newsDate',
    icon: Symbols.calendar_today_outlined,
  ),
];

/// Editör sol panelindeki tüm değişken grupları (sırasıyla gösterilir).
const adminMailTemplateVariableGroups = <AdminMailTemplateVariableGroup>[
  AdminMailTemplateVariableGroup(
    titleKey: 'mail.template.editor.memberInfo',
    icon: Symbols.group_outlined,
    accent: Color(0xFF2F80ED),
    variables: adminMailTemplateMemberVariables,
  ),
  AdminMailTemplateVariableGroup(
    titleKey: 'mail.template.editor.subscriberInfo',
    icon: Symbols.notifications_active_outlined,
    accent: Color(0xFF12B886),
    variables: adminMailTemplateSubscriberVariables,
  ),
  AdminMailTemplateVariableGroup(
    titleKey: 'mail.template.editor.systemInfo',
    icon: Symbols.campaign_outlined,
    accent: AppColors.warmHorizon,
    variables: adminMailTemplateSystemVariables,
  ),
  AdminMailTemplateVariableGroup(
    titleKey: 'mail.template.editor.newsInfo',
    icon: Symbols.newspaper,
    accent: AppColors.actionRed,
    variables: adminMailTemplateNewsVariables,
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
