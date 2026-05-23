import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../core/localization/admin_language_controller.dart';
import '../../core/theme/app_colors.dart';
import 'symbol_icon.dart';

class TableSortState {
  const TableSortState({required this.key, required this.ascending});

  final String key;
  final bool ascending;

  TableSortState toggled(String nextKey) {
    if (key == nextKey) {
      return TableSortState(key: nextKey, ascending: !ascending);
    }
    return TableSortState(key: nextKey, ascending: true);
  }
}

class SortableTableHeader extends StatelessWidget {
  const SortableTableHeader({
    super.key,
    required this.label,
    required this.sortKey,
    required this.sortState,
    required this.onSort,
  });

  final String label;
  final String sortKey;
  final TableSortState sortState;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final selected = sortState.key == sortKey;
    final icon = SymbolIcon(
      Symbols.keyboard_arrow_down,
      color: selected ? AppColors.deepOcean : AppColors.support,
      size: 14,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSort(sortKey),
        child: Row(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                context.t(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.deepOcean : AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            selected && sortState.ascending
                ? RotatedBox(quarterTurns: 2, child: icon)
                : icon,
          ],
        ),
      ),
    );
  }
}
