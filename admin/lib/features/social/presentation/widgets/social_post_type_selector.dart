import 'package:flutter/material.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../social_platform_data.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

/// Segmented control for selecting post type (Feed, Story, Reels, etc.).
class SocialPostTypeSelector extends StatelessWidget {
  const SocialPostTypeSelector({
    super.key,
    required this.current,
    required this.available,
    required this.onChanged,
  });

  final SocialPostType current;
  final List<SocialPostType> available;
  final ValueChanged<SocialPostType> onChanged;

  IconData _iconFor(SocialPostType t) => switch (t) {
    SocialPostType.feed => Symbols.dynamic_feed_rounded,
    SocialPostType.story => Symbols.amp_stories_rounded,
    SocialPostType.reels => Symbols.movie_creation_rounded,
    SocialPostType.thread => Symbols.forum_rounded,
    SocialPostType.shortVideo => Symbols.slow_motion_video_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (available.length <= 1) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            context.t('social.publish.format'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.deepOcean,
              letterSpacing: 0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value * 2),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: available.map((type) {
              final selected = type == current;
              return Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => onChanged(type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppRadius.value * 1.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _iconFor(type),
                            size: 15,
                            color: selected
                                ? AppColors.deepOcean
                                : AppColors.iconMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            context.t(postTypeKey(type)),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: selected
                                  ? AppColors.deepOcean
                                  : AppColors.iconMuted,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
