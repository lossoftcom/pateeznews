import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

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
    this.icon = Icons.data_object_outlined,
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
    icon: Icons.person_outline,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_kullanici_adi}}',
    labelKey: 'mail.template.variable.username',
    icon: Icons.alternate_email,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_eposta}}',
    labelKey: 'mail.template.variable.email',
    icon: Icons.mail_outline,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_telefon}}',
    labelKey: 'mail.template.variable.phone',
    icon: Icons.phone_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_rol}}',
    labelKey: 'mail.template.variable.role',
    icon: Icons.verified_user_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_kayit_tarihi}}',
    labelKey: 'mail.template.variable.registerDate',
    icon: Icons.calendar_today_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_son_giris}}',
    labelKey: 'mail.template.variable.lastLogin',
    icon: Icons.schedule_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_profil_linki}}',
    labelKey: 'mail.template.variable.profileUrl',
    icon: Icons.link_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_avatar}}',
    labelKey: 'mail.template.variable.avatar',
    icon: Icons.image_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_onay_durumu}}',
    labelKey: 'mail.template.variable.approvalStatus',
    icon: Icons.fact_check_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_odul_puani}}',
    labelKey: 'mail.template.variable.rewardPoint',
    icon: Icons.workspace_premium_outlined,
  ),
  AdminMailTemplateVariable(
    token: '{{uye_abonelik_durumu}}',
    labelKey: 'mail.template.variable.subscriptionStatus',
    icon: Icons.notifications_active_outlined,
  ),
];

final sampleAdminMailTemplates = <AdminMailTemplate>[
  AdminMailTemplate(
    id: 501,
    nameKey: 'mail.template.sample.singleNews',
    category: AdminMailTemplateCategory.campaign,
    variableCount: 16,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 5, 7, 21),
    subject: '{{haber_basligi}}',
    previewText: 'mail.template.previewText',
    body: 'Sayin {{uye_adi}}, sizin icin one cikan haberleri hazirladik.',
  ),
  AdminMailTemplate(
    id: 502,
    nameKey: 'mail.template.sample.orderOffer',
    category: AdminMailTemplateCategory.quote,
    variableCount: 15,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 5, 7, 21),
    subject: 'Teklif bilgilendirmesi',
    previewText: 'mail.template.previewText',
    body: 'Sayin {{uye_adi}}, talebiniz icin hazirlanan teklif ekte.',
  ),
  AdminMailTemplate(
    id: 503,
    nameKey: 'mail.template.sample.specialOffer',
    category: AdminMailTemplateCategory.quote,
    variableCount: 17,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 20, 21),
    subject: 'Size ozel firsat',
    previewText: 'mail.template.previewText',
    body: '{{uye_adi}} icin hazirlanan ozel teklif.',
  ),
  AdminMailTemplate(
    id: 504,
    nameKey: 'mail.template.sample.priceOffer',
    category: AdminMailTemplateCategory.quote,
    variableCount: 20,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 20, 21),
    subject: 'Fiyat teklifi',
    previewText: 'mail.template.previewText',
    body: 'Guncel fiyat bilgileri {{uye_eposta}} adresine iletilmistir.',
  ),
  AdminMailTemplate(
    id: 505,
    nameKey: 'mail.template.sample.statusUpdate',
    category: AdminMailTemplateCategory.order,
    variableCount: 13,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 20, 21),
    subject: 'Durum guncellemesi',
    previewText: 'mail.template.previewText',
    body: '{{uye_adi}}, talebinizin son durumu guncellendi.',
  ),
  AdminMailTemplate(
    id: 506,
    nameKey: 'mail.template.sample.confirmation',
    category: AdminMailTemplateCategory.order,
    variableCount: 18,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 20, 21),
    subject: 'Onay bilgisi',
    previewText: 'mail.template.previewText',
    body: '{{uye_adi}} icin onay sureci tamamlandi.',
  ),
  AdminMailTemplate(
    id: 507,
    nameKey: 'mail.template.sample.eventInvite',
    category: AdminMailTemplateCategory.invitation,
    variableCount: 8,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 20, 21),
    subject: 'Etkinlik daveti',
    previewText: 'mail.template.previewText',
    body: '{{uye_adi}}, sizi etkinligimize davet ediyoruz.',
  ),
  AdminMailTemplate(
    id: 508,
    nameKey: 'mail.template.sample.partnerInvite',
    category: AdminMailTemplateCategory.invitation,
    variableCount: 9,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 20, 21),
    subject: 'Is ortakligi daveti',
    previewText: 'mail.template.previewText',
    body: '{{uye_adi}}, is ortakligi detaylarini paylasmak isteriz.',
  ),
  AdminMailTemplate(
    id: 509,
    nameKey: 'mail.template.sample.memberWelcome',
    category: AdminMailTemplateCategory.info,
    variableCount: 12,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 18, 18, 30),
    subject: 'Hos geldiniz {{uye_adi}}',
    previewText: 'mail.template.previewText',
    body: 'Pateeznews hesabiniz basariyla olusturuldu.',
  ),
  AdminMailTemplate(
    id: 510,
    nameKey: 'mail.template.sample.memberApproval',
    category: AdminMailTemplateCategory.info,
    variableCount: 10,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 18, 18, 30),
    subject: 'Uyelik onayi',
    previewText: 'mail.template.previewText',
    body: '{{uye_onay_durumu}} durumu guncellendi.',
  ),
  AdminMailTemplate(
    id: 511,
    nameKey: 'mail.template.sample.rewardNotice',
    category: AdminMailTemplateCategory.info,
    variableCount: 11,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 17, 14, 15),
    subject: 'Odul puani bildirimi',
    previewText: 'mail.template.previewText',
    body: '{{uye_odul_puani}} puaniniz hesabinizda.',
  ),
  AdminMailTemplate(
    id: 512,
    nameKey: 'mail.template.sample.subscriptionNotice',
    category: AdminMailTemplateCategory.info,
    variableCount: 9,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 17, 14, 15),
    subject: 'Abonelik bildirimi',
    previewText: 'mail.template.previewText',
    body: '{{uye_abonelik_durumu}} bilgisi guncellendi.',
  ),
  AdminMailTemplate(
    id: 513,
    nameKey: 'mail.template.sample.dailyDigest',
    category: AdminMailTemplateCategory.campaign,
    variableCount: 14,
    ready: true,
    active: false,
    updatedAt: DateTime(2026, 4, 16, 12),
    subject: 'Gunluk ozet',
    previewText: 'mail.template.previewText',
    body: '{{uye_adi}}, bugunun haber ozetini inceleyin.',
  ),
  AdminMailTemplate(
    id: 514,
    nameKey: 'mail.template.sample.breakingNews',
    category: AdminMailTemplateCategory.campaign,
    variableCount: 13,
    ready: false,
    active: true,
    updatedAt: DateTime(2026, 4, 15, 16, 45),
    subject: 'Son dakika',
    previewText: 'mail.template.previewText',
    body: 'Son dakika haberleri {{uye_eposta}} icin hazir.',
  ),
  AdminMailTemplate(
    id: 515,
    nameKey: 'mail.template.sample.accountReminder',
    category: AdminMailTemplateCategory.info,
    variableCount: 7,
    ready: false,
    active: true,
    updatedAt: DateTime(2026, 4, 14, 11, 5),
    subject: 'Hesap hatirlatmasi',
    previewText: 'mail.template.previewText',
    body: '{{uye_kullanici_adi}} hesabiniz icin hatirlatma.',
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
