import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_date_formatter.dart';
import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/admin_mobile_list.dart';
import '../../../../shared/widgets/sortable_table_header.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import '../users_models.dart';

class UsersTableCard extends StatelessWidget {
  const UsersTableCard({
    super.key,
    required this.users,
    required this.roles,
    required this.loading,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchQuery,
    required this.roleFilter,
    required this.rewardFilter,
    required this.statusFilter,
    required this.selectedUserIds,
    required this.sortState,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onRewardChanged,
    required this.onStatusChanged,
    required this.onPageChanged,
    required this.onToggleUser,
    required this.onToggleAllUsers,
    required this.onAddUser,
    required this.onEditUser,
    required this.onToggleStatus,
    required this.onToggleReward,
    required this.onDeleteUser,
    required this.onDeleteSelected,
    required this.onSort,
  });

  final List<ManagedUser> users;
  final List<AdminUserRole> roles;
  final bool loading;
  final int page;
  final int pageSize;
  final int totalCount;
  final String searchQuery;
  final String roleFilter;
  final String rewardFilter;
  final String statusFilter;
  final Set<String> selectedUserIds;
  final TableSortState sortState;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String?> onRewardChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onToggleUser;
  final VoidCallback onToggleAllUsers;
  final VoidCallback onAddUser;
  final ValueChanged<ManagedUser> onEditUser;
  final ValueChanged<ManagedUser> onToggleStatus;
  final ValueChanged<ManagedUser> onToggleReward;
  final ValueChanged<ManagedUser> onDeleteUser;
  final VoidCallback onDeleteSelected;
  final ValueChanged<String> onSort;

  static const double toolbarHeight = 38;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AdminMobile.breakpoint) {
          return _UsersMobileView(
            users: users,
            roles: roles,
            loading: loading,
            page: page,
            pageSize: pageSize,
            totalCount: totalCount,
            searchQuery: searchQuery,
            roleFilter: roleFilter,
            rewardFilter: rewardFilter,
            statusFilter: statusFilter,
            selectedUserIds: selectedUserIds,
            onPageSizeChanged: onPageSizeChanged,
            onSearchChanged: onSearchChanged,
            onRoleChanged: onRoleChanged,
            onRewardChanged: onRewardChanged,
            onStatusChanged: onStatusChanged,
            onPageChanged: onPageChanged,
            onToggleUser: onToggleUser,
            onAddUser: onAddUser,
            onEditUser: onEditUser,
            onToggleStatus: onToggleStatus,
            onToggleReward: onToggleReward,
            onDeleteUser: onDeleteUser,
            onDeleteSelected: onDeleteSelected,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UsersFilters(
              roles: roles,
              roleFilter: roleFilter,
              rewardFilter: rewardFilter,
              statusFilter: statusFilter,
              onRoleChanged: onRoleChanged,
              onRewardChanged: onRewardChanged,
              onStatusChanged: onStatusChanged,
            ),
            const SizedBox(height: 28),
            _UsersToolbar(
              pageSize: pageSize,
              searchQuery: searchQuery,
              selectedCount: selectedUserIds.length,
              onPageSizeChanged: onPageSizeChanged,
              onSearchChanged: onSearchChanged,
              onAddUser: onAddUser,
              onDeleteSelected: onDeleteSelected,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _UsersDataTable(
                users: users,
                roles: roles,
                loading: loading,
                selectedUserIds: selectedUserIds,
                sortState: sortState,
                onToggleUser: onToggleUser,
                onToggleAllUsers: onToggleAllUsers,
                onEditUser: onEditUser,
                onToggleStatus: onToggleStatus,
                onToggleReward: onToggleReward,
                onDeleteUser: onDeleteUser,
                onSort: onSort,
              ),
            ),
            const SizedBox(height: 16),
            _UsersFooter(
              page: page,
              pageSize: pageSize,
              totalCount: totalCount,
              loading: loading,
              onPageChanged: onPageChanged,
            ),
          ],
        );
      },
    );
  }
}

class _UsersMobileView extends StatelessWidget {
  const _UsersMobileView({
    required this.users,
    required this.roles,
    required this.loading,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchQuery,
    required this.roleFilter,
    required this.rewardFilter,
    required this.statusFilter,
    required this.selectedUserIds,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onRewardChanged,
    required this.onStatusChanged,
    required this.onPageChanged,
    required this.onToggleUser,
    required this.onAddUser,
    required this.onEditUser,
    required this.onToggleStatus,
    required this.onToggleReward,
    required this.onDeleteUser,
    required this.onDeleteSelected,
  });

  final List<ManagedUser> users;
  final List<AdminUserRole> roles;
  final bool loading;
  final int page;
  final int pageSize;
  final int totalCount;
  final String searchQuery;
  final String roleFilter;
  final String rewardFilter;
  final String statusFilter;
  final Set<String> selectedUserIds;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String?> onRewardChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onToggleUser;
  final VoidCallback onAddUser;
  final ValueChanged<ManagedUser> onEditUser;
  final ValueChanged<ManagedUser> onToggleStatus;
  final ValueChanged<ManagedUser> onToggleReward;
  final ValueChanged<ManagedUser> onDeleteUser;
  final VoidCallback onDeleteSelected;

  int get _activeFilterCount {
    var count = 0;
    if (roleFilter != 'Tümü') count++;
    if (rewardFilter != 'Tümü') count++;
    if (statusFilter != 'Tümü') count++;
    return count;
  }

  void _openFilters(BuildContext context) {
    showAdminMobileFilterSheet(
      context: context,
      onClear: () {
        onRoleChanged('Tümü');
        onRewardChanged('Tümü');
        onStatusChanged('Tümü');
      },
      contentBuilder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminMobileFilterField(
              label: 'Rol',
              value: roleFilter,
              items: [
                DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
                for (final role in roles)
                  DropdownMenuItem(
                    value: role.name,
                    child: Text(context.t(role.label)),
                  ),
              ],
              onChanged: (value) {
                onRoleChanged(value);
                setSheetState(() {});
              },
            ),
            AdminMobileFilterField(
              label: 'Ödül Sistemi',
              value: rewardFilter,
              items: [
                DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
                DropdownMenuItem(
                  value: 'Aktif',
                  child: Text(context.t('Active')),
                ),
                DropdownMenuItem(
                  value: 'Pasif',
                  child: Text(context.t('Passive')),
                ),
              ],
              onChanged: (value) {
                onRewardChanged(value);
                setSheetState(() {});
              },
            ),
            AdminMobileFilterField(
              label: 'Durum',
              value: statusFilter,
              items: [
                DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
                DropdownMenuItem(
                  value: 'Aktif',
                  child: Text(context.t('Active')),
                ),
                DropdownMenuItem(
                  value: 'Beklemede',
                  child: Text(context.t('Pending')),
                ),
                DropdownMenuItem(
                  value: 'Engelli',
                  child: Text(context.t('Disabled')),
                ),
              ],
              onChanged: (value) {
                onStatusChanged(value);
                setSheetState(() {});
              },
            ),
            AdminMobileFilterField(
              label: 'Sayfa boyutu',
              value: pageSize.toString(),
              items: const [
                DropdownMenuItem(value: '25', child: Text('25')),
                DropdownMenuItem(value: '50', child: Text('50')),
                DropdownMenuItem(value: '100', child: Text('100')),
              ],
              onChanged: (value) {
                onPageSizeChanged(int.tryParse(value ?? ''));
                setSheetState(() {});
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastPage = totalCount == 0 ? 1 : ((totalCount - 1) ~/ pageSize) + 1;
    final from = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final to = totalCount == 0
        ? 0
        : (page * pageSize > totalCount ? totalCount : page * pageSize);
    final rangeText = context.t(
      'common.recordRange',
      values: {'from': from, 'to': to, 'total': totalCount},
    );
    final hasSelection = selectedUserIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminMobileToolbar(
          query: searchQuery,
          hintText: context.t('Search users...'),
          onSearchChanged: onSearchChanged,
          activeFilterCount: _activeFilterCount,
          onOpenFilters: () => _openFilters(context),
          showFilters: false,
        ),
        const SizedBox(height: 10),
        hasSelection
            ? AdminMobileSelectionBar(
                selectedCount: selectedUserIds.length,
                label: context.t(
                  'users.selectedDelete',
                  values: {'count': selectedUserIds.length},
                ),
                onClear: () {
                  for (final id in selectedUserIds.toList()) {
                    onToggleUser(id);
                  }
                },
                onDelete: onDeleteSelected,
              )
            : Row(
                children: [
                  Expanded(
                    child: AdminMobileFiltersButton(
                      label: context.t('Filtreler'),
                      count: _activeFilterCount,
                      active: _activeFilterCount > 0,
                      fullWidth: true,
                      onPressed: () => _openFilters(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AdminMobilePrimaryButton(
                      icon: Symbols.add,
                      label: context.t('Add User'),
                      fullWidth: true,
                      onPressed: onAddUser,
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 14),
        Expanded(
          child: AdminMobileListView(
            loading: loading,
            itemCount: users.length,
            emptyLabel: context.t('No users found'),
            itemBuilder: (context, index) {
              final user = users[index];
              return _UsersMobileCard(
                user: user,
                roles: roles,
                selected: selectedUserIds.contains(user.id),
                onToggle: () => onToggleUser(user.id),
                onEditUser: onEditUser,
                onToggleStatus: onToggleStatus,
                onToggleReward: onToggleReward,
                onDeleteUser: onDeleteUser,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AdminMobilePager(
          page: page,
          lastPage: lastPage,
          rangeText: rangeText,
          loading: loading,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _UsersMobileCard extends StatelessWidget {
  const _UsersMobileCard({
    required this.user,
    required this.roles,
    required this.selected,
    required this.onToggle,
    required this.onEditUser,
    required this.onToggleStatus,
    required this.onToggleReward,
    required this.onDeleteUser,
  });

  final ManagedUser user;
  final List<AdminUserRole> roles;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<ManagedUser> onEditUser;
  final ValueChanged<ManagedUser> onToggleStatus;
  final ValueChanged<ManagedUser> onToggleReward;
  final ValueChanged<ManagedUser> onDeleteUser;

  @override
  Widget build(BuildContext context) {
    final avatar = user.avatarUrl.trim();
    final statusColor = switch (user.status) {
      'Aktif' => const Color(0xFF198754),
      'Engelli' => AppColors.actionRed,
      _ => AppColors.warmHorizon,
    };

    return AdminMobileCard(
      selected: selected,
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminMobileCheckbox(
                value: selected,
                onChanged: (_) => onToggle(),
              ),
              const SizedBox(width: 12),
              AdminMobileAvatar(
                label: user.displayName,
                imageUrl: avatar.isEmpty ? null : _publicUrl(avatar),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepOcean,
                      ),
                    ),
                    if (user.displayUsername.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.displayUsername,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                    if (user.email.trim().isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.support,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AdminMobileMenuButton(
                tooltip: context.t('User actions'),
                actions: [
                  AdminMobileMenuAction(
                    icon: Symbols.edit_square,
                    label: 'Düzenle',
                    onTap: () => onEditUser(user),
                  ),
                  AdminMobileMenuAction(
                    icon: user.active
                        ? Symbols.visibility_off
                        : Symbols.verified,
                    label: user.active ? 'Pasifleştir' : 'Aktifleştir',
                    onTap: () => onToggleStatus(user),
                  ),
                  AdminMobileMenuAction(
                    icon: user.rewardEnabled
                        ? Symbols.visibility_off
                        : Symbols.verified,
                    label: user.rewardEnabled ? 'Ödülü kapat' : 'Ödülü aç',
                    onTap: () => onToggleReward(user),
                  ),
                  AdminMobileMenuAction(
                    icon: Symbols.delete,
                    label: 'Sil',
                    danger: true,
                    onTap: () => onDeleteUser(user),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AdminMobileChip(
                label: context.t(roleLabelFor(user.role, roles)),
                icon: Symbols.verified,
                color: AppColors.deepOcean,
              ),
              if (user.rewardEnabled)
                AdminMobileChip(
                  label: 'Ödül',
                  icon: Symbols.verified,
                  color: AppColors.warmHorizon,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.softLine.withValues(alpha: 0.9)),
          const SizedBox(height: 10),
          Row(
            children: [
              AdminMobileStatusPill(
                label: context.t(user.status),
                color: statusColor,
              ),
              const Spacer(),
              Text(
                formatAdminFullDate(context, user.createdAt),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.support,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsersFilters extends StatelessWidget {
  const _UsersFilters({
    required this.roles,
    required this.roleFilter,
    required this.rewardFilter,
    required this.statusFilter,
    required this.onRoleChanged,
    required this.onRewardChanged,
    required this.onStatusChanged,
  });

  final List<AdminUserRole> roles;
  final String roleFilter;
  final String rewardFilter;
  final String statusFilter;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String?> onRewardChanged;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final filters = [
          _FilterSelect(
            label: 'Rol',
            value: roleFilter,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              for (final role in roles)
                DropdownMenuItem(
                  value: role.name,
                  child: Text(context.t(role.label)),
                ),
            ],
            onChanged: onRoleChanged,
          ),
          _FilterSelect(
            label: 'Ödül Sistemi',
            value: rewardFilter,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              DropdownMenuItem(
                value: 'Aktif',
                child: Text(context.t('Active')),
              ),
              DropdownMenuItem(
                value: 'Pasif',
                child: Text(context.t('Passive')),
              ),
            ],
            onChanged: onRewardChanged,
          ),
          _FilterSelect(
            label: 'Durum',
            value: statusFilter,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              DropdownMenuItem(
                value: 'Aktif',
                child: Text(context.t('Active')),
              ),
              DropdownMenuItem(
                value: 'Beklemede',
                child: Text(context.t('Pending')),
              ),
              DropdownMenuItem(
                value: 'Engelli',
                child: Text(context.t('Disabled')),
              ),
            ],
            onChanged: onStatusChanged,
          ),
        ];

        if (compact) {
          return Column(
            children: [
              for (var index = 0; index < filters.length; index++) ...[
                filters[index],
                if (index != filters.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < filters.length; index++) ...[
              Expanded(child: filters[index]),
              if (index != filters.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

class _FilterSelect extends StatelessWidget {
  const _FilterSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.any((item) => item.value == value)
        ? value
        : (items.isEmpty ? null : items.first.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(label),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: UsersTableCard.toolbarHeight,
            padding: const EdgeInsets.only(left: 12, right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: safeValue,
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
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UsersToolbar extends StatelessWidget {
  const _UsersToolbar({
    required this.pageSize,
    required this.searchQuery,
    required this.selectedCount,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onAddUser,
    required this.onDeleteSelected,
  });

  final int pageSize;
  final String searchQuery;
  final int selectedCount;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddUser;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final pageSizeSelect = _PageSizeSelect(
          value: pageSize,
          onChanged: onPageSizeChanged,
        );
        final search = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: compact ? double.infinity : 220,
            maxWidth: compact ? double.infinity : 230,
          ),
          child: _UserSearchField(
            value: searchQuery,
            onChanged: onSearchChanged,
          ),
        );
        final addButton = _AddUserButton(onPressed: onAddUser);
        final deleteButton = selectedCount == 0
            ? null
            : _BulkDeleteButton(
                selectedCount: selectedCount,
                onPressed: onDeleteSelected,
              );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: pageSizeSelect),
              if (deleteButton != null) ...[
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: deleteButton),
              ],
              const SizedBox(height: 14),
              search,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: addButton),
            ],
          );
        }

        return Row(
          children: [
            pageSizeSelect,
            if (deleteButton != null) ...[
              const SizedBox(width: 12),
              deleteButton,
            ],
            const Spacer(),
            search,
            const SizedBox(width: 14),
            addButton,
          ],
        );
      },
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
        height: UsersTableCard.toolbarHeight,
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
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 25, child: Text('25')),
              DropdownMenuItem(value: 50, child: Text('50')),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _UserSearchField extends StatefulWidget {
  const _UserSearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_UserSearchField> createState() => _UserSearchFieldState();
}

class _UserSearchFieldState extends State<_UserSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _UserSearchField oldWidget) {
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
      height: UsersTableCard.toolbarHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: TextField(
        controller: _controller,
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        textAlignVertical: TextAlignVertical.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: context.t('Search users...'),
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
            minHeight: UsersTableCard.toolbarHeight,
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

class _AddUserButton extends StatelessWidget {
  const _AddUserButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: UsersTableCard.toolbarHeight,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.actionRed),
              minimumSize: const Size(0, UsersTableCard.toolbarHeight),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
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
            const SymbolIcon(Symbols.add, color: Colors.white, size: 17),
            const SizedBox(width: 8),
            Text(context.t('Add User')),
          ],
        ),
      ),
    );
  }
}

class _BulkDeleteButton extends StatelessWidget {
  const _BulkDeleteButton({
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

class _UsersDataTable extends StatelessWidget {
  const _UsersDataTable({
    required this.users,
    required this.roles,
    required this.loading,
    required this.selectedUserIds,
    required this.sortState,
    required this.onToggleUser,
    required this.onToggleAllUsers,
    required this.onEditUser,
    required this.onToggleStatus,
    required this.onToggleReward,
    required this.onDeleteUser,
    required this.onSort,
  });

  final List<ManagedUser> users;
  final List<AdminUserRole> roles;
  final bool loading;
  final Set<String> selectedUserIds;
  final TableSortState sortState;
  final ValueChanged<String> onToggleUser;
  final VoidCallback onToggleAllUsers;
  final ValueChanged<ManagedUser> onEditUser;
  final ValueChanged<ManagedUser> onToggleStatus;
  final ValueChanged<ManagedUser> onToggleReward;
  final ValueChanged<ManagedUser> onDeleteUser;
  final ValueChanged<String> onSort;

  static const double _minWidth = 900;
  static const double _selectWidth = 42;
  static const double _idWidth = 64;
  static const double _roleWidth = 130;
  static const double _rewardWidth = 130;
  static const double _statusWidth = 112;
  static const double _createdWidth = 160;
  static const double _menuWidth = 76;
  static const double _contentSpacing = 36;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < _minWidth
            ? _minWidth
            : constraints.maxWidth;
        final layout = _UsersTableColumnLayout.forWidth(tableWidth);

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
                  _UsersHeader(
                    layout: layout,
                    selectedCount: selectedUserIds.length,
                    totalCount: users.length,
                    sortState: sortState,
                    onToggleAllUsers: onToggleAllUsers,
                    onSort: onSort,
                  ),
                  Expanded(
                    child: loading
                        ? const _UsersLoading()
                        : users.isEmpty
                        ? const _UsersEmpty()
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final user in users)
                                  _UsersRow(
                                    user: user,
                                    roles: roles,
                                    layout: layout,
                                    selected: selectedUserIds.contains(user.id),
                                    onToggle: () => onToggleUser(user.id),
                                    onEditUser: onEditUser,
                                    onToggleStatus: onToggleStatus,
                                    onToggleReward: onToggleReward,
                                    onDeleteUser: onDeleteUser,
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

class _UsersTableColumnLayout {
  const _UsersTableColumnLayout({
    required this.userWidth,
    required this.roleWidth,
    required this.rewardWidth,
    required this.statusWidth,
    required this.createdWidth,
  });

  final double userWidth;
  final double roleWidth;
  final double rewardWidth;
  final double statusWidth;
  final double createdWidth;

  static double get _baseUserWidth {
    return _UsersDataTable._minWidth -
        _UsersDataTable._selectWidth -
        _UsersDataTable._idWidth -
        _UsersDataTable._roleWidth -
        _UsersDataTable._rewardWidth -
        _UsersDataTable._statusWidth -
        _UsersDataTable._createdWidth -
        _UsersDataTable._menuWidth -
        _UsersDataTable._contentSpacing;
  }

  factory _UsersTableColumnLayout.forWidth(double tableWidth) {
    final extraWidth = tableWidth - _UsersDataTable._minWidth;

    return _UsersTableColumnLayout(
      userWidth: _baseUserWidth + (extraWidth * 0.20),
      roleWidth: _UsersDataTable._roleWidth + (extraWidth * 0.24),
      rewardWidth: _UsersDataTable._rewardWidth + (extraWidth * 0.22),
      statusWidth: _UsersDataTable._statusWidth + (extraWidth * 0.18),
      createdWidth: _UsersDataTable._createdWidth + (extraWidth * 0.16),
    );
  }
}

class _UsersHeader extends StatelessWidget {
  const _UsersHeader({
    required this.layout,
    required this.selectedCount,
    required this.totalCount,
    required this.sortState,
    required this.onToggleAllUsers,
    required this.onSort,
  });

  final _UsersTableColumnLayout layout;
  final int selectedCount;
  final int totalCount;
  final TableSortState sortState;
  final VoidCallback onToggleAllUsers;
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
            width: _UsersDataTable._selectWidth,
            child: _UserCheckbox(
              value: selectedCount == 0 || totalCount == 0
                  ? false
                  : selectedCount == totalCount
                  ? true
                  : null,
              tristate: true,
              onChanged: (_) => onToggleAllUsers(),
            ),
          ),
          SizedBox(
            width: _UsersDataTable._idWidth,
            child: SortableTableHeader(
              label: 'ID',
              sortKey: 'id',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: layout.userWidth,
            child: SortableTableHeader(
              label: 'User',
              sortKey: 'user',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: layout.roleWidth,
            child: SortableTableHeader(
              label: 'Role',
              sortKey: 'role',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: layout.rewardWidth,
            child: SortableTableHeader(
              label: 'Reward System',
              sortKey: 'reward',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: layout.statusWidth,
            child: SortableTableHeader(
              label: 'Status',
              sortKey: 'status',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: layout.createdWidth,
            child: SortableTableHeader(
              label: 'Created',
              sortKey: 'created',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          const SizedBox(
            width: _UsersDataTable._menuWidth,
            child: _HeaderText('Action'),
          ),
        ],
      ),
    );
  }
}

class _UsersRow extends StatelessWidget {
  const _UsersRow({
    required this.user,
    required this.roles,
    required this.layout,
    required this.selected,
    required this.onToggle,
    required this.onEditUser,
    required this.onToggleStatus,
    required this.onToggleReward,
    required this.onDeleteUser,
  });

  final ManagedUser user;
  final List<AdminUserRole> roles;
  final _UsersTableColumnLayout layout;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<ManagedUser> onEditUser;
  final ValueChanged<ManagedUser> onToggleStatus;
  final ValueChanged<ManagedUser> onToggleReward;
  final ValueChanged<ManagedUser> onDeleteUser;

  @override
  Widget build(BuildContext context) {
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
            width: _UsersDataTable._selectWidth,
            child: _UserCheckbox(value: selected, onChanged: (_) => onToggle()),
          ),
          SizedBox(
            width: _UsersDataTable._idWidth,
            child: _RowSelectTapTarget(
              onTap: onToggle,
              child: Text(
                user.rowNumber.toString(),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(
            width: layout.userWidth,
            child: _RowSelectTapTarget(
              onTap: onToggle,
              child: _UserIdentity(user: user),
            ),
          ),
          SizedBox(
            width: layout.roleWidth,
            child: _RoleCell(role: roleLabelFor(user.role, roles)),
          ),
          SizedBox(
            width: layout.rewardWidth,
            child: _RewardCell(enabled: user.rewardEnabled),
          ),
          SizedBox(
            width: layout.statusWidth,
            child: _StatusBadge(label: user.status),
          ),
          SizedBox(
            width: layout.createdWidth,
            child: _DateCell(dateTime: user.createdAt),
          ),
          SizedBox(
            width: _UsersDataTable._menuWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _UserRowMenu(
                user: user,
                onEditUser: onEditUser,
                onToggleStatus: onToggleStatus,
                onToggleReward: onToggleReward,
                onDeleteUser: onDeleteUser,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCheckbox extends StatelessWidget {
  const _UserCheckbox({
    required this.value,
    required this.onChanged,
    this.tristate = false,
  });

  final bool? value;
  final ValueChanged<bool?> onChanged;
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      tristate: tristate,
      mouseCursor: SystemMouseCursors.click,
      activeColor: AppColors.deepOcean,
      checkColor: Colors.white,
      side: BorderSide(color: AppColors.line.withValues(alpha: 0.76)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      onChanged: onChanged,
    );
  }
}

class _RowSelectTapTarget extends StatelessWidget {
  const _RowSelectTapTarget({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
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

class _UserIdentity extends StatelessWidget {
  const _UserIdentity({required this.user});

  final ManagedUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _UserAvatar(user: user),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                user.displayUsername,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.support,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});

  final ManagedUser user;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl.trim();

    return Container(
      width: 34,
      height: 34,
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.support),
      ),
      child: ClipOval(
        child: ColoredBox(
          color: AppColors.softLine,
          child: avatarUrl.isEmpty
              ? Center(child: _UserAvatarFallback(user: user))
              : Image.network(
                  _publicUrl(avatarUrl),
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, _, _) {
                    return Center(child: _UserAvatarFallback(user: user));
                  },
                ),
        ),
      ),
    );
  }
}

class _UserAvatarFallback extends StatelessWidget {
  const _UserAvatarFallback({required this.user});

  final ManagedUser user;

  @override
  Widget build(BuildContext context) {
    return Text(
      user.initials,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: const TextStyle(
        color: AppColors.deepOcean,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _RoleCell extends StatelessWidget {
  const _RoleCell({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SymbolIcon(
          Symbols.verified,
          color: AppColors.iconMuted,
          size: 18,
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            context.t(role),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _RewardCell extends StatelessWidget {
  const _RewardCell({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SymbolIcon(
      enabled ? Symbols.verified : Symbols.visibility_off,
      color: AppColors.iconMuted,
      size: 20,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Aktif' => const Color(0xFF198754),
      'Engelli' => AppColors.actionRed,
      _ => AppColors.warmHorizon,
    };

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
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                context.t(label),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({required this.dateTime});

  final DateTime? dateTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatAdminFullDate(context, dateTime),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatAdminTime(dateTime),
          style: const TextStyle(
            color: AppColors.support,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _UserRowMenu extends StatefulWidget {
  const _UserRowMenu({
    required this.user,
    required this.onEditUser,
    required this.onToggleStatus,
    required this.onToggleReward,
    required this.onDeleteUser,
  });

  final ManagedUser user;
  final ValueChanged<ManagedUser> onEditUser;
  final ValueChanged<ManagedUser> onToggleStatus;
  final ValueChanged<ManagedUser> onToggleReward;
  final ValueChanged<ManagedUser> onDeleteUser;

  @override
  State<_UserRowMenu> createState() => _UserRowMenuState();
}

class _UserRowMenuState extends State<_UserRowMenu> {
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
              child: _UserMenuCard(
                user: widget.user,
                onEdit: () =>
                    _runAndClose(() => widget.onEditUser(widget.user)),
                onToggleStatus: () =>
                    _runAndClose(() => widget.onToggleStatus(widget.user)),
                onToggleReward: () =>
                    _runAndClose(() => widget.onToggleReward(widget.user)),
                onDelete: () =>
                    _runAndClose(() => widget.onDeleteUser(widget.user)),
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
      child: Tooltip(
        message: context.t('User actions'),
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
      ),
    );
  }
}

class _UserMenuCard extends StatelessWidget {
  const _UserMenuCard({
    required this.user,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onToggleReward,
    required this.onDelete,
  });

  final ManagedUser user;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onToggleReward;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 206,
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
            _UserMenuItem(
              icon: Symbols.edit_square,
              label: 'Düzenle',
              onTap: onEdit,
            ),
            _UserMenuItem(
              icon: user.active ? Symbols.visibility_off : Symbols.verified,
              label: user.active ? 'Pasifleştir' : 'Aktifleştir',
              onTap: onToggleStatus,
            ),
            _UserMenuItem(
              icon: user.rewardEnabled
                  ? Symbols.visibility_off
                  : Symbols.verified,
              label: user.rewardEnabled ? 'Ödülü kapat' : 'Ödülü aç',
              onTap: onToggleReward,
            ),
            _UserMenuItem(
              icon: Symbols.delete,
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

class _UserMenuItem extends StatelessWidget {
  const _UserMenuItem({
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

class _UsersLoading extends StatelessWidget {
  const _UsersLoading();

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

class _UsersEmpty extends StatelessWidget {
  const _UsersEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('No users found'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _UsersFooter extends StatelessWidget {
  const _UsersFooter({
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

  @override
  Widget build(BuildContext context) {
    final lastPage = totalCount == 0 ? 1 : ((totalCount - 1) ~/ pageSize) + 1;
    final from = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final to = totalCount == 0
        ? 0
        : (page * pageSize > totalCount ? totalCount : page * pageSize);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final summary = Text(
          context.t(
            'common.recordRange',
            values: {'from': from, 'to': to, 'total': totalCount},
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w500,
          ),
        );
        final pager = _UsersPagination(
          page: page,
          lastPage: lastPage,
          loading: loading,
          onPageChanged: onPageChanged,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 16),
              summary,
              const SizedBox(height: 14),
              pager,
            ],
          );
        }

        return Column(
          children: [
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 16),
            Row(children: [summary, const Spacer(), pager]),
          ],
        );
      },
    );
  }
}

class _UsersPagination extends StatelessWidget {
  const _UsersPagination({
    required this.page,
    required this.lastPage,
    required this.loading,
    required this.onPageChanged,
  });

  final int page;
  final int lastPage;
  final bool loading;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _PageButton(
          label: '<<',
          enabled: page > 1 && !loading,
          onPressed: () => onPageChanged(1),
        ),
        _PageButton(
          label: '<',
          enabled: page > 1 && !loading,
          onPressed: () => onPageChanged(page - 1),
        ),
        _PageButton(label: page.toString(), selected: true),
        _PageButton(
          label: '>',
          enabled: page < lastPage && !loading,
          onPressed: () => onPageChanged(page + 1),
        ),
        _PageButton(
          label: '>>',
          enabled: page < lastPage && !loading,
          onPressed: () => onPageChanged(lastPage),
        ),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _publicUrl(String value) {
  if (value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('data:')) {
    return value;
  }
  final base = !kIsWeb
      ? switch (defaultTargetPlatform) {
          TargetPlatform.android => Uri.parse('http://10.0.2.2:4321'),
          _ => Uri.parse('http://127.0.0.1:4321'),
        }
      : Uri.base;
  return base.resolve(value).toString();
}
