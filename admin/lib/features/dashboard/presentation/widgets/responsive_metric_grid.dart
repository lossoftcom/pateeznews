import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import 'metric_card.dart';

class ResponsiveMetricGrid extends StatelessWidget {
  const ResponsiveMetricGrid({super.key, required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = !isWide || constraints.maxWidth < 1080;
        final items = [
          MetricCard(
            icon: Symbols.article,
            title: 'Yayındaki haber',
            value: '128',
            note: 'Bugün 8 yeni haber',
            color: AppColors.deepOcean,
            compact: compact,
          ),
          MetricCard(
            icon: Symbols.pending_actions,
            title: 'Bekleyen onay',
            value: '24',
            note: 'Editör sırası hazır',
            color: AppColors.actionRed,
            compact: compact,
          ),
          MetricCard(
            icon: Symbols.schedule,
            title: 'Planlı yayın',
            value: '16',
            note: 'Sonraki 48 saat',
            color: AppColors.warmHorizon,
            compact: compact,
          ),
          MetricCard(
            icon: Symbols.group,
            title: 'Aktif editör',
            value: '6',
            note: 'Çevrim içi ekip',
            color: AppColors.support,
            compact: compact,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: compact ? 6 : 14,
            mainAxisSpacing: 0,
            mainAxisExtent: compact ? 118 : 142,
          ),
          itemBuilder: (context, index) => items[index],
        );
      },
    );
  }
}
