import 'package:flutter/material.dart';

class UserMetric {
  const UserMetric({
    required this.title,
    required this.value,
    required this.change,
    required this.description,
    required this.icon,
    required this.iconColor,
    this.centerContent = false,
  });

  final String title;
  final String value;
  final String change;
  final String description;
  final IconData icon;
  final Color iconColor;
  final bool centerContent;
}

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.rowNumber,
    required this.fullName,
    required this.username,
    required this.email,
    required this.city,
    required this.authProvider,
    required this.role,
    required this.roleLabel,
    required this.status,
    required this.rewardEnabled,
    required this.createdAt,
    required this.avatarUrl,
  });

  final String id;
  final int rowNumber;
  final String fullName;
  final String username;
  final String email;
  final String city;
  final String authProvider;
  final String role;
  final String roleLabel;
  final String status;
  final bool rewardEnabled;
  final DateTime? createdAt;
  final String avatarUrl;

  String get displayName {
    final value = fullName.trim();
    if (value.isNotEmpty) return value;
    final fallback = username.trim();
    if (fallback.isNotEmpty) return fallback;
    return email;
  }

  String get displayUsername {
    final value = username.trim();
    return value.isEmpty ? '-' : '@$value';
  }

  String get createdDate {
    final value = createdAt;
    if (value == null) return '-';
    final local = value.toLocal();
    return '${_two(local.day)}.${_two(local.month)}.${local.year}';
  }

  String get createdTime {
    final value = createdAt;
    if (value == null) return '';
    final local = value.toLocal();
    return '${_two(local.hour)}:${_two(local.minute)}';
  }

  String get initials {
    final source = displayName.trim().isEmpty ? email : displayName;
    final words = source
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return source.trim().isEmpty ? 'P' : source.trim()[0].toUpperCase();
  }

  bool get active => status == 'Aktif';

  String get authProviderLabel => authProviderLabelFor(authProvider);
}

String authProviderLabelFor(String provider) {
  final value = provider.trim().toLowerCase();
  return switch (value) {
    'google' => 'Google',
    'apple' => 'Apple',
    'facebook' => 'Facebook',
    'x' || 'twitter' => 'X / Twitter',
    'email' || '' => 'E-posta',
    _ => provider.trim(),
  };
}

class AdminUserRole {
  const AdminUserRole({
    required this.id,
    required this.name,
    required this.label,
    this.description = '',
    this.color = '#2C3E50',
  });

  final String id;
  final String name;
  final String label;
  final String description;
  final String color;
}

class UserMetrics {
  const UserMetrics({
    required this.total,
    required this.rewardEnabled,
    required this.active,
    required this.pending,
  });

  final int total;
  final int rewardEnabled;
  final int active;
  final int pending;
}

class UsersPageResult {
  const UsersPageResult({required this.users, required this.totalCount});

  final List<ManagedUser> users;
  final int totalCount;
}

class UserFormData {
  const UserFormData({
    required this.fullName,
    required this.username,
    required this.email,
    required this.city,
    required this.role,
    required this.status,
    required this.rewardEnabled,
    required this.password,
  });

  final String fullName;
  final String username;
  final String email;
  final String city;
  final String role;
  final String status;
  final bool rewardEnabled;
  final String password;
}

class AdminPermission {
  const AdminPermission({
    required this.id,
    required this.key,
    required this.label,
    required this.groupName,
    required this.description,
  });

  final String id;
  final String key;
  final String label;
  final String groupName;
  final String description;
}

class ManagedRole {
  const ManagedRole({
    required this.id,
    required this.rowNumber,
    required this.name,
    required this.label,
    required this.description,
    required this.color,
    required this.memberCount,
    required this.permissionKeys,
    required this.permissionLabels,
    required this.createdAt,
  });

  final String id;
  final int rowNumber;
  final String name;
  final String label;
  final String description;
  final String color;
  final int memberCount;
  final List<String> permissionKeys;
  final List<String> permissionLabels;
  final DateTime? createdAt;

  bool get systemLocked => name == 'admin';

  String get slug => '@$name';

  String get displayDescription {
    final value = description.trim();
    return value.isEmpty ? 'Açıklama belirtilmemiş.' : value;
  }

  String get initial {
    final source = label.trim().isEmpty ? name : label.trim();
    return source.isEmpty ? 'R' : source[0].toUpperCase();
  }
}

class RolesPermissionsPageResult {
  const RolesPermissionsPageResult({
    required this.roles,
    required this.permissions,
    required this.totalCount,
  });

  final List<ManagedRole> roles;
  final List<AdminPermission> permissions;
  final int totalCount;
}

class RoleFormData {
  const RoleFormData({
    required this.name,
    required this.label,
    required this.description,
    required this.color,
  });

  final String name;
  final String label;
  final String description;
  final String color;
}

String roleLabelFor(String role, List<AdminUserRole> roles) {
  for (final item in roles) {
    if (item.name == role) return item.label;
  }
  return switch (role) {
    'admin' => 'Süper Yönetici',
    'editor' => 'Editör',
    'moderator' => 'Moderatör',
    'member' => 'Standart Üye',
    _ => role,
  };
}

String _two(int value) => value.toString().padLeft(2, '0');
