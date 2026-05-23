class AdminNavigationMenu {
  const AdminNavigationMenu({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
  });

  final String id;
  final String code;
  final String name;
  final String description;

  factory AdminNavigationMenu.fromJson(Map<dynamic, dynamic> json) {
    return AdminNavigationMenu(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: decodeNavigationText(json['name']),
      description: decodeNavigationText(json['description']),
    );
  }
}

class AdminNavigationLanguage {
  const AdminNavigationLanguage({required this.code, required this.name});

  final String code;
  final String name;

  factory AdminNavigationLanguage.fromJson(Map<dynamic, dynamic> json) {
    return AdminNavigationLanguage(
      code: json['code']?.toString() ?? '',
      name: decodeNavigationText(json['name']),
    );
  }
}

class AdminNavigationItem {
  const AdminNavigationItem({
    required this.id,
    required this.menuId,
    required this.parentId,
    required this.label,
    required this.type,
    required this.value,
    required this.icon,
    required this.orderIndex,
    required this.isActive,
    required this.languageCode,
  });

  final String id;
  final String menuId;
  final String? parentId;
  final String label;
  final String type;
  final String value;
  final String icon;
  final int orderIndex;
  final bool isActive;
  final String languageCode;

  factory AdminNavigationItem.fromJson(Map<dynamic, dynamic> json) {
    final parentId = json['parent_id']?.toString().trim();
    return AdminNavigationItem(
      id: json['id']?.toString() ?? '',
      menuId: json['menu_id']?.toString() ?? '',
      parentId: parentId == null || parentId.isEmpty ? null : parentId,
      label: decodeNavigationText(json['label']),
      type: json['type']?.toString() ?? 'link',
      value: decodeNavigationText(json['value']),
      icon: json['icon']?.toString() ?? '',
      orderIndex: asNavigationInt(json['order_index']),
      isActive: json['is_active'] != false,
      languageCode: json['language_code']?.toString() ?? 'tr',
    );
  }

  AdminNavigationItem copyWith({int? orderIndex}) {
    return AdminNavigationItem(
      id: id,
      menuId: menuId,
      parentId: parentId,
      label: label,
      type: type,
      value: value,
      icon: icon,
      orderIndex: orderIndex ?? this.orderIndex,
      isActive: isActive,
      languageCode: languageCode,
    );
  }

  String get typeKey => 'navigation.type.$type';
}

class NavigationItemFormData {
  const NavigationItemFormData({
    required this.label,
    required this.type,
    required this.value,
    required this.icon,
    required this.parentId,
    required this.languageCode,
  });

  final String label;
  final String type;
  final String value;
  final String icon;
  final String? parentId;
  final String languageCode;
}

class AdminNavigationInitialData {
  const AdminNavigationInitialData({
    required this.menus,
    required this.languages,
  });

  final List<AdminNavigationMenu> menus;
  final List<AdminNavigationLanguage> languages;
}

String decodeNavigationText(Object? value) {
  return decodeNavigationHtmlEntities(
    value?.toString() ?? '',
  ).replaceAll('\u00a0', ' ').trim();
}

String decodeNavigationHtmlEntities(String input) {
  const entities = {
    'amp': '&',
    'apos': "'",
    'Ccedil': 'Ç',
    'ccedil': 'ç',
    'Gbreve': 'Ğ',
    'gbreve': 'ğ',
    'hellip': '...',
    'Idot': 'İ',
    'imath': 'ı',
    'laquo': '"',
    'ldquo': '"',
    'lsquo': "'",
    'nbsp': ' ',
    'Ouml': 'Ö',
    'ouml': 'ö',
    'quot': '"',
    'raquo': '"',
    'rdquo': '"',
    'rsquo': "'",
    'Scedil': 'Ş',
    'scedil': 'ş',
    'Uuml': 'Ü',
    'uuml': 'ü',
  };

  String decodePoint(String value, int radix, String fallback) {
    final codePoint = int.tryParse(value, radix: radix);
    if (codePoint == null ||
        codePoint <= 0 ||
        codePoint == 60 ||
        codePoint == 62) {
      return fallback;
    }
    try {
      return String.fromCharCode(codePoint);
    } catch (_) {
      return fallback;
    }
  }

  String decodeOnce(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'&([a-zA-Z][a-zA-Z0-9]+);'),
          (match) => entities[match.group(1)] ?? match.group(0)!,
        )
        .replaceAllMapped(
          RegExp(r'&#x([0-9a-fA-F]+);'),
          (match) => decodePoint(match.group(1)!, 16, match.group(0)!),
        )
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (match) => decodePoint(match.group(1)!, 10, match.group(0)!),
        );
  }

  return decodeOnce(decodeOnce(input));
}

int asNavigationInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
