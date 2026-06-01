import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'frontend_font_settings.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light({FrontendFontSettings? fontSettings}) {
    if (fontSettings != null) {
      AppTypography.configure(fontSettings);
    }
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: AppTypography.primaryFamily,
      fontFamilyFallback: const [
        'SF Pro Display',
        'SF Pro Text',
        'San Francisco',
        'Segoe UI',
        'Roboto',
        'Arial',
        'sans-serif',
      ],
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.deepOcean,
        onPrimary: Colors.white,
        secondary: AppColors.warmHorizon,
        onSecondary: Colors.white,
        tertiary: AppColors.actionRed,
        onTertiary: Colors.white,
        error: AppColors.actionRed,
        onError: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        surfaceContainerHighest: AppColors.surfaceSoft,
        outline: AppColors.line,
        outlineVariant: AppColors.softLine,
      ),
      splashColor: Colors.transparent,
      highlightColor: AppColors.surfaceInk,
      iconTheme: const IconThemeData(color: AppColors.iconStrong, size: 22),
      textTheme: TextTheme(
        displayLarge: AppTypography.display,
        titleLarge: AppTypography.titleL,
        titleMedium: AppTypography.titleM,
        titleSmall: AppTypography.titleS,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.titleS,
        labelMedium: AppTypography.meta,
        labelSmall: AppTypography.eyebrow,
      ),
    );
  }

  /// Sayfa açıldığında status bar ikonlarının koyu tonda görünmesini sağlar.
  static const SystemUiOverlayStyle lightOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  /// Featured carousel gibi koyu görsellerin üstünde açık ikon kullanılır.
  static const SystemUiOverlayStyle darkOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );
}
