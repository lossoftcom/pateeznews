import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/back_circle_button.dart';

/// Kategori sayfasının sabit üst barı.
///
/// Solda sade arama butonu, sağda — login ve haber detayıyla aynı — daire geri
/// butonu. Masthead kaydırılıp geçince ortada, kırmızı dikey çubuk önünde,
/// kategori başlığı yumuşakça belirir. Alt çizgi kaydırmayla birlikte
/// belirginleşir; `HomeAppBar` yüksekliğini korur.
class CategoryAppBar extends StatelessWidget {
  const CategoryAppBar({
    super.key,
    required this.title,
    required this.scrollOffset,
    required this.onBack,
    this.onSearch,
  });

  final String title;
  final double scrollOffset;
  final VoidCallback onBack;
  final VoidCallback? onSearch;

  static const double _height = 56;
  static const double _titleStart = 56;
  static const double _titleEnd = 150;

  /// 0 → başlık gizli (masthead görünür), 1 → başlık tamamen belirgin.
  double get _t {
    final raw = (scrollOffset - _titleStart) / (_titleEnd - _titleStart);
    return raw.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.viewPaddingOf(context).top;
    final elevated = scrollOffset > 4;
    final t = _t;

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
      child: Row(
        children: [
          const SizedBox(width: 6),
          _PlainIconButton(
            icon: Symbols.search_rounded,
            semantics: 'Bu kategoride ara',
            onTap: onSearch ?? () {},
          ),
          Expanded(
            child: IgnorePointer(
              child: Opacity(
                opacity: t,
                child: _CollapsedTitle(title: title),
              ),
            ),
          ),
          BackCircleButton(onTap: onBack),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
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
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}
