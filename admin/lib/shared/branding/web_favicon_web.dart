import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'admin_branding.dart';

class WebFavicon {
  WebFavicon._();

  static bool _started = false;
  static String _lastHref = '';
  static const _fallbackHref = 'favicon.png';

  static void start() {
    if (_started) return;
    _started = true;
    adminBranding.addListener(_apply);
    _apply();
  }

  static void _apply() {
    final configuredHref = adminBranding.value.faviconUrl.trim();
    final href = configuredHref.isEmpty ? _fallbackHref : configuredHref;
    if (href == _lastHref) return;
    _lastHref = href;

    final link = _faviconLink();
    link
      ..rel = 'icon'
      ..href = href
      ..type = _mimeType(href);
  }

  static web.HTMLLinkElement _faviconLink() {
    final existing = web.document.querySelector('link[rel~="icon"]');
    if (existing != null && existing.isA<web.HTMLLinkElement>()) {
      return existing as web.HTMLLinkElement;
    }

    final link = web.document.createElement('link') as web.HTMLLinkElement;
    web.document.head?.appendChild(link);
    return link;
  }

  static String _mimeType(String href) {
    final path = Uri.tryParse(href)?.path.toLowerCase() ?? href.toLowerCase();
    if (path.endsWith('.ico')) return 'image/x-icon';
    if (path.endsWith('.svg')) return 'image/svg+xml';
    if (path.endsWith('.webp')) return 'image/webp';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    return 'image/png';
  }
}
