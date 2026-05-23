import 'package:flutter/material.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';

/// Media picker widget that supports multiple images.
class SocialMediaPicker extends StatelessWidget {
  const SocialMediaPicker({
    super.key,
    required this.mediaUrls,
    required this.onPickMedia,
    required this.onClearMedia,
    required this.onRemoveMedia,
  });

  final List<String> mediaUrls;
  final VoidCallback onPickMedia;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.deepOcean.withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(AppRadius.value * 1.5),
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
                        const Icon(Icons.delete_outline_rounded,
                            size: 14, color: AppColors.actionRed),
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
              // Add more button
              _AddMediaButton(onTap: onPickMedia),
            ],
          )
        else
          // Empty state — add first image
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onPickMedia,
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.circular(AppRadius.value * 2),
                  border: Border.all(
                    color: AppColors.line,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 28,
                      color: AppColors.iconMuted.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t('social.publish.addMedia'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.support.withValues(alpha: 0.8),
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.t('social.publish.newsAutoFill'),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.support.withValues(alpha: 0.5),
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
              image: DecorationImage(
                image: NetworkImage(widget.url),
                fit: BoxFit.cover,
                onError: (_, __) {},
              ),
              color: AppColors.surface,
            ),
            child: widget.url.isEmpty
                ? const Icon(Icons.image_rounded, color: AppColors.iconMuted)
                : null,
          ),
          // Overlay on hover
          if (_hovering)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius:
                      BorderRadius.circular(AppRadius.value * 1.5),
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
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.actionRed),
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

class _AddMediaButton extends StatelessWidget {
  const _AddMediaButton({required this.onTap});
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
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded,
                  size: 22, color: AppColors.iconMuted.withValues(alpha: 0.6)),
              const SizedBox(height: 2),
              Text(
                context.t('social.publish.addMedia'),
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.support.withValues(alpha: 0.6),
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
