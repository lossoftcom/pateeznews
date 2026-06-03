import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/back_circle_button.dart';

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
          BackCircleButton(onTap: onBack),
          const SizedBox(width: 10),
        ],
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
