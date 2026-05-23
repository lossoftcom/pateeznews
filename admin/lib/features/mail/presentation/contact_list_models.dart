import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum AdminContactImportSource { csv, excel }

extension AdminContactImportSourceData on AdminContactImportSource {
  String get value {
    return switch (this) {
      AdminContactImportSource.csv => 'csv',
      AdminContactImportSource.excel => 'excel',
    };
  }

  String get labelKey {
    return switch (this) {
      AdminContactImportSource.csv => 'mail.contacts.source.csv',
      AdminContactImportSource.excel => 'mail.contacts.source.excel',
    };
  }

  String get shortLabelKey {
    return switch (this) {
      AdminContactImportSource.csv => 'mail.contacts.source.csvShort',
      AdminContactImportSource.excel => 'mail.contacts.source.excelShort',
    };
  }

  IconData get icon {
    return switch (this) {
      AdminContactImportSource.csv => Icons.table_chart_outlined,
      AdminContactImportSource.excel => Icons.grid_on_outlined,
    };
  }
}

class AdminContactList {
  const AdminContactList({
    required this.id,
    required this.name,
    required this.description,
    required this.contactCount,
    required this.syncEnabled,
    required this.active,
    required this.createdAt,
    required this.source,
  });

  final int id;
  final String name;
  final String description;
  final int contactCount;
  final bool syncEnabled;
  final bool active;
  final DateTime createdAt;
  final AdminContactImportSource source;

  AdminContactList copyWith({
    String? name,
    String? description,
    int? contactCount,
    bool? syncEnabled,
    bool? active,
    DateTime? createdAt,
    AdminContactImportSource? source,
  }) {
    return AdminContactList(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      contactCount: contactCount ?? this.contactCount,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
    );
  }
}

final sampleAdminContactLists = <AdminContactList>[
  AdminContactList(
    id: 701,
    name: 'Aktif Okurlar',
    description: 'Son 30 gunde haber bulteni acan uyeler',
    contactCount: 1280,
    syncEnabled: false,
    active: true,
    createdAt: DateTime(2026, 5, 23, 12, 20),
    source: AdminContactImportSource.csv,
  ),
  AdminContactList(
    id: 702,
    name: 'Gunluk Bulten',
    description: 'Gundem ve son dakika aboneleri',
    contactCount: 2100,
    syncEnabled: false,
    active: true,
    createdAt: DateTime(2026, 5, 22, 16, 45),
    source: AdminContactImportSource.excel,
  ),
  AdminContactList(
    id: 703,
    name: 'Reklamverenler',
    description: 'Reklam teklifleri icin hedef liste',
    contactCount: 96,
    syncEnabled: false,
    active: true,
    createdAt: DateTime(2026, 5, 21, 10, 30),
    source: AdminContactImportSource.csv,
  ),
  AdminContactList(
    id: 704,
    name: 'Etkinlik Takipcileri',
    description: 'Yerel etkinlik duyurularini alan uyeler',
    contactCount: 740,
    syncEnabled: false,
    active: false,
    createdAt: DateTime(2026, 5, 19, 9, 10),
    source: AdminContactImportSource.excel,
  ),
];

Color contactListSourceColor(AdminContactImportSource source) {
  return switch (source) {
    AdminContactImportSource.csv => AppColors.deepOcean,
    AdminContactImportSource.excel => const Color(0xFF198754),
  };
}
