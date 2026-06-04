import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/app_item.dart';

/// "Uygulamalar" alt sayfasının içeriği: tutamaç, başlık ve yan yana uygulama
/// ızgarası. Her hücre yumuşak köşeli (squircle) bir app-ikon karesi + iki
/// satırlık etikettir — sade, ferah, Apple disiplininde. Kayma/karartma/konum
/// kabuk ekranında yönetilir; açılışta hücreler sırayla belirir.
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
            color: AppColors.deepOcean.withValues(alpha: 0.14),
            blurRadius: 32,
            offset: const Offset(0, -10),
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
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.lg,
              childAspectRatio: 0.80,
              children: [
                for (var i = 0; i < items.length; i++)
                  _AppTile(item: items[i], onTap: () => onSelect(items[i]))
                      .animate()
                      .fadeIn(delay: (50 * i).ms, duration: 280.ms, curve: Curves.easeOutCubic)
                      .slideY(begin: 0.16, end: 0, delay: (50 * i).ms, duration: 280.ms, curve: Curves.easeOutCubic),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.item, required this.onTap});

  final AppItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLogo = item.id == 'nobetci-eczane';
    return Semantics(
      label: item.label,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: isLogo
                      ? AppColors.surface
                      : item.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: isLogo ? Border.all(color: AppColors.line) : null,
                ),
                alignment: Alignment.center,
                child: item.glyph(isLogo ? 42 : 30, item.accent),
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
