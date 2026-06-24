import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';
import 'package:pateeznews_admin/shared/widgets/highlighted_text.dart';

import '../presentation/subscribers_models.dart';

abstract class AdminSubscribersRepository {
  Future<AdminSubscribersPageResult> fetchSubscribers({
    required String search,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  });

  Future<AdminSubscriber> saveSubscriber({
    String? id,
    required SubscriberFormData data,
  });

  Future<void> toggleStatus(AdminSubscriber subscriber);

  Future<void> deleteSubscriber(String subscriberId);

  Future<void> deleteSubscribers(List<String> subscriberIds);
}

class SupabaseAdminSubscribersRepository implements AdminSubscribersRepository {
  const SupabaseAdminSubscribersRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminSubscribersPageResult> fetchSubscribers({
    required String search,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final term = _safeSearchTerm(search);
    if (term.isEmpty) {
      return _fetchSubscribersPage(
        searchFilter: null,
        page: page,
        pageSize: pageSize,
        sortKey: sortKey,
        sortAscending: sortAscending,
      );
    }
    // Haberler ile AYNI teknoloji: normalize (Türkçe-duyarsız) + trigram'lı
    // admin_search_text. Şema/sürüm güncel değilse eski ham filtreye düşeriz.
    try {
      return await _fetchSubscribersPage(
        searchFilter: _normalizedSearchFilter(term),
        page: page,
        pageSize: pageSize,
        sortKey: sortKey,
        sortAscending: sortAscending,
      );
    } catch (_) {
      return _fetchSubscribersPage(
        searchFilter: _legacySearchFilter(term),
        page: page,
        pageSize: pageSize,
        sortKey: sortKey,
        sortAscending: sortAscending,
      );
    }
  }

  Map<String, Object?> _normalizedSearchFilter(String term) {
    final pattern =
        '%${normalizeSearchText(term).replaceAll(',', ' ').trim()}%';
    return {'type': 'or', 'value': 'admin_search_text.ilike.$pattern'};
  }

  Map<String, Object?> _legacySearchFilter(String term) {
    final pattern = '%$term%';
    return {
      'type': 'or',
      'value':
          'full_name.ilike.$pattern,email.ilike.$pattern,phone.ilike.$pattern,ip_address.ilike.$pattern,city.ilike.$pattern,status.ilike.$pattern,source.ilike.$pattern',
    };
  }

  Future<AdminSubscribersPageResult> _fetchSubscribersPage({
    required Map<String, Object?>? searchFilter,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final from = (safePage - 1) * pageSize;
    final to = from + pageSize - 1;
    final result = await _postJson('/api/admin/query', {
      'table': 'newsletter_subscribers',
      'method': 'select',
      'select':
          'id,email,full_name,phone,ip_address,city,language_code,source,status,created_at,updated_at',
      'filters': [?searchFilter],
      'orders': _subscriberOrders(sortKey, sortAscending),
      'range': {'from': from, 'to': to},
      'count': 'exact',
    });
    _throwIfApiError(result, fallbackMessage: 'Aboneler alınamadı');

    final rows = result['data'] is List
        ? (result['data'] as List).whereType<Map>().toList()
        : const <Map>[];
    return AdminSubscribersPageResult(
      subscribers: [for (final row in rows) _subscriberFromJson(row)],
      totalCount: _asInt(result['count']),
    );
  }

  @override
  Future<AdminSubscriber> saveSubscriber({
    String? id,
    required SubscriberFormData data,
  }) async {
    final subscriberId = id?.trim();
    final isUpdate = subscriberId != null && subscriberId.isNotEmpty;
    final payload = _payload(data, includeCreateFields: !isUpdate);
    final result = await _postJson('/api/admin/query', {
      'table': 'newsletter_subscribers',
      'method': isUpdate ? 'update' : 'insert',
      'values': payload,
      if (isUpdate) 'filters': [_idFilter(subscriberId)],
      'single': 'maybeSingle',
    });
    _throwIfApiError(
      result,
      fallbackMessage: isUpdate ? 'Abone güncellenemedi' : 'Abone eklenemedi',
    );
    final row = result['data'];
    if (row is Map) return _subscriberFromJson(row);
    throw const AdminSubscribersException('Abone kaydedilemedi');
  }

  @override
  Future<void> toggleStatus(AdminSubscriber subscriber) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'newsletter_subscribers',
      'method': 'update',
      'values': {
        'status': subscriber.active ? 'passive' : 'active',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      'filters': [_idFilter(subscriber.id)],
    });
    _throwIfApiError(result, fallbackMessage: 'Abone durumu güncellenemedi');
  }

  @override
  Future<void> deleteSubscriber(String subscriberId) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'newsletter_subscribers',
      'method': 'delete',
      'filters': [_idFilter(subscriberId)],
    });
    _throwIfApiError(result, fallbackMessage: 'Abone silinemedi');
  }

  @override
  Future<void> deleteSubscribers(List<String> subscriberIds) async {
    if (subscriberIds.isEmpty) return;
    final result = await _postJson('/api/admin/query', {
      'table': 'newsletter_subscribers',
      'method': 'delete',
      'filters': [
        {
          'type': 'comparison',
          'op': 'in',
          'column': 'id',
          'value': subscriberIds,
        },
      ],
    });
    _throwIfApiError(result, fallbackMessage: 'Seçili aboneler silinemedi');
  }

  Map<String, Object?> _payload(
    SubscriberFormData data, {
    required bool includeCreateFields,
  }) {
    return {
      'email': data.email.trim().toLowerCase(),
      'full_name': data.fullName.trim(),
      'phone': data.phone.trim(),
      'status': data.active ? 'active' : 'passive',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (includeCreateFields) 'language_code': 'tr',
      if (includeCreateFields) 'source': 'admin',
    };
  }

  List<Map<String, Object?>> _subscriberOrders(String sortKey, bool ascending) {
    final column = switch (sortKey) {
      'name' => 'full_name',
      'email' => 'email',
      'phone' => 'phone',
      'ip' => 'ip_address',
      'city' => 'city',
      'status' => 'status',
      'date' => 'created_at',
      _ => 'created_at',
    };
    return [
      {'column': column, 'ascending': ascending},
    ];
  }

  AdminSubscriber _subscriberFromJson(Map<dynamic, dynamic> json) {
    final email = json['email']?.toString() ?? '';
    final fullName = _decodeText(json['full_name']);
    return AdminSubscriber(
      id: json['id']?.toString() ?? '',
      fullName: fullName.isNotEmpty ? fullName : _nameFromEmail(email),
      email: email,
      phone: _decodeText(json['phone']),
      ipAddress: _decodeText(json['ip_address']),
      city: _decodeText(json['city']),
      active: json['status']?.toString().trim().toLowerCase() == 'active',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      languageCode: json['language_code']?.toString() ?? 'tr',
      source: json['source']?.toString() ?? 'site',
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      final uri = _resolveUri(path);
      final response = await client
          .post(uri, headers: await adminJsonHeaders(), body: jsonEncode(body))
          .timeout(_requestTimeout);
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const AdminSubscribersException('Geçersiz sunucu yanıtı');
    } on TimeoutException {
      throw const AdminSubscribersException(
        'Sunucu yanıtı zaman aşımına uğradı',
      );
    } finally {
      if (closeClient) client.close();
    }
  }

  Uri _resolveUri(String path) {
    final configured = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (configured.isNotEmpty && !isLocalAdminApiBaseUrl(configured))
      return Uri.parse(configured).resolve(path);
    return Uri.parse('https://pateez.com').resolve(path);
  }

  Map<String, Object?> _idFilter(String subscriberId) {
    return {
      'type': 'comparison',
      'op': 'eq',
      'column': 'id',
      'value': subscriberId,
    };
  }

  String _safeSearchTerm(String value) {
    return value
        .trim()
        .replaceAll('%', r'\%')
        .replaceAll(',', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _parseDate(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _decodeText(Object? value) {
    if (value == null) return '';
    final text = value.toString();
    try {
      return utf8.decode(latin1.encode(text)).trim();
    } catch (_) {
      return text.trim();
    }
  }

  String _nameFromEmail(String email) {
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return email;
    return localPart
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part.substring(0, 1).toUpperCase() + part.substring(1))
        .join(' ');
  }

  void _throwIfApiError(
    Map<String, dynamic> result, {
    required String fallbackMessage,
  }) {
    final error = result['error'];
    if (error == null) return;
    if (error is Map && error['message'] != null) {
      throw AdminSubscribersException(error['message'].toString());
    }
    throw AdminSubscribersException(fallbackMessage);
  }
}

class AdminSubscribersException implements Exception {
  const AdminSubscribersException(this.message);

  final String message;

  @override
  String toString() => message;
}
