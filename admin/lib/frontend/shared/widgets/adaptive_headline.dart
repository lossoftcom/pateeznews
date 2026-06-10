import 'dart:math' as math;

import 'package:flutter/material.dart';

class AdaptiveHeadline extends StatelessWidget {
  const AdaptiveHeadline({
    super.key,
    required this.text,
    required this.style,
    this.minScale = 0.9,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final double minScale;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final baseFontSize =
            style.fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14;
        final resolvedStyle = maxWidth.isFinite && maxWidth > 0
            ? _resolveStyle(
                context: context,
                maxWidth: maxWidth,
                baseFontSize: baseFontSize,
              )
            : style;

        return Text(
          text,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
          textWidthBasis: TextWidthBasis.parent,
          style: resolvedStyle,
        );
      },
    );
  }

  TextStyle _resolveStyle({
    required BuildContext context,
    required double maxWidth,
    required double baseFontSize,
  }) {
    final safeMinScale = minScale.clamp(0.82, 1.0).toDouble();
    final minFontSize = baseFontSize * safeMinScale;
    var bestFontSize = baseFontSize;
    var bestScore = _layoutScore(
      context: context,
      maxWidth: maxWidth,
      fontSize: baseFontSize,
      baseFontSize: baseFontSize,
    );

    for (
      var fontSize = baseFontSize - 0.5;
      fontSize >= minFontSize;
      fontSize -= 0.5
    ) {
      final score = _layoutScore(
        context: context,
        maxWidth: maxWidth,
        fontSize: fontSize,
        baseFontSize: baseFontSize,
      );
      if (score + 0.02 < bestScore) {
        bestScore = score;
        bestFontSize = fontSize;
      }
    }

    return bestFontSize == baseFontSize
        ? style
        : style.copyWith(fontSize: bestFontSize);
  }

  double _layoutScore({
    required BuildContext context,
    required double maxWidth,
    required double fontSize,
    required double baseFontSize,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(fontSize: fontSize),
      ),
      maxLines: maxLines,
      textAlign: textAlign ?? TextAlign.start,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);

    if (painter.didExceedMaxLines) return 1000;

    final lines = painter
        .computeLineMetrics()
        .where((line) => line.width > 1)
        .toList(growable: false);
    if (lines.isEmpty) return 0;

    var worstGap = 0.0;
    var totalGap = 0.0;
    for (final line in lines) {
      final gap = ((maxWidth - line.width) / maxWidth).clamp(0.0, 1.0);
      worstGap = math.max(worstGap, gap);
      totalGap += gap;
    }

    final averageGap = totalGap / lines.length;
    final lastGap = ((maxWidth - lines.last.width) / maxWidth).clamp(0.0, 1.0);
    final shrinkPenalty = (baseFontSize - fontSize) / baseFontSize;

    return (lines.length * 2.0) +
        (worstGap * 0.95) +
        (averageGap * 0.55) +
        (lastGap * 0.35) +
        (shrinkPenalty * 0.25);
  }
}
