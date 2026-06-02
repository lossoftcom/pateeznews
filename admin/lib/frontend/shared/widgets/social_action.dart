import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../core/mock/home_mock_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

enum PateezSocialGlyph {
  sparkUp,
  sparkDown,
  conversation,
  orbitShare,
  ribbon,
  heart,
}

/// Sayılı, toggle'lı sosyal etkileşim butonu.
///
/// Aktif duruma geçince ikon yumuşak bir scale + fade ile takas olur,
/// sayı rengi ve ağırlığı animasyonla güncellenir.
class SocialAction extends StatelessWidget {
  const SocialAction({
    super.key,
    required this.glyph,
    this.activeGlyph,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
    required this.semanticLabel,
    this.count,
    this.iconSize = 22,
    this.inactiveColor,
    this.countFontSize,
  });

  final PateezSocialGlyph glyph;
  final PateezSocialGlyph? activeGlyph;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;
  final String semanticLabel;
  final int? count;
  final double iconSize;

  /// Pasif duruma özel renk override'ı. Varsayılan `AppColors.iconMuted`'tir;
  /// koyu görsel üstünde (örn. hero overlay) beyaz icon istendiğinde
  /// ezilebilir. Mevcut çağrı yerleri etkilenmez.
  final Color? inactiveColor;

  /// Sayı font boyutu override'ı. Verilmezse `AppTypography.meta` boyutu
  /// (12) kullanılır. Daha kompakt yerleşimlerde (örn. hero overlay)
  /// daha küçük bir sayı görüntülemek için ezilebilir.
  final double? countFontSize;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? activeColor
        : (inactiveColor ?? AppColors.iconMuted);
    final resolvedGlyph = isActive ? activeGlyph ?? glyph : glyph;
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: isActive,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) {
                    return ScaleTransition(
                      scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                        CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                      child: FadeTransition(opacity: anim, child: child),
                    );
                  },
                  child: SizedBox.square(
                    key: ValueKey<String>('${resolvedGlyph.name}-$isActive'),
                    dimension: iconSize,
                    child: Icon(
                      _iconForGlyph(resolvedGlyph, filled: isActive),
                      color: color,
                      size: iconSize,
                    ),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: AppTypography.meta.copyWith(
                      color: color,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      fontSize: countFontSize,
                    ),
                    child: Text(CountFormat.compact(count!)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconForGlyph(PateezSocialGlyph glyph, {required bool filled}) {
  switch (glyph) {
    case PateezSocialGlyph.sparkUp:
      return filled ? Symbols.thumb_up_fill : Symbols.thumb_up_line;
    case PateezSocialGlyph.sparkDown:
      return filled ? Symbols.thumb_down_fill : Symbols.thumb_down_line;
    case PateezSocialGlyph.conversation:
      return filled ? Symbols.chat_3_fill : Symbols.chat_3_line;
    case PateezSocialGlyph.orbitShare:
      return filled ? Symbols.share_2_fill : Symbols.share_2_line;
    case PateezSocialGlyph.ribbon:
      return filled ? Symbols.bookmark_3_fill : Symbols.bookmark_3_line;
    case PateezSocialGlyph.heart:
      return filled ? Symbols.heart_3_fill : Symbols.heart_3_line;
  }
}
