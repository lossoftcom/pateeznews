import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'frontend_font_settings.dart';

class AppTypography {
  const AppTypography._();

  static FrontendFontSettings _settings = FrontendFontSettings.empty();

  static void configure(FrontendFontSettings settings) {
    _settings = settings;
  }

  static String get primaryFamily => _settings.primaryFontFamily;

  static String get titleFamily => _settings.titleFontFamily;

  static String get contentFamily => _settings.contentFontFamily;

  static TextStyle get display => TextStyle(
    fontFamily: titleFamily,
    fontSize: _settings.size('fs-title-3xl'),
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    height: 1.18,
    color: AppColors.inkStrong,
  );

  static TextStyle get postTitle => TextStyle(
    fontFamily: titleFamily,
    fontSize: _settings.size('fs-post-title'),
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    height: 1.08,
    color: AppColors.inkStrong,
  );

  static TextStyle get postSummary => TextStyle(
    fontFamily: contentFamily,
    fontSize: _settings.size('fs-post-summary'),
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.45,
    color: AppColors.inkSoft,
  );

  static TextStyle get articleBody => TextStyle(
    fontFamily: contentFamily,
    fontSize: _settings.size('fs-content'),
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.62,
    color: AppColors.ink,
  );

  static TextStyle get titleL => TextStyle(
    fontFamily: titleFamily,
    fontSize: _settings.size('fs-title-lg'),
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.2,
    color: AppColors.ink,
  );

  static TextStyle get titleM => TextStyle(
    fontFamily: titleFamily,
    fontSize: _settings.size('fs-title-md'),
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.28,
    color: AppColors.ink,
  );

  static TextStyle get titleS => TextStyle(
    fontFamily: titleFamily,
    fontSize: _settings.size('fs-title-xs'),
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
    color: AppColors.ink,
  );

  static TextStyle get body => TextStyle(
    fontFamily: contentFamily,
    fontSize: _settings.size('fs-md'),
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.45,
    color: AppColors.inkSoft,
  );

  static TextStyle get bodySmall => TextStyle(
    fontFamily: contentFamily,
    fontSize: _settings.size('fs-sm'),
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.45,
    color: AppColors.inkSoft,
  );

  static TextStyle get meta => TextStyle(
    fontFamily: primaryFamily,
    fontSize: _settings.size('fs-xs'),
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.3,
    color: AppColors.support,
  );

  static TextStyle get eyebrow => TextStyle(
    fontFamily: primaryFamily,
    fontSize: _settings.size('fs-tiny'),
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.2,
    color: AppColors.inkSoft,
  );

  static TextStyle get navLabel => TextStyle(
    fontFamily: primaryFamily,
    fontSize: _settings.size('fs-main-nav'),
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.2,
  );

  static TextStyle get storyLabel => TextStyle(
    fontFamily: titleFamily,
    fontSize: _settings.size('fs-xs'),
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.2,
    color: AppColors.ink,
  );
}
