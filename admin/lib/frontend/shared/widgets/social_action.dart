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
  forwardShare,
  ribbon,
  heart,
}

/// Sayılı, toggle'lı sosyal etkileşim butonu.
///
/// Aktif duruma geçince ikon yumuşak bir scale + fade ile takas olur,
/// sayı rengi ve ağırlığı animasyonla güncellenir.
class SocialAction extends StatefulWidget {
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
    this.badgeCount,
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

  /// Ikonun sag ust koselerinde gosterilen kompakt sayac. Sifir ve negatif
  /// degerlerde hic yer kaplamaz.
  final int? badgeCount;

  @override
  State<SocialAction> createState() => _SocialActionState();
}

class _SocialActionState extends State<SocialAction> {
  var _pulseSerial = 0;

  void _handleTap() {
    setState(() => _pulseSerial++);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? widget.activeColor
        : (widget.inactiveColor ?? AppColors.iconMuted);
    final resolvedGlyph = widget.isActive
        ? widget.activeGlyph ?? widget.glyph
        : widget.glyph;
    final badgeCount = widget.badgeCount ?? 0;
    return Semantics(
      label: widget.semanticLabel,
      button: true,
      selected: widget.isActive,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
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
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey<String>(
                      '${resolvedGlyph.name}-${widget.isActive}-$_pulseSerial',
                    ),
                    tween: Tween<double>(begin: 0.78, end: 1),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: SizedBox.square(
                      dimension: widget.iconSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Icon(
                              _iconForGlyph(
                                resolvedGlyph,
                                filled: widget.isActive,
                              ),
                              color: color,
                              size: widget.iconSize,
                            ),
                          ),
                          if (badgeCount > 0)
                            Positioned(
                              right: -5,
                              top: -7,
                              child: _SocialActionBadge(
                                count: badgeCount,
                                color: widget.activeColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.count != null) ...[
                  const SizedBox(width: 6),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: AppTypography.meta.copyWith(
                      color: color,
                      fontWeight: widget.isActive
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: widget.countFontSize,
                    ),
                    child: Text(CountFormat.compact(widget.count!)),
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

class _SocialActionBadge extends StatelessWidget {
  const _SocialActionBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.surface, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.24),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Text(
            CountFormat.compact(count),
            style: AppTypography.meta.copyWith(
              color: AppColors.surface,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
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
    case PateezSocialGlyph.forwardShare:
      return Symbols.share_forward_line;
    case PateezSocialGlyph.ribbon:
      return filled ? Symbols.bookmark_fill : Symbols.bookmark_line;
    case PateezSocialGlyph.heart:
      return filled ? Symbols.heart_3_fill : Symbols.heart_3_line;
  }
}
