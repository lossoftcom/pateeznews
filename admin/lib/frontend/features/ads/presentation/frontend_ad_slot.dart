import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/platform/debug_platform_view_hot_restart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/services/frontend_link_launcher.dart';
import '../data/frontend_ads_repository.dart';

class FrontendAdSlot extends StatelessWidget {
  const FrontendAdSlot({
    super.key,
    required this.slotKey,
    this.repository = const FrontendAdsRepository(),
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.pageHorizontal,
      vertical: AppSpacing.md,
    ),
    this.maxWidth,
  });

  final String slotKey;
  final FrontendAdsRepository repository;
  final EdgeInsetsGeometry margin;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FrontendAdSettings>(
      future: repository.fetchMobileAds(),
      builder: (context, snapshot) {
        final slot = snapshot.data?.slotByKey(slotKey);
        if (slot == null || slot.creatives.isEmpty) {
          return const SizedBox.shrink();
        }
        final creative = _pickCreative(slot);
        if (creative == null) return const SizedBox.shrink();
        if (!creative.isImage) {
          return _FrontendWebAd(
            slot: slot,
            creative: creative,
            fallbackCreative: _firstImageCreative(slot),
            margin: margin,
            maxWidth: maxWidth,
          );
        }
        return _FrontendImageAd(
          slot: slot,
          creative: creative,
          margin: margin,
          maxWidth: maxWidth,
        );
      },
    );
  }
}

class _FrontendWebAd extends StatefulWidget {
  const _FrontendWebAd({
    required this.slot,
    required this.creative,
    required this.fallbackCreative,
    required this.margin,
    required this.maxWidth,
  });

  final FrontendAdSlotData slot;
  final FrontendAdCreative creative;
  final FrontendAdCreative? fallbackCreative;
  final EdgeInsetsGeometry margin;
  final double? maxWidth;

  @override
  State<_FrontendWebAd> createState() => _FrontendWebAdState();
}

class _FrontendWebAdState extends State<_FrontendWebAd> {
  static const _pendingCollapseDelay = Duration(milliseconds: 2200);

  WebViewController? _controller;
  Timer? _pendingCollapseTimer;
  var _available = _supportsAdWebView;
  var _visible = false;
  var _collapsed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_configureAndLoad());
  }

  @override
  void didUpdateWidget(covariant _FrontendWebAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slot.key != widget.slot.key ||
        oldWidget.creative.id != widget.creative.id ||
        oldWidget.creative.htmlCode != widget.creative.htmlCode ||
        oldWidget.creative.adsenseSlotId != widget.creative.adsenseSlotId) {
      _pendingCollapseTimer?.cancel();
      _visible = false;
      _collapsed = false;
      unawaited(_loadCurrentAd());
    }
  }

  @override
  void dispose() {
    _pendingCollapseTimer?.cancel();
    super.dispose();
  }

  Future<void> _configureAndLoad() async {
    if (!_available) return;
    try {
      await prepareDebugDarwinPlatformViewsForHotRestart();
      if (!mounted) return;
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.transparent);
      await controller.addJavaScriptChannel(
        'PateezAdStatus',
        onMessageReceived: (message) => _handleAdStatus(message.message),
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!widget.creative.isAdsense) {
              _handleAdStatus('filled');
              return;
            }
            _armPendingCollapseTimer();
          },
          onWebResourceError: (_) => _handleAdStatus('empty'),
        ),
      );
      _controller = controller;
      await _loadCurrentAd();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  Future<void> _loadCurrentAd() async {
    final controller = _controller;
    if (!_available || controller == null) return;
    try {
      _pendingCollapseTimer?.cancel();
      if (mounted) {
        setState(() {
          _visible = false;
          _collapsed = false;
        });
      }
      await controller.loadHtmlString(_buildAdHtml(widget.creative));
      if (widget.creative.isAdsense) _armPendingCollapseTimer();
    } catch (_) {
      _handleAdStatus('empty');
    }
  }

  void _handleAdStatus(String value) {
    if (!mounted) return;
    final status = value.trim().toLowerCase();
    if (status == 'filled') {
      _pendingCollapseTimer?.cancel();
      setState(() {
        _visible = true;
        _collapsed = false;
      });
    } else if (status == 'empty' || status == 'unfilled') {
      _pendingCollapseTimer?.cancel();
      setState(() {
        _visible = false;
        _collapsed = true;
      });
    }
  }

  void _armPendingCollapseTimer() {
    _pendingCollapseTimer?.cancel();
    _pendingCollapseTimer = Timer(_pendingCollapseDelay, () {
      if (!mounted || _visible) return;
      _handleAdStatus('empty');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_available || _collapsed) {
      return _fallbackAd() ?? const SizedBox.shrink();
    }
    final controller = _controller;
    if (!_visible || controller == null) {
      return _buildPendingProbe(controller);
    }
    final naturalWidth =
        _positive(widget.creative.width) ?? _positive(widget.slot.width);
    final naturalHeight =
        _positive(widget.creative.height) ?? _positive(widget.slot.height);
    final ratio = naturalWidth != null && naturalHeight != null
        ? naturalWidth / naturalHeight
        : null;

    return Padding(
      padding: widget.margin,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final targetMaxWidth =
              widget.maxWidth ?? naturalWidth ?? availableWidth;
          final width = math.min(availableWidth, targetMaxWidth);
          final height = ratio != null
              ? width / ratio
              : (naturalHeight ?? 100).toDouble();

          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: width,
                height: height,
                child: WebViewWidget(controller: controller),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingProbe(WebViewController? controller) {
    final fallback = _fallbackAd();
    if (controller == null) return fallback ?? const SizedBox.shrink();
    final probe = SizedBox(
      width: 1,
      height: 1,
      child: Opacity(opacity: 0, child: WebViewWidget(controller: controller)),
    );
    if (fallback == null) return probe;
    return Column(mainAxisSize: MainAxisSize.min, children: [fallback, probe]);
  }

  Widget? _fallbackAd() {
    final fallbackCreative = widget.fallbackCreative;
    if (fallbackCreative == null) return null;
    return _FrontendImageAd(
      slot: widget.slot,
      creative: fallbackCreative,
      margin: widget.margin,
      maxWidth: widget.maxWidth,
    );
  }
}

class _FrontendImageAd extends StatefulWidget {
  const _FrontendImageAd({
    required this.slot,
    required this.creative,
    required this.margin,
    required this.maxWidth,
  });

  final FrontendAdSlotData slot;
  final FrontendAdCreative creative;
  final EdgeInsetsGeometry margin;
  final double? maxWidth;

  @override
  State<_FrontendImageAd> createState() => _FrontendImageAdState();
}

class _FrontendImageAdState extends State<_FrontendImageAd> {
  var _failed = false;

  @override
  void didUpdateWidget(covariant _FrontendImageAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.creative.imageUrl != widget.creative.imageUrl) {
      _failed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final naturalWidth =
        _positive(widget.creative.width) ?? _positive(widget.slot.width);
    final naturalHeight =
        _positive(widget.creative.height) ?? _positive(widget.slot.height);
    final ratio = naturalWidth != null && naturalHeight != null
        ? naturalWidth / naturalHeight
        : null;

    return Padding(
      padding: widget.margin,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final targetMaxWidth =
              widget.maxWidth ?? naturalWidth ?? availableWidth;
          final width = math.min(availableWidth, targetMaxWidth);
          final height = ratio != null ? width / ratio : null;

          final image = ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: width,
              height: height,
              child: CachedNetworkImage(
                imageUrl: widget.creative.imageUrl,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                fadeInDuration: const Duration(milliseconds: 180),
                fadeOutDuration: const Duration(milliseconds: 120),
                placeholder: (context, _) =>
                    const ColoredBox(color: AppColors.surfaceSoft),
                errorWidget: (context, _, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _failed = true);
                  });
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          return Center(
            child: widget.creative.linkUrl.isEmpty
                ? image
                : Semantics(
                    button: true,
                    label: widget.creative.name,
                    child: InkWell(
                      onTap: () => openFrontendLink(widget.creative.linkUrl),
                      borderRadius: BorderRadius.circular(4),
                      child: image,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

FrontendAdCreative? _pickCreative(FrontendAdSlotData slot) {
  if (slot.creatives.isEmpty) return null;
  final totalWeight = slot.creatives.fold<int>(
    0,
    (total, creative) => total + creative.weight,
  );
  if (totalWeight <= 0) return slot.creatives.first;

  final target =
      _hashString(
        '${slot.key}:${slot.creatives.map((creative) => creative.id).join('|')}',
      ) %
      totalWeight;
  var cursor = 0;
  for (final creative in slot.creatives) {
    cursor += creative.weight;
    if (target < cursor) return creative;
  }
  return slot.creatives.first;
}

FrontendAdCreative? _firstImageCreative(FrontendAdSlotData slot) {
  for (final creative in slot.creatives) {
    if (creative.isImage) return creative;
  }
  return null;
}

int _hashString(String value) {
  var hash = 0;
  for (var index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.codeUnitAt(index)) & 0x7fffffff;
  }
  return hash;
}

double? _positive(num value) => value > 0 ? value.toDouble() : null;

bool get _supportsAdWebView {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

String _buildAdHtml(FrontendAdCreative creative) {
  if (creative.isAdsense) return _buildAdsenseHtml(creative);
  return _wrapHtmlAd(creative.htmlCode);
}

String _buildAdsenseHtml(FrontendAdCreative creative) {
  final publisherId = _escapeHtmlAttribute(creative.publisherId);
  final slotId = _escapeHtmlAttribute(creative.adsenseSlotId);
  final width = _positive(creative.width);
  final height = _positive(creative.height);
  final responsive = creative.responsive || width == null || height == null;
  final style = responsive
      ? 'display:block;width:100%;height:100%;'
      : 'display:inline-block;width:${width.round()}px;height:${height.round()}px;';
  return _wrapHtmlAd('''
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$publisherId" crossorigin="anonymous"></script>
<ins class="adsbygoogle"
     style="$style"
     data-ad-client="$publisherId"
     data-ad-slot="$slotId"
     ${responsive ? 'data-ad-format="auto" data-full-width-responsive="true"' : ''}></ins>
<script>
  (adsbygoogle = window.adsbygoogle || []).push({});
  (function () {
    var reported = false;
    function post(value) {
      if (reported && value !== 'filled') return;
      reported = true;
      try {
        if (window.PateezAdStatus && window.PateezAdStatus.postMessage) {
          window.PateezAdStatus.postMessage(value);
        }
      } catch (e) {}
    }
    function inspect() {
      var ad = document.querySelector('.adsbygoogle');
      if (!ad) return;
      var status = ad.getAttribute('data-ad-status');
      if (status === 'filled') {
        post('filled');
      } else if (status === 'unfilled') {
        post('empty');
      } else if (ad.children.length > 0 || ad.innerHTML.trim().length > 0) {
        post('filled');
      }
    }
    try {
      new MutationObserver(inspect).observe(document.documentElement, {
        attributes: true,
        childList: true,
        subtree: true
      });
    } catch (e) {}
    window.addEventListener('load', inspect);
    setTimeout(inspect, 250);
    setTimeout(inspect, 900);
    setTimeout(function () { if (!reported) post('empty'); }, 2000);
  })();
</script>
''');
}

String _wrapHtmlAd(String body) {
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
      height: 100%;
      background: transparent;
      overflow: hidden;
      color-scheme: light;
    }
    * { box-sizing: border-box; }
    .ad-root {
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
      background: transparent;
    }
    .ad-root > * {
      max-width: 100% !important;
      max-height: 100% !important;
    }
    img, iframe, ins {
      max-width: 100% !important;
    }
  </style>
</head>
<body>
  <div class="ad-root">$body</div>
</body>
</html>
''';
}

String _escapeHtmlAttribute(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
