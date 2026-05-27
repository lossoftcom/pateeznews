import 'package:flutter/material.dart';

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
                    child: CustomPaint(
                      painter: PateezSocialGlyphPainter(
                        glyph: resolvedGlyph,
                        color: color,
                        filled: isActive,
                      ),
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

class PateezSocialGlyphPainter extends CustomPainter {
  const PateezSocialGlyphPainter({
    required this.glyph,
    required this.color,
    required this.filled,
  });

  final PateezSocialGlyph glyph;
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final strokeWidth = (s * 0.055).clamp(0.9, 1.2).toDouble();
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color.withValues(alpha: filled ? 0.10 : 0)
      ..style = PaintingStyle.fill;

    switch (glyph) {
      case PateezSocialGlyph.sparkUp:
        _drawSparkVote(canvas, s, stroke, fill, up: true);
      case PateezSocialGlyph.sparkDown:
        _drawSparkVote(canvas, s, stroke, fill, up: false);
      case PateezSocialGlyph.conversation:
        _drawConversation(canvas, s, stroke, fill);
      case PateezSocialGlyph.orbitShare:
        _drawOrbitShare(canvas, s, stroke, fill);
      case PateezSocialGlyph.ribbon:
        _drawRibbon(canvas, s, stroke, fill);
      case PateezSocialGlyph.heart:
        _drawHeart(canvas, s, stroke);
    }
  }

  void _drawHeart(Canvas canvas, double s, Paint stroke) {
    final body = Path()
      ..moveTo(s * 0.50, s * 0.84)
      ..cubicTo(s * 0.10, s * 0.60, s * 0.08, s * 0.22, s * 0.30, s * 0.20)
      ..cubicTo(s * 0.42, s * 0.19, s * 0.50, s * 0.30, s * 0.50, s * 0.40)
      ..cubicTo(s * 0.50, s * 0.30, s * 0.58, s * 0.19, s * 0.70, s * 0.20)
      ..cubicTo(s * 0.92, s * 0.22, s * 0.90, s * 0.60, s * 0.50, s * 0.84)
      ..close();

    if (filled) {
      final solid = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(body, solid);
    } else {
      canvas.drawPath(body, stroke);
    }
  }

  void _drawSparkVote(
    Canvas canvas,
    double s,
    Paint stroke,
    Paint fill, {
    required bool up,
  }) {
    canvas.save();
    if (!up) {
      canvas.translate(0, s);
      canvas.scale(1, -1);
    }

    final body = Path()
      ..moveTo(s * 0.20, s * 0.76)
      ..lineTo(s * 0.36, s * 0.76)
      ..lineTo(s * 0.45, s * 0.43)
      ..quadraticBezierTo(s * 0.50, s * 0.20, s * 0.60, s * 0.20)
      ..quadraticBezierTo(s * 0.67, s * 0.20, s * 0.65, s * 0.34)
      ..lineTo(s * 0.63, s * 0.44)
      ..lineTo(s * 0.80, s * 0.44)
      ..quadraticBezierTo(s * 0.88, s * 0.45, s * 0.86, s * 0.54)
      ..lineTo(s * 0.81, s * 0.72)
      ..quadraticBezierTo(s * 0.79, s * 0.82, s * 0.69, s * 0.82)
      ..lineTo(s * 0.44, s * 0.82)
      ..quadraticBezierTo(s * 0.34, s * 0.82, s * 0.30, s * 0.76)
      ..lineTo(s * 0.20, s * 0.76);
    if (filled) canvas.drawPath(body, fill);
    canvas.drawPath(body, stroke);

    canvas.drawLine(
      Offset(s * 0.18, s * 0.32),
      Offset(s * 0.30, s * 0.38),
      stroke,
    );
    canvas.drawLine(
      Offset(s * 0.44, s * 0.10),
      Offset(s * 0.46, s * 0.25),
      stroke,
    );
    canvas.restore();
  }

  void _drawConversation(Canvas canvas, double s, Paint stroke, Paint fill) {
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.14, s * 0.18, s * 0.72, s * 0.52),
      Radius.circular(s * 0.18),
    );
    if (filled) canvas.drawRRect(bubble, fill);
    canvas.drawRRect(bubble, stroke);
    final tail = Path()
      ..moveTo(s * 0.38, s * 0.70)
      ..lineTo(s * 0.29, s * 0.86)
      ..lineTo(s * 0.55, s * 0.70);
    canvas.drawPath(tail, stroke);
    canvas.drawLine(
      Offset(s * 0.34, s * 0.41),
      Offset(s * 0.66, s * 0.41),
      stroke,
    );
    canvas.drawLine(
      Offset(s * 0.34, s * 0.53),
      Offset(s * 0.56, s * 0.53),
      stroke,
    );
  }

  void _drawOrbitShare(Canvas canvas, double s, Paint stroke, Paint fill) {
    final a = Offset(s * 0.25, s * 0.58);
    final b = Offset(s * 0.64, s * 0.28);
    final c = Offset(s * 0.76, s * 0.72);
    final orbit = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(s * 0.46, s * 0.34, b.dx, b.dy)
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(s * 0.50, s * 0.72, c.dx, c.dy);
    canvas.drawPath(orbit, stroke);
    for (final node in [a, b, c]) {
      if (filled) canvas.drawCircle(node, s * 0.105, fill);
      canvas.drawCircle(node, s * 0.085, stroke);
    }
  }

  void _drawRibbon(Canvas canvas, double s, Paint stroke, Paint fill) {
    final ribbon = Path()
      ..moveTo(s * 0.25, s * 0.15)
      ..lineTo(s * 0.75, s * 0.15)
      ..quadraticBezierTo(s * 0.82, s * 0.15, s * 0.82, s * 0.23)
      ..lineTo(s * 0.82, s * 0.86)
      ..lineTo(s * 0.50, s * 0.68)
      ..lineTo(s * 0.18, s * 0.86)
      ..lineTo(s * 0.18, s * 0.23)
      ..quadraticBezierTo(s * 0.18, s * 0.15, s * 0.25, s * 0.15)
      ..close();
    if (filled) canvas.drawPath(ribbon, fill);
    canvas.drawPath(ribbon, stroke);
    canvas.drawLine(
      Offset(s * 0.33, s * 0.30),
      Offset(s * 0.67, s * 0.30),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant PateezSocialGlyphPainter oldDelegate) {
    return oldDelegate.glyph != glyph ||
        oldDelegate.color != color ||
        oldDelegate.filled != filled;
  }
}
