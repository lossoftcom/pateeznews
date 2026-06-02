import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';

/// Solda menü, ortada wordmark, sağda arama. Scroll'la birlikte alt çizgi
/// belirginleşir.
class HomeAppBar extends StatelessWidget {
  const HomeAppBar({
    super.key,
    required this.onMenuTap,
    required this.onSearchTap,
    this.elevated = false,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onSearchTap;
  final bool elevated;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: _height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: elevated ? AppColors.line : AppColors.softLine,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          _AppBarButton(
            icon: Symbols.menu_rounded,
            onTap: onMenuTap,
            semantics: 'Menü',
          ),
          const Expanded(child: Center(child: _Wordmark())),
          _AppBarButton(
            icon: Symbols.search_rounded,
            onTap: onSearchTap,
            semantics: 'Arama',
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _AppBarButton extends StatelessWidget {
  const _AppBarButton({
    required this.icon,
    required this.onTap,
    required this.semantics,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: AppColors.iconStrong),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'pateez',
            style: TextStyle(
              fontFamily: 'PateezInter',
              color: AppColors.inkStrong,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          TextSpan(
            text: 'news',
            style: TextStyle(
              fontFamily: 'PateezInter',
              color: AppColors.accentAction,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          TextSpan(
            text: '.',
            style: TextStyle(
              fontFamily: 'PateezInter',
              color: AppColors.warmHorizon,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
