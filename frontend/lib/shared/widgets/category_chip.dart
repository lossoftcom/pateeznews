import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Sade, eyebrow tipografisinde tek dilli kategori etiketi.
///
/// İki varyantı vardır:
/// - [CategoryChip.surface]: açık zemin üstünde nötr chip (haber kartlarında)
/// - [CategoryChip.overlay]: koyu görsel üstünde okunaklı şeffaf chip
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.borderColor,
  });

  factory CategoryChip.surface(String label) {
    return CategoryChip(
      label: label,
      background: AppColors.surfaceInk,
      foreground: AppColors.inkSoft,
      borderColor: Colors.transparent,
    );
  }

  factory CategoryChip.overlay(String label) {
    return CategoryChip(
      label: label,
      background: Colors.white.withValues(alpha: 0.14),
      foreground: Colors.white,
      borderColor: Colors.white.withValues(alpha: 0.32),
    );
  }

  final String label;
  final Color background;
  final Color foreground;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.eyebrow.copyWith(color: foreground),
      ),
    );
  }
}
