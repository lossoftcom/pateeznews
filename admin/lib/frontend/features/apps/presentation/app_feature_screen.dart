import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/back_circle_button.dart';
import '../data/app_item.dart';

/// Bir mini servisin (Nöbetçi Eczane, Hava Durumu, Ölüm İlanları...) şimdilik
/// boş, "yakında" durumundaki sayfası.
///
/// Üstte sade app bar (ortada başlık, sağda ortak daire geri butonu), gövdede
/// servisin vurgu tonuyla tonlanmış ikonu ve bilgilendirme metni. Tasarım dili
/// uygulamayla birebir aynıdır; içerik aşama aşama doldurulacaktır.
class AppFeatureScreen extends StatelessWidget {
  const AppFeatureScreen({super.key, required this.item});

  final AppItem item;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            _AppBar(title: item.label),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxxl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: item.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: item.glyph(46, item.accent),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        item.tagline,
                        textAlign: TextAlign.center,
                        style: AppTypography.titleL.copyWith(
                          color: AppColors.inkStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        item.description,
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: AppColors.inkSoft,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _SoonChip(),
                    ],
                  ),
                ),
              ).animate().fadeIn(
                duration: 360.ms,
                curve: Curves.easeOutCubic,
              ).slideY(
                begin: 0.06,
                end: 0,
                duration: 360.ms,
                curve: Curves.easeOutCubic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.title});

  final String title;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Container(
      height: _height + topInset,
      padding: EdgeInsets.only(top: topInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.softLine, width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 56),
          Expanded(
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleM.copyWith(
                  color: AppColors.inkStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          BackCircleButton(onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _SoonChip extends StatelessWidget {
  const _SoonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceInk,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'YAKINDA',
        style: AppTypography.eyebrow.copyWith(
          color: AppColors.inkSoft,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
