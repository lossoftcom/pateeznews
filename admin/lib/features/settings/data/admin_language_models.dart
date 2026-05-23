import '../../../core/localization/admin_translations.dart';

class AdminLanguage {
  const AdminLanguage({
    required this.code,
    required this.name,
    required this.direction,
    required this.status,
    required this.flagCode,
    required this.isDefault,
    required this.rowNumber,
  });

  final String code;
  final String name;
  final String direction;
  final String status;
  final String flagCode;
  final bool isDefault;
  final int rowNumber;

  bool get active => status == 'active';

  bool get isCore => coreAdminLanguageCodes.contains(code);

  String get initial {
    final value = name.trim();
    if (value.isEmpty) return code.toUpperCase();
    return String.fromCharCode(value.runes.first).toUpperCase();
  }

  AdminLanguage copyWith({
    String? code,
    String? name,
    String? direction,
    String? status,
    String? flagCode,
    bool? isDefault,
    int? rowNumber,
  }) {
    return AdminLanguage(
      code: code ?? this.code,
      name: name ?? this.name,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      flagCode: flagCode ?? this.flagCode,
      isDefault: isDefault ?? this.isDefault,
      rowNumber: rowNumber ?? this.rowNumber,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'code': code,
      'name': name,
      'direction': direction,
      'status': status,
      'flag_code': flagCode,
      'is_default': isDefault,
    };
  }

  factory AdminLanguage.fromJson(Map<dynamic, dynamic> json, int rowNumber) {
    final item = json.map((key, value) => MapEntry(key.toString(), value));
    final code = item['code']?.toString().trim().toLowerCase() ?? '';
    return AdminLanguage(
      code: code,
      name: item['name']?.toString() ?? code,
      direction: item['direction']?.toString() == 'rtl' ? 'rtl' : 'ltr',
      status: item['status']?.toString() == 'passive' ? 'passive' : 'active',
      flagCode: item['flag_code']?.toString() ?? code,
      isDefault: item['is_default'] == true,
      rowNumber: rowNumber,
    );
  }
}

class LanguagesPageResult {
  const LanguagesPageResult({
    required this.languages,
    required this.totalCount,
  });

  final List<AdminLanguage> languages;
  final int totalCount;
}

class LanguageFormData {
  const LanguageFormData({
    required this.code,
    required this.name,
    required this.direction,
    required this.status,
    required this.flagCode,
  });

  final String code;
  final String name;
  final String direction;
  final String status;
  final String flagCode;
}

class TranslationEntryData {
  const TranslationEntryData({
    required this.key,
    required this.source,
    required this.value,
  });

  final String key;
  final String source;
  final String value;
}

const fallbackAdminLanguages = [
  AdminLanguage(
    code: 'tr',
    name: 'Türkçe',
    direction: 'ltr',
    status: 'active',
    flagCode: 'tr',
    isDefault: true,
    rowNumber: 1,
  ),
  AdminLanguage(
    code: 'en',
    name: 'English',
    direction: 'ltr',
    status: 'active',
    flagCode: 'us',
    isDefault: false,
    rowNumber: 2,
  ),
  AdminLanguage(
    code: 'ar',
    name: 'العربية',
    direction: 'rtl',
    status: 'active',
    flagCode: 'sa',
    isDefault: false,
    rowNumber: 3,
  ),
];
