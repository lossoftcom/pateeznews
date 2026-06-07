import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../core/theme/app_colors.dart';

/// Tüm önyüz sayfalarında ortak, tek tip daire geri butonu.
///
/// 40×40 dokunma alanında, `surfaceSoft` zeminli ve `line` kenarlıklı 36×36
/// daire içinde `iconStrong` arrow-left-line. Hesap (login), haber detayı ve
/// kategori app bar'larında aynı görünür; açık zeminde de görsel üzerinde de
/// okunaklıdır.
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({
    super.key,
    required this.onTap,
    this.semanticsLabel = 'Geri',
  });

  final VoidCallback onTap;
  final String semanticsLabel;

  static const double _tapSize = 40;
  static const double _circleSize = 36;
  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: _tapSize,
            child: Center(
              child: Container(
                width: _circleSize,
                height: _circleSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line, width: 1),
                ),
                child: const Icon(
                  Symbols.arrow_left_line,
                  size: _iconSize,
                  color: AppColors.iconStrong,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
