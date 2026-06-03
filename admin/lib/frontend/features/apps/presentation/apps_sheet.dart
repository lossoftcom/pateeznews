import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/app_item.dart';

/// "Uygulamalar" alt sayfasının içeriği: tutamaç, başlık ve premium servis
/// kartları. Aşağıdan yukarı kayan, üstü yuvarlatılmış beyaz yüzey; kayma,
/// karartma ve konum (bottom nav'ın üstünde) kabuk ekranında yönetilir.
///
/// Her servis küçük ikon-ızgara yerine geniş, dokunması net bir kart: solda
/// vurgu tonuyla tonlanmış ikon, ortada başlık + kısa açıklama, sağda ok.
/// Açılışta kartlar sırayla belirir (2026 hissi).
class AppsSheet extends StatelessWidget {
  const AppsSheet({super.key, required this.items, required this.onSelect});

  final List<AppItem> items;
  final ValueChanged<AppItem> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.18),
            blurRadius: 36,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.md,
          AppSpacing.pageHorizontal,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.only(right: AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: AppColors.actionRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Uygulamalar',
                  style: AppTypography.titleL.copyWith(
                    color: AppColors.inkStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              _ServiceCard(item: items[i], onTap: () => onSelect(items[i]))
                  .animate()
                  .fadeIn(
                    delay: (70 * i).ms,
                    duration: 320.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .slideY(
                    begin: 0.12,
                    end: 0,
                    delay: (70 * i).ms,
                    duration: 320.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.item, required this.onTap});

  final AppItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.label,
      button: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepOcean.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: item.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: item.glyph(32, item.accent),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleS.copyWith(
                          color: AppColors.inkStrong,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.inkSoft,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceInk,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Symbols.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
