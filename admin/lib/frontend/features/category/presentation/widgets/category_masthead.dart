import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/category_content.dart';

/// Kategori sayfasının kimliğini taşıyan üst blok.
///
/// Eyebrow (tür ikonu + UPPERCASE etiket), kırmızı dikey çubuk imzasıyla büyük
/// başlık, tek satır tanıtım ve altta istatistik satırı (toplam okunma · haber
/// sayısı · güncelleme sıklığı). Ana sayfanın beyaz üst bloğuyla aynı zeminde
/// durur; aşağıdaki gri akıştan net ayrışır.
class CategoryMasthead extends StatelessWidget {
  const CategoryMasthead({
    super.key,
    required this.content,
    required this.articleCount,
    required this.totalReads,
  });

  final CategoryContent content;
  final int articleCount;
  final int totalReads;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Eyebrow(icon: content.icon, label: content.kindLabel),
          const SizedBox(height: AppSpacing.md),
          _Title(title: content.title),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            content.description,
            style: AppTypography.body.copyWith(
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _StatsRow(articleCount: articleCount, totalReads: totalReads),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.actionRed),
        const SizedBox(width: 7),
        Text(
          label,
          style: AppTypography.eyebrow.copyWith(
            color: AppColors.support,
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 30,
          margin: const EdgeInsets.only(top: 4, right: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.actionRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: AppTypography.mobileDetailTitle.copyWith(
              letterSpacing: -0.2,
              height: 1.05,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.articleCount, required this.totalReads});

  final int articleCount;
  final int totalReads;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: AppTypography.meta.copyWith(
        color: AppColors.support,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      child: Row(
        children: [
          const Icon(
            Symbols.visibility_outlined,
            size: 14,
            color: AppColors.support,
          ),
          const SizedBox(width: 6),
          Text(
            '${CountFormat.compact(totalReads)} okunma',
            style: AppTypography.meta.copyWith(
              color: AppColors.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          const _Dot(),
          const SizedBox(width: 10),
          const Icon(Symbols.newspaper, size: 14, color: AppColors.support),
          const SizedBox(width: 6),
          Text('$articleCount haber'),
          const SizedBox(width: 10),
          const _Dot(),
          const SizedBox(width: 10),
          const Icon(
            Symbols.schedule_rounded,
            size: 14,
            color: AppColors.support,
          ),
          const SizedBox(width: 6),
          const Flexible(
            child: Text(
              'Günlük güncellenir',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2.5,
      height: 2.5,
      decoration: const BoxDecoration(
        color: AppColors.support,
        shape: BoxShape.circle,
      ),
    );
  }
}
