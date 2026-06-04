import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../shell/data/app_shell_repository.dart';

/// Solda menü, ortada wordmark. Scroll'la birlikte alt çizgi belirginleşir.
class HomeAppBar extends StatelessWidget {
  const HomeAppBar({
    super.key,
    required this.onMenuTap,
    this.onPharmacyTap,
    this.shellSettings = const AppShellSettings.empty(),
    this.elevated = false,
  });

  final VoidCallback onMenuTap;
  final VoidCallback? onPharmacyTap;
  final AppShellSettings shellSettings;
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
          Expanded(
            child: Center(child: _BrandMark(settings: shellSettings)),
          ),
          _PharmacyBadge(onTap: onPharmacyTap ?? () {}),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Ana sayfa app bar'ında sağa yaslı nöbetçi eczane kısayolu — gerçek Nöbetçi
/// Eczane logosunun optimize webp'i.
class _PharmacyBadge extends StatelessWidget {
  const _PharmacyBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Nöbetçi eczane',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Image.asset(
                'assets/images/nobetci_eczane.webp',
                height: 36,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
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

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.settings});

  final AppShellSettings settings;

  @override
  Widget build(BuildContext context) {
    final logoUrl = settings.displayLogoUrl;
    if (logoUrl.isEmpty) {
      return _Wordmark(siteName: settings.siteName);
    }

    return SizedBox(
      height: 32,
      child: Image.network(
        logoUrl,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: settings.siteName.isEmpty
            ? 'Pateeznews'
            : settings.siteName,
        errorBuilder: (context, error, stackTrace) {
          return _Wordmark(siteName: settings.siteName);
        },
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.siteName});

  final String siteName;

  @override
  Widget build(BuildContext context) {
    final normalized = siteName.toLowerCase().replaceAll(' ', '');
    if (normalized.isNotEmpty && !normalized.contains('pateez')) {
      return Text(
        siteName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'PateezInter',
          color: AppColors.inkStrong,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1,
        ),
      );
    }

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
