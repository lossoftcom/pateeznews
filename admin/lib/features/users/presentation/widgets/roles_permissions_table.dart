import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/sortable_table_header.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import '../users_models.dart';

class RolesPermissionsTable extends StatelessWidget {
  const RolesPermissionsTable({
    super.key,
    required this.roles,
    required this.loading,
    required this.selectedRoleIds,
    required this.sortState,
    required this.onToggleRole,
    required this.onToggleAllRoles,
    required this.onEditRole,
    required this.onManagePermissions,
    required this.onDeleteRole,
    required this.onSort,
  });

  final List<ManagedRole> roles;
  final bool loading;
  final Set<String> selectedRoleIds;
  final TableSortState sortState;
  final ValueChanged<ManagedRole> onToggleRole;
  final VoidCallback onToggleAllRoles;
  final ValueChanged<ManagedRole> onEditRole;
  final ValueChanged<ManagedRole> onManagePermissions;
  final ValueChanged<ManagedRole> onDeleteRole;
  final ValueChanged<String> onSort;

  static const _activeGreen = Color(0xFF198754);
  static const double _minWidth = 1110;
  static const double _selectWidth = 42;
  static const double _orderWidth = 90;
  static const double _slugWidth = 160;
  static const double _permissionsWidth = 340;
  static const double _statusWidth = 176;
  static const double _menuWidth = 138;
  static const double _columnGap = 12;
  static const double _statusActionGap = 20;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < _minWidth
            ? _minWidth
            : constraints.maxWidth;
        final nameWidth =
            tableWidth -
            _selectWidth -
            _orderWidth -
            _slugWidth -
            _permissionsWidth -
            _statusWidth -
            _menuWidth -
            _columnGap -
            _statusActionGap -
            36;
        final selectableCount = roles
            .where((role) => !role.systemLocked)
            .length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(
                  color: AppColors.line.withValues(alpha: 0.72),
                ),
              ),
              child: Column(
                children: [
                  _RolesHeader(
                    nameWidth: nameWidth,
                    selectedCount: selectedRoleIds.length,
                    selectableCount: selectableCount,
                    sortState: sortState,
                    onToggleAllRows: onToggleAllRoles,
                    onSort: onSort,
                  ),
                  Expanded(
                    child: loading
                        ? const _RolesLoading()
                        : roles.isEmpty
                        ? const _RolesEmpty()
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final role in roles)
                                  _RolesTableRow(
                                    role: role,
                                    nameWidth: nameWidth,
                                    selected: selectedRoleIds.contains(role.id),
                                    onToggle: () => onToggleRole(role),
                                    onEditRole: onEditRole,
                                    onManagePermissions: onManagePermissions,
                                    onDeleteRole: onDeleteRole,
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RolesHeader extends StatelessWidget {
  const _RolesHeader({
    required this.nameWidth,
    required this.selectedCount,
    required this.selectableCount,
    required this.sortState,
    required this.onToggleAllRows,
    required this.onSort,
  });

  final double nameWidth;
  final int selectedCount;
  final int selectableCount;
  final TableSortState sortState;
  final VoidCallback onToggleAllRows;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: RolesPermissionsTable._selectWidth,
            child: _RolesCheckbox(
              value: selectedCount == 0 || selectableCount == 0
                  ? false
                  : selectedCount == selectableCount
                  ? true
                  : null,
              tristate: true,
              enabled: selectableCount > 0,
              onChanged: (_) => onToggleAllRows(),
            ),
          ),
          SizedBox(
            width: RolesPermissionsTable._orderWidth,
            child: SortableTableHeader(
              label: 'Order No',
              sortKey: 'order',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: nameWidth,
            child: SortableTableHeader(
              label: 'Role Name',
              sortKey: 'name',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: RolesPermissionsTable._slugWidth,
            child: SortableTableHeader(
              label: 'Slug',
              sortKey: 'slug',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          const SizedBox(width: RolesPermissionsTable._columnGap),
          SizedBox(
            width: RolesPermissionsTable._permissionsWidth,
            child: SortableTableHeader(
              label: 'Permissions',
              sortKey: 'permissions',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: RolesPermissionsTable._statusWidth,
            child: SortableTableHeader(
              label: 'Status',
              sortKey: 'status',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          const SizedBox(width: RolesPermissionsTable._statusActionGap),
          const SizedBox(
            width: RolesPermissionsTable._menuWidth,
            child: _HeaderText('Action'),
          ),
        ],
      ),
    );
  }
}

class _RolesTableRow extends StatelessWidget {
  const _RolesTableRow({
    required this.role,
    required this.nameWidth,
    required this.selected,
    required this.onToggle,
    required this.onEditRole,
    required this.onManagePermissions,
    required this.onDeleteRole,
  });

  final ManagedRole role;
  final double nameWidth;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<ManagedRole> onEditRole;
  final ValueChanged<ManagedRole> onManagePermissions;
  final ValueChanged<ManagedRole> onDeleteRole;

  @override
  Widget build(BuildContext context) {
    final labels = role.permissionLabels;
    final visibleLabels = labels.take(3).toList(growable: false);
    final extraCount = labels.length - visibleLabels.length;

    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selected ? AppColors.surface : Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: RolesPermissionsTable._selectWidth,
            child: _RolesCheckbox(
              value: selected,
              enabled: !role.systemLocked,
              onChanged: (_) => onToggle(),
            ),
          ),
          SizedBox(
            width: RolesPermissionsTable._orderWidth,
            child: _RowSelectTapTarget(
              enabled: !role.systemLocked,
              onTap: onToggle,
              child: Text(
                role.rowNumber.toString(),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(
            width: nameWidth,
            child: _RowSelectTapTarget(
              enabled: !role.systemLocked,
              onTap: onToggle,
              child: _RoleIdentity(role: role),
            ),
          ),
          SizedBox(
            width: RolesPermissionsTable._slugWidth,
            child: Text(
              role.slug,
              style: const TextStyle(
                color: AppColors.support,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: RolesPermissionsTable._columnGap),
          SizedBox(
            width: RolesPermissionsTable._permissionsWidth,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (visibleLabels.isEmpty)
                  const _PermissionChip(label: 'Henüz yetki atanmamış')
                else ...[
                  for (final label in visibleLabels)
                    _PermissionChip(label: label),
                  if (extraCount > 0)
                    _PermissionChip(
                      label: '+$extraCount ${context.t('More')}',
                      isExtra: true,
                    ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: RolesPermissionsTable._statusWidth,
            child: role.systemLocked
                ? const _StatusBadge(
                    label: 'Sistem Kilitli',
                    color: AppColors.inkSoft,
                  )
                : const _StatusBadge(
                    label: 'Aktif',
                    color: RolesPermissionsTable._activeGreen,
                    dot: true,
                  ),
          ),
          const SizedBox(width: RolesPermissionsTable._statusActionGap),
          SizedBox(
            width: RolesPermissionsTable._menuWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: role.systemLocked
                  ? const _SystemLockedBadge()
                  : _RoleRowMenu(
                      role: role,
                      onEditRole: onEditRole,
                      onManagePermissions: onManagePermissions,
                      onDeleteRole: onDeleteRole,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleIdentity extends StatelessWidget {
  const _RoleIdentity({required this.role});

  final ManagedRole role;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _roleColor(role.color),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(
            role.initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t(role.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.t(role.displayDescription),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.support,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.label, this.isExtra = false});

  final String label;
  final bool isExtra;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isExtra
            ? AppColors.warmHorizon.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(
          color: isExtra
              ? AppColors.warmHorizon.withValues(alpha: 0.5)
              : AppColors.softLine.withValues(alpha: 0.9),
        ),
      ),
      child: Text(
        context.t(label),
        style: TextStyle(
          color: isExtra ? AppColors.warmHorizon : AppColors.deepOcean,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RolesCheckbox extends StatelessWidget {
  const _RolesCheckbox({
    required this.value,
    required this.onChanged,
    this.tristate = false,
    this.enabled = true,
  });

  final bool? value;
  final ValueChanged<bool?> onChanged;
  final bool tristate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      tristate: tristate,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      activeColor: AppColors.deepOcean,
      checkColor: Colors.white,
      side: BorderSide(color: AppColors.line.withValues(alpha: 0.76)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _RowSelectTapTarget extends StatelessWidget {
  const _RowSelectTapTarget({
    required this.onTap,
    required this.child,
    this.enabled = true,
  });

  final VoidCallback onTap;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: child,
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t(label),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SystemLockedBadge extends StatelessWidget {
  const _SystemLockedBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 28,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: AppColors.softLine.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SymbolIcon(
                Symbols.lock,
                color: AppColors.inkSoft,
                size: 12,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  context.t('System Locked'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleRowMenu extends StatefulWidget {
  const _RoleRowMenu({
    required this.role,
    required this.onEditRole,
    required this.onManagePermissions,
    required this.onDeleteRole,
  });

  final ManagedRole role;
  final ValueChanged<ManagedRole> onEditRole;
  final ValueChanged<ManagedRole> onManagePermissions;
  final ValueChanged<ManagedRole> onDeleteRole;

  @override
  State<_RoleRowMenu> createState() => _RoleRowMenuState();
}

class _RoleRowMenuState extends State<_RoleRowMenu> {
  final _layerLink = LayerLink();
  OverlayEntry? _menuEntry;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _openMenu() {
    if (_menuEntry != null) return;

    _menuEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeMenu,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: _RoleMenuCard(
                role: widget.role,
                onEdit: () =>
                    _runAndClose(() => widget.onEditRole(widget.role)),
                onManagePermissions: () =>
                    _runAndClose(() => widget.onManagePermissions(widget.role)),
                onDelete: () =>
                    _runAndClose(() => widget.onDeleteRole(widget.role)),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_menuEntry!);
  }

  void _runAndClose(VoidCallback action) {
    _closeMenu();
    action();
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _toggleMenu() {
    if (_menuEntry == null) {
      _openMenu();
    } else {
      _closeMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleMenu,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              '...',
              style: TextStyle(
                color: AppColors.support.withValues(alpha: 0.92),
                fontSize: 18,
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

class _RoleMenuCard extends StatelessWidget {
  const _RoleMenuCard({
    required this.role,
    required this.onEdit,
    required this.onManagePermissions,
    required this.onDelete,
  });

  final ManagedRole role;
  final VoidCallback onEdit;
  final VoidCallback onManagePermissions;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 188,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoleMenuItem(
              icon: Symbols.edit_square,
              label: 'Düzenle',
              onTap: onEdit,
            ),
            _RoleMenuItem(
              icon: Symbols.verified,
              label: 'Yetkileri Yönet',
              onTap: onManagePermissions,
            ),
            _RoleMenuItem(
              icon: Symbols.draft,
              label: 'Sil',
              onTap: onDelete,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleMenuItem extends StatelessWidget {
  const _RoleMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.actionRed : AppColors.deepOcean;

    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(AppRadius.value),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            SymbolIcon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    this.color = AppColors.deepOcean,
    this.dot = false,
  });

  final String label;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 28,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: AppColors.softLine.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  context.t(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolesLoading extends StatelessWidget {
  const _RolesLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.deepOcean,
        ),
      ),
    );
  }
}

class _RolesEmpty extends StatelessWidget {
  const _RolesEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('No roles found'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Color _roleColor(String value) {
  final hex = value.trim().replaceFirst('#', '');
  if (hex.length == 6) {
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed != null) return Color(0xFF000000 | parsed);
  }
  return AppColors.deepOcean;
}
