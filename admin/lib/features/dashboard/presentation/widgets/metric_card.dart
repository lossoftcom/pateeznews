import 'package:flutter/material.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/symbol_icon.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.note,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String note;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padding = compact ? 10.0 : 18.0;
    final iconSize = compact ? 18.0 : 22.0;
    final dotSize = compact ? 6.0 : 8.0;
    final valueSize = compact ? 20.0 : null;
    final titleSize = compact ? 11.0 : null;
    final noteSize = compact ? 10.0 : null;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SymbolIcon(icon, color: color, size: iconSize),
              const Spacer(),
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.deepOcean,
              fontSize: valueSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            context.t(title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          Text(
            context.t(note),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.support,
              fontSize: noteSize,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
