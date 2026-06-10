import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Takip et / takip ediliyor pill'i. Profil ekranında canlı state ile,
/// önizlemelerde ise kendi küçük local state'iyle çalışabilir.
class FollowPill extends StatefulWidget {
  const FollowPill({
    super.key,
    this.initiallyFollowing = false,
    this.following,
    this.loading = false,
    this.onTap,
  });

  final bool initiallyFollowing;
  final bool? following;
  final bool loading;
  final VoidCallback? onTap;

  @override
  State<FollowPill> createState() => _FollowPillState();
}

class _FollowPillState extends State<FollowPill> {
  late bool _following = widget.initiallyFollowing;

  @override
  void didUpdateWidget(covariant FollowPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.following == null &&
        oldWidget.initiallyFollowing != widget.initiallyFollowing) {
      _following = widget.initiallyFollowing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final following = widget.following ?? _following;
    final loading = widget.loading;
    final bg = following
        ? AppColors.surfaceInk
        : AppColors.actionRed.withValues(alpha: 0.10);
    final fg = loading
        ? AppColors.support
        : following
        ? AppColors.inkSoft
        : AppColors.actionRed;
    final label = loading
        ? 'GÜNCELLENİYOR'
        : following
        ? 'TAKİP EDİLİYOR'
        : 'TAKİP ET';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading
            ? null
            : () {
                final onTap = widget.onTap;
                if (onTap != null) {
                  onTap();
                  return;
                }
                setState(() => _following = !_following);
              },
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading) ...[
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
