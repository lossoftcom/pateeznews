import 'package:flutter/material.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Çift halka — dış halka durum (canlı / okunmamış / okunmuş), iç halka beyaz
/// nefes alanı — ve içeride monokrom ikon. Instagram'a "benzemeyen" özgün dil.
class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    super.key,
    required this.story,
    required this.onTap,
  });

  final StoryHighlight story;
  final VoidCallback onTap;

  Color get _ringColor {
    if (story.isLive) return AppColors.actionRed;
    if (story.isUnviewed) return AppColors.deepOcean;
    return AppColors.line;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _ringColor, width: 1.8),
                    ),
                  ),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceSoft,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      story.icon,
                      size: 24,
                      color: AppColors.deepOcean,
                    ),
                  ),
                  if (story.isLive)
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.actionRed,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          'CANLI',
                          style: AppTypography.eyebrow.copyWith(
                            color: Colors.white,
                            fontSize: 8.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            story.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.storyLabel.copyWith(
              color: story.isUnviewed ? AppColors.ink : AppColors.inkSoft,
              fontWeight:
                  story.isUnviewed ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
