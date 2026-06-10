import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/local_api_base_url.dart';

class PostActionException implements Exception {
  const PostActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PostActionState {
  const PostActionState({
    required this.likes,
    required this.dislikes,
    required this.shares,
    required this.views,
    required this.saves,
    required this.liked,
    required this.disliked,
    required this.saved,
  });

  final int likes;
  final int dislikes;
  final int shares;
  final int views;
  final int saves;
  final bool liked;
  final bool disliked;
  final bool saved;

  factory PostActionState.fromJson(Map<String, Object?> json) {
    final counts = _asStringMap(json['counts']);
    final userState = _asStringMap(json['userState']);
    return PostActionState(
      likes: _nonNegativeInt(counts['likes']),
      dislikes: _nonNegativeInt(counts['dislikes']),
      shares: _nonNegativeInt(counts['shares']),
      views: _nonNegativeInt(counts['views']),
      saves: _nonNegativeInt(counts['saves']),
      liked: _bool(userState['liked']),
      disliked: _bool(userState['disliked']),
      saved: _bool(userState['saved']),
    );
  }
}

class PostActionRepository {
  const PostActionRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 8);
  static const _viewerIdKey = 'pateeznews_mobile_viewer_id';
  static final math.Random _viewerIdRandom = math.Random.secure();

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<PostActionState> toggleLike({
    required String postId,
    required String token,
  }) {
    return _sendStateAction(
      action: 'toggle_like',
      postId: postId,
      token: token,
    );
  }

  Future<PostActionState> toggleDislike({
    required String postId,
    required String token,
  }) {
    return _sendStateAction(
      action: 'toggle_dislike',
      postId: postId,
      token: token,
    );
  }

  Future<PostActionState> toggleSave({
    required String postId,
    required String token,
  }) {
    return _sendStateAction(
      action: 'toggle_save',
      postId: postId,
      token: token,
    );
  }

  Future<PostActionState> share({
    required String postId,
    String? token,
    String platform = 'share',
  }) {
    return _sendStateAction(
      action: 'share',
      postId: postId,
      token: token,
      extraBody: {'platform': platform},
    );
  }

  Future<PostActionState> recordView({
    required String postId,
    String? token,
    String source = 'read',
  }) async {
    return _sendStateAction(
      action: 'view',
      postId: postId,
      token: token,
      extraBody: {'source': source, 'viewerId': await _viewerId()},
    );
  }

  Future<PostActionState> recordVideoView({
    required String postId,
    required String videoUrl,
    String? token,
    String source = 'video',
    int watchedSeconds = 0,
    int? durationSeconds,
    int? thresholdSeconds,
  }) async {
    return _sendStateAction(
      action: 'video_view',
      postId: postId,
      token: token,
      extraBody: {
        'source': source,
        'viewerId': await _viewerId(),
        'videoUrl': videoUrl,
        'watchedSeconds': watchedSeconds < 0 ? 0 : watchedSeconds,
        if (durationSeconds != null)
          'durationSeconds': durationSeconds < 0 ? 0 : durationSeconds,
        if (thresholdSeconds != null)
          'thresholdSeconds': thresholdSeconds < 0 ? 0 : thresholdSeconds,
      },
    );
  }

  Future<PostActionState> _sendStateAction({
    required String action,
    required String postId,
    String? token,
    Map<String, Object?> extraBody = const {},
  }) async {
    final result = await _postJson({
      'action': action,
      'postId': postId,
      if (token != null && token.trim().isNotEmpty) 'token': token.trim(),
      ...extraBody,
    }, token: token);
    _throwIfApiError(result, fallbackMessage: 'İşlem tamamlanamadı');
    return PostActionState.fromJson(result);
  }

  Future<Map<String, Object?>> _postJson(
    Map<String, Object?> body, {
    String? token,
  }) async {
    final client = httpClient ?? http.Client();
    final authToken = token?.trim() ?? '';
    try {
      final response = await client
          .post(
            _uri('/api/app/post-action'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=UTF-8',
              if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      final decoded = response.bodyBytes.isEmpty
          ? <String, Object?>{}
          : jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw const PostActionException('Geçersiz sunucu yanıtı');
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

  Future<String> _viewerId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_viewerIdKey)?.trim();
    if (existing != null && existing.length >= 8) return existing;
    final random = List<String>.generate(
      16,
      (_) => _viewerIdRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
      growable: false,
    ).join();
    final generated = 'mobile-${DateTime.now().microsecondsSinceEpoch}-$random';
    await prefs.setString(_viewerIdKey, generated);
    return generated;
  }
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
      throw PostActionException(message);
    }
  }
  throw PostActionException(fallbackMessage);
}

Map<String, Object?> _asStringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}

int _nonNegativeInt(Object? value) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 0;
  return parsed < 0 ? 0 : parsed;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}
