import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/back_circle_button.dart';

/// Profil sayfasının kapağın üzerinde yüzen, kaydırmaya duyarlı üst barı.
///
/// En üstte (kapak görünürken) zemin saydamdır; solda paylaş, sağda — uygulamanın
/// ortak [BackCircleButton]'ı ile aynı — daire geri butonu durur. Kapak yukarı
/// kayınca zemin beyaza döner, alt çizgi belirir ve ortada kırmızı dikey çubuk
/// önünde kullanıcı adı yumuşakça görünür.
class ProfileAppBar extends StatelessWidget {
  const ProfileAppBar({
    super.key,
    required this.title,
    required this.scrollOffset,
    required this.onBack,
    this.onShare,
  });

  final String title;
  final double scrollOffset;
  final VoidCallback onBack;
  final VoidCallback? onShare;

  static const double _height = 56;
  static const double _titleStart = 120;
  static const double _titleEnd = 196;

  double get _t {
    final raw = (scrollOffset - _titleStart) / (_titleEnd - _titleStart);
    return raw.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.viewPaddingOf(context).top;
    final t = _t;
    final surfaceAlpha = t;
    final dividerAlpha = (t * 0.7).clamp(0.0, 1.0);

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
          const SizedBox(width: 10),
          _CircleActionButton(
            icon: Symbols.ios_share_rounded,
            semantics: 'Profili paylaş',
            onTap: onShare ?? () {},
          ),
          Expanded(
            child: IgnorePointer(
              child: Opacity(opacity: t, child: _CollapsedTitle(title: title)),
            ),
          ),
          BackCircleButton(onTap: onBack),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

/// Paylaş gibi yardımcı aksiyonlar için, [BackCircleButton] ile aynı görünümde
/// daire buton.
class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
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
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line, width: 1),
            ),
            child: Icon(icon, size: 20, color: AppColors.iconStrong),
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
