import 'dart:convert';

String mailHtmlDocument(String html, String fallbackText) {
  final source = html.trim();
  if (source.isEmpty) {
    return _wrapMailFragment(
      '<pre>${const HtmlEscape().convert(fallbackText)}</pre>',
    );
  }
  if (_isFullHtmlDocument(source)) return _enhanceFullHtmlDocument(source);
  return _wrapMailFragment(source);
}

bool _isFullHtmlDocument(String value) {
  final lower = value.trimLeft().toLowerCase();
  return lower.startsWith('<!doctype') || lower.startsWith('<html');
}

String _enhanceFullHtmlDocument(String source) {
  var document = source;
  if (!_hasViewportMeta(document)) {
    document = _insertBeforeHeadClose(document, _viewportMeta);
  }
  if (!document.contains('pateez-mail-preview-responsive-css')) {
    document = _insertBeforeHeadClose(document, _responsiveStyleTag);
  }
  return document;
}

String _insertBeforeHeadClose(String document, String markup) {
  final match = RegExp(
    r'</head\s*>',
    caseSensitive: false,
  ).firstMatch(document);
  if (match == null) return _wrapMailFragment(document);
  return document.replaceRange(match.start, match.start, '$markup\n');
}

bool _hasViewportMeta(String document) {
  return RegExp(
    r'''<meta[^>]+name=["']viewport["']''',
    caseSensitive: false,
  ).hasMatch(document);
}

String _wrapMailFragment(String body) {
  return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  $_viewportMeta
  <base target="_blank">
  $_responsiveStyleTag
  <style>
    body {
      padding: 20px 22px;
      color: #26384a;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    pre {
      margin: 0;
      white-space: pre-wrap;
      word-break: break-word;
      font: 14px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
  </style>
</head>
<body>
$body
</body>
</html>
''';
}

const _viewportMeta =
    '<meta name="viewport" content="width=device-width, initial-scale=1">';

const _responsiveStyleTag = '''
<style id="pateez-mail-preview-responsive-css">
  html, body {
    margin: 0;
    min-height: 100%;
    width: 100%;
    background: #ffffff;
    overflow-x: hidden;
    -webkit-text-size-adjust: 100%;
    text-size-adjust: 100%;
  }
  body {
    zoom: 0.92;
  }
  *, *::before, *::after {
    box-sizing: border-box;
  }
  img, video {
    max-width: 100% !important;
    height: auto !important;
  }
  table {
    max-width: 100% !important;
  }
  table[width="600"], table.wrap, .wrap {
    width: 100% !important;
    max-width: 600px !important;
  }
  td, th {
    max-width: 100% !important;
    word-break: break-word;
  }
  a {
    word-break: break-word;
  }
  @media (max-width: 640px) {
    body {
      width: 100% !important;
      zoom: 0.88;
    }
    table[width], table.wrap, .wrap {
      width: 100% !important;
      max-width: 100% !important;
    }
    .inner {
      padding-left: 18px !important;
      padding-right: 18px !important;
    }
  }
</style>
''';
