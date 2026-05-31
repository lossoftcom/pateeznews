import 'package:flutter/material.dart';

import 'app_colors.dart';

/// PateezInter variable font üzerine kurulu, editorial hiyerarşili tipografi.
///
/// Hiyerarşi:
///   display   → featured haber başlığı (büyük, ekstra siyah)
///   titleL    → bölüm başlığı
///   titleM    → haber kartı başlığı
///   titleS    → küçük kart başlığı
///   body      → açıklama metni
///   bodySmall → ikinci açıklama
///   meta      → zaman, kategori, kaynak
///   eyebrow   → kategori chip / küçük caps etiket
class AppTypography {
  const AppTypography._();

  static const String _family = 'PateezInter';

  static const TextStyle display = TextStyle(
    fontFamily: _family,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.18,
    color: AppColors.inkStrong,
  );

  static const TextStyle titleL = TextStyle(
    fontFamily: _family,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
    color: AppColors.ink,
  );

  static const TextStyle titleM = TextStyle(
    fontFamily: _family,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.28,
    color: AppColors.ink,
  );

  static const TextStyle titleS = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.45,
    color: AppColors.inkSoft,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.45,
    color: AppColors.inkSoft,
  );

  static const TextStyle meta = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
    color: AppColors.support,
  );

  static const TextStyle eyebrow = TextStyle(
    fontFamily: _family,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
    height: 1.2,
    color: AppColors.inkSoft,
  );

  static const TextStyle navLabel = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static const TextStyle storyLabel = TextStyle(
    fontFamily: _family,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.2,
    color: AppColors.ink,
  );
}
