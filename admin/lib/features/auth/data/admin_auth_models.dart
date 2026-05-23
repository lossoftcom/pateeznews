class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.role,
    required this.aud,
    required this.userMetadata,
    required this.appMetadata,
  });

  final String id;
  final String? email;
  final String? role;
  final String? aud;
  final Map<String, Object?> userMetadata;
  final Map<String, Object?> appMetadata;

  factory AdminUser.fromJson(Map<String, Object?> json) {
    return AdminUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString(),
      role: json['role']?.toString(),
      aud: json['aud']?.toString(),
      userMetadata: _asObjectMap(json['user_metadata']),
      appMetadata: _asObjectMap(json['app_metadata']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'aud': aud,
      'user_metadata': userMetadata,
      'app_metadata': appMetadata,
    };
  }
}

class AdminSession {
  const AdminSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final int expiresAt;
  final AdminUser user;

  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt <= now;
  }

  factory AdminSession.fromJson(Map<String, Object?> json) {
    final userJson = _asObjectMap(json['user']);

    return AdminSession(
      accessToken: json['access_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      expiresAt: _asInt(json['expires_at']),
      user: AdminUser.fromJson(userJson),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'expires_at': expiresAt,
      'user': user.toJson(),
    };
  }
}

class AdminProfile {
  const AdminProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.role,
    required this.email,
  });

  final String id;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final String? role;
  final String? email;

  String get displayName {
    for (final value in [fullName, username, email]) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return 'Pateeznews admin';
  }

  String get initials {
    final words = displayName
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return displayName.trim().isEmpty
        ? 'P'
        : displayName.trim()[0].toUpperCase();
  }

  factory AdminProfile.fromJson(Map<String, Object?> json) {
    return AdminProfile(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString(),
      fullName: json['full_name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      role: json['role']?.toString(),
      email: json['email']?.toString(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'role': role,
      'email': email,
    };
  }
}

class AdminAuthState {
  const AdminAuthState({required this.session, required this.profile});

  final AdminSession session;
  final AdminProfile? profile;
}

Map<String, Object?> _asObjectMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map(
      (key, nestedValue) => MapEntry(key.toString(), nestedValue),
    );
  }
  return const {};
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
