import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Takip et / takip ediliyor pill'i. Tap'le state geçişi yapar.
class FollowPill extends StatefulWidget {
  const FollowPill({super.key, this.initiallyFollowing = false});

  final bool initiallyFollowing;

  @override
  State<FollowPill> createState() => _FollowPillState();
}

class _FollowPillState extends State<FollowPill> {
  late bool _following = widget.initiallyFollowing;

  @override
  Widget build(BuildContext context) {
    final following = _following;
    final bg = following
        ? AppColors.surfaceInk
        : AppColors.actionRed.withValues(alpha: 0.10);
    final fg = following ? AppColors.inkSoft : AppColors.actionRed;
    final label = following ? 'TAKİP EDİLİYOR' : 'TAKİP ET';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _following = !_following),
        borderRadius: BorderRadius.circular(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: AppTypography.eyebrow.copyWith(
              color: fg,
              fontSize: 10,
              letterSpacing: 0.7,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
