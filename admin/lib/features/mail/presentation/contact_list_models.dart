import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

enum AdminContactImportSource { csv, excel, subscribers }

extension AdminContactImportSourceData on AdminContactImportSource {
  String get value {
    return switch (this) {
      AdminContactImportSource.csv => 'csv',
      AdminContactImportSource.excel => 'excel',
      AdminContactImportSource.subscribers => 'newsletter',
    };
  }

  String get labelKey {
    return switch (this) {
      AdminContactImportSource.csv => 'mail.contacts.source.csv',
      AdminContactImportSource.excel => 'mail.contacts.source.excel',
      AdminContactImportSource.subscribers =>
        'mail.contacts.source.subscribers',
    };
  }

  String get shortLabelKey {
    return switch (this) {
      AdminContactImportSource.csv => 'mail.contacts.source.csvShort',
      AdminContactImportSource.excel => 'mail.contacts.source.excelShort',
      AdminContactImportSource.subscribers =>
        'mail.contacts.source.subscribersShort',
    };
  }

  IconData get icon {
    return switch (this) {
      AdminContactImportSource.csv => Symbols.table_chart_outlined,
      AdminContactImportSource.excel => Symbols.grid_on_outlined,
      AdminContactImportSource.subscribers => Symbols.groups_outlined,
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

class AdminContactImportRow {
  const AdminContactImportRow({
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
  });

  final String email;
  final String firstName;
  final String lastName;
  final String phone;

  Map<String, String> toJson() {
    return {
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
    };
  }
}

class AdminMailContact {
  const AdminMailContact({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.active,
    required this.createdAt,
  });

  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final bool active;
  final DateTime createdAt;

  String get fullName => [
    firstName,
    lastName,
  ].where((value) => value.trim().isNotEmpty).join(' ').trim();
}

Color contactListSourceColor(AdminContactImportSource source) {
  return switch (source) {
    AdminContactImportSource.csv => AppColors.deepOcean,
    AdminContactImportSource.excel => const Color(0xFF198754),
    AdminContactImportSource.subscribers => const Color(0xFF2563EB),
  };
}
