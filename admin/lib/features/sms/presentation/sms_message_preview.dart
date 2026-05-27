import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

class SmsSegmentStats {
  const SmsSegmentStats({
    required this.characterCount,
    required this.segmentCount,
    required this.remaining,
    required this.usesUnicode,
  });

  final int characterCount;
  final int segmentCount;
  final int remaining;
  final bool usesUnicode;

  String get encodingLabel => usesUnicode ? 'UCS-2' : 'GSM-7';

  factory SmsSegmentStats.fromText(String value) {
    final text = value.trim();
    final length = text.length;
    final usesUnicode = text.runes.any((rune) => rune > 127);
    final singleLimit = usesUnicode ? 70 : 160;
    final multiLimit = usesUnicode ? 67 : 153;

    if (length == 0) {
      return SmsSegmentStats(
        characterCount: 0,
        segmentCount: 0,
        remaining: singleLimit,
        usesUnicode: usesUnicode,
      );
    }

    final segmentCount = length <= singleLimit
        ? 1
        : (length / multiLimit).ceil();
    final activeLimit = segmentCount <= 1
        ? singleLimit
        : segmentCount * multiLimit;
    return SmsSegmentStats(
      characterCount: length,
      segmentCount: segmentCount,
      remaining: math.max(activeLimit - length, 0),
      usesUnicode: usesUnicode,
    );
  }
}

class SmsStatsRow extends StatelessWidget {
  const SmsStatsRow({
    super.key,
    required this.message,
    this.alignment = WrapAlignment.center,
    this.compact = false,
  });

  final String message;
  final WrapAlignment alignment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final stats = SmsSegmentStats.fromText(message);
    final countLabel = context.t(
      'sms.preview.characters',
      values: {'count': stats.characterCount},
    );
    final smsLabel = '${stats.segmentCount} ${context.t('sms.preview.sms')}';
    final encodingLabel =
        '${stats.encodingLabel} ${context.t('sms.preview.encoding')}';
    final remainingLabel =
        '${stats.remaining} ${context.t('sms.preview.remaining')}';

    return Wrap(
      alignment: alignment,
      spacing: compact ? 6 : 8,
      runSpacing: compact ? 6 : 8,
      children: [
        SmsMetricPill(label: countLabel, compact: compact),
        SmsMetricPill(label: smsLabel, compact: compact),
        SmsMetricPill(
          label: encodingLabel,
          compact: compact,
          color: const Color(0xFF198754),
          backgroundColor: const Color(0xFF198754).withValues(alpha: 0.10),
        ),
        SmsMetricPill(label: remainingLabel, compact: compact),
      ],
    );
  }
}

class SmsMetricPill extends StatelessWidget {
  const SmsMetricPill({
    super.key,
    required this.label,
    this.compact = false,
    this.color = AppColors.deepOcean,
    this.backgroundColor,
  });

  final String label;
  final bool compact;
  final Color color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 12),
        child: SizedBox(
          height: compact ? 28 : 32,
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SmsVariableChip extends StatelessWidget {
  const SmsVariableChip({
    super.key,
    required this.label,
    this.verified = false,
    this.onTap,
  });

  final String label;
  final bool verified;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = verified ? const Color(0xFF16A34A) : const Color(0xFFF59E0B);
    return MouseRegion(
      cursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            border: Border.all(color: color.withValues(alpha: 0.42)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                verified ? Icons.check_circle : Icons.dynamic_feed,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SmsImessagePreview extends StatelessWidget {
  const SmsImessagePreview({
    super.key,
    required this.message,
    this.contactName = 'Jane',
    this.avatarInitial = 'P',
    this.width = 292,
    this.height = 520,
    this.showInput = true,
    this.maxBubbleLines,
  });

  final String message;
  final String contactName;
  final String avatarInitial;
  final double width;
  final double height;
  final bool showInput;
  final int? maxBubbleLines;

  @override
  Widget build(BuildContext context) {
    final safeMessage = message.trim().isEmpty
        ? context.t('sms.preview.placeholder')
        : message.trim();

    return SizedBox(
      width: width,
      height: height,
      child: Align(
        alignment: Alignment.topCenter,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 760,
            height: 840,
            child: _IMessageReferansOnizleme(
              hamMesaj: safeMessage,
              contactName: contactName,
              avatarInitial: avatarInitial,
              maxLines: maxBubbleLines ?? 8,
            ),
          ),
        ),
      ),
    );
  }
}

class _IMessageReferansOnizleme extends StatelessWidget {
  const _IMessageReferansOnizleme({
    required this.hamMesaj,
    required this.contactName,
    required this.avatarInitial,
    required this.maxLines,
  });

  final String hamMesaj;
  final String contactName;
  final String avatarInitial;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: Image.asset(
            'assets/images/sms_imessage_reference.png',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
        ),
        const Positioned(
          left: 92,
          top: 350,
          width: 576,
          height: 420,
          child: ColoredBox(color: Colors.white),
        ),
        Positioned(
          left: 150,
          right: 103,
          top: 362,
          child: Align(
            alignment: Alignment.topRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _IMessageGidenBalon(
                  mesaj: hamMesaj,
                  maxLines: maxLines,
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    context.t('sms.preview.delivered'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6E6E73),
                      fontSize: 18,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IMessageGidenBalon extends StatelessWidget {
  const _IMessageGidenBalon({
    required this.mesaj,
    required this.maxLines,
  });

  final String mesaj;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 374),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFF0A84FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: RichText(
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: _mesajSpanlari(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            right: -12,
            bottom: 0,
            child: _IMessageGidenBalonKuyrugu(),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _mesajSpanlari() {
    final regex = RegExp(r'\{\{([a-zA-Z0-9_]+)\}\}|\{([a-zA-Z0-9_]+)\}');
    final values = _ornekDegerler;
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in regex.allMatches(mesaj)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: mesaj.substring(cursor, match.start)));
      }

      final key = (match.group(1) ?? match.group(2) ?? '').trim();
      final placeholder = match.group(0) ?? '';
      final value = values[key];
      final label = (value?.trim().isNotEmpty ?? false)
          ? value!.trim()
          : placeholder;

      final dolduruldu = value?.trim().isNotEmpty ?? false;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 1,
              vertical: 1,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: dolduruldu
                  ? const Color(0xFFFFF2E0)
                  : const Color(0xFFFFE0B2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: dolduruldu
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFD97706),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9A3412),
                fontSize: 18,
                height: 1.05,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor < mesaj.length) {
      spans.add(TextSpan(text: mesaj.substring(cursor)));
    }

    return spans.isEmpty ? <InlineSpan>[TextSpan(text: mesaj)] : spans;
  }
}

class _IMessageGidenBalonKuyrugu extends StatelessWidget {
  const _IMessageGidenBalonKuyrugu();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 28),
      painter: _IMessageGidenBalonKuyruguPainter(),
    );
  }
}

class _IMessageGidenBalonKuyruguPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF0A84FF)
      ..style = PaintingStyle.fill;

    final Path path = Path()
      ..moveTo(0, 0)
      ..cubicTo(2, 14, 10, 23, size.width, size.height)
      ..cubicTo(12, size.height, 5, 24, 0, 16)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _ornekDegerler = <String, String>{
  'uye_adi': 'Jane Carter',
  'alici_adi': 'Jane Carter',
  'haber_basligi': 'Haftanın haber özeti',
  'haber_ozeti': 'Okurlar için haftanın en çok okunan haberlerinden kısa özet.',
  'haber_linki': 'pateeznews.com/haber',
  'kategori': 'Gündem',
  'tarih': '24.05.2026',
  'telefon': '+90 541 947 49 80',
};

