import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../core/theme/app_colors.dart';

/// Tüm önyüz sayfalarında ortak, tek tip daire geri butonu.
///
/// `surfaceSoft` zeminli, `line` kenarlıklı 40×40 daire içinde `iconStrong`
/// chevron. Hesap (login), haber detayı ve kategori app bar'larında aynı
/// görünür; açık zeminde de görsel üzerinde de okunaklıdır.
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({
    super.key,
    required this.onTap,
    this.semanticsLabel = 'Geri',
  });

  final VoidCallback onTap;
  final String semanticsLabel;

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
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line, width: 1),
            ),
            child: const Icon(
              Symbols.chevron_left_rounded,
              size: 24,
              color: AppColors.iconStrong,
            ),
          ),
        ),
      ),
    );
  }
}
