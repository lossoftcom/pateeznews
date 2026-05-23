import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import 'metric_card.dart';

class ResponsiveMetricGrid extends StatelessWidget {
  const ResponsiveMetricGrid({super.key, required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final items = const [
      MetricCard(
        icon: Symbols.article,
        title: 'Yayındaki haber',
        value: '128',
        note: 'Bugün 8 yeni haber',
        color: AppColors.deepOcean,
      ),
      MetricCard(
        icon: Symbols.pending_actions,
        title: 'Bekleyen onay',
        value: '24',
        note: 'Editör sırası hazır',
        color: AppColors.actionRed,
      ),
      MetricCard(
        icon: Symbols.schedule,
        title: 'Planlı yayın',
        value: '16',
        note: 'Sonraki 48 saat',
        color: AppColors.warmHorizon,
      ),
      MetricCard(
        icon: Symbols.group,
        title: 'Aktif editör',
        value: '6',
        note: 'Çevrim içi ekip',
        color: AppColors.support,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 142,
      ),
      itemBuilder: (context, index) => items[index],
    );
  }
}
