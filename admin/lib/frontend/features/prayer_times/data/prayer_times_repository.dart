import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/frontend_http_client.dart';

import '../../../core/network/local_api_base_url.dart';

@immutable
class PrayerTimesData {
  const PrayerTimesData({
    required this.enabled,
    required this.source,
    required this.location,
    required this.country,
    required this.timezone,
    required this.serviceDateLabel,
    required this.fetchedAt,
    required this.refreshLeadDays,
    required this.cacheDays,
    required this.today,
    required this.days,
    required this.dailyAyah,
    required this.errorMessage,
  });

  const PrayerTimesData.empty({this.errorMessage = ''})
    : enabled = true,
      source = 'Diyanet Namaz Vakitleri',
      location = 'Niğde',
      country = 'Türkiye',
      timezone = 'Europe/Istanbul',
      serviceDateLabel = '',
      fetchedAt = '',
      refreshLeadDays = 3,
      cacheDays = 370,
      today = null,
      days = const [],
      dailyAyah = null;

  factory PrayerTimesData.fromJson(Map<dynamic, dynamic> json) {
    return PrayerTimesData(
      enabled: json['enabled'] != false,
      source: _string(json['source'], fallback: 'Diyanet Namaz Vakitleri'),
      location: _string(json['location'], fallback: 'Niğde'),
      country: _string(json['country'], fallback: 'Türkiye'),
      timezone: _string(json['timezone'], fallback: 'Europe/Istanbul'),
      serviceDateLabel: _string(json['serviceDateLabel']),
      fetchedAt: _string(json['fetchedAt']),
      refreshLeadDays: _int(json['refreshLeadDays'], 3),
      cacheDays: _int(json['cacheDays'], 370),
      today: json['today'] is Map
          ? PrayerDay.fromJson(json['today'] as Map)
          : null,
      days: [
        for (final row
            in (json['days'] is List ? json['days'] as List : const []))
          if (row is Map) PrayerDay.fromJson(row),
      ],
      dailyAyah: json['dailyAyah'] is Map
          ? DailyAyah.fromJson(json['dailyAyah'] as Map)
          : null,
      errorMessage: _string(json['error']),
    );
  }

  final bool enabled;
  final String source;
  final String location;
  final String country;
  final String timezone;
  final String serviceDateLabel;
  final String fetchedAt;
  final int refreshLeadDays;
  final int cacheDays;
  final PrayerDay? today;
  final List<PrayerDay> days;
  final DailyAyah? dailyAyah;
  final String errorMessage;

  bool get hasTimes => today?.times.isNotEmpty == true;
}

@immutable
class PrayerDay {
  const PrayerDay({
    required this.date,
    required this.gregorianDateLabel,
    required this.hijriDateLabel,
    required this.times,
    required this.qiblaAngle,
  });

  factory PrayerDay.fromJson(Map<dynamic, dynamic> json) {
    return PrayerDay(
      date: _string(json['date']),
      gregorianDateLabel: _string(json['gregorianDateLabel']),
      hijriDateLabel: _string(json['hijriDateLabel']),
      times: [
        for (final row
            in (json['times'] is List ? json['times'] as List : const []))
          if (row is Map) PrayerTime.fromJson(row),
      ],
      qiblaAngle: _string(json['qiblaAngle'], fallback: '147°'),
    );
  }

  final String date;
  final String gregorianDateLabel;
  final String hijriDateLabel;
  final List<PrayerTime> times;
  final String qiblaAngle;

  PrayerTime? get sunrise => _timeByKey('gunes');
  PrayerTime? get sunset => _timeByKey('aksam');

  PrayerTime? _timeByKey(String key) {
    for (final time in times) {
      if (time.key == key) return time;
    }
    return null;
  }
}

@immutable
class PrayerTime {
  const PrayerTime({required this.key, required this.name, required this.time});

  factory PrayerTime.fromJson(Map<dynamic, dynamic> json) {
    return PrayerTime(
      key: _string(json['key']),
      name: _string(json['name']),
      time: _string(json['time']),
    );
  }

  final String key;
  final String name;
  final String time;

  int get hour => int.tryParse(time.split(':').first) ?? 0;
  int get minute {
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    return int.tryParse(parts[1]) ?? 0;
  }
}

@immutable
class DailyAyah {
  const DailyAyah({
    required this.surahId,
    required this.surahName,
    required this.verseNumber,
    required this.arabicText,
    required this.translation,
    required this.source,
  });

  factory DailyAyah.fromJson(Map<dynamic, dynamic> json) {
    return DailyAyah(
      surahId: _int(json['surahId'], 1),
      surahName: _string(json['surahName'], fallback: 'Fâtiha'),
      verseNumber: _int(json['verseNumber'], 1),
      arabicText: _string(json['arabicText']),
      translation: _string(json['translation']),
      source: _string(json['source'], fallback: 'Diyanet Kur’an API'),
    );
  }

  final int surahId;
  final String surahName;
  final int verseNumber;
  final String arabicText;
  final String translation;
  final String source;

  String get reference => '$surahName $verseNumber';
}

class PrayerTimesRepository {
  const PrayerTimesRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _fetchTimeout = Duration(seconds: 13);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<PrayerTimesData> fetch({bool forceRefresh = false}) async {
    final uri = _uri(
      '/api/app/prayer-times?lang=tr${forceRefresh ? '&refresh=1' : ''}',
    );
    final client = httpClient ?? sharedFrontendClient;
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_fetchTimeout);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return const PrayerTimesData.empty();
      final data = PrayerTimesData.fromJson(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return PrayerTimesData.empty(
          errorMessage: data.errorMessage.isEmpty
              ? 'Namaz vakitleri alınamadı'
              : data.errorMessage,
        );
      }
      return data;
    } catch (_) {
      return const PrayerTimesData.empty(
        errorMessage: 'Namaz vakitleri alınamadı',
      );
    } finally {
      // Shared frontend client is not closed.
    }
  }

  Uri _uri(String path) {
    return frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);
  }
}

String _string(Object? value, {String fallback = ''}) {
  final result = (value ?? '').toString().trim();
  return result.isEmpty ? fallback : result;
}

int _int(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
