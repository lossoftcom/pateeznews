import 'package:flutter/material.dart';

import 'dashboard_panel.dart';
import 'status_row.dart';

class StatusPanel extends StatelessWidget {
  const StatusPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: 'Son durum',
      subtitle: 'Panelin anlık yayın sağlığı',
      child: Column(
        children: const [
          StatusRow(label: 'Yayın dengesi', value: 'Dengeli', progress: 0.78),
          StatusRow(label: 'Editör yoğunluğu', value: 'Normal', progress: 0.52),
          StatusRow(label: 'Medya kuyruğu', value: 'Hafif', progress: 0.34),
        ],
      ),
    );
  }
}
