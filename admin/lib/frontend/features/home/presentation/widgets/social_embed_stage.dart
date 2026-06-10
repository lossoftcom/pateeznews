import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/platform/debug_platform_view_hot_restart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class SocialEmbedStage extends StatefulWidget {
  const SocialEmbedStage({
    super.key,
    required this.embed,
    this.sourceUrl = '',
    this.platform = '',
  });

  final String embed;
  final String sourceUrl;
  final String platform;

  @override
  State<SocialEmbedStage> createState() => _SocialEmbedStageState();
}

class _SocialEmbedStageState extends State<SocialEmbedStage>
    with AutomaticKeepAliveClientMixin {
  static const double _minEmbedHeight = 300;
  static const double _maxSocialEmbedHeight = 1200;
  static const double _maxIframeEmbedHeight = 12000;
  static const int _maxEmbedWidth = 540;

  WebViewController? _controller;
  Timer? _loadingFallbackTimer;
  final List<Timer> _heightProbeTimers = [];
  double? _measuredHeight;
  bool _loading = true;
  bool _inlineAvailable = _supportsInlineSocialWebView;
  // Platform view (WebView) yalnızca ekranda görünürken bağlanır: liste
  // kaydırılırken ekran dışı embed'ler render edilmez (akıcı scroll) ve geri
  // dönünce boş kalmaz. WebViewController keepAlive ile yaşar; native WebView ve
  // yüklenmiş içerik korunur, yalnızca görsel yüzey gerektiğinde bağlanır.
  bool _surfaceActive = false;
  late final Key _visibilityKey = ValueKey<int>(identityHashCode(this));

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _configureAndLoad();
  }

  @override
  void didUpdateWidget(covariant SocialEmbedStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.embed != widget.embed ||
        oldWidget.sourceUrl != widget.sourceUrl ||
        oldWidget.platform != widget.platform) {
      _measuredHeight = null;
      _loadCurrentEmbed();
    }
  }

  @override
  void dispose() {
    _loadingFallbackTimer?.cancel();
    _cancelHeightProbeTimers();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final active = info.visibleFraction > 0;
    if (active == _surfaceActive || !mounted) return;
    setState(() => _surfaceActive = active);
  }

  Future<void> _configureAndLoad() async {
    if (!_inlineAvailable) return;
    try {
      await prepareDebugDarwinPlatformViewsForHotRestart();
      if (!mounted || !_inlineAvailable) return;
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.addJavaScriptChannel(
        'PateezHeight',
        onMessageReceived: (message) {
          final parsed = double.tryParse(message.message);
          if (parsed == null || !parsed.isFinite || parsed <= 0 || !mounted) {
            return;
          }
          _updateMeasuredHeight(parsed, _resolvedPlatform);
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _loadingFallbackTimer?.cancel();
            if (mounted) setState(() => _loading = false);
            unawaited(_requestHeight());
            _scheduleHeightProbes();
          },
          onWebResourceError: (_) {
            _loadingFallbackTimer?.cancel();
            if (mounted) setState(() => _loading = false);
          },
        ),
      );
      _controller = controller;
      await _loadCurrentEmbed();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inlineAvailable = false;
        _loading = false;
      });
    }
  }

  Future<void> _loadCurrentEmbed() async {
    final controller = _controller;
    if (!_inlineAvailable || controller == null) return;
    _loadingFallbackTimer?.cancel();
    _cancelHeightProbeTimers();
    if (mounted) setState(() => _loading = true);
    _loadingFallbackTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _loading = false);
    });
    try {
      final directIframeUri = _directIframeUri;
      if (directIframeUri != null) {
        await controller.loadRequest(directIframeUri);
      } else {
        await controller.loadHtmlString(_buildSocialEmbedHtml(widget.embed));
      }
    } catch (_) {
      _loadingFallbackTimer?.cancel();
      if (mounted) {
        setState(() {
          _inlineAvailable = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _requestHeight() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final platform = _resolvedPlatform;
      if (_directIframeUri != null) {
        final result = await controller.runJavaScriptReturningResult('''
(() => {
  const body = document.body;
  const doc = document.documentElement;
  const values = [
    body ? body.scrollHeight : 0,
    body ? body.offsetHeight : 0,
    body ? body.getBoundingClientRect().height : 0,
    doc ? doc.scrollHeight : 0,
    doc ? doc.offsetHeight : 0,
    doc ? doc.getBoundingClientRect().height : 0,
    window.innerHeight || 0
  ];
  return Math.ceil(Math.max.apply(null, values.filter(Number.isFinite)));
})()
''');
        _updateMeasuredHeight(_heightFromJavaScriptResult(result), platform);
        return;
      }
      await controller.runJavaScript(
        'window.pateezReportHeight && window.pateezReportHeight();',
      );
    } catch (_) {
      // Height reporting is progressive enhancement; the initial platform
      // height keeps the card usable if a provider blocks script execution.
    }
  }

  void _updateMeasuredHeight(double? value, String platform) {
    if (value == null || !mounted) return;
    final next = _clampEmbedHeight(value, platform);
    if (((_measuredHeight ?? 0) - next).abs() < 2) return;
    setState(() => _measuredHeight = next);
  }

  void _scheduleHeightProbes() {
    _cancelHeightProbeTimers();
    for (final delay in const [
      Duration(milliseconds: 120),
      Duration(milliseconds: 420),
      Duration(milliseconds: 900),
      Duration(milliseconds: 1600),
      Duration(milliseconds: 2800),
      Duration(milliseconds: 4500),
    ]) {
      _heightProbeTimers.add(
        Timer(delay, () {
          if (mounted) unawaited(_requestHeight());
        }),
      );
    }
  }

  void _cancelHeightProbeTimers() {
    for (final timer in _heightProbeTimers) {
      timer.cancel();
    }
    _heightProbeTimers.clear();
  }

  Future<void> _openSource() async {
    final source = _resolvedSourceUrl;
    final uri = Uri.tryParse(source);
    if (uri == null || !uri.hasScheme) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Uri? get _directIframeUri {
    if (_resolvedPlatform != 'iframe') return null;
    return _iframeSourceUriFromMarkup(widget.embed);
  }

  String get _resolvedSourceUrl {
    final explicit = widget.sourceUrl.trim();
    if (explicit.isNotEmpty) return explicit;
    return _sourceUrlFromRaw(widget.embed);
  }

  String get _resolvedPlatform {
    final explicit = widget.platform.trim().toLowerCase();
    if (explicit.isNotEmpty && explicit != 'link') return explicit;

    final embedPlatform = _detectPlatform(widget.embed);
    if (embedPlatform.isNotEmpty && embedPlatform != 'link') {
      return embedPlatform;
    }
    if (explicit.isNotEmpty) return explicit;

    return _detectPlatform(_resolvedSourceUrl);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final platform = _resolvedPlatform;
    final label = _platformLabel(platform);
    final sourceUrl = _resolvedSourceUrl;
    final height = _clampEmbedHeight(
      _measuredHeight ?? _initialHeightForEmbed(platform, widget.embed),
      platform,
    );

    return Semantics(
      label: platform == 'iframe' ? label : '$label gönderisi',
      child: RepaintBoundary(
        child: _inlineAvailable && _controller != null
            ? VisibilityDetector(
                key: _visibilityKey,
                onVisibilityChanged: _onVisibilityChanged,
                child: _SocialWebViewFrame(
                  controller: _controller!,
                  height: height,
                  loading: _loading,
                  showSurface: _surfaceActive,
                ),
              )
            : _SocialFallbackCard(
                platform: platform,
                label: label,
                onOpen: sourceUrl.isEmpty ? null : _openSource,
              ),
      ),
    );
  }

  static double _initialHeightForEmbed(String platform, String embed) {
    if (platform == 'iframe') {
      return _iframeHeightFromMarkup(embed) ?? 500;
    }
    return switch (platform) {
      'instagram' => 820,
      'tiktok' => 760,
      'pinterest' => 760,
      'facebook' => 520,
      'x' => 520,
      'nsosyal' => 620,
      _ => 430,
    };
  }

  static double _clampEmbedHeight(double value, String platform) {
    final maxHeight = platform == 'iframe'
        ? _maxIframeEmbedHeight
        : _maxSocialEmbedHeight;
    return value.clamp(_minEmbedHeight, maxHeight).toDouble();
  }
}

class _SocialWebViewFrame extends StatelessWidget {
  const _SocialWebViewFrame({
    required this.controller,
    required this.height,
    required this.loading,
    required this.showSurface,
  });

  final WebViewController controller;
  final double height;
  final bool loading;
  final bool showSurface;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(color: AppColors.surface),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showSurface) WebViewWidget(controller: controller),
          if (showSurface && loading)
            ColoredBox(
              color: AppColors.surface.withValues(alpha: 0.82),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.actionRed,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SocialFallbackCard extends StatelessWidget {
  const _SocialFallbackCard({
    required this.platform,
    required this.label,
    required this.onOpen,
  });

  final String platform;
  final String label;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final isIframe = platform == 'iframe';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _platformIcon(platform),
            color: _platformColor(platform),
            size: 34,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isIframe ? label : '$label gönderisi',
            textAlign: TextAlign.center,
            style: AppTypography.titleS.copyWith(
              color: AppColors.inkStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isIframe
                ? 'Bu içerik bu cihazda dışarıda açılır.'
                : 'Gönderi bu cihazda dışarıda açılır.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AppColors.inkSoft),
          ),
          if (onOpen != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Symbols.open_in_new, size: 16),
              label: Text(isIframe ? 'İçeriği aç' : 'Gönderiyi aç'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepOcean,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                textStyle: AppTypography.meta.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

bool get _supportsInlineSocialWebView {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

String _buildSocialEmbedHtml(String value) {
  final markup = _processSocialEmbedMarkup(value);
  return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      min-height: 0;
      background: #ffffff;
      overflow: hidden;
      color-scheme: light;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    * { box-sizing: border-box; }
    .embed-stage {
      width: 100%;
      display: flex;
      justify-content: center;
      align-items: flex-start;
      overflow: hidden;
      background: #ffffff;
    }
    .embed-root {
      width: 100%;
      max-width: ${_SocialEmbedStageState._maxEmbedWidth}px;
      min-height: 1px;
      overflow: hidden;
    }
    .embed-root > * {
      max-width: 100% !important;
      margin-left: auto !important;
      margin-right: auto !important;
    }
    iframe,
    blockquote,
    .twitter-tweet,
    .instagram-media,
    .tiktok-embed {
      max-width: 100% !important;
      margin-left: auto !important;
      margin-right: auto !important;
    }
    iframe {
      border: 0;
      display: block;
      width: 100% !important;
    }
  </style>
</head>
<body>
  <div class="embed-stage">
    <div class="embed-root">$markup</div>
  </div>
  <script>
    (function () {
      function reportHeight() {
        var root = document.querySelector('.embed-root');
        if (!root) return;
        var height;
        var iframe = root.querySelector('iframe');
        if (iframe && iframe.offsetHeight > 1) {
          // Twitter/Facebook gibi gömüler gerçek yüksekliği iframe'e yazar;
          // konteyner scrollHeight'ı render sonrası fazladan boşlukla şişebilir.
          // iframe'in kendi yüksekliğini (kenar boşluklarıyla) esas al → altta
          // boşluk kalmaz.
          var cs = window.getComputedStyle(iframe);
          height = iframe.offsetHeight +
            (parseFloat(cs.marginTop) || 0) +
            (parseFloat(cs.marginBottom) || 0);
        } else {
          var body = document.body;
          var doc = document.documentElement;
          var rect = root.getBoundingClientRect();
          height = Math.max(
            root.scrollHeight,
            rect.height || 0,
            body ? body.scrollHeight : 0,
            doc ? doc.scrollHeight : 0,
            1
          );
        }
        try {
          if (window.PateezHeight && window.PateezHeight.postMessage) {
            window.PateezHeight.postMessage(String(Math.ceil(height + 2)));
          }
        } catch (e) {}
      }
      function processEmbeds() {
        try { if (window.twttr && window.twttr.widgets) window.twttr.widgets.load(); } catch (e) {}
        try { if (window.instgrm && window.instgrm.Embeds) window.instgrm.Embeds.process(); } catch (e) {}
        try { if (window.FB && window.FB.XFBML) window.FB.XFBML.parse(); } catch (e) {}
        try { if (window.PinUtils && window.PinUtils.build) window.PinUtils.build(); } catch (e) {}
        reportHeight();
      }
      window.pateezReportHeight = reportHeight;
      window.addEventListener('load', processEmbeds);
      window.addEventListener('resize', reportHeight);
      if (window.ResizeObserver) {
        try { new ResizeObserver(reportHeight).observe(document.body); } catch (e) {}
      }
      setTimeout(reportHeight, 50);
      setTimeout(processEmbeds, 180);
      setTimeout(reportHeight, 500);
      setTimeout(processEmbeds, 900);
      setTimeout(reportHeight, 1400);
      setTimeout(reportHeight, 2600);
      setTimeout(reportHeight, 4200);
    })();
  </script>
</body>
</html>
''';
}

String _processSocialEmbedMarkup(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '';

  final rawUri = Uri.tryParse(raw);
  final isRawUrl =
      rawUri != null &&
      (rawUri.scheme == 'http' || rawUri.scheme == 'https') &&
      rawUri.host.isNotEmpty &&
      !raw.contains('<');
  if (isRawUrl) return _embedMarkupFromUrl(raw);

  var processed = raw.replaceAll('src="//', 'src="https://');
  processed = processed.replaceAll("src='//", "src='https://");
  processed = processed.replaceAll('href="//', 'href="https://');
  processed = processed.replaceAll("href='//", "href='https://");

  final lower = processed.toLowerCase();
  if (lower.contains('twitter-tweet') &&
      !lower.contains('platform.twitter.com/widgets.js')) {
    processed +=
        '<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>';
  }
  if (lower.contains('instagram-media') &&
      !lower.contains('instagram.com/embed.js')) {
    processed +=
        '<script async src="https://www.instagram.com/embed.js"></script>';
  }
  if (lower.contains('tiktok-embed') &&
      !lower.contains('tiktok.com/embed.js')) {
    processed +=
        '<script async src="https://www.tiktok.com/embed.js"></script>';
  }
  if (lower.contains('data-pin-do') &&
      !lower.contains('assets.pinterest.com/js/pinit.js')) {
    processed +=
        '<script async defer src="https://assets.pinterest.com/js/pinit.js"></script>';
  }
  if (lower.contains('fb-post') &&
      !lower.contains('connect.facebook.net') &&
      !lower.contains('facebook.com/plugins/post.php')) {
    processed =
        '<div id="fb-root"></div><script async defer crossorigin="anonymous" src="https://connect.facebook.net/en_US/sdk.js#xfbml=1&version=v24.0"></script>$processed';
  }
  if (lower.contains('nsosyal.com') &&
      !lower.contains('nsosyal.com/embed.js')) {
    processed += '<script async src="https://nsosyal.com/embed.js"></script>';
  }
  return _normalizeIframeEmbedSizing(processed);
}

String _normalizeIframeEmbedSizing(String html) {
  return html.replaceAllMapped(
    RegExp(r'<iframe\b[^>]*>', caseSensitive: false),
    (match) {
      var tag = match.group(0) ?? '';
      if (!RegExp(r'\swidth\s*=', caseSensitive: false).hasMatch(tag)) {
        tag = tag.replaceFirst(
          RegExp(r'<iframe\b', caseSensitive: false),
          '<iframe width="100%"',
        );
      } else {
        tag = tag.replaceAllMapped(
          RegExp(
            r'''\swidth\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)''',
            caseSensitive: false,
          ),
          (_) => ' width="100%"',
        );
      }
      if (!RegExp(r'\sheight\s*=', caseSensitive: false).hasMatch(tag)) {
        tag = tag.replaceFirst(
          RegExp(r'<iframe\b', caseSensitive: false),
          '<iframe height="620"',
        );
      }
      return tag;
    },
  );
}

String _embedMarkupFromUrl(String url) {
  final escaped = _escapeHtmlAttribute(url);
  final lower = url.toLowerCase();

  if (lower.contains('instagram.com')) {
    final match = RegExp(
      r'instagram\.com\/(p|reel|tv)\/([^\/?#]+)',
      caseSensitive: false,
    ).firstMatch(url);
    if (match != null) {
      final type = match.group(1) ?? 'p';
      final code = match.group(2) ?? '';
      final embedUrl =
          'https://www.instagram.com/$type/$code/embed/captioned/?utm_source=ig_embed&captioned=1';
      return '''
<iframe src="${_escapeHtmlAttribute(embedUrl)}" title="Instagram gönderisi" width="100%" height="820" loading="eager" style="border:0;overflow:hidden;" scrolling="no" frameborder="0" allow="autoplay; clipboard-write; encrypted-media; picture-in-picture; web-share"></iframe>
''';
    }
    return '''
<blockquote class="instagram-media" data-instgrm-permalink="$escaped" data-instgrm-version="14" style="background:#fff;border:1px solid #dbdbdb;border-radius:3px;margin:1px;max-width:${_SocialEmbedStageState._maxEmbedWidth}px;min-width:326px;padding:0;width:calc(100% - 2px);"></blockquote>
<script async src="https://www.instagram.com/embed.js"></script>
''';
  }

  if (lower.contains('twitter.com') || lower.contains('x.com')) {
    return '''
<blockquote class="twitter-tweet" data-width="${_SocialEmbedStageState._maxEmbedWidth}"><a href="$escaped"></a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
''';
  }

  if (lower.contains('facebook.com') || lower.contains('fb.watch')) {
    final encoded = Uri.encodeComponent(url);
    return '''
<iframe src="https://www.facebook.com/plugins/post.php?href=$encoded&show_text=true&width=500" width="100%" height="520" style="border:none;overflow:hidden;" scrolling="no" frameborder="0" allowfullscreen="true" allow="autoplay; clipboard-write; encrypted-media; picture-in-picture; web-share"></iframe>
''';
  }

  if (lower.contains('pinterest.com') || lower.contains('pin.it')) {
    final pathSegments =
        Uri.tryParse(url)?.pathSegments
            .where((segment) => segment.trim().isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final pinId = pathSegments.isEmpty
        ? null
        : pathSegments.last.split('?').first;
    if (pinId != null && RegExp(r'^\d+$').hasMatch(pinId)) {
      return '''
<iframe src="https://assets.pinterest.com/ext/embed.html?id=${_escapeHtmlAttribute(pinId)}" width="100%" height="1000" style="border:none;overflow:hidden;" scrolling="no" frameborder="0" allowfullscreen="true"></iframe>
''';
    }
    return '''
<a href="$escaped" data-pin-do="embedPin" data-pin-width="large"></a>
<script async defer src="https://assets.pinterest.com/js/pinit.js"></script>
''';
  }

  if (lower.contains('tiktok.com')) {
    final videoId = RegExp(
      r'/video/(\d+)',
      caseSensitive: false,
    ).firstMatch(url)?.group(1);
    final userId = RegExp(
      r'tiktok\.com/@([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(url)?.group(1);
    if (videoId != null) {
      return '''
<blockquote class="tiktok-embed" cite="$escaped" data-video-id="${_escapeHtmlAttribute(videoId)}" style="max-width:605px;min-width:325px;"><section><a target="_blank" href="$escaped"></a></section></blockquote>
<script async src="https://www.tiktok.com/embed.js"></script>
''';
    }
    if (userId != null) {
      return '''
<blockquote class="tiktok-embed" cite="$escaped" data-unique-id="${_escapeHtmlAttribute(userId)}" data-embed-type="creator" style="max-width:720px;min-width:288px;"><section><a target="_blank" href="$escaped">@${_escapeHtml(userId)}</a></section></blockquote>
<script async src="https://www.tiktok.com/embed.js"></script>
''';
    }
  }

  if (lower.contains('nsosyal.com')) {
    final baseUrl = url.split('?').first.replaceFirst(RegExp(r'/$'), '');
    final embedUrl = baseUrl.endsWith('/embed') ? baseUrl : '$baseUrl/embed';
    return '''
<iframe src="${_escapeHtmlAttribute(embedUrl)}" width="100%" height="620" style="max-width:100%;border:0;border-radius:3px;overflow:hidden;" allowfullscreen="true"></iframe>
<script async src="https://nsosyal.com/embed.js"></script>
''';
  }

  return '''
<div style="box-sizing:border-box;width:100%;max-width:360px;padding:18px;border:1px solid #dde5e8;border-radius:4px;background:#fff;text-align:center;">
  <a href="$escaped" target="_blank" rel="noopener noreferrer" style="color:#26394b;font:600 13px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;text-decoration:none;word-break:break-all;">$escaped</a>
</div>
''';
}

String _sourceUrlFromRaw(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';

  final twitterMatch = RegExp(
    r'href="(https?:\/\/(?:twitter\.com|x\.com)\/[^"]*\/status\/\d+[^"]*)"',
    caseSensitive: false,
  ).firstMatch(value);
  if (twitterMatch != null) return twitterMatch.group(1)!.split('?').first;

  final instagramMatch = RegExp(
    r'(https?:\/\/(?:www\.)?instagram\.com\/(?:p|reel|tv)\/[^/\s"]+)',
    caseSensitive: false,
  ).firstMatch(value);
  if (instagramMatch != null) {
    return instagramMatch.group(1)!.replaceFirst(RegExp(r'/embed.*$'), '/');
  }

  if (value.contains('facebook.com/plugins/')) {
    final uri = Uri.tryParse(value);
    final href = uri?.queryParameters['href'];
    if (href != null && href.trim().isNotEmpty) return href;
  }

  if (value.contains('assets.pinterest.com/ext/embed.html')) {
    final uri = Uri.tryParse(value);
    final id = uri?.queryParameters['id'];
    if (id != null && id.trim().isNotEmpty) {
      return 'https://www.pinterest.com/pin/$id/';
    }
  }

  final genericMatch = RegExp(
    r'https?:\/\/[^\s"<>]+',
    caseSensitive: false,
  ).firstMatch(value);
  if (genericMatch != null) return genericMatch.group(0)!.split('?').first;
  return value.startsWith('http') ? value : '';
}

String _detectPlatform(String raw) {
  final value = raw.toLowerCase();
  if (value.contains('instagram.com')) return 'instagram';
  if (value.contains('twitter.com') || value.contains('x.com')) return 'x';
  if (value.contains('facebook.com') || value.contains('fb.watch')) {
    return 'facebook';
  }
  if (value.contains('tiktok.com')) return 'tiktok';
  if (value.contains('pinterest.com') || value.contains('pin.it')) {
    return 'pinterest';
  }
  if (value.contains('nsosyal.com')) return 'nsosyal';
  if (_containsIframeMarkup(value)) return 'iframe';
  return value.isEmpty ? '' : 'link';
}

String _platformLabel(String platform) {
  return switch (platform) {
    'instagram' => 'Instagram',
    'x' => 'X',
    'facebook' => 'Facebook',
    'tiktok' => 'TikTok',
    'pinterest' => 'Pinterest',
    'nsosyal' => 'nSosyal',
    'iframe' => 'Web içeriği',
    _ => 'Sosyal medya',
  };
}

IconData _platformIcon(String platform) {
  return switch (platform) {
    'instagram' => Symbols.instagram_fill,
    'x' => Symbols.twitter_x_fill,
    'facebook' => Symbols.facebook_fill,
    'nsosyal' => Symbols.public_rounded,
    'iframe' => Symbols.public_rounded,
    'link' => Symbols.open_in_new,
    _ => Symbols.share_2_fill,
  };
}

Color _platformColor(String platform) {
  return switch (platform) {
    'instagram' => AppColors.actionRed,
    'x' => Colors.black,
    'facebook' => const Color(0xFF1877F2),
    'tiktok' => Colors.black,
    'pinterest' => const Color(0xFFE60023),
    'nsosyal' => AppColors.deepOcean,
    'iframe' => AppColors.deepOcean,
    _ => AppColors.deepOcean,
  };
}

bool _containsIframeMarkup(String value) =>
    RegExp(r'<iframe\b', caseSensitive: false).hasMatch(value);

double? _iframeHeightFromMarkup(String html) {
  final tag = RegExp(
    r'<iframe\b[^>]*>',
    caseSensitive: false,
  ).firstMatch(html)?.group(0);
  if (tag == null) return null;

  final match = RegExp(
    r'''\sheight\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''',
    caseSensitive: false,
  ).firstMatch(tag);
  final raw = match?.group(1) ?? match?.group(2) ?? match?.group(3);
  if (raw == null) return null;

  final numeric = RegExp(r'\d+(?:\.\d+)?').firstMatch(raw)?.group(0);
  final parsed = double.tryParse(numeric ?? '');
  if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
  return parsed;
}

Uri? _iframeSourceUriFromMarkup(String html) {
  final tag = RegExp(
    r'<iframe\b[^>]*>',
    caseSensitive: false,
  ).firstMatch(html)?.group(0);
  if (tag == null) return null;

  final match = RegExp(
    r'''\ssrc\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''',
    caseSensitive: false,
  ).firstMatch(tag);
  var raw = match?.group(1) ?? match?.group(2) ?? match?.group(3);
  raw = raw?.trim().replaceAll('&amp;', '&');
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('//')) raw = 'https:$raw';

  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

double? _heightFromJavaScriptResult(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  var raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  raw = raw.replaceAll(RegExp(r'^"+|"+$'), '');

  final numeric = RegExp(r'\d+(?:\.\d+)?').firstMatch(raw)?.group(0);
  final parsed = double.tryParse(numeric ?? '');
  if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
  return parsed;
}

String _escapeHtml(String value) => const HtmlEscape().convert(value);

String _escapeHtmlAttribute(String value) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(value);
