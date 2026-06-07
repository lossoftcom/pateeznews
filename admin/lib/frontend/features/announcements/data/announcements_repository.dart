import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/local_api_base_url.dart';
import 'announcement_content.dart';

@immutable
class AnnouncementData {
  const AnnouncementData({
    required this.city,
    required this.serviceDateLabel,
    required this.updateIntervalMinutes,
    required this.announcements,
    required this.total,
    required this.fetchedAt,
    required this.errorMessage,
  });

  const AnnouncementData.empty({this.errorMessage = ''})
    : city = 'Niğde',
      serviceDateLabel = '',
      updateIntervalMinutes = 30,
      announcements = const [],
      total = 0,
      fetchedAt = '';

  factory AnnouncementData.fromJson(Map<dynamic, dynamic> json) {
    final meta = json['meta'] is Map ? json['meta'] as Map : const {};
    return AnnouncementData(
      city: _string(json['city'], fallback: 'Niğde'),
      serviceDateLabel: _string(json['serviceDateLabel']),
      updateIntervalMinutes: _int(json['updateIntervalMinutes'], 30),
      announcements: [
        for (final row
            in (json['announcements'] is List
                ? json['announcements'] as List
                : const []))
          if (row is Map) AnnouncementItem.fromJson(row),
      ],
      total: _int(meta['total'], 0),
      fetchedAt: _string(json['fetchedAt']),
      errorMessage: _string(json['error']),
    );
  }

  final String city;
  final String serviceDateLabel;
  final int updateIntervalMinutes;
  final List<AnnouncementItem> announcements;
  final int total;
  final String fetchedAt;
  final String errorMessage;

  bool get hasAnnouncements => announcements.isNotEmpty;
}

class AnnouncementsRepository {
  const AnnouncementsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 13);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<AnnouncementData> fetch() async {
    final uri = _uri('/api/app/announcements?city=nigde&limit=80');
    final client = httpClient ?? http.Client();
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return const AnnouncementData.empty();
      final data = AnnouncementData.fromJson(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AnnouncementData.empty(
          errorMessage: data.errorMessage.isEmpty
              ? 'Duyurular alınamadı'
              : data.errorMessage,
        );
      }
      return data;
    } catch (_) {
      return const AnnouncementData.empty(errorMessage: 'Duyurular alınamadı');
    } finally {
      if (httpClient == null) client.close();
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
