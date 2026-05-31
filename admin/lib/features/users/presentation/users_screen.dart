import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_users_repository.dart';
import 'users_models.dart';
import 'widgets/users_dialogs.dart';
import 'widgets/users_summary_grid.dart';
import 'widgets/users_table_card.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminUsersRepository(),
  });

  final AdminSession session;
  final AdminUsersRepository repository;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const _all = 'Tümü';
  static const _fallbackRoles = [
    AdminUserRole(id: 'admin', name: 'admin', label: 'Süper Yönetici'),
    AdminUserRole(id: 'editor', name: 'editor', label: 'Editör'),
    AdminUserRole(id: 'moderator', name: 'moderator', label: 'Moderatör'),
    AdminUserRole(id: 'member', name: 'member', label: 'Standart Üye'),
  ];

  var _roles = _fallbackRoles;
  var _users = const <ManagedUser>[];
  var _metrics = const UserMetrics(
    total: 0,
    rewardEnabled: 0,
    active: 0,
    pending: 0,
  );
  final Set<String> _selectedUserIds = {};
  Timer? _searchDebounce;
  String? _errorText;
  var _loading = true;
  var _page = 1;
  var _pageSize = 10;
  var _totalCount = 0;
  var _searchQuery = '';
  var _roleFilter = _all;
  var _rewardFilter = _all;
  var _statusFilter = _all;
  var _sortState = const TableSortState(key: 'created', ascending: false);

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final rolesFuture = widget.repository.fetchRoles();
      final metricsFuture = widget.repository.fetchMetrics();
      final usersFuture = _fetchUsers();
      final roles = await rolesFuture;
      final metrics = await metricsFuture;
      final users = await usersFuture;
      if (!mounted) return;
      setState(() {
        _roles = roles.isEmpty ? _fallbackRoles : roles;
        _metrics = metrics;
        _users = users.users;
        _totalCount = users.totalCount;
        _selectedUserIds.removeWhere(
          (id) => !_users.any((user) => user.id == id),
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

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final result = await _fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = result.users;
        _totalCount = result.totalCount;
        _selectedUserIds.removeWhere(
          (id) => !_users.any((user) => user.id == id),
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

  Future<UsersPageResult> _fetchUsers() {
    return widget.repository.fetchUsers(
      search: _searchQuery,
      role: _roleFilter,
      reward: _rewardFilter,
      status: _statusFilter,
      page: _page,
      pageSize: _pageSize,
      sortKey: _sortState.key,
      sortAscending: _sortState.ascending,
    );
  }

  void _toggleUser(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _toggleAllUsers() {
    setState(() {
      if (_users.isNotEmpty && _selectedUserIds.length == _users.length) {
        _selectedUserIds.clear();
      } else {
        _selectedUserIds
          ..clear()
          ..addAll(_users.map((user) => user.id));
      }
    });
  }

  void _changePageSize(int? value) {
    if (value == null || value == _pageSize) return;
    setState(() {
      _pageSize = value;
      _page = 1;
      _selectedUserIds.clear();
    });
    unawaited(_loadUsers());
  }

  void _changeSearch(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _page = 1;
        _selectedUserIds.clear();
      });
      unawaited(_loadUsers());
    });
  }

  void _changeRole(String? value) => _changeFilter(role: value);

  void _changeReward(String? value) => _changeFilter(reward: value);

  void _changeStatus(String? value) => _changeFilter(status: value);

  void _changeSort(String sortKey) {
    setState(() {
      _sortState = _sortState.toggled(sortKey);
      _page = 1;
      _selectedUserIds.clear();
    });
    unawaited(_loadUsers());
  }

  void _changeFilter({String? role, String? reward, String? status}) {
    setState(() {
      if (role != null) _roleFilter = role;
      if (reward != null) _rewardFilter = reward;
      if (status != null) _statusFilter = status;
      _page = 1;
      _selectedUserIds.clear();
    });
    unawaited(_loadUsers());
  }

  void _changePage(int page) {
    if (page == _page) return;
    setState(() {
      _page = page;
      _selectedUserIds.clear();
    });
    unawaited(_loadUsers());
  }

  Future<void> _addUser() async {
    final data = await showUserFormDialog(context, roles: _roles);
    if (data == null) return;
    await _runMutation(
      () => widget.repository.createUser(session: widget.session, data: data),
    );
  }

  Future<void> _editUser(ManagedUser user) async {
    final data = await showUserFormDialog(context, roles: _roles, user: user);
    if (data == null) return;
    await _runMutation(
      () => widget.repository.updateUser(
        session: widget.session,
        userId: user.id,
        data: data,
      ),
    );
  }

  Future<void> _toggleStatus(ManagedUser user) async {
    final nextStatus = user.active ? 'Engelli' : 'Aktif';
    await _runMutation(
      () => widget.repository.updateUser(
        session: widget.session,
        userId: user.id,
        data: _formDataFor(user, status: nextStatus),
      ),
      reloadMetrics: true,
    );
  }

  Future<void> _toggleReward(ManagedUser user) async {
    await _runMutation(
      () => widget.repository.updateUser(
        session: widget.session,
        userId: user.id,
        data: _formDataFor(user, rewardEnabled: !user.rewardEnabled),
      ),
      reloadMetrics: true,
    );
  }

  Future<void> _deleteUser(ManagedUser user) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('Delete user?'),
      message: context.t(
        'users.deleteMessage',
        values: {'name': user.displayName},
      ),
      confirmLabel: context.t('Delete'),
      danger: true,
    );
    if (!confirmed) return;

    await _runMutation(
      () => widget.repository.deleteUser(
        session: widget.session,
        userId: user.id,
      ),
      reloadMetrics: true,
    );
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedUserIds.toList(growable: false);
    if (ids.isEmpty) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('Delete selected users?'),
      message: context.t(
        'users.deleteSelectedMessage',
        values: {'count': ids.length},
      ),
      confirmLabel: context.t('Delete'),
      danger: true,
    );
    if (!confirmed) return;

    await _runMutation(
      () =>
          widget.repository.deleteUsers(session: widget.session, userIds: ids),
      reloadMetrics: true,
    );
  }

  Future<void> _runMutation(
    Future<void> Function() action, {
    bool reloadMetrics = true,
  }) async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      await action();
      if (!mounted) return;
      _selectedUserIds.clear();
      if (reloadMetrics) {
        await _loadAll();
      } else {
        await _loadUsers();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  UserFormData _formDataFor(
    ManagedUser user, {
    String? status,
    bool? rewardEnabled,
  }) {
    return UserFormData(
      fullName: user.fullName,
      username: user.username,
      email: user.email,
      role: user.role,
      status: status ?? user.status,
      rewardEnabled: rewardEnabled ?? user.rewardEnabled,
      password: '',
    );
  }

  List<UserMetric> get _metricCards {
    return [
      UserMetric(
        title: context.t('Session'),
        value: _metrics.total.toString(),
        change: '(+0%)',
        description: context.t('Total users'),
        icon: Symbols.group,
        iconColor: AppColors.actionRed,
      ),
      UserMetric(
        title: context.t('Reward System'),
        value: _metrics.rewardEnabled.toString(),
        change: '(+0%)',
        description: context.t('Active systems'),
        icon: Symbols.verified,
        iconColor: AppColors.actionRed,
      ),
      UserMetric(
        title: context.t('Active Users'),
        value: _metrics.active.toString(),
        change: '(+0%)',
        description: context.t('Active users in the system'),
        icon: Symbols.person,
        iconColor: AppColors.warmHorizon,
      ),
      UserMetric(
        title: context.t('Pending Approval'),
        value: _metrics.pending.toString(),
        change: '(+0%)',
        description: context.t('Users awaiting approval'),
        icon: Symbols.person,
        iconColor: AppColors.warmHorizon,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final compact = constraints.maxWidth < 900;

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _UsersTitle(),
            const SizedBox(height: 22),
            UsersSummaryGrid(metrics: _metricCards),
            if (_errorText != null) ...[
              const SizedBox(height: 16),
              _UsersErrorBanner(message: _errorText!),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: UsersTableCard(
                users: _users,
                roles: _roles,
                loading: _loading,
                page: _page,
                pageSize: _pageSize,
                totalCount: _totalCount,
                searchQuery: _searchQuery,
                roleFilter: _roleFilter,
                rewardFilter: _rewardFilter,
                statusFilter: _statusFilter,
                selectedUserIds: _selectedUserIds,
                sortState: _sortState,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onRoleChanged: _changeRole,
                onRewardChanged: _changeReward,
                onStatusChanged: _changeStatus,
                onPageChanged: _changePage,
                onToggleUser: _toggleUser,
                onToggleAllUsers: _toggleAllUsers,
                onAddUser: () => unawaited(_addUser()),
                onEditUser: (user) => unawaited(_editUser(user)),
                onToggleStatus: (user) => unawaited(_toggleStatus(user)),
                onToggleReward: (user) => unawaited(_toggleReward(user)),
                onDeleteUser: (user) => unawaited(_deleteUser(user)),
                onDeleteSelected: () => unawaited(_deleteSelected()),
                onSort: _changeSort,
              ),
            ),
          ],
        );

        if (compact) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              28,
              horizontalPadding,
              28,
            ),
            child: SizedBox(height: 980, child: content),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            28,
            horizontalPadding,
            28,
          ),
          child: content,
        );
      },
    );
  }
}

class _UsersTitle extends StatelessWidget {
  const _UsersTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t('Users'),
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _UsersErrorBanner extends StatelessWidget {
  const _UsersErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
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
