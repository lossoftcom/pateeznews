import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Henüz içeriği gelmeyen sekmeler için sade, marka diline uygun karşılama
/// ekranı. Mock placeholder hissi yerine bilinçli bir "yakında" tasarımı.
class SectionPlaceholder extends StatelessWidget {
  const SectionPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.canvas,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.deepOcean.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 32, color: AppColors.deepOcean),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTypography.titleL),
          const SizedBox(height: AppSpacing.xs),
          Text(message, textAlign: TextAlign.center, style: AppTypography.body),
        ],
      ),
    );
  }
}
