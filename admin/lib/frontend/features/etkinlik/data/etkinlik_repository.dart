import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/local_api_base_url.dart';
import '../../home/data/home_repository.dart';
import 'etkinlik_mock.dart';

class EtkinlikRepository {
  const EtkinlikRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 12);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<List<EtkinlikEvent>> fetch({String lang = 'tr'}) async {
    final uri = _uri(
      '/api/app/events',
    ).replace(queryParameters: {'lang': lang, 'limit': '30'});
    final client = httpClient ?? http.Client();
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      return compute(_parseEvents, utf8.decode(response.bodyBytes));
    } catch (_) {
      return const [];
    } finally {
      if (httpClient == null) client.close();
    }
  }

  Uri _uri(String path) {
    return frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);
  }
}

List<EtkinlikEvent> _parseEvents(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) return const [];
  final rawItems = decoded['items'];
  if (rawItems is! List) return const [];
  final events = <EtkinlikEvent>[];
  for (final item in rawItems) {
    if (item is! Map) continue;
    final event = _mapEvent(item);
    if (event != null) events.add(event);
  }
  events.sort((a, b) => a.date.compareTo(b.date));
  return events;
}

EtkinlikEvent? _mapEvent(Map<dynamic, dynamic> json) {
  final date = _parseEventDate(_str(json['startDateTime']));
  if (date == null) return null;
  final title = _str(json['title']);
  if (title.isEmpty) return null;
  final ticketPrice = _str(json['ticketPrice']);
  final registrationType = _str(json['registrationType']).toLowerCase();
  final free = _isFree(ticketPrice);
  return EtkinlikEvent(
    date: date,
    category: EtkinlikCategoryInfo.fromApi(json['category']),
    title: title,
    venue: _firstNonEmpty([
      _str(json['venueName']),
      _str(json['address']),
      'Mekan bilgisi yok',
    ]),
    time: _eventTimeLabel(date, _str(json['startDateTime'])),
    free: free,
    priceLabel: free
        ? ''
        : _firstNonEmpty([
            ticketPrice,
            registrationType == 'none' ? 'Bilgi yok' : 'Kayıt gerekli',
          ]),
    summary: _str(json['summary']),
    organizer: _str(json['organizer']),
    address: _str(json['address']),
    imageUrl: _str(json['imageUrl']),
    article: json['article'] is Map
        ? HomeRepository.mapArticle(json['article'] as Map)
        : null,
  );
}

DateTime? _parseEventDate(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  final trMatch = RegExp(
    r'^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:\s+(\d{1,2}):(\d{2}))?',
  ).firstMatch(raw);
  if (trMatch != null) {
    final day = int.tryParse(trMatch.group(1) ?? '');
    final month = int.tryParse(trMatch.group(2) ?? '');
    final year = int.tryParse(trMatch.group(3) ?? '');
    final hour = int.tryParse(trMatch.group(4) ?? '') ?? 0;
    final minute = int.tryParse(trMatch.group(5) ?? '') ?? 0;
    if (day != null && month != null && year != null) {
      return DateTime(year, month, day, hour, minute);
    }
  }
  return DateTime.tryParse(raw);
}

String _eventTimeLabel(DateTime date, String rawDate) {
  final hasExplicitTime =
      RegExp(r'\b\d{1,2}:\d{2}\b').hasMatch(rawDate) ||
      (rawDate.contains('T') && (date.hour != 0 || date.minute != 0));
  if (!hasExplicitTime) return 'Saat belirtilmedi';
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

bool _isFree(String value) {
  final clean = value.toLowerCase();
  return clean.contains('ücretsiz') ||
      clean.contains('ucretsiz') ||
      clean == '0' ||
      clean == '0 tl' ||
      clean == '0 ₺';
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    final clean = value.trim();
    if (clean.isNotEmpty) return clean;
  }
  return '';
}

String _str(Object? value) => (value ?? '').toString().trim();
