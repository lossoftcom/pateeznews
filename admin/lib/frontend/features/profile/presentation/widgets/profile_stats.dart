import 'package:flutter/material.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/profile_content.dart';

/// Dört eşit sütunlu istatistik şeridi: Haber · Takipçi · Takip · Katıldı.
///
/// Sayı büyük (inkStrong), etiket küçük UPPERCASE (support); aralarında ince
/// dikey ayraç. Beyaz kart, 4px keskin radius — projenin dilinde sade ve net.
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key, required this.data});

  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
        AppSpacing.pageHorizontal,
        0,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          _StatCell(value: '${data.postsCount}', label: 'HABER'),
          const _Divider(),
          _StatCell(value: CountFormat.compact(data.followers), label: 'TAKİPÇİ'),
          const _Divider(),
          _StatCell(value: CountFormat.compact(data.following), label: 'TAKİP'),
          const _Divider(),
          _StatCell(value: data.joinedYear, label: 'KATILDI'),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleL.copyWith(
              color: AppColors.inkStrong,
              fontWeight: FontWeight.w800,
              fontSize: 19,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.eyebrow.copyWith(
              color: AppColors.support,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: AppColors.line);
  }
}
