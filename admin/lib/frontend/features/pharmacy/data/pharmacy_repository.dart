import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/frontend_http_client.dart';

import '../../../core/network/local_api_base_url.dart';

@immutable
class DutyPharmacyData {
  const DutyPharmacyData({
    required this.city,
    required this.source,
    required this.sourceUrl,
    required this.serviceDateLabel,
    required this.updateIntervalMinutes,
    required this.districts,
    required this.pharmacies,
    required this.total,
    required this.fetchedAt,
    required this.errorMessage,
  });

  const DutyPharmacyData.empty({this.errorMessage = ''})
    : city = 'Niğde',
      source = 'Niğde Eczacı Odası',
      sourceUrl = 'https://www.neo.org.tr/nobetci-eczaneler',
      serviceDateLabel = '',
      updateIntervalMinutes = 15,
      districts = const [],
      pharmacies = const [],
      total = 0,
      fetchedAt = '';

  factory DutyPharmacyData.fromJson(Map<dynamic, dynamic> json) {
    return DutyPharmacyData(
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
          if (row is Map) DutyPharmacyItem.fromJson(row),
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
  final List<String> districts;
  final List<DutyPharmacyItem> pharmacies;
  final int total;
  final String fetchedAt;
  final String errorMessage;

  bool get hasPharmacies => pharmacies.isNotEmpty;

  DutyPharmacyItem? get primaryPharmacy {
    for (final pharmacy in pharmacies) {
      if (pharmacy.district.toUpperCase() == 'MERKEZ') return pharmacy;
    }
    return pharmacies.isEmpty ? null : pharmacies.first;
  }

  String get districtSummary {
    if (districts.isEmpty) return 'Niğde';
    if (districts.length == 1) return _formatDistrict(districts.first);
    return '${districts.length} ilçe';
  }
}

@immutable
class DutyPharmacyItem {
  const DutyPharmacyItem({
    required this.id,
    required this.name,
    required this.district,
    required this.address,
    required this.phone,
    required this.phoneHref,
    required this.mapUrl,
    required this.directionUrl,
    required this.note,
    required this.isUntilMidnight,
  });

  factory DutyPharmacyItem.fromJson(Map<dynamic, dynamic> json) {
    return DutyPharmacyItem(
      id: _string(json['id']),
      name: _string(json['name']),
      district: _string(json['district'], fallback: 'MERKEZ'),
      address: _string(json['address']),
      phone: _string(json['phone']),
      phoneHref: _string(json['phoneHref']),
      mapUrl: _string(json['mapUrl']),
      directionUrl: _string(json['directionUrl']),
      note: _string(json['note']),
      isUntilMidnight: json['isUntilMidnight'] == true,
    );
  }

  final String id;
  final String name;
  final String district;
  final String address;
  final String phone;
  final String phoneHref;
  final String mapUrl;
  final String directionUrl;
  final String note;
  final bool isUntilMidnight;

  String get displayDistrict => _formatDistrict(district);

  String get dutyLabel {
    if (isUntilMidnight) return "Gece 00:00'a kadar nöbetçi";
    final cleanNote = note
        .replaceAll('!', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleanNote.isNotEmpty ? cleanNote : 'Bugün nöbetçi';
  }

  String get statusLabel => isUntilMidnight ? '00:00' : 'AÇIK';

  String get callUrl {
    final digits = (phoneHref.isNotEmpty ? phoneHref : phone).replaceAll(
      RegExp(r'\D'),
      '',
    );
    return digits.isEmpty ? '' : 'tel:$digits';
  }

  String get routeUrl {
    if (directionUrl.isNotEmpty) return directionUrl;
    return mapUrl;
  }
}

class PharmacyRepository {
  const PharmacyRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 13);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<DutyPharmacyData> fetch({bool forceRefresh = false}) async {
    final uri = _uri(
      '/api/app/duty-pharmacies?city=nigde${forceRefresh ? '&refresh=1' : ''}',
    );
    final client = httpClient ?? sharedFrontendClient;
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return const DutyPharmacyData.empty();
      final data = DutyPharmacyData.fromJson(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return DutyPharmacyData.empty(
          errorMessage: data.errorMessage.isEmpty
              ? 'Nöbetçi eczaneler alınamadı'
              : data.errorMessage,
        );
      }
      return data;
    } catch (_) {
      return const DutyPharmacyData.empty(
        errorMessage: 'Nöbetçi eczaneler alınamadı',
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
  final parsed = int.tryParse(value?.toString() ?? '');
  return parsed ?? fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (_string(item).isNotEmpty) _string(item),
  ];
}

String _formatDistrict(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return 'Merkez';
  const knownDistricts = {
    'MERKEZ': 'Merkez',
    'ALTUNHİSAR': 'Altunhisar',
    'BOR': 'Bor',
    'ÇAMARDI': 'Çamardı',
    'ÇİFTLİK': 'Çiftlik',
    'ULUKIŞLA': 'Ulukışla',
  };
  final known = knownDistricts[clean.toUpperCase()];
  if (known != null) return known;
  final lower = clean.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}
