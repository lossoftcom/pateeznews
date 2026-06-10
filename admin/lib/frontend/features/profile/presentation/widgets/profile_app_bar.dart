import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/back_circle_button.dart';

/// Profil sayfasının kapağın üzerinde yüzen, kaydırmaya duyarlı üst barı.
///
/// En üstte (kapak görünürken) zemin saydamdır; sağda uygulamanın ortak
/// [BackCircleButton]'ı durur. Kapak yukarı kayınca zemin beyaza döner, alt
/// çizgi belirir ve ortada kırmızı dikey çubuk önünde kullanıcı adı yumuşakça
/// görünür.
class ProfileAppBar extends StatelessWidget {
  const ProfileAppBar({
    super.key,
    required this.title,
    required this.scrollOffset,
    required this.onBack,
  });

  final String title;
  final double scrollOffset;
  final VoidCallback onBack;

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
          const SizedBox(width: 50),
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
