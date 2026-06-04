import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'back_circle_button.dart';

/// Mini servis sayfaları (Hava Durumu, Nöbetçi Eczane, Ölüm İlanları) için ortak
/// üst bar: ortada başlık, sağda uygulamanın tek tip [BackCircleButton]'ı.
/// İsteğe bağlı [trailing] sağ üst aksiyon (örn. paylaş) için kullanılır.
class FeatureAppBar extends StatelessWidget {
  const FeatureAppBar({super.key, required this.title, this.onBack, this.trailing});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

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
          SizedBox(
            width: 56,
            child: trailing == null
                ? null
                : Align(alignment: Alignment.centerLeft, child: trailing),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleM.copyWith(
                  color: AppColors.inkStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          BackCircleButton(onTap: onBack ?? () => Navigator.of(context).maybePop()),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}
