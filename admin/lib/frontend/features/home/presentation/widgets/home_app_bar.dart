import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/brand/default_brand_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../shell/data/app_shell_repository.dart';

/// Solda menü, ortada wordmark. Scroll'la birlikte alt çizgi belirginleşir.
class HomeAppBar extends StatelessWidget {
  const HomeAppBar({
    super.key,
    required this.onMenuTap,
    this.onSubmitNewsTap,
    this.onPharmacyTap,
    this.shellSettings = const AppShellSettings.empty(),
    this.elevated = false,
  });

  final VoidCallback onMenuTap;
  final VoidCallback? onSubmitNewsTap;
  final VoidCallback? onPharmacyTap;
  final AppShellSettings shellSettings;
  final bool elevated;

  static const double _height = 56;
  static const double _brandHeight = 34;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: _height + topPadding,
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: elevated ? AppColors.line : AppColors.softLine,
            width: 1,
          ),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            top: 6,
            bottom: 6,
            child: _AppBarButton(
              icon: Symbols.menu_rounded,
              onTap: onMenuTap,
              semantics: 'Menü',
            ),
          ),
          Center(
            child: _BrandMark(settings: shellSettings, height: _brandHeight),
          ),
          Positioned(
            right: 0,
            top: 6,
            bottom: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SubmitNewsBadge(onTap: onSubmitNewsTap ?? () {}),
                const SizedBox(width: 2),
                _PharmacyBadge(onTap: onPharmacyTap ?? () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// WhatsApp üzerinden haber iletme kısayolu. Görsel yüksekliği eczane logosuyla
/// aynı tutulur; 44px dokunma alanı app bar ritmini bozmaz.
class _SubmitNewsBadge extends StatefulWidget {
  const _SubmitNewsBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SubmitNewsBadge> createState() => _SubmitNewsBadgeState();
}

class _SubmitNewsBadgeState extends State<_SubmitNewsBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  late final Animation<double> _heartbeat = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.035,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 9,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.035,
        end: 0.99,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 8,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.99,
        end: 1.018,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 7,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.018,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 8,
    ),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 68),
  ]).animate(_controller);

  static const _whatsappGreen = Color(0xFF25D366);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'WhatsApp ile haber gönder',
      button: true,
      child: AnimatedBuilder(
        animation: _heartbeat,
        builder: (context, child) {
          return Transform.scale(scale: _heartbeat.value, child: child);
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 72,
              height: 44,
              child: Center(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF32E176),
                        _whatsappGreen,
                        Color(0xFF119C4A),
                      ],
                      stops: [0, 0.56, 1],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _whatsappGreen.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        child: const Icon(
                          Symbols.whatsapp_fill,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Haber',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.eyebrow.copyWith(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                            Text(
                              'gönder',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.eyebrow.copyWith(
                                color: Colors.white.withValues(alpha: 0.94),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
  const _BrandMark({required this.settings, required this.height});

  final AppShellSettings settings;
  final double height;

  @override
  Widget build(BuildContext context) {
    final logoUrl = settings.lightSurfaceLogoUrl;
    final fallbackLogo = Image.asset(
      DefaultBrandAssets.logo,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: settings.siteName.isEmpty
          ? 'Pateeznews'
          : settings.siteName,
      errorBuilder: (_, _, _) => _Wordmark(siteName: settings.siteName),
    );
    if (logoUrl.isEmpty) {
      return SizedBox(height: height, width: 132, child: fallbackLogo);
    }

    return SizedBox(
      height: height,
      width: 132,
      child: Image.network(
        logoUrl,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: settings.siteName.isEmpty
            ? 'Pateeznews'
            : settings.siteName,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return fallbackLogo;
        },
        errorBuilder: (context, error, stackTrace) {
          return fallbackLogo;
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
