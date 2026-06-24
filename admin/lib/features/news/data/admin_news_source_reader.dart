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
    required this.structuredBodyText,
    required this.images,
  });

  final String url;
  final String title;
  final String description;
  final String author;
  final String publishedAt;
  final String bodyText;
  final String structuredBodyText;
  final List<AdminNewsSourceImage> images;

  String get topicHint => title.isNotEmpty ? title : _firstUsefulLine(bodyText);

  String toPromptBlock({bool includeStructureHints = false}) {
    final lines = <String>[
      'Kaynak URL: $url',
      if (title.isNotEmpty) 'Kaynak başlık: $title',
      if (description.isNotEmpty) 'Kaynak açıklama: $description',
      if (publishedAt.isNotEmpty) 'Yayın tarihi: $publishedAt',
      if (author.isNotEmpty) 'Yazar/Kaynak: $author',
      if (includeStructureHints && structuredBodyText.isNotEmpty) ...[
        'Kaynak HTML başlık hiyerarşisi ve bölüm metni:',
        structuredBodyText,
      ],
      'Kaynak metni:',
      bodyText,
    ];
    return lines.where((line) => line.trim().isNotEmpty).join('\n');
  }
}

class AdminNewsSourceImage {
  const AdminNewsSourceImage({
    required this.url,
    required this.alt,
    this.displayUrl = '',
    this.displayHeaders = const <String, String>{},
  });

  final String url;
  final String alt;
  final String displayUrl;
  final Map<String, String> displayHeaders;
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
    final structuredQuizText = _extractStructuredQuizText(html, document);
    final structuredBodyText = _joinDistinctText([
      structured.bodyText,
      structuredQuizText,
    ]);
    final htmlStructuredBodyText = _cleanBodyText(
      _extractStructuredMainText(document),
    );
    final bodyText = _cleanBodyText(
      _firstNonEmpty([structuredBodyText, _extractMainText(document)]),
    );
    final images = _extractSourceImages(html, document, uri, title: title);

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
      structuredBodyText: htmlStructuredBodyText,
      images: images,
    );
  }

  Future<http.Response> _fetch(Uri uri) async {
    final headers = {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'User-Agent':
          'PateezAdmin/1.0 (+https://pateeznews.com) AppleWebKit/605.1.15',
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

List<AdminNewsSourceImage> _extractSourceImages(
  String html,
  dom.Document document,
  Uri pageUri, {
  required String title,
}) {
  final images = <AdminNewsSourceImage>[];
  final seen = <String>{};
  final fallbackAlt = _cleanLine(title);

  void add(String? rawUrl, {String? alt}) {
    final url = _normalizeSourceImageUrl(rawUrl, pageUri);
    if (url == null || _shouldSkipSourceImageUrl(url)) return;
    if (!seen.add(_sourceImageIdentityKey(url))) return;
    images.add(
      AdminNewsSourceImage(url: url, alt: _cleanLine(alt ?? fallbackAlt)),
    );
  }

  for (final imageUrl in _structuredImageUrls(html, document)) {
    add(imageUrl);
  }

  const metaSelectors = [
    'meta[property="og:image"]',
    'meta[property="og:image:url"]',
    'meta[property="og:image:secure_url"]',
    'meta[name="twitter:image"]',
    'meta[name="twitter:image:src"]',
  ];
  for (final selector in metaSelectors) {
    add(_metaContent(document, selector));
  }

  for (final link in document.querySelectorAll('link[rel]')) {
    final rel = link.attributes['rel']?.toLowerCase() ?? '';
    if (rel.contains('image_src')) add(link.attributes['href']);
  }

  for (final root in _articleImageSearchRoots(document)) {
    _removeSourceImageNoise(root);
    for (final pictureSource in root.querySelectorAll('picture source')) {
      add(_bestSrcsetUrl(pictureSource.attributes['srcset']));
    }
    for (final image in root.querySelectorAll('img')) {
      final alt = _firstNonEmpty([
        image.attributes['alt'],
        image.attributes['title'],
        fallbackAlt,
      ]);
      add(_bestSrcsetUrl(image.attributes['srcset']), alt: alt);
      add(_bestSrcsetUrl(image.attributes['data-srcset']), alt: alt);
      add(image.attributes['src'], alt: alt);
      add(image.attributes['data-src'], alt: alt);
      add(image.attributes['data-original'], alt: alt);
      add(image.attributes['data-lazy-src'], alt: alt);
      add(image.attributes['data-image'], alt: alt);
    }
  }

  return images.take(32).toList(growable: false);
}

Iterable<String> _structuredImageUrls(
  String html,
  dom.Document document,
) sync* {
  for (final raw in _jsonLdBlocks(html, document)) {
    if (raw.isEmpty) continue;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      continue;
    }
    for (final node in _jsonMapsDeep(decoded)) {
      final type = _jsonText(node['@type']).toLowerCase();
      if (!type.contains('article') &&
          !type.contains('posting') &&
          !type.contains('quiz') &&
          !type.contains('question')) {
        continue;
      }
      yield* _jsonImageUrls(node['image']);
      yield* _jsonImageUrls(node['thumbnailUrl']);
    }
  }
}

Iterable<String> _jsonImageUrls(Object? value) sync* {
  if (value == null) return;
  if (value is String || value is num || value is bool) {
    final text = value.toString();
    if (text.trim().isNotEmpty) yield text;
    return;
  }
  if (value is Map) {
    final map = value.map((key, item) => MapEntry(key.toString(), item));
    final direct = _jsonText(
      map['url'] ?? map['contentUrl'] ?? map['thumbnailUrl'] ?? map['@id'],
    );
    if (direct.isNotEmpty) yield direct;
    return;
  }
  if (value is Iterable) {
    for (final item in value) {
      yield* _jsonImageUrls(item);
    }
  }
}

List<dom.Element> _articleImageSearchRoots(dom.Document document) {
  final seen = <dom.Element>{};

  List<dom.Element> collect(Iterable<String> selectors) {
    final roots = <dom.Element>[];
    for (final selector in selectors) {
      for (final element in document.querySelectorAll(selector)) {
        if (seen.add(element)) roots.add(element);
      }
    }
    return roots;
  }

  final strictRoots = collect(const [
    '[itemprop="articleBody"]',
    '[property="articleBody"]',
    'article [itemprop="articleBody"]',
    'article [property="articleBody"]',
    '.article-text',
    '.article-content',
    '.article-body',
    '.entry-content',
    '.post-content',
    '.news-content',
  ]);
  if (strictRoots.isNotEmpty) return strictRoots;

  return collect(const [
    'article',
    '.article-detail',
    '.news-detail',
    '.haber-detay',
  ]);
}

void _removeSourceImageNoise(dom.Element root) {
  for (final element in root.querySelectorAll(
    '.post-flash, .related-news, .similar-news, .recommended-news, .other-news, '
    '.last-news, .popular-news, .article-source, .reporter-name, '
    '.ng-other-news-container, .ng-other-news, .body-banner-block, '
    '.mymani-layout-banner, .home-mymani-widget, .app-link-container, '
    '.breadcrumb, .share, .share-box, .detail-post-info, '
    '.post-date-info-container, .mynet-user-reactions, '
    '[class*="related"], [class*="recommend"], [class*="similar"], '
    '[class*="ilgili"], [class*="advert"], [class*="reklam"], '
    '[id*="advert"], [id*="reklam"], [data-ad], [data-advert]',
  )) {
    element.remove();
  }
}

String _sourceImageIdentityKey(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments
      .map((segment) => Uri.decodeComponent(segment).trim())
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  final fileIndex = segments.indexWhere(
    (segment) => segment.toLowerCase() == 'file',
  );
  if (fileIndex >= 0 && fileIndex + 1 < segments.length) {
    final id = segments[fileIndex + 1];
    if (RegExp(r'^\d+$').hasMatch(id)) return '$host/file/$id';
  }
  final uploadsIndex = segments.indexWhere(
    (segment) => segment.toLowerCase() == 'uploads',
  );
  if (uploadsIndex >= 0 && uploadsIndex + 1 < segments.length) {
    return '$host/uploads/${segments.sublist(uploadsIndex + 1).join('/').toLowerCase()}';
  }
  return '$host/${segments.join('/').toLowerCase()}';
}

String? _bestSrcsetUrl(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  var bestUrl = '';
  var bestScore = -1.0;
  var fallbackScore = 0.0;
  for (final part in raw.split(',')) {
    final tokens = part.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty || tokens.first.isEmpty) continue;
    var score = fallbackScore;
    if (tokens.length > 1) {
      final descriptor = tokens[1].trim().toLowerCase();
      if (descriptor.endsWith('w')) {
        score =
            double.tryParse(descriptor.substring(0, descriptor.length - 1)) ??
            score;
      } else if (descriptor.endsWith('x')) {
        score =
            (double.tryParse(descriptor.substring(0, descriptor.length - 1)) ??
                1) *
            1000;
      }
    }
    fallbackScore += 1;
    if (score > bestScore) {
      bestScore = score;
      bestUrl = tokens.first;
    }
  }
  return bestUrl.isEmpty ? null : bestUrl;
}

String? _normalizeSourceImageUrl(String? rawUrl, Uri pageUri) {
  final value = _decodeHtmlEntities(rawUrl ?? '').trim();
  if (value.isEmpty) return null;
  final lower = value.toLowerCase();
  if (lower.startsWith('data:') ||
      lower.startsWith('blob:') ||
      lower.startsWith('javascript:')) {
    return null;
  }
  try {
    final resolved = pageUri.resolve(value.replaceAll(' ', '%20'));
    if (resolved.scheme != 'http' && resolved.scheme != 'https') return null;
    return resolved.toString();
  } on FormatException {
    return null;
  }
}

bool _shouldSkipSourceImageUrl(String url) {
  final uri = Uri.tryParse(url);
  final path = uri?.path.toLowerCase() ?? url.toLowerCase();
  if (path.endsWith('.svg')) return true;
  const noisyParts = [
    'favicon',
    'logo',
    'avatar',
    'author',
    'profile',
    'sprite',
    'placeholder',
    'blank',
    'pixel',
    'tracker',
    'advert',
    '/ads/',
  ];
  return noisyParts.any(path.contains);
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

String _extractStructuredQuizText(String html, dom.Document document) {
  final lines = <String>[];
  final seen = <String>{};

  void add(String label, String value) {
    final text = _cleanLine(value);
    if (text.isEmpty) return;
    final line = '$label: $text';
    if (seen.add(line.toLowerCase())) lines.add(line);
  }

  for (final raw in _jsonLdBlocks(html, document)) {
    if (raw.isEmpty) continue;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      continue;
    }
    for (final node in _jsonMapsDeep(decoded)) {
      final type = _jsonText(node['@type']).toLowerCase();
      if (type.contains('quiz')) {
        add('Test başlığı', _jsonText(node['name'] ?? node['headline']));
        add('Test açıklaması', _jsonText(node['description']));
      }
      if (type.contains('question')) {
        add('Test sorusu', _jsonText(node['name'] ?? node['headline']));
        add('Test sorusu', _jsonText(node['text']));
        for (final answer in _jsonAnswerTexts(node['acceptedAnswer'])) {
          add('Doğru cevap', answer);
        }
        for (final answer in _jsonAnswerTexts(node['suggestedAnswer'])) {
          add('Cevap', answer);
        }
      }
      if (type.contains('answer')) {
        add('Cevap', _jsonText(node['text'] ?? node['name']));
      }
    }
  }

  return lines.join('\n');
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

Iterable<Map<String, Object?>> _jsonMapsDeep(Object? value) sync* {
  if (value is Map) {
    final map = value.map((key, item) => MapEntry(key.toString(), item));
    yield map;
    for (final item in map.values) {
      yield* _jsonMapsDeep(item);
    }
    return;
  }
  if (value is Iterable) {
    for (final item in value) {
      yield* _jsonMapsDeep(item);
    }
  }
}

Iterable<String> _jsonAnswerTexts(Object? value) sync* {
  if (value == null) return;
  if (value is String || value is num || value is bool) {
    final text = value.toString().trim();
    if (text.isNotEmpty) yield text;
    return;
  }
  if (value is Map) {
    final map = value.map((key, item) => MapEntry(key.toString(), item));
    final text = _jsonText(map['text'] ?? map['name'] ?? map['answerText']);
    if (text.isNotEmpty) yield text;
    return;
  }
  if (value is Iterable) {
    for (final item in value) {
      yield* _jsonAnswerTexts(item);
    }
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
  final candidates = _mainTextCandidates(document);
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

String _extractStructuredMainText(dom.Document document) {
  final candidates = _mainTextCandidates(document);
  var bestText = '';
  var bestScore = 0;
  for (final candidate in candidates) {
    final lines = _extractStructuredTextLines(candidate);
    final text = lines.join('\n');
    final score = text.length + (lines.length * 24);
    if (score > bestScore) {
      bestScore = score;
      bestText = text;
    }
  }
  if (bestText.length >= 80 || document.body == null) return bestText;
  final bodyLines = _extractStructuredTextLines(document.body!);
  if (bodyLines.isEmpty) return bestText;
  return bodyLines.join('\n');
}

List<dom.Element> _mainTextCandidates(dom.Document document) {
  final candidates = <dom.Element>[];
  const selectors = [
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
  return candidates;
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

List<String> _extractStructuredTextLines(dom.Element root) {
  final lines = <String>[];
  final seen = <String>{};
  final nodes = root.querySelectorAll('h1, h2, h3, h4, p, li');
  for (final node in nodes) {
    final tag = node.localName?.toLowerCase() ?? '';
    final isListItem = tag == 'li';
    final text = isListItem ? _directListItemText(node) : _cleanLine(node.text);
    if (text.isEmpty) continue;
    if (_isStopLine(text) && lines.length >= 2) break;
    if (_shouldSkipLine(text)) continue;
    if (isListItem && _hasArticleTextChild(node)) continue;

    final marker = switch (tag) {
      'h1' || 'h2' || 'h3' || 'h4' => _headingMarker(node, tag),
      'li' => '[LI L${_listDepth(node)}]',
      'p' => _paragraphMarker(node),
      _ => '',
    };
    if (marker.isEmpty) continue;
    final line = '$marker $text';
    if (!seen.add(line.toLowerCase())) continue;
    lines.add(line);
  }
  return lines;
}

String _headingMarker(dom.Element element, String tag) {
  final depth = _listDepth(element);
  final suffix = depth > 0 ? ' L$depth' : '';
  return '[${tag.toUpperCase()}$suffix]';
}

String _paragraphMarker(dom.Element element) {
  final depth = _listDepth(element);
  return depth > 0 ? '[P L$depth]' : '[P]';
}

String _directListItemText(dom.Element element) {
  final buffer = StringBuffer();
  for (final node in element.nodes) {
    if (node is dom.Text) {
      buffer.write(' ${node.text} ');
      continue;
    }
    if (node is! dom.Element) continue;
    final tag = node.localName?.toLowerCase() ?? '';
    if (tag == 'ul' || tag == 'ol') continue;
    buffer.write(' ${node.text} ');
  }
  return _cleanLine(buffer.toString());
}

bool _hasArticleTextChild(dom.Element element) {
  return element.children.any((child) {
    final tag = child.localName?.toLowerCase() ?? '';
    return tag == 'h1' ||
        tag == 'h2' ||
        tag == 'h3' ||
        tag == 'h4' ||
        tag == 'p';
  });
}

int _listDepth(dom.Element element) {
  var depth = 0;
  dom.Element? current = element.localName?.toLowerCase() == 'li'
      ? element
      : element.parent;
  while (current != null) {
    if (current.localName?.toLowerCase() == 'li') depth++;
    current = current.parent;
  }
  if (depth < 0) return 0;
  if (depth > 6) return 6;
  return depth;
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

String _joinDistinctText(Iterable<String> values) {
  final lines = <String>[];
  final seen = <String>{};
  for (final value in values) {
    for (final line in value.split(RegExp(r'\r?\n+'))) {
      final text = _cleanLine(line);
      if (text.isEmpty) continue;
      if (seen.add(text.toLowerCase())) lines.add(text);
    }
  }
  return lines.join('\n');
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
