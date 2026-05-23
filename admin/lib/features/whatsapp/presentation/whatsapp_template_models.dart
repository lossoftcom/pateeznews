import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

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
    this.icon = Icons.data_object_outlined,
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
    icon: Icons.person_outline,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_kullanici_adi}}',
    labelKey: 'whatsapp.template.variable.username',
    icon: Icons.alternate_email,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_eposta}}',
    labelKey: 'whatsapp.template.variable.email',
    icon: Icons.mail_outline,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_telefon}}',
    labelKey: 'whatsapp.template.variable.phone',
    icon: Icons.phone_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_rol}}',
    labelKey: 'whatsapp.template.variable.role',
    icon: Icons.verified_user_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_kayit_tarihi}}',
    labelKey: 'whatsapp.template.variable.registerDate',
    icon: Icons.calendar_today_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_son_giris}}',
    labelKey: 'whatsapp.template.variable.lastLogin',
    icon: Icons.schedule_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_profil_linki}}',
    labelKey: 'whatsapp.template.variable.profileUrl',
    icon: Icons.link_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_avatar}}',
    labelKey: 'whatsapp.template.variable.avatar',
    icon: Icons.image_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_onay_durumu}}',
    labelKey: 'whatsapp.template.variable.approvalStatus',
    icon: Icons.fact_check_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_odul_puani}}',
    labelKey: 'whatsapp.template.variable.rewardPoint',
    icon: Icons.workspace_premium_outlined,
  ),
  AdminWhatsappTemplateVariable(
    token: '{{uye_abonelik_durumu}}',
    labelKey: 'whatsapp.template.variable.subscriptionStatus',
    icon: Icons.notifications_active_outlined,
  ),
];

final sampleAdminWhatsappTemplates = <AdminWhatsappTemplate>[
  AdminWhatsappTemplate(
    id: 501,
    nameKey: 'whatsapp.template.sample.singleNews',
    category: AdminWhatsappTemplateCategory.campaign,
    variableCount: 16,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 5, 7, 21),
    subject: '{{haber_basligi}}',
    previewText: 'whatsapp.template.previewText',
    body: 'Sayin {{uye_adi}}, sizin icin one cikan haberleri hazirladik.',
  ),
  AdminWhatsappTemplate(
    id: 502,
    nameKey: 'whatsapp.template.sample.orderOffer',
    category: AdminWhatsappTemplateCategory.quote,
    variableCount: 15,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 5, 7, 21),
    subject: 'Teklif bilgilendirmesi',
    previewText: 'whatsapp.template.previewText',
    body: 'Sayin {{uye_adi}}, talebiniz icin hazirlanan teklif ekte.',
  ),
  AdminWhatsappTemplate(
    id: 503,
    nameKey: 'whatsapp.template.sample.specialOffer',
    category: AdminWhatsappTemplateCategory.quote,
    variableCount: 17,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 20, 21),
    subject: 'Size ozel firsat',
    previewText: 'whatsapp.template.previewText',
    body: '{{uye_adi}} icin hazirlanan ozel teklif.',
  ),
  AdminWhatsappTemplate(
    id: 504,
    nameKey: 'whatsapp.template.sample.priceOffer',
    category: AdminWhatsappTemplateCategory.quote,
    variableCount: 20,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 20, 21),
    subject: 'Fiyat teklifi',
    previewText: 'whatsapp.template.previewText',
    body: 'Guncel fiyat bilgileri {{uye_eposta}} adresine iletilmistir.',
  ),
  AdminWhatsappTemplate(
    id: 505,
    nameKey: 'whatsapp.template.sample.statusUpdate',
    category: AdminWhatsappTemplateCategory.order,
    variableCount: 13,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 20, 21),
    subject: 'Durum guncellemesi',
    previewText: 'whatsapp.template.previewText',
    body: '{{uye_adi}}, talebinizin son durumu guncellendi.',
  ),
  AdminWhatsappTemplate(
    id: 506,
    nameKey: 'whatsapp.template.sample.confirmation',
    category: AdminWhatsappTemplateCategory.order,
    variableCount: 18,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 20, 21),
    subject: 'Onay bilgisi',
    previewText: 'whatsapp.template.previewText',
    body: '{{uye_adi}} icin onay sureci tamamlandi.',
  ),
  AdminWhatsappTemplate(
    id: 507,
    nameKey: 'whatsapp.template.sample.eventInvite',
    category: AdminWhatsappTemplateCategory.invitation,
    variableCount: 8,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 20, 21),
    subject: 'Etkinlik daveti',
    previewText: 'whatsapp.template.previewText',
    body: '{{uye_adi}}, sizi etkinligimize davet ediyoruz.',
  ),
  AdminWhatsappTemplate(
    id: 508,
    nameKey: 'whatsapp.template.sample.partnerInvite',
    category: AdminWhatsappTemplateCategory.invitation,
    variableCount: 9,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 20, 21),
    subject: 'Is ortakligi daveti',
    previewText: 'whatsapp.template.previewText',
    body: '{{uye_adi}}, is ortakligi detaylarini paylasmak isteriz.',
  ),
  AdminWhatsappTemplate(
    id: 509,
    nameKey: 'whatsapp.template.sample.memberWelcome',
    category: AdminWhatsappTemplateCategory.info,
    variableCount: 12,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 18, 18, 30),
    subject: 'Hos geldiniz {{uye_adi}}',
    previewText: 'whatsapp.template.previewText',
    body: 'Pateeznews hesabiniz basariyla olusturuldu.',
  ),
  AdminWhatsappTemplate(
    id: 510,
    nameKey: 'whatsapp.template.sample.memberApproval',
    category: AdminWhatsappTemplateCategory.info,
    variableCount: 10,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 18, 18, 30),
    subject: 'Uyelik onayi',
    previewText: 'whatsapp.template.previewText',
    body: '{{uye_onay_durumu}} durumu guncellendi.',
  ),
  AdminWhatsappTemplate(
    id: 511,
    nameKey: 'whatsapp.template.sample.rewardNotice',
    category: AdminWhatsappTemplateCategory.info,
    variableCount: 11,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 17, 14, 15),
    subject: 'Odul puani bildirimi',
    previewText: 'whatsapp.template.previewText',
    body: '{{uye_odul_puani}} puaniniz hesabinizda.',
  ),
  AdminWhatsappTemplate(
    id: 512,
    nameKey: 'whatsapp.template.sample.subscriptionNotice',
    category: AdminWhatsappTemplateCategory.info,
    variableCount: 9,
    ready: true,
    active: true,
    updatedAt: DateTime(2026, 4, 17, 14, 15),
    subject: 'Abonelik bildirimi',
    previewText: 'whatsapp.template.previewText',
    body: '{{uye_abonelik_durumu}} bilgisi guncellendi.',
  ),
  AdminWhatsappTemplate(
    id: 513,
    nameKey: 'whatsapp.template.sample.dailyDigest',
    category: AdminWhatsappTemplateCategory.campaign,
    variableCount: 14,
    ready: true,
    active: false,
    updatedAt: DateTime(2026, 4, 16, 12),
    subject: 'Gunluk ozet',
    previewText: 'whatsapp.template.previewText',
    body: '{{uye_adi}}, bugunun haber ozetini inceleyin.',
  ),
  AdminWhatsappTemplate(
    id: 514,
    nameKey: 'whatsapp.template.sample.breakingNews',
    category: AdminWhatsappTemplateCategory.campaign,
    variableCount: 13,
    ready: false,
    active: true,
    updatedAt: DateTime(2026, 4, 15, 16, 45),
    subject: 'Son dakika',
    previewText: 'whatsapp.template.previewText',
    body: 'Son dakika haberleri {{uye_eposta}} icin hazir.',
  ),
  AdminWhatsappTemplate(
    id: 515,
    nameKey: 'whatsapp.template.sample.accountReminder',
    category: AdminWhatsappTemplateCategory.info,
    variableCount: 7,
    ready: false,
    active: true,
    updatedAt: DateTime(2026, 4, 14, 11, 5),
    subject: 'Hesap hatirlatmasi',
    previewText: 'whatsapp.template.previewText',
    body: '{{uye_kullanici_adi}} hesabiniz icin hatirlatma.',
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
