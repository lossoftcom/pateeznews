import 'admin_translations/ar.dart';
import 'admin_translations/en.dart';
import 'admin_translations/legacy_key_aliases.dart';
import 'admin_translations/tr.dart';

const defaultAdminLanguageCodes = ['tr', 'en', 'ar'];

const coreAdminLanguageCodes = {'tr', 'en', 'ar'};

const Map<String, Map<String, String>> defaultAdminTranslationFiles = {
  'tr': adminTrTranslations,
  'en': adminEnTranslations,
  'ar': adminArTranslations,
};

String normalizeAdminTranslationKey(String key) {
  return legacyAdminTranslationKeyAliases[key] ?? key;
}

Map<String, String> normalizeAdminTranslationMapKeys(
  Map<String, String> source,
) {
  final normalized = <String, String>{};
  for (final entry in source.entries) {
    normalized[normalizeAdminTranslationKey(entry.key)] = entry.value;
  }
  return normalized;
}

Map<String, String> defaultTranslationsFor(String code) {
  final normalized = code.trim().toLowerCase();
  return {...adminEnTranslations, ...?defaultAdminTranslationFiles[normalized]};
}
