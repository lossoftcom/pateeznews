import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/data/admin_image_url.dart';
import '../../../../shared/data/media_service.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

const _socialVideoExtensions = {
  'mp4',
  'm4v',
  'webm',
  'mov',
  'avi',
  'mkv',
  '3gp',
  '3g2',
};

const _socialImageExtensions = {
  'jpg',
  'jpeg',
  'webp',
  'png',
  'gif',
  'avif',
  'bmp',
  'tif',
  'tiff',
  'heic',
  'heif',
  'svg',
};

bool isSocialVideoUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('data:video/')) return true;
  if (lower.contains('youtube.com/') ||
      lower.contains('youtu.be/') ||
      lower.contains('vimeo.com/')) {
    return true;
  }
  return _socialVideoExtensions.contains(_mediaExtension(trimmed));
}

String socialMediaDisplayUrl(String value, {int imageWidth = 1080}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (!isSocialVideoUrl(trimmed)) {
    return adminImageUrl(trimmed, width: imageWidth, quality: 90);
  }
  if (_hasAbsoluteScheme(trimmed)) return trimmed;
  return MediaService().resolveUrl(trimmed);
}

class SocialMediaPreview extends StatelessWidget {
  const SocialMediaPreview({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.placeholderColor = AppColors.surface,
    this.errorWidget,
    this.fadeIn = true,
    this.filterQuality = FilterQuality.medium,
    this.useOldImageOnUrlChange = false,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final Color placeholderColor;
  final Widget? errorWidget;
  final bool fadeIn;
  final FilterQuality filterQuality;
  final bool useOldImageOnUrlChange;

  @override
  Widget build(BuildContext context) {
    final displayUrl = socialMediaDisplayUrl(
      url,
      imageWidth: memCacheWidth ?? 1080,
    );
    if (displayUrl.isEmpty) return errorWidget ?? const SizedBox.shrink();

    if (!isSocialVideoUrl(url) && !isSocialVideoUrl(displayUrl)) {
      return AdminCachedImage(
        url: displayUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        placeholderColor: placeholderColor,
        errorWidget: errorWidget,
        fadeIn: fadeIn,
        filterQuality: filterQuality,
        useOldImageOnUrlChange: useOldImageOnUrlChange,
      );
    }

    return _SocialVideoPreview(
      url: displayUrl,
      originalUrl: url,
      width: width,
      height: height,
    );
  }
}

class SocialVideoThumb extends StatelessWidget {
  const SocialVideoThumb({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final extension = _mediaExtension(url).toUpperCase();
    return ColoredBox(
      color: const Color(0xFF1E293B),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Text(
              extension.isEmpty ? 'VIDEO' : extension,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialVideoPreview extends StatefulWidget {
  const _SocialVideoPreview({
    required this.url,
    required this.originalUrl,
    required this.width,
    required this.height,
  });

  final String url;
  final String originalUrl;
  final double? width;
  final double? height;

  @override
  State<_SocialVideoPreview> createState() => _SocialVideoPreviewState();
}

class _SocialVideoPreviewState extends State<_SocialVideoPreview> {
  VideoPlayerController? _controller;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _SocialVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _failed = false;
      _load();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  Future<void> _load() async {
    if (!_isPlayableDirectVideoUrl(widget.url)) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted || _controller != controller) return;
      setState(() {});
    } catch (_) {
      if (!mounted || _controller != controller) return;
      await controller.dispose();
      _controller = null;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller != null && controller.value.isInitialized;
    final aspectRatio = initialized
        ? _safeAspectRatio(controller.value.size)
        : 16 / 9;
    final child = initialized
        ? _VideoFrame(controller: controller)
        : _VideoPlaceholder(url: widget.originalUrl, failed: _failed);

    return LayoutBuilder(
      builder: (context, constraints) {
        final framed = ClipRect(child: child);
        if (widget.height != null || constraints.hasBoundedHeight) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: framed,
          );
        }
        return SizedBox(
          width: widget.width,
          child: AspectRatio(aspectRatio: aspectRatio, child: framed),
        );
      },
    );
  }
}

class _VideoFrame extends StatelessWidget {
  const _VideoFrame({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: size.width <= 0 ? 16 : size.width,
                height: size.height <= 0 ? 9 : size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.deepOcean.withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.url, required this.failed});

  final String url;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final extension = _mediaExtension(url).toUpperCase();
    return ColoredBox(
      color: const Color(0xFF111827),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                failed
                    ? Symbols.videocam_outlined
                    : Symbols.play_circle_outline_rounded,
                color: Colors.white.withValues(alpha: 0.72),
                size: 32,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              extension.isEmpty ? 'VIDEO' : extension,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _hasAbsoluteScheme(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.hasScheme;
}

bool _isPlayableDirectVideoUrl(String value) {
  final lower = value.toLowerCase();
  if (lower.startsWith('data:video/')) return false;
  if (lower.contains('youtube.com/') ||
      lower.contains('youtu.be/') ||
      lower.contains('vimeo.com/')) {
    return false;
  }
  return _socialVideoExtensions.contains(_mediaExtension(value));
}

String _mediaExtension(String value) {
  final path = Uri.tryParse(value)?.path ?? value;
  final clean = path.split('?').first.split('#').first.toLowerCase();
  final fileName = clean.split('/').last;
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  final extension = fileName.substring(dot + 1);
  if (_socialImageExtensions.contains(extension) ||
      _socialVideoExtensions.contains(extension)) {
    return extension;
  }
  return extension;
}

double _safeAspectRatio(Size size) {
  if (size.width <= 0 || size.height <= 0) return 16 / 9;
  return size.width / size.height;
}
