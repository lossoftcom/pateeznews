import 'package:flutter/material.dart';

import 'publishing_panel.dart';
import 'responsive_metric_grid.dart';
import 'status_panel.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth < 640 ? 16 : 28,
            28,
            constraints.maxWidth < 640 ? 16 : 28,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResponsiveMetricGrid(isWide: isWide),
              const SizedBox(height: 18),
              if (isWide)
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: PublishingPanel()),
                    SizedBox(width: 18),
                    Expanded(flex: 5, child: StatusPanel()),
                  ],
                )
              else
                const Column(
                  children: [
                    PublishingPanel(),
                    SizedBox(height: 18),
                    StatusPanel(),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
