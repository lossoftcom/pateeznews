import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import '../users_models.dart';

class UsersSummaryGrid extends StatelessWidget {
  const UsersSummaryGrid({
    super.key,
    required this.metrics,
    this.compact = false,
  });

  final List<UserMetric> metrics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final density = width < 620
            ? _SummaryDensity.tight
            : width < 1120
            ? _SummaryDensity.compact
            : _SummaryDensity.regular;
        final gap = switch (density) {
          _SummaryDensity.tight => 6.0,
          _SummaryDensity.compact => 10.0,
          _SummaryDensity.regular => 16.0,
        };

        return Row(
          children: [
            for (var index = 0; index < metrics.length; index++) ...[
              Expanded(
                child: _MetricCard(
                  metric: metrics[index],
                  compact: compact,
                  density: density,
                ),
              ),
              if (index != metrics.length - 1) SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

enum _SummaryDensity { regular, compact, tight }

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.metric,
    required this.compact,
    required this.density,
  });

  final UserMetric metric;
  final bool compact;
  final _SummaryDensity density;

  @override
  Widget build(BuildContext context) {
    final centered = metric.centerContent;
    final isTight = density == _SummaryDensity.tight;
    final isCompact = compact || density == _SummaryDensity.compact;
    final minHeight = isTight
        ? 92.0
        : isCompact
        ? 104.0
        : 146.0;
    final horizontalPadding = isTight
        ? 10.0
        : isCompact
        ? 16.0
        : 24.0;
    final verticalPadding = isTight
        ? 12.0
        : isCompact
        ? 14.0
        : 24.0;
    final iconSize = isTight
        ? 28.0
        : isCompact
        ? 34.0
        : 42.0;
    final iconGap = isTight ? 8.0 : 12.0;
    final titleSize = isTight
        ? 11.0
        : isCompact
        ? 12.0
        : null;
    final valueSize = isTight
        ? 20.0
        : isCompact
        ? 24.0
        : null;
    final changeSize = isTight
        ? 10.0
        : isCompact
        ? 11.0
        : null;
    final descriptionSize = isTight
        ? 10.0
        : isCompact
        ? 11.0
        : null;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
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
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: centered
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  metric.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: centered ? TextAlign.center : TextAlign.start,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
                SizedBox(height: isTight ? 7 : 8),
                Row(
                  mainAxisAlignment: centered
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          metric.value,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: AppColors.deepOcean,
                                fontSize: valueSize,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                                height: 1,
                              ),
                        ),
                      ),
                    ),
                    SizedBox(width: isTight ? 4 : 7),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        metric.change,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warmHorizon,
                          fontSize: changeSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isTight ? 10 : 14),
                Text(
                  metric.description,
                  maxLines: isTight ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.deepOcean,
                    fontSize: descriptionSize,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          if (!isTight) ...[
            SizedBox(width: iconGap),
            Container(
              width: iconSize,
              height: iconSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              child: SymbolIcon(
                metric.icon,
                color: metric.iconColor,
                size: isCompact ? 18 : 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
