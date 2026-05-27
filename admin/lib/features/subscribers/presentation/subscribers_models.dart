class AdminSubscriber {
  const AdminSubscriber({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.active,
    required this.createdAt,
    this.ipAddress = '',
    this.city = '',
    this.languageCode = 'tr',
    this.source = 'admin',
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final bool active;
  final DateTime createdAt;
  final String ipAddress;
  final String city;
  final String languageCode;
  final String source;

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  AdminSubscriber copyWith({
    String? fullName,
    String? email,
    String? phone,
    bool? active,
    DateTime? createdAt,
    String? ipAddress,
    String? city,
    String? languageCode,
    String? source,
  }) {
    return AdminSubscriber(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      ipAddress: ipAddress ?? this.ipAddress,
      city: city ?? this.city,
      languageCode: languageCode ?? this.languageCode,
      source: source ?? this.source,
    );
  }
}

class AdminSubscribersPageResult {
  const AdminSubscribersPageResult({
    required this.subscribers,
    required this.totalCount,
  });

  final List<AdminSubscriber> subscribers;
  final int totalCount;
}

class SubscriberFormData {
  const SubscriberFormData({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.active,
  });

  final String fullName;
  final String email;
  final String phone;
  final bool active;
}

final sampleAdminSubscribers = <AdminSubscriber>[
  AdminSubscriber(
    id: '801',
    fullName: 'Nasip Gündoğu',
    email: 'nasip@pateez.com',
    phone: '+90 555 010 20 26',
    active: true,
    createdAt: DateTime(2026, 5, 24, 13, 37),
  ),
  AdminSubscriber(
    id: '802',
    fullName: 'Pateez Haber',
    email: 'haber@pateeznews.com',
    phone: '+90 532 120 45 60',
    active: true,
    createdAt: DateTime(2026, 5, 23, 16, 18),
  ),
  AdminSubscriber(
    id: '803',
    fullName: 'Niğde Okuru',
    email: 'okur@example.com',
    phone: '+90 505 330 14 22',
    active: false,
    createdAt: DateTime(2026, 5, 22, 9, 45),
  ),
  AdminSubscriber(
    id: '804',
    fullName: 'Bülten Abonesi',
    email: 'bulten@example.com',
    phone: '+90 542 600 12 34',
    active: true,
    createdAt: DateTime(2026, 5, 21, 11, 5),
  ),
  AdminSubscriber(
    id: '805',
    fullName: 'Pasif Abone',
    email: 'pasif@example.com',
    phone: '+90 530 700 18 40',
    active: false,
    createdAt: DateTime(2026, 5, 18, 14, 30),
  ),
];
