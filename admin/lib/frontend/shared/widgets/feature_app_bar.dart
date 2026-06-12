import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../features/search/presentation/search_screen.dart';
import 'back_circle_button.dart';

/// Mini servis / uygulama sayfaları (Etkinlikler, Duyurular, Nöbetçi Eczane,
/// Namaz Vakitleri, Hava Durumu, Niğde'de Bugün, Ölüm İlanları, Döviz & Altın …)
/// için ortak üst bar.
///
/// Kategori sayfasının üst barıyla birebir aynı dil: solda sade arama ikonu,
/// ortada kırmızı dikey çubuk önünde başlık (aynı font/boyut/kalınlık), sağda
/// uygulamanın tek tip daire geri butonu. Böylece tüm uygulamalar tutarlı görünür.
class FeatureAppBar extends StatelessWidget {
  const FeatureAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.onSearch,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;

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
          const SizedBox(width: 6),
          _PlainIconButton(
            icon: Symbols.search_rounded,
            semantics: 'Ara',
            onTap: onSearch ?? () => _openSearch(context),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.actionRed,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleM.copyWith(
                      color: AppColors.inkStrong,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          BackCircleButton(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

void _openSearch(BuildContext context) {
  Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => const SearchScreen(showBackButton: true),
      transitionsBuilder: (context, animation, secondary, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    ),
  );
}

class _PlainIconButton extends StatelessWidget {
  const _PlainIconButton({
    required this.icon,
    required this.semantics,
    required this.onTap,
  });

  final IconData icon;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 23, color: AppColors.iconStrong),
          ),
        ),
      ),
    );
  }
}
