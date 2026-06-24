import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';

class WeatherSettingsData {
  const WeatherSettingsData({
    required this.languageCode,
    required this.enabled,
    required this.locationName,
    required this.locationCountry,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.updateIntervalMinutes,
  });

  factory WeatherSettingsData.empty(String languageCode) {
    return WeatherSettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      enabled: true,
      locationName: 'Niğde',
      locationCountry: 'Türkiye',
      latitude: 37.96583,
      longitude: 34.67935,
      timezone: 'Europe/Istanbul',
      updateIntervalMinutes: 30,
    );
  }

  factory WeatherSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    final fallback = WeatherSettingsData.empty(languageCode);
    return WeatherSettingsData(
      languageCode: _string(
        json['language_code'],
        fallback: fallback.languageCode,
      ),
      enabled: json['weather_enabled'] != false,
      locationName: _string(
        json['weather_location_name'],
        fallback: fallback.locationName,
      ),
      locationCountry: _string(
        json['weather_location_country'],
        fallback: fallback.locationCountry,
      ),
      latitude: _number(json['weather_latitude'], fallback.latitude),
      longitude: _number(json['weather_longitude'], fallback.longitude),
      timezone: _string(json['weather_timezone'], fallback: fallback.timezone),
      updateIntervalMinutes: _int(
        json['weather_update_interval_minutes'],
        fallback.updateIntervalMinutes,
      ),
    );
  }

  final String languageCode;
  final bool enabled;
  final String locationName;
  final String locationCountry;
  final double latitude;
  final double longitude;
  final String timezone;
  final int updateIntervalMinutes;

  Map<String, Object?> toJson() {
    return {
      'language_code': _cleanLanguageCode(languageCode),
      'weather_enabled': enabled,
      'weather_location_name': locationName.trim().isEmpty
          ? 'Niğde'
          : locationName.trim(),
      'weather_location_country': locationCountry.trim(),
      'weather_latitude': latitude,
      'weather_longitude': longitude,
      'weather_timezone': timezone.trim().isEmpty
          ? 'Europe/Istanbul'
          : timezone.trim(),
      'weather_update_interval_minutes': updateIntervalMinutes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class WeatherLocationSearchResult {
  const WeatherLocationSearchResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.timezone = 'Europe/Istanbul',
    this.country = '',
    this.admin1 = '',
  });

  factory WeatherLocationSearchResult.fromJson(Map<String, Object?> json) {
    return WeatherLocationSearchResult(
      name: _string(json['name']),
      latitude: _number(json['latitude'], 0),
      longitude: _number(json['longitude'], 0),
      timezone: _string(json['timezone'], fallback: 'Europe/Istanbul'),
      country: _string(json['country']),
      admin1: _string(json['admin1']),
    );
  }

  final String name;
  final double latitude;
  final double longitude;
  final String timezone;
  final String country;
  final String admin1;
}

class ModuleCacheInfo {
  const ModuleCacheInfo({
    required this.source,
    required this.hit,
    required this.stale,
  });

  factory ModuleCacheInfo.fromJson(Object? value) {
    if (value is! Map) {
      return const ModuleCacheInfo(
        source: 'database',
        hit: false,
        stale: false,
      );
    }
    return ModuleCacheInfo(
      source: _string(value['source'], fallback: 'database'),
      hit: value['hit'] == true,
      stale: value['stale'] == true,
    );
  }

  final String source;
  final bool hit;
  final bool stale;
}

class DutyPharmacyPreviewData {
  const DutyPharmacyPreviewData({
    required this.city,
    required this.source,
    required this.sourceUrl,
    required this.serviceDateLabel,
    required this.updateIntervalMinutes,
    required this.districts,
    required this.pharmacies,
    required this.total,
    required this.cache,
  });

  factory DutyPharmacyPreviewData.fromJson(Map<String, Object?> json) {
    return DutyPharmacyPreviewData(
      city: _string(json['city'], fallback: 'Niğde'),
      source: _string(json['source'], fallback: 'Niğde Eczacı Odası'),
      sourceUrl: _string(
        json['sourceUrl'],
        fallback: 'https://www.neo.org.tr/nobetci-eczaneler',
      ),
      serviceDateLabel: _string(json['serviceDateLabel']),
      updateIntervalMinutes: _int(json['updateIntervalMinutes'], 15),
      districts: _stringList(json['districts']),
      pharmacies: [
        for (final row
            in (json['pharmacies'] is List
                ? json['pharmacies'] as List
                : const []))
          if (row is Map) DutyPharmacyItem.fromJson(_asStringKeyMap(row)),
      ],
      total: _int(
        json['meta'] is Map ? (json['meta'] as Map)['total'] : null,
        0,
      ),
      cache: ModuleCacheInfo.fromJson(json['cache']),
    );
  }

  final String city;
  final String source;
  final String sourceUrl;
  final String serviceDateLabel;
  final int updateIntervalMinutes;
  final List<String> districts;
  final List<DutyPharmacyItem> pharmacies;
  final int total;
  final ModuleCacheInfo cache;
}

class DutyPharmacyItem {
  const DutyPharmacyItem({
    required this.id,
    required this.name,
    required this.district,
    required this.address,
    required this.phone,
    required this.directionUrl,
    this.note = '',
  });

  factory DutyPharmacyItem.fromJson(Map<String, Object?> json) {
    return DutyPharmacyItem(
      id: _string(json['id']),
      name: _string(json['name']),
      district: _string(json['district']),
      address: _string(json['address']),
      phone: _string(json['phone']),
      directionUrl: _string(json['directionUrl']),
      note: _string(json['note']),
    );
  }

  final String id;
  final String name;
  final String district;
  final String address;
  final String phone;
  final String directionUrl;
  final String note;
}

class DeathNoticePreviewData {
  const DeathNoticePreviewData({
    required this.city,
    required this.source,
    required this.sourceUrl,
    required this.serviceDateLabel,
    required this.updateIntervalMinutes,
    required this.notices,
    required this.total,
    required this.cache,
  });

  factory DeathNoticePreviewData.fromJson(Map<String, Object?> json) {
    return DeathNoticePreviewData(
      city: _string(json['city'], fallback: 'Niğde'),
      source: _string(json['source'], fallback: 'Niğde Belediyesi'),
      sourceUrl: _string(
        json['sourceUrl'],
        fallback: 'https://nigde.bel.tr/vefat-edenler',
      ),
      serviceDateLabel: _string(json['serviceDateLabel']),
      updateIntervalMinutes: _int(json['updateIntervalMinutes'], 30),
      notices: [
        for (final row
            in (json['notices'] is List ? json['notices'] as List : const []))
          if (row is Map) DeathNoticeItem.fromJson(_asStringKeyMap(row)),
      ],
      total: _int(
        json['meta'] is Map ? (json['meta'] as Map)['total'] : null,
        0,
      ),
      cache: ModuleCacheInfo.fromJson(json['cache']),
    );
  }

  final String city;
  final String source;
  final String sourceUrl;
  final String serviceDateLabel;
  final int updateIntervalMinutes;
  final List<DeathNoticeItem> notices;
  final int total;
  final ModuleCacheInfo cache;
}

class DeathNoticeItem {
  const DeathNoticeItem({
    required this.id,
    required this.name,
    required this.deathDateLabel,
    required this.prayerTime,
    required this.burialPlace,
    required this.description,
  });

  factory DeathNoticeItem.fromJson(Map<String, Object?> json) {
    return DeathNoticeItem(
      id: _string(json['id']),
      name: _string(json['name']),
      deathDateLabel: _string(json['deathDateLabel']),
      prayerTime: _string(json['prayerTime']),
      burialPlace: _string(json['burialPlace']),
      description: _string(json['description']),
    );
  }

  final String id;
  final String name;
  final String deathDateLabel;
  final String prayerTime;
  final String burialPlace;
  final String description;
}

class MarketSettingsData {
  const MarketSettingsData({
    required this.languageCode,
    required this.enabled,
    required this.provider,
    required this.altinApiKey,
    required this.altinApiBaseUrl,
    required this.genelParaBaseUrl,
    required this.updateIntervalSeconds,
    required this.currencySymbols,
    required this.goldSymbols,
  });

  factory MarketSettingsData.empty(String languageCode) {
    return MarketSettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      enabled: true,
      provider: 'genelpara',
      altinApiKey: '',
      altinApiBaseUrl: 'https://altinapi.com/api/v1',
      genelParaBaseUrl: 'https://api.genelpara.com/json/',
      updateIntervalSeconds: 300,
      currencySymbols: const [
        'USD',
        'EUR',
        'BTC',
        'GBP',
        'CHF',
        'CAD',
        'AUD',
        'JPY',
        'SAR',
        'KWD',
        'NOK',
        'SEK',
        'DKK',
        'RUB',
        'CNY',
        'AED',
      ],
      goldSymbols: const [
        'HAS',
        'ONS',
        'AYAR22',
        'GRAM',
        'ALTINGUMUS',
        'CEYREK',
        'YARIM',
        'TAM',
        'CUMHURIYET',
        'GREMSE',
        'AYAR14',
        'GUMUS',
        'AYAR18',
        'RESAT',
        'ATA',
        'BESLI',
        'HAMIT',
        'IKIBUCUK',
      ],
    );
  }

  factory MarketSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    final fallback = MarketSettingsData.empty(languageCode);
    return MarketSettingsData(
      languageCode: _string(
        json['languageCode'] ?? json['language_code'],
        fallback: fallback.languageCode,
      ),
      enabled: json['enabled'] != false && json['market_enabled'] != false,
      provider: _marketProvider(
        json['provider'] ?? json['market_provider'],
        fallback.provider,
      ),
      altinApiKey: _string(json['altinApiKey'] ?? json['market_altinapi_key']),
      altinApiBaseUrl: _string(
        json['altinApiBaseUrl'] ?? json['market_altinapi_base_url'],
        fallback: fallback.altinApiBaseUrl,
      ),
      genelParaBaseUrl: _string(
        json['genelParaBaseUrl'] ?? json['market_genelpara_base_url'],
        fallback: fallback.genelParaBaseUrl,
      ),
      updateIntervalSeconds: _int(
        json['updateIntervalSeconds'] ?? json['market_update_interval_seconds'],
        fallback.updateIntervalSeconds,
      ).clamp(15, 3600).toInt(),
      currencySymbols: _nonEmptyStringList(
        json['currencySymbols'] ?? json['market_currency_symbols'],
        fallback.currencySymbols,
      ),
      goldSymbols: _nonEmptyStringList(
        json['goldSymbols'] ?? json['market_gold_symbols'],
        fallback.goldSymbols,
      ),
    );
  }

  final String languageCode;
  final bool enabled;
  final String provider;
  final String altinApiKey;
  final String altinApiBaseUrl;
  final String genelParaBaseUrl;
  final int updateIntervalSeconds;
  final List<String> currencySymbols;
  final List<String> goldSymbols;

  MarketSettingsData copyWith({
    String? languageCode,
    bool? enabled,
    String? provider,
    String? altinApiKey,
    String? altinApiBaseUrl,
    String? genelParaBaseUrl,
    int? updateIntervalSeconds,
    List<String>? currencySymbols,
    List<String>? goldSymbols,
  }) {
    return MarketSettingsData(
      languageCode: languageCode ?? this.languageCode,
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      altinApiKey: altinApiKey ?? this.altinApiKey,
      altinApiBaseUrl: altinApiBaseUrl ?? this.altinApiBaseUrl,
      genelParaBaseUrl: genelParaBaseUrl ?? this.genelParaBaseUrl,
      updateIntervalSeconds:
          updateIntervalSeconds ?? this.updateIntervalSeconds,
      currencySymbols: currencySymbols ?? this.currencySymbols,
      goldSymbols: goldSymbols ?? this.goldSymbols,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'enabled': enabled,
      'provider': _marketProvider(provider, 'genelpara'),
      'altinApiKey': altinApiKey.trim(),
      'altinApiBaseUrl': altinApiBaseUrl.trim().isEmpty
          ? 'https://altinapi.com/api/v1'
          : altinApiBaseUrl.trim(),
      'genelParaBaseUrl': genelParaBaseUrl.trim().isEmpty
          ? 'https://api.genelpara.com/json/'
          : genelParaBaseUrl.trim(),
      'updateIntervalSeconds': updateIntervalSeconds.clamp(15, 3600).toInt(),
      'currencySymbols': currencySymbols.join(','),
      'goldSymbols': goldSymbols.join(','),
    };
  }
}

class MarketPreviewData {
  const MarketPreviewData({
    required this.enabled,
    required this.provider,
    required this.source,
    required this.serviceDateLabel,
    required this.fetchedAt,
    required this.updateIntervalSeconds,
    required this.currencies,
    required this.gold,
    required this.cache,
  });

  factory MarketPreviewData.fromJson(Map<String, Object?> json) {
    return MarketPreviewData(
      enabled: json['enabled'] != false,
      provider: _string(json['provider'], fallback: 'genelpara'),
      source: _string(json['source'], fallback: 'GenelPara'),
      serviceDateLabel: _string(json['serviceDateLabel']),
      fetchedAt: _string(json['fetchedAt']),
      updateIntervalSeconds: _int(json['updateIntervalSeconds'], 180),
      currencies: [
        for (final row
            in (json['currencies'] is List
                ? json['currencies'] as List
                : const []))
          if (row is Map) MarketPreviewRate.fromJson(_asStringKeyMap(row)),
      ],
      gold: [
        for (final row
            in (json['gold'] is List ? json['gold'] as List : const []))
          if (row is Map) MarketPreviewRate.fromJson(_asStringKeyMap(row)),
      ],
      cache: ModuleCacheInfo.fromJson(json['cache']),
    );
  }

  final bool enabled;
  final String provider;
  final String source;
  final String serviceDateLabel;
  final String fetchedAt;
  final int updateIntervalSeconds;
  final List<MarketPreviewRate> currencies;
  final List<MarketPreviewRate> gold;
  final ModuleCacheInfo cache;
}

class MarketPreviewRate {
  const MarketPreviewRate({
    required this.id,
    required this.symbol,
    required this.name,
    required this.bid,
    required this.ask,
    required this.changePercent,
    required this.isUp,
    required this.currencySymbol,
    this.secondaryAsk,
    this.secondaryCurrencyCode = '',
    this.secondaryCurrencySymbol = '',
  });

  factory MarketPreviewRate.fromJson(Map<String, Object?> json) {
    return MarketPreviewRate(
      id: _string(json['id']),
      symbol: _string(json['symbol']),
      name: _string(json['name']),
      bid: _number(json['bid'], 0),
      ask: _number(json['ask'], 0),
      changePercent: NumberFormatHelper.parse(json['changePercent']),
      isUp: json['isUp'] != false,
      currencySymbol: _string(json['currencySymbol'], fallback: '₺'),
      secondaryAsk: NumberFormatHelper.parse(json['secondaryAsk']),
      secondaryCurrencyCode: _string(json['secondaryCurrencyCode']),
      secondaryCurrencySymbol: _string(json['secondaryCurrencySymbol']),
    );
  }

  final String id;
  final String symbol;
  final String name;
  final double bid;
  final double ask;
  final double? changePercent;
  final bool isUp;
  final String currencySymbol;
  final double? secondaryAsk;
  final String secondaryCurrencyCode;
  final String secondaryCurrencySymbol;

  bool get hasSecondaryAsk =>
      secondaryAsk != null &&
      secondaryCurrencyCode.isNotEmpty &&
      secondaryCurrencySymbol.isNotEmpty;
}

class PrayerSettingsData {
  const PrayerSettingsData({
    required this.languageCode,
    required this.enabled,
    required this.diyanetBaseUrl,
    required this.locationName,
    required this.locationCountry,
    required this.locationStateId,
    required this.locationCityId,
    required this.timezone,
    required this.refreshLeadDays,
    required this.cacheDays,
    required this.ayahEnabled,
    required this.ayahStartDate,
    required this.quranApiBaseUrl,
    required this.quranApiToken,
  });

  factory PrayerSettingsData.empty(String languageCode) {
    return PrayerSettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      enabled: true,
      diyanetBaseUrl: 'https://namazvakitleri.diyanet.gov.tr',
      locationName: 'Niğde',
      locationCountry: 'Türkiye',
      locationStateId: 561,
      locationCityId: 9766,
      timezone: 'Europe/Istanbul',
      refreshLeadDays: 3,
      cacheDays: 370,
      ayahEnabled: true,
      ayahStartDate: '2026-06-05',
      quranApiBaseUrl: 'https://t061.diyanet.gov.tr/apigateway/acikkaynakkuran',
      quranApiToken: '',
    );
  }

  factory PrayerSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    final fallback = PrayerSettingsData.empty(languageCode);
    return PrayerSettingsData(
      languageCode: _string(
        json['languageCode'] ?? json['language_code'],
        fallback: fallback.languageCode,
      ),
      enabled: json['enabled'] != false && json['prayer_enabled'] != false,
      diyanetBaseUrl: _string(
        json['diyanetBaseUrl'] ?? json['prayer_diyanet_base_url'],
        fallback: fallback.diyanetBaseUrl,
      ),
      locationName: _string(
        json['locationName'] ?? json['prayer_location_name'],
        fallback: fallback.locationName,
      ),
      locationCountry: _string(
        json['locationCountry'] ?? json['prayer_location_country'],
        fallback: fallback.locationCountry,
      ),
      locationStateId: _int(
        json['locationStateId'] ?? json['prayer_location_state_id'],
        fallback.locationStateId,
      ),
      locationCityId: _int(
        json['locationCityId'] ?? json['prayer_location_city_id'],
        fallback.locationCityId,
      ),
      timezone: _string(
        json['timezone'] ?? json['prayer_timezone'],
        fallback: fallback.timezone,
      ),
      refreshLeadDays: _int(
        json['refreshLeadDays'] ?? json['prayer_refresh_lead_days'],
        fallback.refreshLeadDays,
      ).clamp(1, 10).toInt(),
      cacheDays: _int(
        json['cacheDays'] ?? json['prayer_cache_days'],
        fallback.cacheDays,
      ).clamp(31, 400).toInt(),
      ayahEnabled:
          json['ayahEnabled'] != false && json['daily_ayah_enabled'] != false,
      ayahStartDate: _string(
        json['ayahStartDate'] ?? json['daily_ayah_start_date'],
        fallback: fallback.ayahStartDate,
      ),
      quranApiBaseUrl: _string(
        json['quranApiBaseUrl'] ?? json['daily_ayah_quran_api_base_url'],
        fallback: fallback.quranApiBaseUrl,
      ),
      quranApiToken: _string(
        json['quranApiToken'] ?? json['daily_ayah_quran_api_token'],
      ),
    );
  }

  final String languageCode;
  final bool enabled;
  final String diyanetBaseUrl;
  final String locationName;
  final String locationCountry;
  final int locationStateId;
  final int locationCityId;
  final String timezone;
  final int refreshLeadDays;
  final int cacheDays;
  final bool ayahEnabled;
  final String ayahStartDate;
  final String quranApiBaseUrl;
  final String quranApiToken;

  PrayerSettingsData copyWith({
    String? languageCode,
    bool? enabled,
    String? diyanetBaseUrl,
    String? locationName,
    String? locationCountry,
    int? locationStateId,
    int? locationCityId,
    String? timezone,
    int? refreshLeadDays,
    int? cacheDays,
    bool? ayahEnabled,
    String? ayahStartDate,
    String? quranApiBaseUrl,
    String? quranApiToken,
  }) {
    return PrayerSettingsData(
      languageCode: languageCode ?? this.languageCode,
      enabled: enabled ?? this.enabled,
      diyanetBaseUrl: diyanetBaseUrl ?? this.diyanetBaseUrl,
      locationName: locationName ?? this.locationName,
      locationCountry: locationCountry ?? this.locationCountry,
      locationStateId: locationStateId ?? this.locationStateId,
      locationCityId: locationCityId ?? this.locationCityId,
      timezone: timezone ?? this.timezone,
      refreshLeadDays: refreshLeadDays ?? this.refreshLeadDays,
      cacheDays: cacheDays ?? this.cacheDays,
      ayahEnabled: ayahEnabled ?? this.ayahEnabled,
      ayahStartDate: ayahStartDate ?? this.ayahStartDate,
      quranApiBaseUrl: quranApiBaseUrl ?? this.quranApiBaseUrl,
      quranApiToken: quranApiToken ?? this.quranApiToken,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'enabled': enabled,
      'diyanetBaseUrl': diyanetBaseUrl.trim().isEmpty
          ? 'https://namazvakitleri.diyanet.gov.tr'
          : diyanetBaseUrl.trim(),
      'locationName': locationName.trim().isEmpty
          ? 'Niğde'
          : locationName.trim(),
      'locationCountry': locationCountry.trim().isEmpty
          ? 'Türkiye'
          : locationCountry.trim(),
      'locationStateId': locationStateId.clamp(1, 999999).toInt(),
      'locationCityId': locationCityId.clamp(1, 999999).toInt(),
      'timezone': timezone.trim().isEmpty ? 'Europe/Istanbul' : timezone.trim(),
      'refreshLeadDays': refreshLeadDays.clamp(1, 10).toInt(),
      'cacheDays': cacheDays.clamp(31, 400).toInt(),
      'ayahEnabled': ayahEnabled,
      'ayahStartDate': ayahStartDate.trim().isEmpty
          ? '2026-06-05'
          : ayahStartDate.trim(),
      'quranApiBaseUrl': quranApiBaseUrl.trim().isEmpty
          ? 'https://t061.diyanet.gov.tr/apigateway/acikkaynakkuran'
          : quranApiBaseUrl.trim(),
      'quranApiToken': quranApiToken.trim(),
    };
  }
}

class PrayerPreviewData {
  const PrayerPreviewData({
    required this.enabled,
    required this.source,
    required this.location,
    required this.country,
    required this.timezone,
    required this.serviceDateLabel,
    required this.fetchedAt,
    required this.today,
    required this.days,
    required this.dailyAyah,
    required this.cache,
  });

  factory PrayerPreviewData.fromJson(Map<String, Object?> json) {
    return PrayerPreviewData(
      enabled: json['enabled'] != false,
      source: _string(json['source'], fallback: 'Diyanet Namaz Vakitleri'),
      location: _string(json['location'], fallback: 'Niğde'),
      country: _string(json['country'], fallback: 'Türkiye'),
      timezone: _string(json['timezone'], fallback: 'Europe/Istanbul'),
      serviceDateLabel: _string(json['serviceDateLabel']),
      fetchedAt: _string(json['fetchedAt']),
      today: json['today'] is Map
          ? PrayerPreviewDay.fromJson(_asStringKeyMap(json['today'] as Map))
          : null,
      days: [
        for (final row
            in (json['days'] is List ? json['days'] as List : const []))
          if (row is Map) PrayerPreviewDay.fromJson(_asStringKeyMap(row)),
      ],
      dailyAyah: json['dailyAyah'] is Map
          ? PrayerPreviewAyah.fromJson(
              _asStringKeyMap(json['dailyAyah'] as Map),
            )
          : null,
      cache: ModuleCacheInfo.fromJson(json['cache']),
    );
  }

  final bool enabled;
  final String source;
  final String location;
  final String country;
  final String timezone;
  final String serviceDateLabel;
  final String fetchedAt;
  final PrayerPreviewDay? today;
  final List<PrayerPreviewDay> days;
  final PrayerPreviewAyah? dailyAyah;
  final ModuleCacheInfo cache;
}

class PrayerPreviewDay {
  const PrayerPreviewDay({
    required this.date,
    required this.gregorianDateLabel,
    required this.hijriDateLabel,
    required this.times,
    required this.qiblaAngle,
  });

  factory PrayerPreviewDay.fromJson(Map<String, Object?> json) {
    return PrayerPreviewDay(
      date: _string(json['date']),
      gregorianDateLabel: _string(json['gregorianDateLabel']),
      hijriDateLabel: _string(json['hijriDateLabel']),
      times: [
        for (final row
            in (json['times'] is List ? json['times'] as List : const []))
          if (row is Map) PrayerPreviewTime.fromJson(_asStringKeyMap(row)),
      ],
      qiblaAngle: _string(json['qiblaAngle'], fallback: '147°'),
    );
  }

  final String date;
  final String gregorianDateLabel;
  final String hijriDateLabel;
  final List<PrayerPreviewTime> times;
  final String qiblaAngle;
}

class PrayerPreviewTime {
  const PrayerPreviewTime({
    required this.key,
    required this.name,
    required this.time,
  });

  factory PrayerPreviewTime.fromJson(Map<String, Object?> json) {
    return PrayerPreviewTime(
      key: _string(json['key']),
      name: _string(json['name']),
      time: _string(json['time']),
    );
  }

  final String key;
  final String name;
  final String time;
}

class PrayerPreviewAyah {
  const PrayerPreviewAyah({
    required this.surahName,
    required this.verseNumber,
    required this.arabicText,
    required this.translation,
    required this.source,
  });

  factory PrayerPreviewAyah.fromJson(Map<String, Object?> json) {
    return PrayerPreviewAyah(
      surahName: _string(json['surahName'], fallback: 'Fâtiha'),
      verseNumber: _int(json['verseNumber'], 1),
      arabicText: _string(json['arabicText']),
      translation: _string(json['translation']),
      source: _string(json['source'], fallback: 'Diyanet Kur’an API'),
    );
  }

  final String surahName;
  final int verseNumber;
  final String arabicText;
  final String translation;
  final String source;
}

class AnnouncementSourceData {
  const AnnouncementSourceData({
    required this.id,
    required this.sourceKey,
    required this.name,
    required this.sourceType,
    required this.categoryHint,
    required this.district,
    required this.websiteUrl,
    required this.listUrl,
    required this.socialUrl,
    required this.facebookUrl,
    required this.instagramUrl,
    required this.crawlStrategy,
    required this.isActive,
    required this.crawlIntervalMinutes,
    required this.lastCheckedAt,
    required this.lastSuccessAt,
    required this.lastError,
    required this.sortOrder,
  });

  const AnnouncementSourceData.empty()
    : id = '',
      sourceKey = '',
      name = '',
      sourceType = 'other',
      categoryHint = 'official',
      district = 'merkez',
      websiteUrl = '',
      listUrl = '',
      socialUrl = '',
      facebookUrl = '',
      instagramUrl = '',
      crawlStrategy = 'auto',
      isActive = true,
      crawlIntervalMinutes = 30,
      lastCheckedAt = '',
      lastSuccessAt = '',
      lastError = '',
      sortOrder = 500;

  factory AnnouncementSourceData.fromJson(Map<String, Object?> json) {
    return AnnouncementSourceData(
      id: _string(json['id']),
      sourceKey: _string(json['sourceKey'] ?? json['source_key']),
      name: _string(json['name']),
      sourceType: _string(
        json['sourceType'] ?? json['source_type'],
        fallback: 'other',
      ),
      categoryHint: _announcementCategory(
        json['categoryHint'] ?? json['category_hint'],
      ),
      district: _announcementDistrict(json['district']),
      websiteUrl: _string(json['websiteUrl'] ?? json['website_url']),
      listUrl: _string(json['listUrl'] ?? json['list_url']),
      socialUrl: _string(json['socialUrl'] ?? json['social_url']),
      facebookUrl: _string(json['facebookUrl'] ?? json['facebook_url']),
      instagramUrl: _string(json['instagramUrl'] ?? json['instagram_url']),
      crawlStrategy: _string(
        json['crawlStrategy'] ?? json['crawl_strategy'],
        fallback: 'auto',
      ),
      isActive: (json['isActive'] ?? json['is_active']) != false,
      crawlIntervalMinutes: _int(
        json['crawlIntervalMinutes'] ?? json['crawl_interval_minutes'],
        30,
      ),
      lastCheckedAt: _string(json['lastCheckedAt'] ?? json['last_checked_at']),
      lastSuccessAt: _string(json['lastSuccessAt'] ?? json['last_success_at']),
      lastError: _string(json['lastError'] ?? json['last_error']),
      sortOrder: _int(json['sortOrder'] ?? json['sort_order'], 500),
    );
  }

  final String id;
  final String sourceKey;
  final String name;
  final String sourceType;
  final String categoryHint;
  final String district;
  final String websiteUrl;
  final String listUrl;
  final String socialUrl;
  final String facebookUrl;
  final String instagramUrl;
  final String crawlStrategy;
  final bool isActive;
  final int crawlIntervalMinutes;
  final String lastCheckedAt;
  final String lastSuccessAt;
  final String lastError;
  final int sortOrder;

  AnnouncementSourceData copyWith({
    String? id,
    String? sourceKey,
    String? name,
    String? sourceType,
    String? categoryHint,
    String? district,
    String? websiteUrl,
    String? listUrl,
    String? socialUrl,
    String? facebookUrl,
    String? instagramUrl,
    String? crawlStrategy,
    bool? isActive,
    int? crawlIntervalMinutes,
    String? lastCheckedAt,
    String? lastSuccessAt,
    String? lastError,
    int? sortOrder,
  }) {
    return AnnouncementSourceData(
      id: id ?? this.id,
      sourceKey: sourceKey ?? this.sourceKey,
      name: name ?? this.name,
      sourceType: sourceType ?? this.sourceType,
      categoryHint: categoryHint ?? this.categoryHint,
      district: district ?? this.district,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      listUrl: listUrl ?? this.listUrl,
      socialUrl: socialUrl ?? this.socialUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      crawlStrategy: crawlStrategy ?? this.crawlStrategy,
      isActive: isActive ?? this.isActive,
      crawlIntervalMinutes: crawlIntervalMinutes ?? this.crawlIntervalMinutes,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastError: lastError ?? this.lastError,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'sourceKey': sourceKey,
      'name': name,
      'sourceType': sourceType,
      'categoryHint': _announcementCategory(categoryHint),
      'district': _announcementDistrict(district),
      'websiteUrl': websiteUrl,
      'listUrl': listUrl,
      'socialUrl': socialUrl,
      'facebookUrl': facebookUrl,
      'instagramUrl': instagramUrl,
      'crawlStrategy': crawlStrategy.trim().isEmpty ? 'auto' : crawlStrategy,
      'isActive': isActive,
      'crawlIntervalMinutes': crawlIntervalMinutes.clamp(5, 1440),
      'sortOrder': sortOrder,
    };
  }
}

class AnnouncementPreviewData {
  const AnnouncementPreviewData({
    required this.city,
    required this.source,
    required this.serviceDateLabel,
    required this.fetchedAt,
    required this.updateIntervalMinutes,
    required this.announcements,
    required this.total,
    required this.officialCount,
    required this.powerCount,
    required this.roadCount,
    required this.activeSources,
  });

  const AnnouncementPreviewData.empty()
    : city = 'Niğde',
      source = 'Niğde Duyuru Ağı',
      serviceDateLabel = '',
      fetchedAt = '',
      updateIntervalMinutes = 30,
      announcements = const [],
      total = 0,
      officialCount = 0,
      powerCount = 0,
      roadCount = 0,
      activeSources = 0;

  factory AnnouncementPreviewData.fromJson(Map<String, Object?> json) {
    final meta = json['meta'] is Map ? json['meta'] as Map : const {};
    return AnnouncementPreviewData(
      city: _string(json['city'], fallback: 'Niğde'),
      source: _string(json['source'], fallback: 'Niğde Duyuru Ağı'),
      serviceDateLabel: _string(json['serviceDateLabel']),
      fetchedAt: _string(json['fetchedAt']),
      updateIntervalMinutes: _int(json['updateIntervalMinutes'], 30),
      announcements: [
        for (final row
            in (json['announcements'] is List
                ? json['announcements'] as List
                : const []))
          if (row is Map)
            AnnouncementPreviewItem.fromJson(_asStringKeyMap(row)),
      ],
      total: _int(meta['total'], 0),
      officialCount: _int(meta['officialCount'], 0),
      powerCount: _int(meta['powerCount'], 0),
      roadCount: _int(meta['roadCount'], 0),
      activeSources: _int(meta['activeSources'], 0),
    );
  }

  final String city;
  final String source;
  final String serviceDateLabel;
  final String fetchedAt;
  final int updateIntervalMinutes;
  final List<AnnouncementPreviewItem> announcements;
  final int total;
  final int officialCount;
  final int powerCount;
  final int roadCount;
  final int activeSources;

  AnnouncementPreviewData copyWith({
    List<AnnouncementPreviewItem>? announcements,
  }) {
    final nextAnnouncements = announcements ?? this.announcements;
    return AnnouncementPreviewData(
      city: city,
      source: source,
      serviceDateLabel: serviceDateLabel,
      fetchedAt: fetchedAt,
      updateIntervalMinutes: updateIntervalMinutes,
      announcements: nextAnnouncements,
      total: nextAnnouncements.length,
      officialCount: nextAnnouncements
          .where((item) => item.category == 'official' && item.isActive)
          .length,
      powerCount: nextAnnouncements
          .where((item) => item.category == 'power' && item.isActive)
          .length,
      roadCount: nextAnnouncements
          .where((item) => item.category == 'road' && item.isActive)
          .length,
      activeSources: activeSources,
    );
  }
}

class AnnouncementPreviewItem {
  const AnnouncementPreviewItem({
    required this.id,
    required this.category,
    required this.district,
    required this.source,
    required this.sourceKey,
    required this.title,
    required this.summary,
    required this.body,
    required this.place,
    required this.timeLabel,
    required this.statusLabel,
    required this.scheduleLabel,
    required this.imageUrl,
    required this.sourceUrl,
    required this.canonicalUrl,
    required this.linkedPostId,
    required this.linkedPostTitle,
    required this.linkedPostSlug,
    required this.linkedPostThumbnailUrl,
    required this.publishedAt,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
  });

  factory AnnouncementPreviewItem.fromJson(Map<String, Object?> json) {
    final linkedPost = json['linkedPost'] is Map
        ? _asStringKeyMap(json['linkedPost'] as Map)
        : const <String, Object?>{};
    return AnnouncementPreviewItem(
      id: _string(json['id']),
      category: _announcementCategory(json['category']),
      district: _announcementDistrict(json['district']),
      source: _string(json['source']),
      sourceKey: _string(json['sourceKey'] ?? json['source_key']),
      title: _string(json['title']),
      summary: _string(json['summary']),
      body: _string(json['body']),
      place: _string(json['place'], fallback: 'Niğde geneli'),
      timeLabel: _string(json['timeLabel'], fallback: 'Bugün'),
      statusLabel: _string(json['statusLabel']),
      scheduleLabel: _string(json['scheduleLabel']),
      imageUrl: _string(json['imageUrl']),
      sourceUrl: _string(json['sourceUrl']),
      canonicalUrl: _string(json['canonicalUrl'] ?? json['canonical_url']),
      linkedPostId: _string(
        json['linkedPostId'] ?? json['linked_post_id'] ?? linkedPost['id'],
      ),
      linkedPostTitle: _string(
        json['linkedPostTitle'] ??
            json['linked_post_title'] ??
            linkedPost['title'],
      ),
      linkedPostSlug: _string(
        json['linkedPostSlug'] ??
            json['linked_post_slug'] ??
            linkedPost['slug'],
      ),
      linkedPostThumbnailUrl: _string(
        json['linkedPostThumbnailUrl'] ??
            json['linked_post_thumbnail_url'] ??
            linkedPost['imageUrl'] ??
            linkedPost['image_url'],
      ),
      publishedAt: _string(json['publishedAt'] ?? json['published_at']),
      startsAt: _string(json['startsAt'] ?? json['starts_at']),
      endsAt: _string(json['endsAt'] ?? json['ends_at']),
      isActive: (json['isActive'] ?? json['is_active']) != false,
    );
  }

  final String id;
  final String category;
  final String district;
  final String source;
  final String sourceKey;
  final String title;
  final String summary;
  final String body;
  final String place;
  final String timeLabel;
  final String statusLabel;
  final String scheduleLabel;
  final String imageUrl;
  final String sourceUrl;
  final String canonicalUrl;
  final String linkedPostId;
  final String linkedPostTitle;
  final String linkedPostSlug;
  final String linkedPostThumbnailUrl;
  final String publishedAt;
  final String startsAt;
  final String endsAt;
  final bool isActive;

  AnnouncementPreviewItem copyWith({
    String? id,
    String? category,
    String? district,
    String? source,
    String? sourceKey,
    String? title,
    String? summary,
    String? body,
    String? place,
    String? timeLabel,
    String? statusLabel,
    String? scheduleLabel,
    String? imageUrl,
    String? sourceUrl,
    String? canonicalUrl,
    String? linkedPostId,
    String? linkedPostTitle,
    String? linkedPostSlug,
    String? linkedPostThumbnailUrl,
    String? publishedAt,
    String? startsAt,
    String? endsAt,
    bool? isActive,
  }) {
    return AnnouncementPreviewItem(
      id: id ?? this.id,
      category: category ?? this.category,
      district: district ?? this.district,
      source: source ?? this.source,
      sourceKey: sourceKey ?? this.sourceKey,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      body: body ?? this.body,
      place: place ?? this.place,
      timeLabel: timeLabel ?? this.timeLabel,
      statusLabel: statusLabel ?? this.statusLabel,
      scheduleLabel: scheduleLabel ?? this.scheduleLabel,
      imageUrl: imageUrl ?? this.imageUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      linkedPostId: linkedPostId ?? this.linkedPostId,
      linkedPostTitle: linkedPostTitle ?? this.linkedPostTitle,
      linkedPostSlug: linkedPostSlug ?? this.linkedPostSlug,
      linkedPostThumbnailUrl:
          linkedPostThumbnailUrl ?? this.linkedPostThumbnailUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'category': _announcementCategory(category),
      'district': _announcementDistrict(district),
      'sourceKey': sourceKey,
      'title': title,
      'summary': summary,
      'body': body,
      'place': place,
      'statusLabel': statusLabel,
      'scheduleLabel': scheduleLabel,
      'imageUrl': imageUrl,
      'sourceUrl': sourceUrl,
      'canonicalUrl': canonicalUrl,
      'linkedPostId': linkedPostId,
      'linkedPostTitle': linkedPostTitle,
      'linkedPostSlug': linkedPostSlug,
      'linkedPostThumbnailUrl': linkedPostThumbnailUrl,
      'publishedAt': publishedAt,
      'startsAt': startsAt,
      'endsAt': endsAt,
      'isActive': isActive,
    };
  }
}

class ManualAnnouncementAiRequest {
  const ManualAnnouncementAiRequest({
    required this.text,
    required this.notes,
    required this.district,
    required this.sourceName,
    this.imageUrl = '',
  });

  final String text;
  final String notes;
  final String district;
  final String sourceName;
  final String imageUrl;

  Map<String, Object?> toJson() {
    final cleanImageUrl = imageUrl.trim();
    return {
      'text': text.trim(),
      'notes': notes.trim(),
      'district': district.trim(),
      'sourceName': sourceName.trim(),
      if (cleanImageUrl.isNotEmpty) 'imageUrl': cleanImageUrl,
    };
  }
}

class AnnouncementRunData {
  const AnnouncementRunData({
    required this.id,
    required this.runType,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.candidatesFound,
    required this.insertedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.errorMessage,
    required this.sourceName,
  });

  factory AnnouncementRunData.fromJson(Map<String, Object?> json) {
    return AnnouncementRunData(
      id: _string(json['id']),
      runType: _string(json['run_type'] ?? json['runType']),
      status: _string(json['status']),
      startedAt: _string(json['started_at'] ?? json['startedAt']),
      finishedAt: _string(json['finished_at'] ?? json['finishedAt']),
      candidatesFound: _int(
        json['candidates_found'] ?? json['candidatesFound'],
        0,
      ),
      insertedCount: _int(json['inserted_count'] ?? json['insertedCount'], 0),
      updatedCount: _int(json['updated_count'] ?? json['updatedCount'], 0),
      skippedCount: _int(json['skipped_count'] ?? json['skippedCount'], 0),
      errorMessage: _string(json['error_message'] ?? json['errorMessage']),
      sourceName: _string(json['source_name'] ?? json['sourceName']),
    );
  }

  final String id;
  final String runType;
  final String status;
  final String startedAt;
  final String finishedAt;
  final int candidatesFound;
  final int insertedCount;
  final int updatedCount;
  final int skippedCount;
  final String errorMessage;
  final String sourceName;
}

class AnnouncementRefreshResult {
  const AnnouncementRefreshResult({
    required this.preview,
    required this.sourcesChecked,
    required this.candidatesFound,
    required this.insertedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.errors,
  });

  factory AnnouncementRefreshResult.fromJson(Map<String, Object?> json) {
    final totals = json['totals'] is Map ? json['totals'] as Map : const {};
    return AnnouncementRefreshResult(
      preview: json['payload'] is Map
          ? AnnouncementPreviewData.fromJson(
              _asStringKeyMap(json['payload'] as Map),
            )
          : const AnnouncementPreviewData.empty(),
      sourcesChecked: _int(totals['sourcesChecked'], 0),
      candidatesFound: _int(totals['candidatesFound'], 0),
      insertedCount: _int(totals['insertedCount'], 0),
      updatedCount: _int(totals['updatedCount'], 0),
      skippedCount: _int(totals['skippedCount'], 0),
      errors: _stringList(totals['errors']),
    );
  }

  final AnnouncementPreviewData preview;
  final int sourcesChecked;
  final int candidatesFound;
  final int insertedCount;
  final int updatedCount;
  final int skippedCount;
  final List<String> errors;
}

abstract class AdminModuleSettingsRepository {
  Future<WeatherSettingsData> fetchWeatherSettings(String languageCode);

  Future<WeatherSettingsData> saveWeatherSettings({
    required AdminSession session,
    required WeatherSettingsData settings,
  });

  Future<List<WeatherLocationSearchResult>> searchWeatherLocations({
    required String query,
    required String languageCode,
  });

  Future<DutyPharmacyPreviewData> fetchDutyPharmacyPreview({
    bool forceRefresh = false,
  });

  Future<DeathNoticePreviewData> fetchDeathNoticePreview({
    bool forceRefresh = false,
  });

  Future<MarketSettingsData> fetchMarketSettings(String languageCode);

  Future<MarketSettingsData> saveMarketSettings({
    required AdminSession session,
    required MarketSettingsData settings,
  });

  Future<MarketPreviewData> fetchMarketPreview({bool forceRefresh = false});

  Future<PrayerSettingsData> fetchPrayerSettings(String languageCode);

  Future<PrayerSettingsData> savePrayerSettings({
    required AdminSession session,
    required PrayerSettingsData settings,
  });

  Future<PrayerPreviewData> fetchPrayerPreview({bool forceRefresh = false});

  Future<List<AnnouncementSourceData>> fetchAnnouncementSources({
    bool includeInactive = true,
  });

  Future<AnnouncementSourceData> saveAnnouncementSource({
    required AdminSession session,
    required AnnouncementSourceData source,
  });

  Future<void> deleteAnnouncementSource({
    required AdminSession session,
    required String id,
  });

  Future<AnnouncementPreviewData> fetchAnnouncementPreview();

  Future<AnnouncementPreviewItem> saveAnnouncement({
    required AdminSession session,
    required AnnouncementPreviewItem announcement,
  });

  Future<AnnouncementPreviewItem> createManualAnnouncementWithAi({
    required AdminSession session,
    required ManualAnnouncementAiRequest request,
  });

  Future<AnnouncementPreviewItem> setAnnouncementActive({
    required AdminSession session,
    required String id,
    required bool isActive,
  });

  Future<void> deleteAnnouncement({
    required AdminSession session,
    required String id,
  });

  Future<void> deleteAnnouncements({
    required AdminSession session,
    required List<String> ids,
  });

  Future<AnnouncementRefreshResult> refreshAnnouncements({
    required AdminSession session,
  });

  Future<List<AnnouncementRunData>> fetchAnnouncementRuns();
}

class SupabaseAdminModuleSettingsRepository
    implements AdminModuleSettingsRepository {
  const SupabaseAdminModuleSettingsRepository({
    this.httpClient,
    this.apiBaseUrl,
  });

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 18);
  static const _manualAnnouncementAiTimeout = Duration(seconds: 60);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<WeatherSettingsData> fetchWeatherSettings(String languageCode) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'select',
      'select':
          'language_code,weather_enabled,weather_location_name,weather_location_country,weather_latitude,weather_longitude,weather_timezone,weather_update_interval_minutes',
      'filters': [
        {
          'type': 'comparison',
          'op': 'eq',
          'column': 'language_code',
          'value': normalizedCode,
        },
      ],
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'Hava durumu ayarları alınamadı');
    final data = result['data'];
    if (data is! Map) return WeatherSettingsData.empty(normalizedCode);
    return WeatherSettingsData.fromJson(_asStringKeyMap(data), normalizedCode);
  }

  @override
  Future<WeatherSettingsData> saveWeatherSettings({
    required AdminSession session,
    required WeatherSettingsData settings,
  }) async {
    final normalizedSettings = WeatherSettingsData(
      languageCode: _cleanLanguageCode(settings.languageCode),
      enabled: settings.enabled,
      locationName: settings.locationName,
      locationCountry: settings.locationCountry,
      latitude: settings.latitude,
      longitude: settings.longitude,
      timezone: settings.timezone,
      updateIntervalMinutes: settings.updateIntervalMinutes,
    );
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'upsert',
      'values': normalizedSettings.toJson(),
      'options': {'onConflict': 'language_code'},
      'single': 'maybeSingle',
    });
    _throwIfApiError(
      result,
      fallbackMessage: 'Hava durumu ayarları kaydedilemedi',
    );
    await _deleteCacheKey('sidebar:${normalizedSettings.languageCode}');
    final data = result['data'];
    if (data is! Map) return normalizedSettings;
    return WeatherSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedSettings.languageCode,
    );
  }

  @override
  Future<List<WeatherLocationSearchResult>> searchWeatherLocations({
    required String query,
    required String languageCode,
  }) async {
    final term = query.trim();
    if (term.length < 2) return const [];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': term,
      'count': '8',
      'format': 'json',
      'language': _cleanLanguageCode(languageCode),
    });
    final decoded = await _getExternalJson(uri);
    final results = decoded['results'];
    if (results is! List) return const [];
    return [
      for (final item in results)
        if (item is Map)
          WeatherLocationSearchResult.fromJson(_asStringKeyMap(item)),
    ];
  }

  @override
  Future<DutyPharmacyPreviewData> fetchDutyPharmacyPreview({
    bool forceRefresh = false,
  }) async {
    final uri = _uri(
      '/api/app/duty-pharmacies?city=nigde${forceRefresh ? '&refresh=1' : ''}',
    );
    final decoded = await _getJson(uri);
    return DutyPharmacyPreviewData.fromJson(decoded);
  }

  @override
  Future<DeathNoticePreviewData> fetchDeathNoticePreview({
    bool forceRefresh = false,
  }) async {
    final uri = _uri(
      '/api/app/death-notices?city=nigde${forceRefresh ? '&refresh=1' : ''}',
    );
    final decoded = await _getJson(uri);
    return DeathNoticePreviewData.fromJson(decoded);
  }

  @override
  Future<MarketSettingsData> fetchMarketSettings(String languageCode) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final uri = _uri('/api/admin/market-settings?lang=$normalizedCode');
    final decoded = await _getAdminJson(uri);
    _throwIfApiError(decoded, fallbackMessage: 'Piyasa ayarları alınamadı');
    final data = decoded['data'];
    if (data is! Map) return MarketSettingsData.empty(normalizedCode);
    return MarketSettingsData.fromJson(_asStringKeyMap(data), normalizedCode);
  }

  @override
  Future<MarketSettingsData> saveMarketSettings({
    required AdminSession session,
    required MarketSettingsData settings,
  }) async {
    final normalized = settings.copyWith(
      languageCode: _cleanLanguageCode(settings.languageCode),
      provider: _marketProvider(settings.provider, 'genelpara'),
    );
    final result = await _postJson('/api/admin/market-settings', {
      'languageCode': normalized.languageCode,
      'values': normalized.toJson(),
    });
    _throwIfApiError(result, fallbackMessage: 'Piyasa ayarları kaydedilemedi');
    final data = result['data'];
    if (data is! Map) return normalized;
    return MarketSettingsData.fromJson(
      _asStringKeyMap(data),
      normalized.languageCode,
    );
  }

  @override
  Future<MarketPreviewData> fetchMarketPreview({
    bool forceRefresh = false,
  }) async {
    final uri = _uri(
      '/api/app/markets?lang=tr${forceRefresh ? '&refresh=1' : ''}',
    );
    final decoded = await _getJson(uri);
    return MarketPreviewData.fromJson(decoded);
  }

  @override
  Future<PrayerSettingsData> fetchPrayerSettings(String languageCode) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final uri = _uri('/api/admin/prayer-settings?lang=$normalizedCode');
    final decoded = await _getAdminJson(uri);
    _throwIfApiError(
      decoded,
      fallbackMessage: 'Namaz vakitleri ayarları alınamadı',
    );
    final data = decoded['data'];
    if (data is! Map) return PrayerSettingsData.empty(normalizedCode);
    return PrayerSettingsData.fromJson(_asStringKeyMap(data), normalizedCode);
  }

  @override
  Future<PrayerSettingsData> savePrayerSettings({
    required AdminSession session,
    required PrayerSettingsData settings,
  }) async {
    final normalized = settings.copyWith(
      languageCode: _cleanLanguageCode(settings.languageCode),
    );
    final result = await _postJson('/api/admin/prayer-settings', {
      'languageCode': normalized.languageCode,
      'values': normalized.toJson(),
    });
    _throwIfApiError(
      result,
      fallbackMessage: 'Namaz vakitleri ayarları kaydedilemedi',
    );
    final data = result['data'];
    if (data is! Map) return normalized;
    return PrayerSettingsData.fromJson(
      _asStringKeyMap(data),
      normalized.languageCode,
    );
  }

  @override
  Future<PrayerPreviewData> fetchPrayerPreview({
    bool forceRefresh = false,
  }) async {
    final uri = _uri(
      '/api/app/prayer-times?lang=tr${forceRefresh ? '&refresh=1' : ''}',
    );
    final decoded = await _getJson(uri);
    return PrayerPreviewData.fromJson(decoded);
  }

  @override
  Future<List<AnnouncementSourceData>> fetchAnnouncementSources({
    bool includeInactive = true,
  }) async {
    final uri = _uri(
      '/api/admin/announcements/sources${includeInactive ? '?includeInactive=1' : ''}',
    );
    final decoded = await _getAdminJson(uri);
    _throwIfApiError(decoded, fallbackMessage: 'Duyuru kaynakları alınamadı');
    final data = decoded['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) AnnouncementSourceData.fromJson(_asStringKeyMap(row)),
    ];
  }

  @override
  Future<AnnouncementSourceData> saveAnnouncementSource({
    required AdminSession session,
    required AnnouncementSourceData source,
  }) async {
    final result = await _postJson('/api/admin/announcements/sources', {
      'values': source.toJson(),
    });
    _throwIfApiError(result, fallbackMessage: 'Duyuru kaynağı kaydedilemedi');
    final data = result['data'];
    if (data is! Map) return source;
    return AnnouncementSourceData.fromJson(_asStringKeyMap(data));
  }

  @override
  Future<void> deleteAnnouncementSource({
    required AdminSession session,
    required String id,
  }) async {
    final result = await _postJson('/api/admin/announcements/sources', {
      'action': 'delete',
      'id': id,
    });
    _throwIfApiError(result, fallbackMessage: 'Duyuru kaynağı silinemedi');
  }

  @override
  Future<AnnouncementPreviewData> fetchAnnouncementPreview() async {
    final uri = _uri(
      '/api/admin/announcements/items?includeInactive=1&limit=200',
    );
    final decoded = await _getAdminJson(uri);
    _throwIfApiError(decoded, fallbackMessage: 'Duyurular alınamadı');
    final data = decoded['data'];
    if (data is Map) {
      return AnnouncementPreviewData.fromJson(_asStringKeyMap(data));
    }
    return const AnnouncementPreviewData.empty();
  }

  @override
  Future<AnnouncementPreviewItem> saveAnnouncement({
    required AdminSession session,
    required AnnouncementPreviewItem announcement,
  }) async {
    final result = await _postJson('/api/admin/announcements/items', {
      'action': 'save',
      'values': announcement.toJson(),
    });
    _throwIfApiError(result, fallbackMessage: 'Duyuru kaydedilemedi');
    final data = result['data'];
    if (data is! Map) return announcement;
    return AnnouncementPreviewItem.fromJson(_asStringKeyMap(data));
  }

  @override
  Future<AnnouncementPreviewItem> createManualAnnouncementWithAi({
    required AdminSession session,
    required ManualAnnouncementAiRequest request,
  }) async {
    final result = await _postJson('/api/admin/announcements/items', {
      'action': 'createManualAi',
      'values': request.toJson(),
    }, timeout: _manualAnnouncementAiTimeout);
    _throwIfApiError(result, fallbackMessage: 'Manuel duyuru eklenemedi');
    final data = result['data'];
    if (data is! Map) {
      throw const AdminModuleSettingsException('Manuel duyuru alınamadı');
    }
    return AnnouncementPreviewItem.fromJson(_asStringKeyMap(data));
  }

  @override
  Future<AnnouncementPreviewItem> setAnnouncementActive({
    required AdminSession session,
    required String id,
    required bool isActive,
  }) async {
    final result = await _postJson('/api/admin/announcements/items', {
      'action': 'setActive',
      'id': id,
      'isActive': isActive,
    });
    _throwIfApiError(result, fallbackMessage: 'Duyuru durumu güncellenemedi');
    final data = result['data'];
    if (data is! Map) {
      throw const AdminModuleSettingsException('Duyuru durumu alınamadı');
    }
    return AnnouncementPreviewItem.fromJson(_asStringKeyMap(data));
  }

  @override
  Future<void> deleteAnnouncement({
    required AdminSession session,
    required String id,
  }) async {
    final result = await _postJson('/api/admin/announcements/items', {
      'action': 'delete',
      'id': id,
    });
    _throwIfApiError(result, fallbackMessage: 'Duyuru silinemedi');
  }

  @override
  Future<void> deleteAnnouncements({
    required AdminSession session,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return;
    final result = await _postJson('/api/admin/announcements/items', {
      'action': 'delete',
      'ids': ids,
    });
    _throwIfApiError(result, fallbackMessage: 'Duyurular silinemedi');
  }

  @override
  Future<AnnouncementRefreshResult> refreshAnnouncements({
    required AdminSession session,
  }) async {
    final result = await _postJson('/api/admin/announcements/refresh', {});
    _throwIfApiError(result, fallbackMessage: 'Duyurular yenilenemedi');
    final data = result['data'];
    if (data is! Map) {
      return const AnnouncementRefreshResult(
        preview: AnnouncementPreviewData.empty(),
        sourcesChecked: 0,
        candidatesFound: 0,
        insertedCount: 0,
        updatedCount: 0,
        skippedCount: 0,
        errors: [],
      );
    }
    return AnnouncementRefreshResult.fromJson(_asStringKeyMap(data));
  }

  @override
  Future<List<AnnouncementRunData>> fetchAnnouncementRuns() async {
    final uri = _uri('/api/admin/announcements/runs?limit=30');
    final decoded = await _getAdminJson(uri);
    _throwIfApiError(
      decoded,
      fallbackMessage: 'Duyuru çalışma kayıtları alınamadı',
    );
    final data = decoded['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) AnnouncementRunData.fromJson(_asStringKeyMap(row)),
    ];
  }

  Future<void> _deleteCacheKey(String key) async {
    try {
      final result = await _postJson('/api/admin/query', {
        'table': 'app_cache',
        'method': 'delete',
        'filters': [
          {'type': 'comparison', 'op': 'eq', 'column': 'key', 'value': key},
        ],
      });
      _throwIfApiError(result, fallbackMessage: 'Cache temizlenemedi');
    } catch (_) {
      // The next frontend request can rebuild the cache if cleanup fails.
    }
  }

  Future<Map<String, Object?>> _getExternalJson(Uri uri) async {
    final response =
        await (httpClient?.get(
                  uri,
                  headers: const {'Accept': 'application/json'},
                ) ??
                http.get(uri, headers: const {'Accept': 'application/json'}))
            .timeout(_requestTimeout);
    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminModuleSettingsException('Geçersiz servis yanıtı');
    }
    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _string(
        result['reason'],
        fallback: 'Servis isteği başarısız',
      );
      throw AdminModuleSettingsException(message);
    }
    return result;
  }

  Future<Map<String, Object?>> _getJson(Uri uri) async {
    final response =
        await (httpClient?.get(
                  uri,
                  headers: const {'Accept': 'application/json'},
                ) ??
                http.get(uri, headers: const {'Accept': 'application/json'}))
            .timeout(_requestTimeout);
    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminModuleSettingsException('Geçersiz sunucu yanıtı');
    }
    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = result['error'];
      throw AdminModuleSettingsException(
        error?.toString() ?? 'Sunucu isteği başarısız',
      );
    }
    return result;
  }

  Future<Map<String, Object?>> _getAdminJson(Uri uri) async {
    final response =
        await (httpClient?.get(uri, headers: await adminJsonHeaders()) ??
                adminHttpClient.get(uri, headers: await adminJsonHeaders()))
            .timeout(_requestTimeout);
    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminModuleSettingsException('Geçersiz sunucu yanıtı');
    }
    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfApiError(result, fallbackMessage: 'Sunucu isteği başarısız');
    }
    return result;
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body, {
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _requestTimeout;
    final response =
        await (httpClient?.post(
                  _uri(path),
                  headers: await adminJsonHeaders(),
                  body: jsonEncode(body),
                ) ??
                adminHttpClient.post(
                  _uri(path),
                  headers: await adminJsonHeaders(),
                  body: jsonEncode(body),
                ))
            .timeout(effectiveTimeout);
    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminModuleSettingsException('Geçersiz sunucu yanıtı');
    }
    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfApiError(result, fallbackMessage: 'Sunucu isteği başarısız');
    }
    return result;
  }

  Uri _uri(String path) {
    final baseUrl = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (baseUrl.isNotEmpty && !isLocalAdminApiBaseUrl(baseUrl))
      return Uri.parse(baseUrl).resolve(path);
    return _defaultLocalApiBaseUrl().resolve(path);
  }

  Uri _defaultLocalApiBaseUrl() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse('https://pateez.com'),
      _ => Uri.parse('https://pateez.com'),
    };
  }

  void _throwIfApiError(
    Map<String, Object?> result, {
    required String fallbackMessage,
  }) {
    final error = result['error'];
    if (error == null) return;
    if (error is Map) {
      final message = error['message']?.toString();
      if (message != null && message.isNotEmpty) {
        throw AdminModuleSettingsException(message);
      }
    }
    throw AdminModuleSettingsException(fallbackMessage);
  }
}

class AdminModuleSettingsException implements Exception {
  const AdminModuleSettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

double _number(Object? value, double fallback) {
  final number = NumberFormatHelper.parse(value);
  return number ?? fallback;
}

int _int(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item != null && item.toString().trim().isNotEmpty)
        item.toString().trim(),
  ];
}

List<String> _nonEmptyStringList(Object? value, List<String> fallback) {
  final raw = value is List ? value.join(',') : value?.toString() ?? '';
  final result = raw
      .split(',')
      .map((item) => item.trim().toUpperCase())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  return result.isEmpty ? fallback : result;
}

String _marketProvider(Object? value, String fallback) {
  final provider = value?.toString().trim().toLowerCase() ?? '';
  return switch (provider) {
    'auto' || 'altinapi' || 'genelpara' => provider,
    _ => fallback,
  };
}

String _announcementCategory(Object? value) {
  final category = value?.toString().trim().toLowerCase() ?? '';
  return switch (category) {
    'official' || 'power' || 'road' => category,
    _ => 'official',
  };
}

String _announcementDistrict(Object? value) {
  final district = value?.toString().trim().toLowerCase() ?? '';
  return switch (district) {
    'merkez' ||
    'altunhisar' ||
    'bor' ||
    'camardi' ||
    'ciftlik' ||
    'ulukisla' => district,
    _ => 'merkez',
  };
}

String _cleanLanguageCode(String value) {
  final code = value.trim().toLowerCase().replaceAll('_', '-');
  return code.isEmpty ? 'tr' : code;
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}

class NumberFormatHelper {
  const NumberFormatHelper._();

  static double? parse(Object? value) {
    if (value is num) return value.toDouble();
    final text = value?.toString().replaceAll(',', '.').trim() ?? '';
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }
}
