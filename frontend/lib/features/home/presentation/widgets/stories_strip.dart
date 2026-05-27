import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_spacing.dart';
import 'story_avatar.dart';

/// Yatay kayan, soft fade-in girişli hikaye şeridi.
class StoriesStrip extends StatelessWidget {
  const StoriesStrip({super.key, required this.stories});

  final List<StoryHighlight> stories;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.sm,
        ),
        physics: const BouncingScrollPhysics(),
        itemCount: stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final story = stories[index];
          return StoryAvatar(
            story: story,
            onTap: () {
              // Hikaye detay rotası ileride buradan açılır.
            },
          )
              .animate()
              .fadeIn(
                delay: (40 * index).ms,
                duration: 320.ms,
                curve: Curves.easeOutCubic,
              )
              .slideY(
                begin: 0.08,
                end: 0,
                delay: (40 * index).ms,
                duration: 320.ms,
                curve: Curves.easeOutCubic,
              );
        },
      ),
    );
  }
}
