import 'package:flutter/material.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import 'social_media_preview.dart';

const _socialMediaStrongLine = Color(0xFFDDE5E8);
const _socialMediaUploadInk = Color(0xFF6D7B83);

/// Media picker widget that supports multiple images and videos.
class SocialMediaPicker extends StatelessWidget {
  const SocialMediaPicker({
    super.key,
    required this.mediaUrls,
    required this.onPickImage,
    required this.onPickImageUrl,
    required this.onPickVideo,
    required this.onPickVideoUrl,
    required this.onClearMedia,
    required this.onRemoveMedia,
  });

  final List<String> mediaUrls;
  final VoidCallback onPickImage;
  final VoidCallback onPickImageUrl;
  final VoidCallback onPickVideo;
  final VoidCallback onPickVideoUrl;
  final VoidCallback onClearMedia;
  final ValueChanged<int> onRemoveMedia;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(
                context.t('social.publish.mediaTitle'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepOcean,
                  letterSpacing: 0,
                ),
              ),
              if (mediaUrls.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.deepOcean.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
                  ),
                  child: Text(
                    '${mediaUrls.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepOcean,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (mediaUrls.isNotEmpty)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onClearMedia,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Symbols.delete_outline_rounded,
                          size: 14,
                          color: AppColors.actionRed,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          context.t('social.publish.clearAll'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.actionRed,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Media grid
        if (mediaUrls.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...mediaUrls.asMap().entries.map((entry) {
                final idx = entry.key;
                final url = entry.value;
                return _MediaThumb(
                  url: url,
                  index: idx,
                  onRemove: () => onRemoveMedia(idx),
                );
              }),
              _CompactMediaActionTile(
                icon: Symbols.add_photo_alternate_outlined,
                label: context.t('social.publish.imageSelect'),
                onTap: onPickImage,
              ),
              _CompactMediaActionTile(
                icon: Symbols.public,
                label: context.t('social.publish.imageUrl'),
                onTap: onPickImageUrl,
              ),
              _CompactMediaActionTile(
                icon: Symbols.video_library_outlined,
                label: context.t('social.publish.videoSelect'),
                onTap: onPickVideo,
              ),
              _CompactMediaActionTile(
                icon: Symbols.link_rounded,
                label: context.t('social.publish.videoUrl'),
                onTap: onPickVideoUrl,
              ),
            ],
          )
        else
          _EmptyMediaPicker(
            onPickImage: onPickImage,
            onPickImageUrl: onPickImageUrl,
            onPickVideo: onPickVideo,
            onPickVideoUrl: onPickVideoUrl,
          ),
      ],
    );
  }
}

class _MediaThumb extends StatefulWidget {
  const _MediaThumb({
    required this.url,
    required this.index,
    required this.onRemove,
  });

  final String url;
  final int index;
  final VoidCallback onRemove;

  @override
  State<_MediaThumb> createState() => _MediaThumbState();
}

class _MediaThumbState extends State<_MediaThumb> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isVideo = isSocialVideoUrl(widget.url);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Stack(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
              border: Border.all(color: AppColors.line),
              color: AppColors.surface,
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.url.isEmpty
                ? const Center(
                    child: Icon(
                      Symbols.image_rounded,
                      color: AppColors.iconMuted,
                    ),
                  )
                : isVideo
                ? SocialVideoThumb(url: widget.url)
                : SocialMediaPreview(
                    url: widget.url,
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                    memCacheWidth: 180,
                    errorWidget: const Center(
                      child: Icon(
                        Symbols.image_rounded,
                        color: AppColors.iconMuted,
                      ),
                    ),
                  ),
          ),
          // Overlay on hover
          if (_hovering)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
                ),
                child: Center(
                  child: GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Symbols.close_rounded,
                        size: 16,
                        color: AppColors.actionRed,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Index badge
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.deepOcean.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '${widget.index + 1}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMediaPicker extends StatelessWidget {
  const _EmptyMediaPicker({
    required this.onPickImage,
    required this.onPickImageUrl,
    required this.onPickVideo,
    required this.onPickVideoUrl,
  });

  final VoidCallback onPickImage;
  final VoidCallback onPickImageUrl;
  final VoidCallback onPickVideo;
  final VoidCallback onPickVideoUrl;

  @override
  Widget build(BuildContext context) {
    return _SocialMediaDashedRect(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 142),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.deepOcean.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.perm_media_outlined,
                color: _socialMediaUploadInk,
                size: 21,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _InlineMediaActionButton(
                  icon: Symbols.add_photo_alternate_outlined,
                  label: context.t('social.publish.imageSelect'),
                  onTap: onPickImage,
                ),
                _InlineMediaActionButton(
                  icon: Symbols.public,
                  label: context.t('social.publish.imageUrl'),
                  onTap: onPickImageUrl,
                ),
                _InlineMediaActionButton(
                  icon: Symbols.video_library_outlined,
                  label: context.t('social.publish.videoSelect'),
                  onTap: onPickVideo,
                ),
                _InlineMediaActionButton(
                  icon: Symbols.link_rounded,
                  label: context.t('social.publish.videoUrl'),
                  onTap: onPickVideoUrl,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMediaActionTile extends StatelessWidget {
  const _CompactMediaActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 90,
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
            border: Border.all(color: _socialMediaStrongLine),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: AppColors.deepOcean),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepOcean,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineMediaActionButton extends StatelessWidget {
  const _InlineMediaActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _socialMediaStrongLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.deepOcean),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialMediaDashedRect extends StatelessWidget {
  const _SocialMediaDashedRect({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SocialMediaDashedBorderPainter(),
      child: child,
    );
  }
}

class _SocialMediaDashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _socialMediaStrongLine
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(AppRadius.value),
    );
    final path = Path()..addRRect(rect);
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 7;
        dashed.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + 4;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _SocialMediaDashedBorderPainter oldDelegate) =>
      false;
}
