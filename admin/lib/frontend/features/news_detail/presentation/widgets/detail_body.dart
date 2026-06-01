import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/news_detail_mock.dart';

/// Haber gövdesi: paragraflar, içeride bir pull-quote ve kaynak notu.
///
/// Tipografi yüksek okunabilirlik için 16px boyutunda, 1.62 satır
/// yüksekliğinde tutuldu. İlk paragrafın başında klasik gazete tarzı
/// drop-cap kullanılır.
class DetailBody extends StatelessWidget {
  const DetailBody({super.key, required this.body});

  final NewsBody body;

  @override
  Widget build(BuildContext context) {
    final paragraphs = body.paragraphs;
    if (paragraphs.isEmpty) return const SizedBox.shrink();

    final int pullQuoteIndex = paragraphs.length > 2 ? 2 : paragraphs.length;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        0,
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < paragraphs.length; i++) ...[
            if (i == 0)
              _DropCapParagraph(text: paragraphs[i])
            else
              _Paragraph(text: paragraphs[i]),
            if (i + 1 == pullQuoteIndex) ...[
              const SizedBox(height: AppSpacing.xl),
              _PullQuote(text: body.pullQuote),
              const SizedBox(height: AppSpacing.xl),
            ] else if (i < paragraphs.length - 1)
              const SizedBox(height: AppSpacing.lg),
          ],
          const SizedBox(height: AppSpacing.xl),
          _SourceNote(text: body.sourceNote),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.articleBody.copyWith(
        color: AppColors.ink,
        height: 1.62,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
    );
  }
}

class _DropCapParagraph extends StatelessWidget {
  const _DropCapParagraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final first = text.characters.isEmpty ? '' : text.characters.first;
    final rest = text.characters.isEmpty
        ? ''
        : text.characters.skip(1).toString();

    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.actionRed,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  first.toUpperCase(),
                  style: AppTypography.titleL.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
          TextSpan(
            text: rest,
            style: AppTypography.articleBody.copyWith(
              color: AppColors.ink,
              height: 1.62,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PullQuote extends StatelessWidget {
  const _PullQuote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: AppColors.warmHorizon, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Text(
              '“',
              style: AppTypography.display.copyWith(
                color: AppColors.warmHorizon,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                height: 0.8,
                letterSpacing: 0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.titleM.copyWith(
                color: AppColors.inkStrong,
                fontSize: 17,
                height: 1.4,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceNote extends StatelessWidget {
  const _SourceNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.softLine, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1, right: 8),
            child: Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: AppColors.support,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.support,
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
