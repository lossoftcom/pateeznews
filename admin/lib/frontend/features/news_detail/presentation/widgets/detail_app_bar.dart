import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Detay sayfasının en üstünde her zaman görünen, scroll'a göre saydam zeminden
/// beyaz zemine dönüşen üst bar.
///
/// Yapı: sadece yuvarlak (daire) geri butonu — paylaşım ve kaydet aksiyonları
/// artık hero görsel üstünde, tarih hizasında ve sağa yaslı görünür.
/// Scroll edilince ortada, kırmızı dikey çubuk önünde, küçük punto ile
/// haber başlığı belirir; sığmazsa üç nokta ile kesilir.
class DetailAppBar extends StatelessWidget {
  const DetailAppBar({
    super.key,
    required this.scrollOffset,
    required this.onBack,
    required this.title,
  });

  final double scrollOffset;
  final VoidCallback onBack;
  final String title;

  static const double _height = 52;
  static const double _transitionStart = 60;
  static const double _transitionEnd = 220;

  double get _t {
    final range = _transitionEnd - _transitionStart;
    final raw = (scrollOffset - _transitionStart) / range;
    return raw.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final topPadding = MediaQuery.viewPaddingOf(context).top;

    final surfaceAlpha = (t * 1.0).clamp(0.0, 1.0);
    final iconColor = Color.lerp(Colors.white, AppColors.iconStrong, t)!;
    final glassBg = Color.lerp(
      Colors.black.withValues(alpha: 0.34),
      Colors.transparent,
      t,
    )!;
    final glassBorder = Color.lerp(
      Colors.white.withValues(alpha: 0.32),
      Colors.transparent,
      t,
    )!;
    final titleOpacity = t;
    final dividerAlpha = (t * 0.6).clamp(0.0, 1.0);

    return Container(
      height: _height + topPadding,
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: surfaceAlpha),
        border: Border(
          bottom: BorderSide(
            color: AppColors.line.withValues(alpha: dividerAlpha),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Opacity(
              opacity: titleOpacity,
              child: _CollapsedTitle(title: title),
            ),
          ),
          _CircleBackButton(
            onTap: onBack,
            background: glassBg,
            border: glassBorder,
            foreground: iconColor,
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({
    required this.onTap,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final VoidCallback onTap;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Geri',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 1),
            ),
            child: Icon(
              Symbols.chevron_left_rounded,
              size: 24,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
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
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}
