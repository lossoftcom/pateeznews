import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/mock/home_mock_data.dart';
import '../../../core/network/local_api_base_url.dart';

class NewsCommentsException implements Exception {
  const NewsCommentsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NewsCommentsRepository {
  const NewsCommentsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<List<NewsComment>> fetchComments({
    required String postId,
    String? token,
    int limit = 2,
  }) async {
    final result = await _postJson({
      'action': 'list',
      'postId': postId,
      'token': token,
      'limit': limit,
    });
    _throwIfApiError(result, fallbackMessage: 'Yorumlar alınamadı');
    return _parseComments(result['comments']);
  }

  Future<void> submitComment({
    required String postId,
    required String content,
    String? token,
    String? guestName,
    String? guestEmail,
    String? parentId,
  }) async {
    final result = await _postJson({
      'action': 'submit',
      'postId': postId,
      'content': content,
      'token': token,
      'guestName': guestName,
      'guestEmail': guestEmail,
      'parentId': parentId,
    });
    _throwIfApiError(result, fallbackMessage: 'Yorum gönderilemedi');
  }

  Future<List<NewsComment>> toggleLike({
    required String postId,
    required String commentId,
    required String token,
    int limit = 2,
  }) async {
    final result = await _postJson({
      'action': 'toggle_like',
      'postId': postId,
      'commentId': commentId,
      'token': token,
      'limit': limit,
    });
    _throwIfApiError(result, fallbackMessage: 'Yorum beğenilemedi');
    return _parseComments(result['comments']);
  }

  Future<List<NewsComment>> deleteComment({
    required String postId,
    required String commentId,
    required String token,
    int limit = 2,
  }) async {
    final result = await _postJson({
      'action': 'delete',
      'postId': postId,
      'commentId': commentId,
      'token': token,
      'limit': limit,
    });
    _throwIfApiError(result, fallbackMessage: 'Yorum silinemedi');
    return _parseComments(result['comments']);
  }

  Future<Map<String, Object?>> _postJson(Map<String, Object?> body) async {
    final client = httpClient ?? http.Client();
    try {
      final response = await client
          .post(
            _uri('/api/app/comments'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      final decoded = response.bodyBytes.isEmpty
          ? <String, Object?>{}
          : jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw const NewsCommentsException('Geçersiz sunucu yanıtı');
      }
      final result = _asStringMap(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _throwIfApiError(result, fallbackMessage: 'Sunucu isteği başarısız');
      }
      return result;
    } finally {
      if (httpClient == null) client.close();
    }
  }

  Uri _uri(String path) =>
      frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);
}

List<NewsComment> _parseComments(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) _parseComment(_asStringMap(item)),
  ];
}

NewsComment _parseComment(Map<String, Object?> json) {
  final authorJson = _asStringMap(json['author']);
  return NewsComment(
    id: _str(json['id']),
    parentId: _str(json['parentId']),
    author: NewsAuthor(
      name: _str(authorJson['name'], fallback: 'Misafir'),
      avatarUrl: _str(authorJson['avatarUrl']),
      handle: _nullableStr(authorJson['handle']),
      isVerified: _bool(authorJson['isVerified']),
      isOfficial: _bool(authorJson['isOfficial']),
    ),
    body: _str(json['body']),
    publishedAt: DateTime.tryParse(_str(json['publishedAt'])) ?? DateTime.now(),
    likes: _int(json['likes']),
    userLiked: _bool(json['userLiked']),
    canDelete: _bool(json['canDelete']),
    replies: _parseComments(json['replies']),
  );
}

void _throwIfApiError(
  Map<String, Object?> result, {
  required String fallbackMessage,
}) {
  final error = result['error'];
  if (error == null) return;
  if (error is Map) {
    final message = error['message']?.toString();
    if (message != null && message.trim().isNotEmpty) {
      throw NewsCommentsException(message);
    }
  }
  throw NewsCommentsException(fallbackMessage);
}

Map<String, Object?> _asStringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}

String _str(Object? value, {String fallback = ''}) {
  final result = (value ?? '').toString().trim();
  return result.isEmpty ? fallback : result;
}

String? _nullableStr(Object? value) {
  final result = _str(value);
  return result.isEmpty ? null : result;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _bool(Object? value) => value == true || value?.toString() == 'true';
