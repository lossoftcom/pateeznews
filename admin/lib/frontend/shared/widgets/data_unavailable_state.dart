import 'package:flutter/material.dart';

import '../../core/brand/default_brand_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class DataUnavailableState extends StatelessWidget {
  const DataUnavailableState({
    super.key,
    this.message = '',
    this.minHeight = 320,
  });

  final String message;
  final double minHeight;

  static const _logoAsset = DefaultBrandAssets.logo;

  @override
  Widget build(BuildContext context) {
    final cleanMessage = message.trim();
    return SizedBox(
      width: double.infinity,
      height: minHeight,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: 0.14,
                child: Image.asset(
                  _logoAsset,
                  width: 88,
                  height: 88,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 88, height: 88),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Veri yüklenemedi',
                textAlign: TextAlign.center,
                style: AppTypography.titleM.copyWith(
                  color: AppColors.inkStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (cleanMessage.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  cleanMessage,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.inkSoft,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
