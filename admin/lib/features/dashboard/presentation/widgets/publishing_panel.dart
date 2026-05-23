import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import 'dashboard_panel.dart';
import 'flow_row.dart';

class PublishingPanel extends StatelessWidget {
  const PublishingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: 'Yayın akışı',
      subtitle: 'Bugün takip edilen içerikler',
      child: Column(
        children: const [
          FlowRow(
            icon: Symbols.edit_square,
            title: 'Ekonomi gündemi',
            status: 'Editörde',
            time: '09:40',
          ),
          FlowRow(
            icon: Symbols.verified,
            title: 'Teknoloji bülteni',
            status: 'Onaylandı',
            time: '11:15',
          ),
          FlowRow(
            icon: Symbols.schedule_send,
            title: 'Spor özeti',
            status: 'Planlandı',
            time: '14:30',
          ),
          FlowRow(
            icon: Symbols.draft,
            title: 'Kültür dosyası',
            status: 'Taslak',
            time: '16:20',
          ),
        ],
      ),
    );
  }
}
