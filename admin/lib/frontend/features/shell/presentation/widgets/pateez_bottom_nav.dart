import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../account/data/frontend_auth_repository.dart';

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
    this.authState,
    this.authLoading = false,
  });

  final List<PateezNavItem> items;
  final int activeIndex;
  final ValueChanged<int> onSelected;
  final FrontendAuthState? authState;
  final bool authLoading;

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
                compact: items.length >= 5,
                authState: item.label == 'Hesap' ? authState : null,
                authLoading: item.label == 'Hesap' && authLoading,
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
    required this.compact,
    required this.authState,
    required this.authLoading,
    required this.onTap,
  });

  final PateezNavItem item;
  final bool isActive;
  final bool compact;
  final FrontendAuthState? authState;
  final bool authLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.deepOcean;
    final passiveColor = AppColors.support;
    final color = isActive ? activeColor : passiveColor;
    final showAvatar = authState != null;

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
                  width: 34,
                  height: compact ? 28 : 30,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: authLoading
                        ? const _AvatarSkeleton(key: ValueKey('loading'))
                        : showAvatar
                        ? _BottomAvatar(
                            key: ValueKey<String>(authState!.session.user.id),
                            authState: authState!,
                            active: isActive,
                          )
                        : Icon(
                            isActive ? item.activeIcon : item.icon,
                            key: ValueKey<bool>(isActive),
                            size: compact
                                ? (isActive ? 22 : 21)
                                : (isActive ? 23 : 22),
                            color: color,
                          ),
                  ),
                ),
                SizedBox(height: compact ? 3 : 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.mobileMenuLabel.copyWith(
                    color: color,
                    fontSize: compact ? 11.5 : null,
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

class _BottomAvatar extends StatelessWidget {
  const _BottomAvatar({
    super.key,
    required this.authState,
    required this.active,
  });

  final FrontendAuthState authState;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(child: _BottomAvatarContent(authState: authState)),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? AppColors.deepOcean : AppColors.line,
                  width: active ? 1.4 : 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomAvatarContent extends StatelessWidget {
  const _BottomAvatarContent({required this.authState});

  final FrontendAuthState authState;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = authState.avatarUrl;
    if (avatarUrl.isEmpty) return _BottomAvatarFallback(authState: authState);
    return Image.network(
      avatarUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _BottomAvatarFallback(authState: authState),
    );
  }
}

class _BottomAvatarFallback extends StatelessWidget {
  const _BottomAvatarFallback({required this.authState});

  final FrontendAuthState authState;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceSoft,
      child: Center(
        child: Text(
          authState.initials,
          style: AppTypography.titleS.copyWith(
            color: AppColors.deepOcean,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _AvatarSkeleton extends StatelessWidget {
  const _AvatarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceInk,
        border: Border.all(color: AppColors.softLine),
      ),
    );
  }
}
