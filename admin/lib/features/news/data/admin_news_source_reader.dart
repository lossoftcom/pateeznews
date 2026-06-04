import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class AdminNewsSourceArticle {
  const AdminNewsSourceArticle({
    required this.url,
    required this.title,
    required this.description,
    required this.author,
    required this.publishedAt,
    required this.bodyText,
  });

  final String url;
  final String title;
  final String description;
  final String author;
  final String publishedAt;
  final String bodyText;

  String get topicHint => title.isNotEmpty ? title : _firstUsefulLine(bodyText);

  String toPromptBlock() {
    final lines = <String>[
      'Kaynak URL: $url',
      if (title.isNotEmpty) 'Kaynak başlık: $title',
      if (description.isNotEmpty) 'Kaynak açıklama: $description',
      if (publishedAt.isNotEmpty) 'Yayın tarihi: $publishedAt',
      if (author.isNotEmpty) 'Yazar/Kaynak: $author',
      'Kaynak metni:',
      bodyText,
    ];
    return lines.where((line) => line.trim().isNotEmpty).join('\n');
  }
}

class AdminNewsSourceReadException implements Exception {
  const AdminNewsSourceReadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminNewsSourceReader {
  const AdminNewsSourceReader({this.httpClient});

  static const _timeout = Duration(seconds: 18);
  static const _maxPromptChars = 14000;

  final http.Client? httpClient;

  Future<AdminNewsSourceArticle> read(String rawUrl) async {
    final uri = _normalizeHttpUri(rawUrl);
    final response = await _fetch(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AdminNewsSourceReadException(
        'Link okunamadı. HTTP ${response.statusCode}.',
      );
    }

    final html = _decodeResponseBody(response);
    final document = html_parser.parse(html);
    _removeNoise(document);

    final structured = _extractStructuredArticle(html, document);
    final title = _firstNonEmpty([
      structured.title,
      _metaContent(document, 'meta[property="og:title"]'),
      _metaContent(document, 'meta[name="twitter:title"]'),
      document.querySelector('h1')?.text,
      document.querySelector('title')?.text,
    ]);
    final description = _firstNonEmpty([
      structured.description,
      _metaContent(document, 'meta[property="og:description"]'),
      _metaContent(document, 'meta[name="description"]'),
      _metaContent(document, 'meta[name="twitter:description"]'),
    ]);
    final bodyText = _cleanBodyText(
      _firstNonEmpty([structured.bodyText, _extractMainText(document)]),
    );

    if (bodyText.length < 80) {
      throw const AdminNewsSourceReadException(
        'Linkten yeterli haber metni çıkarılamadı.',
      );
    }

    return AdminNewsSourceArticle(
      url: uri.toString(),
      title: _cleanLine(title),
      description: _cleanLine(description),
      author: _cleanLine(structured.author),
      publishedAt: _cleanLine(structured.publishedAt),
      bodyText: bodyText,
    );
  }

  Future<http.Response> _fetch(Uri uri) async {
    final headers = {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'User-Agent':
          'PateezNewsAdmin/1.0 (+https://pateeznews.com) AppleWebKit/605.1.15',
    };
    try {
      final request = httpClient?.get(uri, headers: headers);
      return await (request ?? http.get(uri, headers: headers)).timeout(
        _timeout,
      );
    } on TimeoutException {
      throw const AdminNewsSourceReadException(
        'Link okuma zaman aşımına uğradı.',
      );
    } on Object catch (error) {
      throw AdminNewsSourceReadException('Link okunamadı: $error');
    }
  }
}

Uri _normalizeHttpUri(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty) {
    throw const AdminNewsSourceReadException('Haber linki girin.');
  }
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    throw const AdminNewsSourceReadException('Geçerli bir haber linki girin.');
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw const AdminNewsSourceReadException(
      'Sadece http veya https haber linki okunabilir.',
    );
  }
  return uri;
}

String _decodeResponseBody(http.Response response) {
  final charset = RegExp(
    r'charset=([^;\s]+)',
    caseSensitive: false,
  ).firstMatch(response.headers['content-type'] ?? '')?.group(1)?.toLowerCase();
  if (charset == 'iso-8859-1' || charset == 'latin1') {
    return latin1.decode(response.bodyBytes, allowInvalid: true);
  }
  return utf8.decode(response.bodyBytes, allowMalformed: true);
}

void _removeNoise(dom.Document document) {
  for (final element in document.querySelectorAll(
    'script, style, noscript, svg, canvas, iframe, form, nav, header, footer, aside',
  )) {
    element.remove();
  }
}

_StructuredArticle _extractStructuredArticle(
  String html,
  dom.Document document,
) {
  var best = const _StructuredArticle();
  for (final raw in _jsonLdBlocks(html, document)) {
    if (raw.isEmpty) continue;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      continue;
    }
    for (final node in _jsonMaps(decoded)) {
      final type = _jsonText(node['@type']).toLowerCase();
      if (!type.contains('article') && !type.contains('posting')) continue;
      final candidate = _StructuredArticle(
        title: _jsonText(node['headline']),
        description: _jsonText(node['description']),
        author: _jsonText(node['author']),
        publishedAt: _jsonText(node['datePublished']),
        bodyText: _jsonText(node['articleBody']),
      );
      if (candidate.score > best.score) best = candidate;
    }
  }
  return best;
}

Iterable<String> _jsonLdBlocks(String html, dom.Document document) sync* {
  final seen = <String>{};
  final pattern = RegExp(
    r"""<script\b[^>]*type=["'][^"']*ld\+json[^"']*["'][^>]*>([\s\S]*?)</script>""",
    caseSensitive: false,
  );
  for (final match in pattern.allMatches(html)) {
    final raw = _decodeHtmlEntities(match.group(1) ?? '').trim();
    if (raw.isNotEmpty && seen.add(raw)) yield raw;
  }
  for (final script in document.getElementsByTagName('script')) {
    final type = script.attributes['type']?.toLowerCase() ?? '';
    if (!type.contains('ld+json')) continue;
    final raw = _decodeHtmlEntities(script.innerHtml).trim();
    if (raw.isNotEmpty && seen.add(raw)) yield raw;
  }
}

String _decodeHtmlEntities(String value) {
  return value
      .replaceAll('&quot;', '"')
      .replaceAll('&#34;', '"')
      .replaceAll('&#x22;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

Iterable<Map<String, Object?>> _jsonMaps(Object? value) sync* {
  if (value is Map) {
    final map = value.map((key, item) => MapEntry(key.toString(), item));
    yield map;
    final graph = map['@graph'];
    if (graph is Iterable) {
      for (final item in graph) {
        yield* _jsonMaps(item);
      }
    }
    return;
  }
  if (value is Iterable) {
    for (final item in value) {
      yield* _jsonMaps(item);
    }
  }
}

String _jsonText(Object? value) {
  if (value == null) return '';
  if (value is String || value is num || value is bool) return value.toString();
  if (value is Map) {
    return _jsonText(value['name'] ?? value['headline'] ?? value['text']);
  }
  if (value is Iterable) {
    return value.map(_jsonText).where((item) => item.isNotEmpty).join(', ');
  }
  return '';
}

String _extractMainText(dom.Document document) {
  final candidates = <dom.Element>[];
  final selectors = [
    'article',
    '[itemprop="articleBody"]',
    '[property="articleBody"]',
    '.article-content',
    '.article-body',
    '.article-detail',
    '.entry-content',
    '.post-content',
    '.news-content',
    '.news-detail',
    '.haber-detay',
    '.detay',
    'main',
  ];
  final seen = <dom.Element>{};
  for (final selector in selectors) {
    for (final element in document.querySelectorAll(selector)) {
      if (seen.add(element)) candidates.add(element);
    }
  }
  var bestText = '';
  var bestScore = 0;
  for (final candidate in candidates) {
    final lines = _extractTextLines(candidate);
    final text = lines.join('\n');
    final score = text.length + (lines.length * 24);
    if (score > bestScore) {
      bestScore = score;
      bestText = text;
    }
  }
  if (bestText.length >= 80 || document.body == null) return bestText;
  final bodyLines = _extractTextLines(document.body!);
  if (bodyLines.isEmpty) return bestText;
  return bodyLines.join('\n');
}

List<String> _extractTextLines(dom.Element root) {
  final lines = <String>[];
  final seen = <String>{};
  final nodes = root.querySelectorAll('h1, h2, h3, p, li');
  for (final node in nodes) {
    final text = _cleanLine(node.text);
    if (text.isEmpty) continue;
    if (_isStopLine(text) && lines.length >= 2) break;
    if (_shouldSkipLine(text)) continue;
    final key = text.toLowerCase();
    if (!seen.add(key)) continue;
    lines.add(text);
  }
  return lines;
}

bool _shouldSkipLine(String value) {
  final text = value.trim();
  if (text.length < 3) return true;
  final lower = text.toLowerCase();
  const exact = {
    'a - a +',
    'giriş yap',
    'kopyala',
    'paylaş',
    'reklam',
    'yazdır',
    'yorum yazın',
    'yorumlar',
    'gönder',
  };
  if (exact.contains(lower)) return true;
  const noisyParts = [
    'favorilerinize ekleyin',
    'içeriğin devamı aşağıda',
    'içeriği görüntüle',
    'okunma süresi',
    'son eklenenler',
    'sana özel seçtiklerimiz',
    'sosyal medya',
    'tercih edilen kaynak',
    'tüm içerikleri',
    'üyeleri ne diyor',
    'yorumlar aşağıda',
    'yorumlar ve emojiler aşağıda',
  ];
  return noisyParts.any(lower.contains);
}

bool _isStopLine(String value) {
  final lower = value.toLowerCase();
  const markers = [
    'bu haberler de ilginizi çekebilir',
    'bunlar da ilginizi çekebilir',
    'editörün seçtiği',
    'günün popüler başlıkları',
    'hızlı erişim',
    'keşfet',
    'yorumlar ve emojiler aşağıda',
  ];
  return markers.any(lower.contains);
}

String _metaContent(dom.Document document, String selector) {
  return document.querySelector(selector)?.attributes['content'] ?? '';
}

String _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final text = _cleanLine(value ?? '');
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _firstUsefulLine(String text) {
  for (final line in text.split('\n')) {
    final clean = _cleanLine(line);
    if (clean.length > 20) return clean;
  }
  return '';
}

String _cleanBodyText(String value) {
  final lines = value
      .split(RegExp(r'\r?\n+'))
      .map(_cleanLine)
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  final text = lines.join('\n').trim();
  if (text.length <= AdminNewsSourceReader._maxPromptChars) return text;
  return '${text.substring(0, AdminNewsSourceReader._maxPromptChars).trim()}\n[Kaynak metin uzun olduğu için burada kesildi.]';
}

String _cleanLine(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').replaceAll('\u00a0', ' ').trim();
}

class _StructuredArticle {
  const _StructuredArticle({
    this.title = '',
    this.description = '',
    this.author = '',
    this.publishedAt = '',
    this.bodyText = '',
  });

  final String title;
  final String description;
  final String author;
  final String publishedAt;
  final String bodyText;

  int get score =>
      title.length + description.length + author.length + bodyText.length;
}
