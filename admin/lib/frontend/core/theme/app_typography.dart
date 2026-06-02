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

  static FontWeight _weightFromValue(int value) {
    final index = ((value.clamp(100, 900) / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[index];
  }

  static FontWeight _mobileWeight(String key) {
    return _weightFromValue(_settings.mobileWeightValue(key));
  }

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

  static TextStyle get mobileMenuLabel => TextStyle(
    fontFamily: primaryFamily,
    fontSize: _settings.mobileSize('mobile-nav-label'),
    fontWeight: _mobileWeight('mobile-nav-label'),
    letterSpacing: 0,
    height: 1.2,
  );

  static TextStyle get mobileFeaturedTitle => TextStyle(
    fontFamily: titleFamily,
    fontSize: _settings.mobileSize('mobile-featured-title'),
    fontWeight: _mobileWeight('mobile-featured-title'),
    letterSpacing: 0,
    height: 1.08,
    color: AppColors.inkStrong,
  );

  static TextStyle get mobileFeaturedSummary => TextStyle(
    fontFamily: contentFamily,
    fontSize: _settings.mobileSize('mobile-featured-summary'),
    fontWeight: _mobileWeight('mobile-featured-summary'),
    letterSpacing: 0,
    height: 1.42,
    color: AppColors.ink,
  );

  static TextStyle get mobileNewsCardTitle => TextStyle(
    fontFamily: titleFamily,
    fontSize: _settings.mobileSize('mobile-card-title'),
    fontWeight: _mobileWeight('mobile-card-title'),
    letterSpacing: 0,
    height: 1.08,
    color: AppColors.inkStrong,
  );

  static TextStyle get mobileNewsCardSummary => TextStyle(
    fontFamily: contentFamily,
    fontSize: _settings.mobileSize('mobile-card-summary'),
    fontWeight: _mobileWeight('mobile-card-summary'),
    letterSpacing: 0,
    height: 1.5,
    color: AppColors.inkSoft,
  );

  static TextStyle get mobileDetailTitle => TextStyle(
    fontFamily: titleFamily,
    fontSize: _settings.mobileSize('mobile-detail-title'),
    fontWeight: _mobileWeight('mobile-detail-title'),
    letterSpacing: 0,
    height: 1.1,
    color: AppColors.inkStrong,
  );

  static TextStyle get mobileDetailSummary => TextStyle(
    fontFamily: contentFamily,
    fontSize: _settings.mobileSize('mobile-detail-summary'),
    fontWeight: _mobileWeight('mobile-detail-summary'),
    letterSpacing: 0,
    height: 1.45,
    color: AppColors.inkSoft,
  );

  static TextStyle get mobileDetailBody => TextStyle(
    fontFamily: contentFamily,
    fontSize: _settings.mobileSize('mobile-detail-body'),
    fontWeight: _mobileWeight('mobile-detail-body'),
    letterSpacing: 0,
    height: 1.62,
    color: AppColors.ink,
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
