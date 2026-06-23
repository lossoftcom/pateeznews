import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_mobile_list.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/admin_table_chrome.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/highlighted_text.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_roles_repository.dart';
import 'users_models.dart';
import 'widgets/roles_permissions_dialogs.dart';
import 'widgets/roles_permissions_table.dart';

class RolesPermissionsScreen extends StatefulWidget {
  const RolesPermissionsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminRolesRepository(),
  });

  static const double toolbarHeight = 38;

  final AdminSession session;
  final AdminRolesRepository repository;

  @override
  State<RolesPermissionsScreen> createState() => _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends State<RolesPermissionsScreen> {
  final Set<String> _selectedRoleIds = {};
  Timer? _searchDebounce;

  var _roles = const <ManagedRole>[];
  var _permissions = const <AdminPermission>[];
  var _loading = true;
  String? _errorText;
  var _page = 1;
  var _pageSize = 25;
  var _totalCount = 0;
  var _searchQuery = '';
  var _sortState = const TableSortState(key: 'order', ascending: true);
  var _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRoles());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final result = await widget.repository.fetchRolesPermissions(
        search: _searchQuery,
        page: _page,
        pageSize: _pageSize,
        sortKey: _sortState.key,
        sortAscending: _sortState.ascending,
      );
      if (!mounted) return;
      setState(() {
        _roles = result.roles;
        _permissions = result.permissions;
        _totalCount = result.totalCount;
        _selectedRoleIds.removeWhere(
          (id) => !_roles.any((role) => role.id == id && !role.systemLocked),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  void _changePageSize(int? value) {
    if (value == null || value == _pageSize) return;
    setState(() {
      _pageSize = value;
      _page = 1;
      _selectedRoleIds.clear();
    });
    unawaited(_loadRoles());
  }

  /// Anlık (0ms) istemci filtresi — Haberler ile aynı Türkçe-duyarsız eşleşme.
  List<ManagedRole> _visibleRoles() {
    final query = _searchQuery.trim();
    if (query.isEmpty) return _roles;
    return _roles
        .where((role) => searchMatchesAll(_roleHaystack(role), query))
        .toList(growable: false);
  }

  String _roleHaystack(ManagedRole role) {
    return '${role.id} ${role.name} ${role.label} '
        '${role.description} ${role.slug}';
  }

  Future<void> _refreshRolesSilently() async {
    final seq = ++_searchSeq;
    try {
      final result = await widget.repository.fetchRolesPermissions(
        search: _searchQuery,
        page: _page,
        pageSize: _pageSize,
        sortKey: _sortState.key,
        sortAscending: _sortState.ascending,
      );
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _roles = result.roles;
        _permissions = result.permissions;
        _totalCount = result.totalCount;
        _selectedRoleIds.removeWhere(
          (id) => !_roles.any((role) => role.id == id && !role.systemLocked),
        );
        _errorText = null;
      });
    } catch (_) {
      // Sessiz yenileme; mevcut veri ekranda kalır.
    }
  }

  void _changeSearch(String value) {
    // Anlık his: yazar yazmaz görünür satırlar istemci tarafında filtrelenir.
    setState(() {
      _searchQuery = value;
      _page = 1;
      _selectedRoleIds.clear();
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      unawaited(_refreshRolesSilently());
    });
  }

  void _changePage(int page) {
    if (page == _page) return;
    setState(() {
      _page = page;
      _selectedRoleIds.clear();
    });
    unawaited(_loadRoles());
  }

  void _changeSort(String sortKey) {
    setState(() {
      _sortState = _sortState.toggled(sortKey);
      _page = 1;
      _selectedRoleIds.clear();
    });
    unawaited(_loadRoles());
  }

  void _toggleRole(ManagedRole role) {
    if (role.systemLocked) return;
    setState(() {
      if (_selectedRoleIds.contains(role.id)) {
        _selectedRoleIds.remove(role.id);
      } else {
        _selectedRoleIds.add(role.id);
      }
    });
  }

  void _toggleAllRoles() {
    final selectableIds = _roles
        .where((role) => !role.systemLocked)
        .map((role) => role.id)
        .toList(growable: false);
    setState(() {
      if (selectableIds.isNotEmpty &&
          selectableIds.every(_selectedRoleIds.contains)) {
        _selectedRoleIds.clear();
      } else {
        _selectedRoleIds
          ..clear()
          ..addAll(selectableIds);
      }
    });
  }

  Future<void> _addRole() async {
    final data = await showRoleFormDialog(context);
    if (data == null) return;
    await _runMutation(
      () => widget.repository.createRole(session: widget.session, data: data),
    );
  }

  Future<void> _editRole(ManagedRole role) async {
    if (role.systemLocked) return;
    final data = await showRoleFormDialog(context, role: role);
    if (data == null) return;
    await _runMutation(
      () => widget.repository.updateRole(
        session: widget.session,
        roleId: role.id,
        data: data,
      ),
    );
  }

  Future<void> _managePermissions(ManagedRole role) async {
    final permissionKeys = await showManagePermissionsDialog(
      context,
      role: role,
      permissions: _permissions,
    );
    if (permissionKeys == null) return;
    await _runMutation(
      () => widget.repository.saveRolePermissions(
        session: widget.session,
        roleId: role.id,
        permissionKeys: permissionKeys,
      ),
    );
  }

  Future<void> _deleteRole(ManagedRole role) async {
    if (role.systemLocked) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('Delete role?'),
      message: context.t(
        'roles.deleteMessage',
        values: {'name': context.t(role.label)},
      ),
      confirmLabel: context.t('Delete'),
      danger: true,
    );
    if (!confirmed) return;

    await _runMutation(
      () => widget.repository.deleteRole(
        session: widget.session,
        roleId: role.id,
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedRoleIds.toList(growable: false);
    if (ids.isEmpty) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('Delete selected roles?'),
      message: context.t(
        'roles.deleteSelectedMessage',
        values: {'count': ids.length},
      ),
      confirmLabel: context.t('Delete'),
      danger: true,
    );
    if (!confirmed) return;

    await _runMutation(() async {
      for (final roleId in ids) {
        await widget.repository.deleteRole(
          session: widget.session,
          roleId: roleId,
        );
      }
    });
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      await action();
      if (!mounted) return;
      _selectedRoleIds.clear();
      await _loadRoles();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final mobile = constraints.maxWidth < AdminMobile.breakpoint;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            mobile ? 18 : 28,
            horizontalPadding,
            mobile ? 0 : 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _RolesPermissionsTitle(),
              if (_errorText != null) ...[
                const SizedBox(height: 16),
                _RolesPermissionsErrorBanner(message: _errorText!),
              ],
              const SizedBox(height: 18),
              _RolesPermissionsToolbar(
                pageSize: _pageSize,
                searchQuery: _searchQuery,
                totalCount: _totalCount,
                selectedCount: _selectedRoleIds.length,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onAddRole: () => unawaited(_addRole()),
                onDeleteSelected: () => unawaited(_deleteSelected()),
                onClearSelection: () => setState(_selectedRoleIds.clear),
              ),
              SizedBox(height: mobile ? 14 : 18),
              Expanded(
                child: RolesPermissionsTable(
                  roles: _visibleRoles(),
                  loading: _loading,
                  searchQuery: _searchQuery,
                  selectedRoleIds: _selectedRoleIds,
                  sortState: _sortState,
                  onToggleRole: _toggleRole,
                  onToggleAllRoles: _toggleAllRoles,
                  onEditRole: (role) => unawaited(_editRole(role)),
                  onManagePermissions: (role) =>
                      unawaited(_managePermissions(role)),
                  onDeleteRole: (role) => unawaited(_deleteRole(role)),
                  onSort: _changeSort,
                ),
              ),
              SizedBox(height: mobile ? 4 : 16),
              _RolesPermissionsFooter(
                page: _page,
                pageSize: _pageSize,
                totalCount: _totalCount,
                loading: _loading,
                onPageChanged: _changePage,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RolesPermissionsTitle extends StatelessWidget {
  const _RolesPermissionsTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t('Roles & Permissions'),
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _RolesPermissionsErrorBanner extends StatelessWidget {
  const _RolesPermissionsErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.22)),
      ),
      child: Text(
        context.t(message),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.actionRed,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _RolesPermissionsToolbar extends StatelessWidget {
  const _RolesPermissionsToolbar({
    required this.pageSize,
    required this.searchQuery,
    required this.totalCount,
    required this.selectedCount,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onAddRole,
    required this.onDeleteSelected,
    required this.onClearSelection,
  });

  final int pageSize;
  final String searchQuery;
  final int totalCount;
  final int selectedCount;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddRole;
  final VoidCallback onDeleteSelected;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < AdminMobile.breakpoint;
        final compact = constraints.maxWidth < 1160;
        final pageSizeSelect = _PageSizeSelect(
          value: pageSize,
          onChanged: onPageSizeChanged,
        );
        final deleteButton = selectedCount == 0
            ? null
            : _SelectedDeleteButton(
                selectedCount: selectedCount,
                onPressed: onDeleteSelected,
              );
        final leftControls = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            pageSizeSelect,
            if (deleteButton != null) ...[
              const SizedBox(width: 12),
              deleteButton,
            ],
          ],
        );
        final search = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? double.infinity : 270,
            minWidth: compact ? double.infinity : 260,
          ),
          child: _RolesSearchField(
            value: searchQuery,
            onChanged: onSearchChanged,
          ),
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          children: [
            _ToolbarButton(
              textIcon: '+',
              label: 'Rol Ekle',
              variant: _ToolbarButtonVariant.danger,
              onPressed: onAddRole,
            ),
          ],
        );

        if (mobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RolesMobileSearchPanel(
                value: searchQuery,
                hintText: context.t('Search...'),
                onChanged: onSearchChanged,
                recordCount: totalCount,
                pageSize: pageSize,
                onPageSizeChanged: onPageSizeChanged,
              ),
              const SizedBox(height: 10),
              selectedCount == 0
                  ? AdminMobilePrimaryButton(
                      icon: Symbols.add,
                      label: context.t('Add Role'),
                      fullWidth: true,
                      onPressed: onAddRole,
                    )
                  : AdminMobileSelectionBar(
                      selectedCount: selectedCount,
                      onClear: onClearSelection,
                      onDelete: onDeleteSelected,
                    ),
            ],
          );
        }

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: leftControls),
              const SizedBox(height: 12),
              search,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leftControls,
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [search, const SizedBox(width: 12), actions],
            ),
          ],
        );
      },
    );
  }
}

class _RolesMobileSearchPanel extends StatefulWidget {
  const _RolesMobileSearchPanel({
    required this.value,
    required this.hintText,
    required this.onChanged,
    required this.recordCount,
    required this.pageSize,
    required this.onPageSizeChanged,
  });

  final String value;
  final String hintText;
  final ValueChanged<String> onChanged;
  final int recordCount;
  final int pageSize;
  final ValueChanged<int?> onPageSizeChanged;

  @override
  State<_RolesMobileSearchPanel> createState() =>
      _RolesMobileSearchPanelState();
}

class _RolesMobileSearchPanelState extends State<_RolesMobileSearchPanel> {
  static const _borderColor = Color(0xFFE6EAF0);
  static const _muted = Color(0xFF9AA3AA);
  static const _navy = Color(0xFF2F4053);

  late final TextEditingController _controller;
  var _expanded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _RolesMobileSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 9),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const SymbolIcon(
                          Symbols.search,
                          color: _muted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextField(
                                controller: _controller,
                                onChanged: widget.onChanged,
                                mouseCursor: SystemMouseCursors.text,
                                textAlignVertical: TextAlignVertical.center,
                                cursorColor: _navy,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: _navy,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: widget.hintText,
                                  hintStyle: const TextStyle(
                                    color: _muted,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                              Container(
                                height: 1,
                                color: const Color(0xFFB9BEC4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 78),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _expanded ? 'Gizle' : 'Göster',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _navy,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                RotatedBox(
                                  quarterTurns: _expanded ? 2 : 0,
                                  child: const SymbolIcon(
                                    Symbols.keyboard_arrow_down,
                                    color: _navy,
                                    size: 17,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.recordCount} kayıt',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _navy,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Filtre yok',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _muted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: _borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _RolesMobilePageSizeDropdown(
                  value: widget.pageSize,
                  onChanged: widget.onPageSizeChanged,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RolesMobilePageSizeDropdown extends StatelessWidget {
  const _RolesMobilePageSizeDropdown({
    required this.value,
    required this.onChanged,
  });

  static const _values = ['25', '50', '100'];

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = _values.contains(value.toString())
        ? value.toString()
        : '25';
    return Container(
      width: 66,
      height: 42,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(10),
          dropdownColor: Colors.white,
          focusColor: Colors.transparent,
          mouseCursor: SystemMouseCursors.click,
          dropdownMenuItemMouseCursor: SystemMouseCursors.click,
          icon: const SymbolIcon(
            Symbols.keyboard_arrow_down,
            color: Color(0xFF6F7780),
            size: 16,
          ),
          style: const TextStyle(
            color: Color(0xFF2F4053),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            DropdownMenuItem(value: '25', child: Text('25')),
            DropdownMenuItem(value: '50', child: Text('50')),
            DropdownMenuItem(value: '100', child: Text('100')),
          ],
          onChanged: (value) => onChanged(int.tryParse(value ?? '')),
        ),
      ),
    );
  }
}

class _PageSizeSelect extends StatelessWidget {
  const _PageSizeSelect({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: RolesPermissionsScreen.toolbarHeight,
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
              fontWeight: FontWeight.w500,
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

class _SelectedDeleteButton extends StatelessWidget {
  const _SelectedDeleteButton({
    required this.selectedCount,
    required this.onPressed,
  });

  final int selectedCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 34),
              maximumSize: const Size(double.infinity, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
            const SymbolIcon(Symbols.delete, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              context.t(
                'users.selectedDelete',
                values: {'count': selectedCount},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolesSearchField extends StatefulWidget {
  const _RolesSearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_RolesSearchField> createState() => _RolesSearchFieldState();
}

class _RolesSearchFieldState extends State<_RolesSearchField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _RolesSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: RolesPermissionsScreen.toolbarHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        textAlignVertical: TextAlignVertical.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: context.t('Search...'),
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.placeholder,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12, right: 9),
            child: SymbolIcon(
              Symbols.search,
              color: AppColors.iconMuted,
              size: 18,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 39,
            minHeight: RolesPermissionsScreen.toolbarHeight,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                mouseCursor: SystemMouseCursors.click,
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  _focusNode.requestFocus();
                },
                icon: const SymbolIcon(
                  Symbols.close,
                  color: AppColors.iconMuted,
                  size: 16,
                ),
              );
            },
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: RolesPermissionsScreen.toolbarHeight,
          ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

enum _ToolbarButtonVariant { outlined, dark, warning, danger }

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.variant,
    this.textIcon,
    this.onPressed,
  });

  final String label;
  final _ToolbarButtonVariant variant;
  final String? textIcon;
  final VoidCallback? onPressed;

  Color get _background {
    return switch (variant) {
      _ToolbarButtonVariant.outlined => Colors.white,
      _ToolbarButtonVariant.dark => AppColors.deepOcean,
      _ToolbarButtonVariant.warning => AppColors.warmHorizon,
      _ToolbarButtonVariant.danger => AppColors.actionRed,
    };
  }

  Color get _foreground {
    return switch (variant) {
      _ToolbarButtonVariant.outlined => AppColors.deepOcean,
      _ToolbarButtonVariant.dark => Colors.white,
      _ToolbarButtonVariant.warning => Colors.white,
      _ToolbarButtonVariant.danger => Colors.white,
    };
  }

  Color get _border {
    return switch (variant) {
      _ToolbarButtonVariant.outlined => AppColors.line,
      _ToolbarButtonVariant.dark => AppColors.deepOcean,
      _ToolbarButtonVariant.warning => AppColors.warmHorizon,
      _ToolbarButtonVariant.danger => AppColors.actionRed,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: RolesPermissionsScreen.toolbarHeight,
      child: TextButton(
        onPressed: onPressed ?? () {},
        style:
            TextButton.styleFrom(
              backgroundColor: _background,
              foregroundColor: _foreground,
              side: BorderSide(color: _border.withValues(alpha: 0.88)),
              minimumSize: const Size(0, RolesPermissionsScreen.toolbarHeight),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
            Text(
              textIcon ?? '',
              style: TextStyle(
                color: _foreground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
            const SizedBox(width: 8),
            Text(context.t(label)),
          ],
        ),
      ),
    );
  }
}

class _RolesPermissionsFooter extends StatelessWidget {
  const _RolesPermissionsFooter({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.loading,
    required this.onPageChanged,
  });

  final int page;
  final int pageSize;
  final int totalCount;
  final bool loading;
  final ValueChanged<int> onPageChanged;

  int get _pageCount {
    if (totalCount == 0) return 1;
    return ((totalCount - 1) ~/ pageSize) + 1;
  }

  String _summary(BuildContext context) {
    if (loading) return context.t('common.recordsLoading');
    if (totalCount == 0) return context.t('common.zeroRecords');
    final start = ((page - 1) * pageSize) + 1;
    final end = (start + pageSize - 1).clamp(1, totalCount);
    return context.t(
      'common.recordRange',
      values: {'from': start, 'to': end, 'total': totalCount},
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final text = Text(
          _summary(context),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w500,
          ),
        );
        final pager = _RolesPagination(
          page: page,
          pageCount: _pageCount,
          onPageChanged: onPageChanged,
        );

        if (compact) {
          return AdminMobilePager(
            page: page,
            lastPage: _pageCount,
            rangeText: _summary(context),
            loading: loading,
            onPageChanged: onPageChanged,
          );
        }

        return Column(
          children: [
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 16),
            Row(children: [text, const Spacer(), pager]),
          ],
        );
      },
    );
  }
}

class _RolesPagination extends StatelessWidget {
  const _RolesPagination({
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return AdminTablePagination(
      page: page,
      pageCount: pageCount,
      onPageChanged: onPageChanged,
    );
  }
}
