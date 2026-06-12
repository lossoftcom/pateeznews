import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

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
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
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
          AppSpacing.sm,
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
            const SizedBox(height: AppSpacing.md),
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
                    decoration: TextDecoration.none,
                    decorationColor: Colors.transparent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.78,
              children: [
                for (var i = 0; i < items.length; i++)
                  _animatedTile(
                    item: items[i],
                    index: i,
                    disableAnimations: disableAnimations,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedTile({
    required AppItem item,
    required int index,
    required bool disableAnimations,
  }) {
    final tile = _AppTile(item: item, onTap: () => onSelect(item));
    if (disableAnimations) return tile;
    return tile
        .animate()
        .fadeIn(
          delay: (50 * index).ms,
          duration: 280.ms,
          curve: Curves.easeOutCubic,
        )
        .slideY(
          begin: 0.16,
          end: 0,
          delay: (50 * index).ms,
          duration: 280.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.item, required this.onTap});

  final AppItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = item.accent;
    // Duyurular afiş diliyle aynı: renk gradyanı + yumuşak daireler + beyaz ikon.
    // Nöbetçi Eczane kendi kırmızısında; gerçek logo gradyan üzerinde okunmadığı
    // için sade beyaz kapsül ikonu kullanılır (logo eczane sayfasında korunur).
    final Widget glyph = item.id == 'nobetci-eczane'
        ? const Icon(Symbols.capsule_fill, size: 30, color: Colors.white)
        : item.glyph(30, Colors.white);

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
                width: 62,
                height: 62,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(accent, Colors.white, 0.16)!,
                      accent,
                      Color.lerp(accent, Colors.black, 0.28)!,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const Positioned(
                      right: -12,
                      top: -14,
                      child: _SoftCircle(size: 36, opacity: 0.12),
                    ),
                    const Positioned(
                      left: -10,
                      bottom: -16,
                      child: _SoftCircle(size: 30, opacity: 0.08),
                    ),
                    Center(child: glyph),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
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

/// Afiş üzerindeki yumuşak dekoratif daire (Duyurular görseliyle aynı doku).
class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
