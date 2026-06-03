import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import '../users_models.dart';

class UsersSummaryGrid extends StatelessWidget {
  const UsersSummaryGrid({super.key, required this.metrics});

  final List<UserMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1120
            ? 4
            : width >= 720
            ? 2
            : 1;
        const gap = 16.0;
        final itemWidth = (width - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: itemWidth,
                child: _MetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final UserMetric metric;

  @override
  Widget build(BuildContext context) {
    final centered = metric.centerContent;
    return Container(
      constraints: const BoxConstraints(minHeight: 146),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.74)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: centered
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  metric.title,
                  textAlign: centered ? TextAlign.center : TextAlign.start,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: centered
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      metric.value,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.deepOcean,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            height: 1,
                          ),
                    ),
                    const SizedBox(width: 7),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        metric.change,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warmHorizon,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  metric.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: SymbolIcon(metric.icon, color: metric.iconColor, size: 20),
          ),
        ],
      ),
    );
  }
}
