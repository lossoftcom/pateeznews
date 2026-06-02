import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Haber akışı sıralama / filtre seçenekleri.
enum FeedFilter { latest, popular }

/// Section header'ın sağ ucuna oturan, çift segmentli sıralama tab'ı.
///
/// Aktif segment palet kırmızısı (`AppColors.actionRed`) zeminli kompakt
/// pill, pasif segment şeffaf zeminli `inkSoft` tonlu sade etiket. Geçiş
/// `AnimatedContainer` + `AnimatedDefaultTextStyle` ile yumuşak ve sessiz.
class FeedFilterTabs extends StatelessWidget {
  const FeedFilterTabs({
    super.key,
    required this.filter,
    required this.onChange,
  });

  final FeedFilter filter;
  final ValueChanged<FeedFilter> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterPill(
          label: 'En yeni',
          icon: Symbols.schedule_rounded,
          isActive: filter == FeedFilter.latest,
          onTap: () => onChange(FeedFilter.latest),
        ),
        const SizedBox(width: 4),
        _FilterPill(
          label: 'Popüler',
          icon: Symbols.local_fire_department_rounded,
          isActive: filter == FeedFilter.popular,
          onTap: () => onChange(FeedFilter.popular),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.actionRed;
    const inactiveColor = AppColors.inkSoft;
    final fg = isActive ? Colors.white : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: AppTypography.meta.copyWith(
                  color: fg,
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.1,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
