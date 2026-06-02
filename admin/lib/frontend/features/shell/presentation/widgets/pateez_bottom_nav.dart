import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

@immutable
class PateezNavItem {
  const PateezNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Ergonomi, sade dil ve mikro animasyon birlikteliğiyle özelleştirilmiş
/// bottom navigation. Aktif öğe yumuşak bir pill ile ifade edilir.
class PateezBottomNav extends StatelessWidget {
  const PateezBottomNav({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.onSelected,
  });

  final List<PateezNavItem> items;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.softLine, width: 1)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: AppSpacing.bottomNavHeight,
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isActive = index == activeIndex;
            return Expanded(
              child: _NavCell(
                item: item,
                isActive: isActive,
                onTap: () => onSelected(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final PateezNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.deepOcean;
    final passiveColor = AppColors.support;
    final color = isActive ? activeColor : passiveColor;

    return Semantics(
      label: item.label,
      selected: isActive,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 28,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      isActive ? item.activeIcon : item.icon,
                      key: ValueKey<bool>(isActive),
                      size: isActive ? 23 : 22,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: AppTypography.mobileMenuLabel.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
