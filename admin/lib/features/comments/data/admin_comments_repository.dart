import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';
import '../presentation/comments_models.dart';

abstract class AdminCommentsRepository {
  Future<AdminCommentMetricData> fetchMetrics();

  Future<AdminCommentFilterOptions> fetchFilterOptions();

  Future<AdminCommentsPageResult> fetchComments({
    required String search,
    required String status,
    required String postId,
    required String userId,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  });

  Future<void> approveComment(String commentId);

  Future<void> rejectComment(String commentId);

  Future<void> togglePinned({required String commentId, required bool pinned});

  Future<void> deleteComment(String commentId);

  Future<void> deleteComments(List<String> commentIds);

  Future<void> replyToComment({
    required AdminSession session,
    required AdminComment comment,
    required String content,
  });
}

class SupabaseAdminCommentsRepository implements AdminCommentsRepository {
  const SupabaseAdminCommentsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 8);
  static const _all = 'Tümü';
  static const _reported = 'Reported';
  static const _guestFilterPrefix = 'guest:';

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminCommentMetricData> fetchMetrics() async {
    final result = await _postJson('/api/admin/query', {
      'kind': 'rpc',
      'name': 'get_admin_comment_stats',
    });
    _throwIfApiError(result, fallbackMessage: 'Yorum istatistikleri alınamadı');
    final data = result['data'];
    if (data is! Map) return _emptyMetrics;
    final item = _asStringKeyMap(data);
    return AdminCommentMetricData(
      total: _asInt(item['total']),
      approved: _asInt(item['approved']),
      pending: _asInt(item['pending']),
      rejected: _asInt(item['rejected']),
      totalChange: item['total_change']?.toString() ?? '+0%',
      approvedChange: item['approved_change']?.toString() ?? '+0%',
      pendingChange: item['pending_change']?.toString() ?? '+0%',
      rejectedChange: item['rejected_change']?.toString() ?? '+0%',
    );
  }

  @override
  Future<AdminCommentFilterOptions> fetchFilterOptions() async {
    final responses = await Future.wait([
      _postJson('/api/admin/query', {
        'table': 'admin_comment_details',
        'method': 'select',
        'select': 'post_id,post_title',
        'orders': [
          {'column': 'post_title', 'ascending': true},
        ],
      }),
      _postJson('/api/admin/query', {
        'table': 'admin_comment_details',
        'method': 'select',
        'select': 'user_id,user_name,guest_name,guest_email',
        'orders': [
          {'column': 'user_name', 'ascending': true},
        ],
      }),
    ]);

    for (final response in responses) {
      _throwIfApiError(response, fallbackMessage: 'Yorum filtreleri alınamadı');
    }

    return AdminCommentFilterOptions(
      posts: _uniqueFilterItems(
        responses[0]['data'],
        idKey: 'post_id',
        labelKeys: const ['post_title'],
        fallback: 'Unnamed Post',
      ),
      users: _uniqueCommentUserFilterItems(responses[1]['data']),
    );
  }

  @override
  Future<AdminCommentsPageResult> fetchComments({
    required String search,
    required String status,
    required String postId,
    required String userId,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final filters = <Map<String, Object?>>[];
    final term = _safeSearchTerm(search);
    if (term.isNotEmpty) {
      final pattern = '%$term%';
      filters.add({
        'type': 'or',
        'value':
            'content.ilike.$pattern,post_title.ilike.$pattern,user_name.ilike.$pattern',
      });
    }
    if (status == _reported) {
      filters.add({
        'type': 'comparison',
        'op': 'gt',
        'column': 'reports_count',
        'value': 0,
      });
    } else if (status != _all) {
      filters.add({
        'type': 'comparison',
        'op': 'eq',
        'column': 'status',
        'value': status,
      });
    }
    if (postId != _all) {
      filters.add({
        'type': 'comparison',
        'op': 'eq',
        'column': 'post_id',
        'value': _intOrString(postId),
      });
    }
    if (userId != _all) {
      final guestEmail = userId.startsWith(_guestFilterPrefix)
          ? userId.substring(_guestFilterPrefix.length)
          : '';
      filters.add({
        'type': 'comparison',
        'op': 'eq',
        'column': guestEmail.isNotEmpty ? 'guest_email' : 'user_id',
        'value': guestEmail.isNotEmpty ? guestEmail : userId,
      });
    }

    final safePage = page < 1 ? 1 : page;
    final from = (safePage - 1) * pageSize;
    final to = from + pageSize - 1;
    final result = await _postJson('/api/admin/query', {
      'table': 'admin_comment_details',
      'method': 'select',
      'select':
          'id,post_id,user_id,guest_name,guest_email,parent_id,content,status,is_pinned,likes_count,created_at,updated_at,post_title,user_name,user_avatar,replies_count,reports_count',
      'filters': filters,
      'orders': _commentOrders(sortKey, sortAscending),
      'range': {'from': from, 'to': to},
      'count': 'exact',
    });
    _throwIfApiError(result, fallbackMessage: 'Yorumlar alınamadı');

    final data = result['data'];
    final rows = data is List ? data.whereType<Map>().toList() : const <Map>[];
    return AdminCommentsPageResult(
      comments: [
        for (var index = 0; index < rows.length; index++)
          _commentFromJson(rows[index], from + index + 1),
      ],
      totalCount: _asInt(result['count']),
    );
  }

  @override
  Future<void> approveComment(String commentId) {
    return _updateCommentStatus(commentId, 'approved');
  }

  @override
  Future<void> rejectComment(String commentId) {
    return _updateCommentStatus(commentId, 'rejected');
  }

  @override
  Future<void> togglePinned({
    required String commentId,
    required bool pinned,
  }) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'comments',
      'method': 'update',
      'values': {'is_pinned': pinned},
      'filters': [_idFilter(commentId)],
    });
    _throwIfApiError(result, fallbackMessage: 'Yorum işlemi tamamlanamadı');
  }

  @override
  Future<void> deleteComment(String commentId) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'comments',
      'method': 'delete',
      'filters': [_idFilter(commentId)],
    });
    _throwIfApiError(result, fallbackMessage: 'Yorum silinemedi');
  }

  @override
  Future<void> deleteComments(List<String> commentIds) async {
    final ids = commentIds.map(int.tryParse).whereType<int>().toList();
    if (ids.isEmpty) return;
    final result = await _postJson('/api/admin/query', {
      'table': 'comments',
      'method': 'delete',
      'filters': [
        {'type': 'comparison', 'op': 'in', 'column': 'id', 'value': ids},
      ],
    });
    _throwIfApiError(result, fallbackMessage: 'Seçili yorumlar silinemedi');
  }

  @override
  Future<void> replyToComment({
    required AdminSession session,
    required AdminComment comment,
    required String content,
  }) async {
    final text = content.trim();
    if (text.isEmpty) return;
    final result = await _postJson('/api/admin/query', {
      'table': 'comments',
      'method': 'insert',
      'values': {
        'post_id': _intOrString(comment.postId),
        'user_id': session.user.id,
        'parent_id': _intOrString(comment.id),
        'content': text,
        'status': 'approved',
      },
    });
    _throwIfApiError(result, fallbackMessage: 'Yanıt gönderilemedi');
  }

  Future<void> _updateCommentStatus(String commentId, String status) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'comments',
      'method': 'update',
      'values': {'status': status},
      'filters': [_idFilter(commentId)],
    });
    _throwIfApiError(result, fallbackMessage: 'Yorum işlemi tamamlanamadı');
  }

  Map<String, Object?> _idFilter(String commentId) {
    return {
      'type': 'comparison',
      'op': 'eq',
      'column': 'id',
      'value': _intOrString(commentId),
    };
  }

  List<Map<String, Object?>> _commentOrders(String sortKey, bool ascending) {
    final column = switch (sortKey) {
      'id' => 'id',
      'comment' => 'content',
      'post' => 'post_title',
      'status' => 'status',
      'likes' => 'likes_count',
      'replies' => 'replies_count',
      'date' => 'created_at',
      _ => 'created_at',
    };
    return [
      {'column': 'is_pinned', 'ascending': false},
      {'column': column, 'ascending': ascending},
    ];
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
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
            .timeout(_requestTimeout);

    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminCommentsException('Geçersiz sunucu yanıtı');
    }

    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfApiError(result, fallbackMessage: 'Sunucu isteği başarısız');
    }
    return result;
  }

  Uri _uri(String path) {
    final baseUrl = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (baseUrl.isNotEmpty) return Uri.parse(baseUrl).resolve(path);
    if (!kIsWeb) return _defaultLocalApiBaseUrl().resolve(path);
    return Uri.base.resolve(path);
  }

  Uri _defaultLocalApiBaseUrl() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse('http://10.0.2.2:4321'),
      _ => Uri.parse('http://127.0.0.1:4321'),
    };
  }

  List<AdminCommentFilterItem> _uniqueFilterItems(
    Object? data, {
    required String idKey,
    required List<String> labelKeys,
    required String fallback,
  }) {
    if (data is! List) return const [];
    final byId = <String, String>{};
    for (final row in data.whereType<Map>()) {
      final item = _asStringKeyMap(row);
      final id = item[idKey]?.toString() ?? '';
      if (id.isEmpty || byId.containsKey(id)) continue;
      var label = '';
      for (final key in labelKeys) {
        label = item[key]?.toString().trim() ?? '';
        if (label.isNotEmpty) break;
      }
      byId[id] = label.isEmpty ? fallback : label;
    }
    return [
      for (final entry in byId.entries)
        AdminCommentFilterItem(id: entry.key, label: entry.value),
    ];
  }

  List<AdminCommentFilterItem> _uniqueCommentUserFilterItems(Object? data) {
    if (data is! List) return const [];
    final byId = <String, String>{};
    for (final row in data.whereType<Map>()) {
      final item = _asStringKeyMap(row);
      final userId = item['user_id']?.toString().trim() ?? '';
      if (userId.isNotEmpty) {
        final label = _firstNonEmpty(item, const ['user_name', 'guest_name']);
        byId[userId] = label.isEmpty ? 'Anonymous User' : label;
        continue;
      }

      final guestEmail = item['guest_email']?.toString().trim() ?? '';
      if (guestEmail.isEmpty) continue;
      final label = _firstNonEmpty(item, const [
        'guest_name',
        'user_name',
        'guest_email',
      ]);
      byId['$_guestFilterPrefix$guestEmail'] = label.isEmpty
          ? 'Misafir'
          : label;
    }
    return [
      for (final entry in byId.entries)
        AdminCommentFilterItem(id: entry.key, label: entry.value),
    ];
  }

  String _firstNonEmpty(Map<String, Object?> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  AdminComment _commentFromJson(Map<dynamic, dynamic> json, int rowNumber) {
    final item = _asStringKeyMap(json);
    return AdminComment(
      id: item['id']?.toString() ?? '',
      rowNumber: rowNumber,
      content: item['content']?.toString() ?? '',
      postId: item['post_id']?.toString() ?? '',
      userId: item['user_id']?.toString() ?? '',
      status: item['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(item['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(item['updated_at']?.toString() ?? ''),
      likesCount: _asInt(item['likes_count']),
      repliesCount: _asInt(item['replies_count']),
      reportsCount: _asInt(item['reports_count']),
      isPinned: item['is_pinned'] == true,
      postTitle: item['post_title']?.toString() ?? '',
      userName: item['user_name']?.toString() ?? '',
      userAvatar: item['user_avatar']?.toString() ?? '',
      guestName: item['guest_name']?.toString() ?? '',
      guestEmail: item['guest_email']?.toString() ?? '',
    );
  }

  String _safeSearchTerm(String value) {
    return value.trim().replaceAll(',', ' ');
  }

  Object _intOrString(String value) {
    return int.tryParse(value) ?? value;
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
        throw AdminCommentsException(message);
      }
    }
    throw AdminCommentsException(fallbackMessage);
  }
}

const _emptyMetrics = AdminCommentMetricData(
  total: 0,
  approved: 0,
  pending: 0,
  rejected: 0,
  totalChange: '+0%',
  approvedChange: '+0%',
  pendingChange: '+0%',
  rejectedChange: '+0%',
);

class AdminCommentsException implements Exception {
  const AdminCommentsException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
