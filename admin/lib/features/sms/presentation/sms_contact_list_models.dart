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
      AdminContactImportSource.csv => 'sms.contacts.source.csv',
      AdminContactImportSource.excel => 'sms.contacts.source.excel',
    };
  }

  String get shortLabelKey {
    return switch (this) {
      AdminContactImportSource.csv => 'sms.contacts.source.csvShort',
      AdminContactImportSource.excel => 'sms.contacts.source.excelShort',
    };
  }

  IconData get icon {
    return switch (this) {
      AdminContactImportSource.csv => Icons.table_chart_outlined,
      AdminContactImportSource.excel => Icons.grid_on_outlined,
    };
  }
}

class AdminSmsContactList {
  const AdminSmsContactList({
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

  AdminSmsContactList copyWith({
    String? name,
    String? description,
    int? contactCount,
    bool? syncEnabled,
    bool? active,
    DateTime? createdAt,
    AdminContactImportSource? source,
  }) {
    return AdminSmsContactList(
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


Color contactListSourceColor(AdminContactImportSource source) {
  return switch (source) {
    AdminContactImportSource.csv => AppColors.deepOcean,
    AdminContactImportSource.excel => const Color(0xFF198754),
  };
}
