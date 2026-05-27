import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/symbol_icon.dart';

class SidebarItem extends StatelessWidget {
  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.inkSoft;
    final background = selected ? AppColors.deepOcean : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(AppRadius.value),
        onTap: onTap ?? () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected ? AppColors.deepOcean : Colors.transparent,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.deepOcean.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              SymbolIcon(icon, color: color, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 10),
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SidebarExpandableItem extends StatelessWidget {
  const SidebarExpandableItem({
    super.key,
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.selected = false,
    this.children = const [],
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final bool selected;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hasChildren = children.isNotEmpty;
    final color = selected ? Colors.white : AppColors.inkSoft;
    final background = selected ? AppColors.deepOcean : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(AppRadius.value),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(
                  color: selected ? AppColors.deepOcean : Colors.transparent,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.deepOcean.withValues(alpha: 0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  SymbolIcon(icon, color: color, size: 19),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 15,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: SymbolIcon(
                      Symbols.keyboard_arrow_down,
                      color: color,
                      size: 17,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.topCenter,
              child: expanded && hasChildren
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class SidebarSubItem extends StatelessWidget {
  const SidebarSubItem({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.deepOcean : AppColors.inkSoft;

    return Padding(
      padding: const EdgeInsets.only(left: 18, top: 2),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(AppRadius.value),
        onTap: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 15,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.actionRed,
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
