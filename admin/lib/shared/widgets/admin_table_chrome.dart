import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../core/localization/admin_language_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import 'symbol_icon.dart';

class AdminTableChrome {
  const AdminTableChrome._();

  static const double toolbarHeight = 38;
}

class AdminTablePageSizeSelect extends StatelessWidget {
  const AdminTablePageSizeSelect({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: AdminTableChrome.toolbarHeight,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value,
            borderRadius: BorderRadius.circular(AppRadius.value),
            dropdownColor: Colors.white,
            focusColor: Colors.transparent,
            mouseCursor: SystemMouseCursors.click,
            dropdownMenuItemMouseCursor: SystemMouseCursors.click,
            icon: const SymbolIcon(
              Symbols.keyboard_arrow_down,
              color: AppColors.iconMuted,
              size: 18,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            items: const [
              DropdownMenuItem(value: 25, child: Text('25')),
              DropdownMenuItem(value: 50, child: Text('50')),
              DropdownMenuItem(value: 100, child: Text('100')),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class AdminTableSearchField extends StatelessWidget {
  const AdminTableSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.query = '',
    this.showClearButton = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final String query;
  final bool showClearButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AdminTableChrome.toolbarHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: TextField(
        controller: controller,
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        textAlignVertical: TextAlignVertical.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.placeholder,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12, right: 9),
            child: SymbolIcon(
              Symbols.search,
              color: AppColors.iconMuted,
              size: 18,
            ),
          ),
          suffixIcon: showClearButton && query.isNotEmpty
              ? IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const SymbolIcon(
                    Symbols.close,
                    color: AppColors.iconMuted,
                    size: 16,
                  ),
                )
              : null,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 39,
            minHeight: AdminTableChrome.toolbarHeight,
          ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class AdminTablePrimaryActionButton extends StatelessWidget {
  const AdminTablePrimaryActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor = AppColors.actionRed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AdminTableChrome.toolbarHeight,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, AdminTableChrome.toolbarHeight),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 7),
            Flexible(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class AdminTableSecondaryActionButton extends StatelessWidget {
  const AdminTableSecondaryActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.actionRed : AppColors.deepOcean;

    return SizedBox(
      height: AdminTableChrome.toolbarHeight,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: color,
              minimumSize: const Size(0, AdminTableChrome.toolbarHeight),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                side: BorderSide(color: AppColors.line.withValues(alpha: 0.72)),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(icon, color: color, size: 17),
            const SizedBox(width: 7),
            Flexible(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class AdminTablePageButton extends StatelessWidget {
  const AdminTablePageButton({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.46,
          child: Container(
            width: 36,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.deepOcean : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(
                color: selected
                    ? AppColors.deepOcean
                    : AppColors.line.withValues(alpha: 0.72),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.support,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminTablePagination extends StatelessWidget {
  const AdminTablePagination({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
    this.enabled = true,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;
  final bool enabled;

  static const _visibleNumberCount = 3;

  List<int?> _visiblePageItems(int currentPage, int totalPages) {
    if (totalPages <= _visibleNumberCount) {
      return List<int?>.generate(totalPages, (index) => index + 1);
    }

    var firstVisible = currentPage - 1;
    var lastVisible = currentPage + 1;

    if (currentPage <= 2) {
      firstVisible = 1;
      lastVisible = _visibleNumberCount;
    } else if (currentPage >= totalPages - 1) {
      firstVisible = totalPages - _visibleNumberCount + 1;
      lastVisible = totalPages;
    }

    final items = <int?>[];
    if (firstVisible > 1) items.add(null);

    for (var value = firstVisible; value <= lastVisible; value += 1) {
      items.add(value);
    }

    if (lastVisible < totalPages) items.add(null);

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final safePageCount = pageCount < 1 ? 1 : pageCount;
    final safePage = page.clamp(1, safePageCount).toInt();
    final pageItems = _visiblePageItems(safePage, safePageCount);

    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          AdminTablePageButton(
            label: '<<',
            enabled: enabled && safePage > 1,
            onPressed: () => onPageChanged(1),
          ),
          AdminTablePageButton(
            label: '<',
            enabled: enabled && safePage > 1,
            onPressed: () => onPageChanged(safePage - 1),
          ),
          for (final pageItem in pageItems)
            if (pageItem == null)
              const _AdminTablePageEllipsis()
            else
              AdminTablePageButton(
                label: '$pageItem',
                selected: pageItem == safePage,
                enabled: pageItem == safePage || enabled,
                onPressed: pageItem == safePage
                    ? null
                    : () => onPageChanged(pageItem),
              ),
          AdminTablePageButton(
            label: '>',
            enabled: enabled && safePage < safePageCount,
            onPressed: () => onPageChanged(safePage + 1),
          ),
          AdminTablePageButton(
            label: '>>',
            enabled: enabled && safePage < safePageCount,
            onPressed: () => onPageChanged(safePageCount),
          ),
        ],
      ),
    );
  }
}

class _AdminTablePageEllipsis extends StatelessWidget {
  const _AdminTablePageEllipsis();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 34,
      child: Center(
        child: Text(
          '...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.support,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class AdminTableEmptyText extends StatelessWidget {
  const AdminTableEmptyText({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t(label),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}
