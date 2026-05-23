import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/settings/data/admin_language_models.dart';
import '../../features/settings/data/admin_languages_repository.dart';
import 'admin_translations.dart';

class AdminLanguageController extends ChangeNotifier {
  AdminLanguageController({required this.repository});

  static const _storageKey = 'pateez_admin_lang';

  final AdminLanguagesRepository repository;

  List<AdminLanguage> _availableLanguages = fallbackAdminLanguages;
  String _code = 'tr';
  Map<String, String> _translations = defaultTranslationsFor('tr');
  bool _loading = false;

  List<AdminLanguage> get availableLanguages => _availableLanguages;

  String get code => _code;

  Locale get locale => Locale(_code.split('-').first);

  bool get loading => _loading;

  bool get isRtl =>
      _availableLanguages.any(
        (language) => language.code == _code && language.direction == 'rtl',
      ) ||
      _code == 'ar';

  Iterable<Locale> get supportedLocales {
    final codes = <String>{
      ...defaultAdminLanguageCodes,
      ..._availableLanguages.map((language) => language.code),
    };
    return codes.map((code) => Locale(code.split('-').first));
  }

  String t(String key, {Map<String, Object?> values = const {}}) {
    final normalizedKey = normalizeAdminTranslationKey(key);
    var text =
        _translations[normalizedKey] ??
        _translations[key] ??
        defaultTranslationsFor(_code)[normalizedKey] ??
        defaultTranslationsFor(_code)[key] ??
        key;
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value?.toString() ?? '');
    }
    return text;
  }

  Future<void> loadInitial() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      await refreshLanguages(notify: false);
      final preferences = await SharedPreferences.getInstance();
      final savedCode = preferences.getString(_storageKey)?.trim();
      final defaultCode =
          _availableLanguages
              .where((language) => language.isDefault)
              .map((language) => language.code)
              .firstOrNull ??
          'tr';
      final targetCode = _isAvailable(savedCode) ? savedCode! : defaultCode;
      await _applyLanguage(targetCode, persist: false, notify: false);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshLanguages({bool notify = true}) async {
    try {
      final rows = await repository.fetchActiveLanguages();
      if (rows.isNotEmpty) _availableLanguages = rows;
      if (!_isAvailable(_code)) _code = 'tr';
    } catch (_) {
      _availableLanguages = fallbackAdminLanguages;
      if (!_isAvailable(_code)) _code = 'tr';
    }
    if (notify) notifyListeners();
  }

  Future<void> refreshTranslations() async {
    await _applyLanguage(_code, persist: false);
  }

  Future<void> setLanguage(String code) async {
    if (!_isAvailable(code)) return;
    await _applyLanguage(code, persist: true);
  }

  bool _isAvailable(String? code) {
    if (code == null || code.isEmpty) return false;
    return _availableLanguages.any((language) => language.code == code);
  }

  Future<void> _applyLanguage(
    String code, {
    required bool persist,
    bool notify = true,
  }) async {
    _code = code;
    try {
      _translations = normalizeAdminTranslationMapKeys(
        await repository.fetchTranslations(code),
      );
    } catch (_) {
      _translations = defaultTranslationsFor(code);
    }
    if (persist) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_storageKey, code);
    }
    if (notify) notifyListeners();
  }
}

class AdminLocalizationScope
    extends InheritedNotifier<AdminLanguageController> {
  const AdminLocalizationScope({
    super.key,
    required AdminLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AdminLanguageController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AdminLocalizationScope>();
    assert(scope?.notifier != null, 'AdminLocalizationScope missing');
    return scope!.notifier!;
  }

  static AdminLanguageController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdminLocalizationScope>()
        ?.notifier;
  }
}

extension AdminLocalizationContext on BuildContext {
  String t(String key, {Map<String, Object?> values = const {}}) {
    final controller = AdminLocalizationScope.maybeOf(this);
    final normalizedKey = normalizeAdminTranslationKey(key);
    return controller?.t(key, values: values) ??
        defaultTranslationsFor('tr')[normalizedKey] ??
        defaultTranslationsFor('tr')[key] ??
        key;
  }
}
