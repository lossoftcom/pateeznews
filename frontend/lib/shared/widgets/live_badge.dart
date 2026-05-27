import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Pulse efektli, kısıtlı kullanım için canlı / breaking rozeti.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.label = 'CANLI'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.actionRed,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 700.ms)
              .fade(begin: 1, end: 0.35, duration: 700.ms),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.eyebrow.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
