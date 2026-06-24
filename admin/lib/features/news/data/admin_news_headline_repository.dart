import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

class AdminNewsHeadlineContext {
  const AdminNewsHeadlineContext({
    required this.title,
    required this.summary,
    required this.categoryPath,
    required this.publishedAt,
    required this.slug,
    required this.editorNotes,
  });

  final String title;
  final String summary;
  final String categoryPath;
  final String publishedAt;
  final String slug;
  final String editorNotes;

  Map<String, Object?> toJson() {
    return {
      'title': title.trim(),
      'summary': summary.trim(),
      'categoryPath': categoryPath.trim(),
      'publishedAt': publishedAt.trim(),
      'slug': slug.trim(),
      'editorNotes': editorNotes.trim(),
    };
  }
}

class AdminNewsHeadlineSource {
  const AdminNewsHeadlineSource({
    required this.mediaSrc,
    required this.originalUrl,
    required this.altText,
  });

  final String mediaSrc;
  final String originalUrl;
  final String altText;

  Map<String, Object?> toJson() {
    return {
      'mediaSrc': mediaSrc.trim(),
      'originalUrl': originalUrl.trim(),
      'altText': altText.trim(),
    };
  }
}

class AdminNewsHeadlinePlan {
  const AdminNewsHeadlinePlan({required this.json});

  factory AdminNewsHeadlinePlan.fromJson(Map<String, Object?> json) {
    return AdminNewsHeadlinePlan(json: Map<String, Object?>.from(json));
  }

  final Map<String, Object?> json;

  String get target => _text(json['target'], fallback: 'headline_square');
  String get templateId =>
      _text(json['templateId'], fallback: 'classic-red-yellow-blue');

  Map<String, Object?> get headline => _map(json['headline']);
  Map<String, Object?> get media => _map(json['media']);

  String get kicker => _text(headline['kicker']);
  String get top => _text(headline['top']);
  String get main => _text(headline['main']);
  String get bottom => _text(headline['bottom']);
  String get support => _text(headline['support']);
  String get tagline => _text(headline['tagline']);
  String get altText => _text(media['altText']);
  String get filenameStem => _text(media['filenameStem']);

  AdminNewsHeadlinePlan copyWithText({
    required String kicker,
    required String top,
    required String main,
    required String bottom,
    required String support,
    required String tagline,
    required String altText,
  }) {
    final next = Map<String, Object?>.from(json);
    next['headline'] = {
      ...headline,
      'kicker': kicker.trim(),
      'top': top.trim(),
      'main': main.trim(),
      'bottom': bottom.trim(),
      'support': support.trim(),
      'tagline': tagline.trim(),
    };
    next['media'] = {...media, 'altText': altText.trim()};
    return AdminNewsHeadlinePlan(json: next);
  }
}

class AdminNewsHeadlinePreview {
  const AdminNewsHeadlinePreview({
    required this.bytes,
    required this.contentType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String contentType;
  final String fileName;
}

class AdminNewsHeadlineException implements Exception {
  const AdminNewsHeadlineException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AdminNewsHeadlineRepository {
  Future<AdminNewsHeadlinePlan> generatePlan({
    required String languageCode,
    required String promptId,
    required String target,
    required AdminNewsHeadlineContext context,
    required AdminNewsHeadlineSource source,
  });

  Future<AdminNewsHeadlinePreview> renderPreview({
    required String languageCode,
    required String target,
    required AdminNewsHeadlineContext context,
    required AdminNewsHeadlineSource source,
    required AdminNewsHeadlinePlan plan,
  });
}

class HttpAdminNewsHeadlineRepository implements AdminNewsHeadlineRepository {
  const HttpAdminNewsHeadlineRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 60);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminNewsHeadlinePlan> generatePlan({
    required String languageCode,
    required String promptId,
    required String target,
    required AdminNewsHeadlineContext context,
    required AdminNewsHeadlineSource source,
  }) async {
    final response = await _post('/api/admin/news/headline-plan', {
      'languageCode': languageCode,
      'promptId': promptId,
      'target': target,
      'context': context.toJson(),
      'source': source.toJson(),
    });
    final data = _decodeResponse(response);
    final plan = data['plan'];
    if (plan is! Map) {
      throw const AdminNewsHeadlineException('Manşet planı alınamadı.');
    }
    return AdminNewsHeadlinePlan.fromJson(_stringKeyMap(plan));
  }

  @override
  Future<AdminNewsHeadlinePreview> renderPreview({
    required String languageCode,
    required String target,
    required AdminNewsHeadlineContext context,
    required AdminNewsHeadlineSource source,
    required AdminNewsHeadlinePlan plan,
  }) async {
    final response = await _post('/api/admin/news/headline-render', {
      'languageCode': languageCode,
      'target': target,
      'context': context.toJson(),
      'source': source.toJson(),
      'plan': plan.json,
    });
    final data = _decodeResponse(response);
    final base64Bytes = _text(data['base64']);
    if (base64Bytes.isEmpty) {
      throw const AdminNewsHeadlineException('Manşet önizlemesi alınamadı.');
    }
    return AdminNewsHeadlinePreview(
      bytes: base64Decode(base64Bytes),
      contentType: _text(data['contentType'], fallback: 'image/webp'),
      fileName: _text(data['fileName'], fallback: 'manset.webp'),
    );
  }

  Future<http.Response> _post(String path, Map<String, Object?> body) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      return await client
          .post(
            _resolve(path),
            headers: await adminJsonHeaders(),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } finally {
      if (closeClient) client.close();
    }
  }

  Map<String, Object?> _decodeResponse(http.Response response) {
    final decoded = response.body.trim().isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map ? _text(decoded['error']) : '';
      throw AdminNewsHeadlineException(
        error.isEmpty ? 'Manşet işlemi başarısız oldu.' : error,
      );
    }
    if (decoded is! Map) {
      throw const AdminNewsHeadlineException('Geçersiz manşet yanıtı.');
    }
    return _stringKeyMap(decoded);
  }

  Uri _resolve(String path) {
    final configured = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (configured.isNotEmpty) return Uri.parse(configured).resolve(path);
    return Uri.base.resolve(path);
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) return _stringKeyMap(value);
  return const <String, Object?>{};
}

Map<String, Object?> _stringKeyMap(Map value) {
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
