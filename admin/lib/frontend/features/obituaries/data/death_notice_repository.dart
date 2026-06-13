import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/frontend_http_client.dart';

import '../../../core/network/local_api_base_url.dart';

@immutable
class DeathNoticeData {
  const DeathNoticeData({
    required this.city,
    required this.source,
    required this.sourceUrl,
    required this.serviceDateLabel,
    required this.updateIntervalMinutes,
    required this.notices,
    required this.total,
    required this.fetchedAt,
    required this.errorMessage,
  });

  const DeathNoticeData.empty({this.errorMessage = ''})
    : city = 'Niğde',
      source = 'Niğde Belediyesi',
      sourceUrl = 'https://nigde.bel.tr/vefat-edenler',
      serviceDateLabel = '',
      updateIntervalMinutes = 30,
      notices = const [],
      total = 0,
      fetchedAt = '';

  factory DeathNoticeData.fromJson(Map<dynamic, dynamic> json) {
    return DeathNoticeData(
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
          if (row is Map) DeathNoticeItem.fromJson(row),
      ],
      total: _int(
        json['meta'] is Map ? (json['meta'] as Map)['total'] : null,
        0,
      ),
      fetchedAt: _string(json['fetchedAt']),
      errorMessage: _string(json['error']),
    );
  }

  final String city;
  final String source;
  final String sourceUrl;
  final String serviceDateLabel;
  final int updateIntervalMinutes;
  final List<DeathNoticeItem> notices;
  final int total;
  final String fetchedAt;
  final String errorMessage;

  bool get hasNotices => notices.isNotEmpty;
}

@immutable
class DeathNoticeItem {
  const DeathNoticeItem({
    required this.id,
    required this.name,
    required this.deathDateLabel,
    required this.prayerTime,
    required this.burialPlace,
    required this.description,
  });

  factory DeathNoticeItem.fromJson(Map<dynamic, dynamic> json) {
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

  String get routeLabel {
    final parts = [
      if (prayerTime.trim().isNotEmpty) _upperCaseTurkish(prayerTime),
      if (burialPlace.trim().isNotEmpty) _upperCaseTurkish(burialPlace),
    ];
    return parts.join(' · ');
  }

  String get shortDescription {
    final clean = description.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean;
  }
}

@immutable
class CondolenceDraft {
  const CondolenceDraft({
    required this.noticeId,
    required this.noticeName,
    required this.message,
    this.guestName = '',
    this.guestEmail = '',
    this.authToken = '',
  });

  final String noticeId;
  final String noticeName;
  final String message;
  final String guestName;
  final String guestEmail;
  final String authToken;

  Map<String, Object?> toJson() {
    return {
      'noticeId': noticeId,
      'noticeName': noticeName,
      'message': message,
      'guestName': guestName,
      'guestEmail': guestEmail,
    };
  }
}

class DeathNoticeRepository {
  const DeathNoticeRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _fetchTimeout = Duration(seconds: 13);
  static const _submitTimeout = Duration(seconds: 10);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<DeathNoticeData> fetch({bool forceRefresh = false}) async {
    final uri = _uri(
      '/api/app/death-notices?city=nigde${forceRefresh ? '&refresh=1' : ''}',
    );
    final client = httpClient ?? sharedFrontendClient;
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_fetchTimeout);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return const DeathNoticeData.empty();
      final data = DeathNoticeData.fromJson(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return DeathNoticeData.empty(
          errorMessage: data.errorMessage.isEmpty
              ? 'Ölüm ilanları alınamadı'
              : data.errorMessage,
        );
      }
      return data;
    } catch (_) {
      return const DeathNoticeData.empty(
        errorMessage: 'Ölüm ilanları alınamadı',
      );
    } finally {
      // Shared frontend client is not closed.
    }
  }

  Future<bool> submitCondolence(CondolenceDraft draft) async {
    final client = httpClient ?? sharedFrontendClient;
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (draft.authToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${draft.authToken.trim()}',
    };
    try {
      final response = await client
          .post(
            _uri('/api/app/death-notices/condolences'),
            headers: headers,
            body: jsonEncode(draft.toJson()),
          )
          .timeout(_submitTimeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
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
  final parsed = int.tryParse(value?.toString() ?? '');
  return parsed ?? fallback;
}

String _upperCaseTurkish(String value) {
  final clean = value.trim();
  return clean.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}
