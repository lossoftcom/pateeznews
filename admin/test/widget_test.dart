import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pateeznews_admin/app/pateeznews_admin_app.dart';
import 'package:pateeznews_admin/core/localization/admin_translations.dart';
import 'package:pateeznews_admin/core/theme/app_colors.dart';
import 'package:pateeznews_admin/features/account/data/admin_account_settings_repository.dart';
import 'package:pateeznews_admin/features/auth/data/admin_auth_models.dart';
import 'package:pateeznews_admin/features/auth/data/admin_auth_repository.dart';
import 'package:pateeznews_admin/features/comments/data/admin_comments_repository.dart';
import 'package:pateeznews_admin/features/comments/presentation/comments_models.dart';
import 'package:pateeznews_admin/features/navigation/data/admin_navigation_repository.dart';
import 'package:pateeznews_admin/features/navigation/presentation/navigation_models.dart';
import 'package:pateeznews_admin/features/news/data/admin_news_repository.dart';
import 'package:pateeznews_admin/features/news/presentation/news_models.dart';
import 'package:pateeznews_admin/features/pages/data/admin_pages_repository.dart';
import 'package:pateeznews_admin/features/pages/presentation/pages_models.dart';
import 'package:pateeznews_admin/features/stories/data/admin_stories_repository.dart';
import 'package:pateeznews_admin/features/stories/presentation/stories_models.dart';
import 'package:pateeznews_admin/features/auth/data/supabase_auth_client.dart';
import 'package:pateeznews_admin/features/auth/data/remembered_login_store.dart';
import 'package:pateeznews_admin/features/settings/data/admin_ai_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_content_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_font_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_general_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_language_models.dart';
import 'package:pateeznews_admin/features/settings/data/admin_languages_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_module_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_security_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_storage_settings_repository.dart';
import 'package:pateeznews_admin/features/social/data/admin_social_repository.dart';
import 'package:pateeznews_admin/features/social/presentation/social_platform_data.dart';
import 'package:pateeznews_admin/features/social/presentation/social_settings_models.dart';
import 'package:pateeznews_admin/features/subscribers/data/admin_subscribers_repository.dart';
import 'package:pateeznews_admin/features/subscribers/presentation/subscribers_models.dart';
import 'package:pateeznews_admin/features/users/data/admin_roles_repository.dart';
import 'package:pateeznews_admin/features/users/data/admin_users_repository.dart';
import 'package:pateeznews_admin/features/users/presentation/users_models.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

const _testUser = AdminUser(
  id: '6c1a27d3-ce8e-4c42-bec1-fc092139e3ee',
  email: 'demo.user@gmail.com',
  role: 'authenticated',
  aud: 'authenticated',
  userMetadata: {},
  appMetadata: {},
);

const _testSession = AdminSession(
  accessToken: 'test-token',
  tokenType: 'bearer',
  expiresAt: 4102444800,
  user: _testUser,
);

const _testProfile = AdminProfile(
  id: '6c1a27d3-ce8e-4c42-bec1-fc092139e3ee',
  username: 'nigdejournal',
  fullName: 'Pateez Niğde',
  avatarUrl: '',
  role: 'admin',
  email: 'demo.user@gmail.com',
);

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
final _secureStorageValues = <String, String>{};

Future<Object?> _handleSecureStorageCall(MethodCall call) async {
  final args = call.arguments is Map
      ? Map<Object?, Object?>.from(call.arguments as Map)
      : <Object?, Object?>{};
  final key = args['key']?.toString() ?? '';

  switch (call.method) {
    case 'read':
      return _secureStorageValues[key];
    case 'write':
      _secureStorageValues[key] = args['value']?.toString() ?? '';
      return null;
    case 'delete':
      _secureStorageValues.remove(key);
      return null;
    case 'deleteAll':
      _secureStorageValues.clear();
      return null;
    case 'readAll':
      return Map<String, String>.from(_secureStorageValues);
    case 'containsKey':
      return _secureStorageValues.containsKey(key);
  }
  return null;
}

class _FakeAdminAuthRepository implements AdminAuthRepository {
  _FakeAdminAuthRepository({this.signInException});

  final AdminAuthException? signInException;

  @override
  Future<AdminAuthState?> restoreSession() async => null;

  @override
  Future<AdminAuthState> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final exception = signInException;
    if (exception != null) throw exception;
    return const AdminAuthState(session: _testSession, profile: _testProfile);
  }

  @override
  Future<void> signOut() async {}
}

class _FakeAdminAccountSettingsRepository
    implements AdminAccountSettingsRepository {
  _FakeAdminAccountSettingsRepository();

  var profile = AdminAccountProfile(
    id: _testUser.id,
    fullName: 'Pateez Niğde',
    username: 'nigdejournal',
    email: 'demo.user@gmail.com',
    phone: '+90 5XX XXX XX XX',
    expertise: 'Yerel haber',
    foundationDate: '2026',
    address: 'Niğde',
    website: 'https://www.pateez.com',
    aboutMe: 'Pateez admin hesabı',
    slug: 'nigdejournal',
    metaTitle: 'Pateez Niğde',
    metaKeywords: 'niğde, haber',
    metaDescription: 'Pateez Niğde admin profili',
    canonicalUrl: 'https://www.pateez.com/yazar/nigdejournal',
    avatarUrl: '',
    coverUrl: '',
    socialLinks: const {'facebook': 'pateez', 'twitter': 'pateez'},
    rewardSystem: false,
    showEmail: true,
    rssFeeds: true,
    supportsShowEmail: true,
    supportsRssFeeds: true,
  );

  AdminAccountProfile? savedProfile;
  var passwordUpdated = false;
  var accountDeleted = false;

  @override
  Future<AdminAccountProfile> fetchProfile(AdminSession session) async {
    return profile;
  }

  @override
  Future<AdminAccountProfile> saveProfile({
    required AdminSession session,
    required AdminAccountProfile profile,
  }) async {
    savedProfile = profile;
    this.profile = profile;
    return profile;
  }

  @override
  Future<String> uploadProfileImage({
    required AdminSession session,
    required AccountProfileImageKind kind,
    required String fileName,
    required List<int> bytes,
  }) async {
    return '/api/storage/file/profile/${session.user.id}-${kind.name}.png';
  }

  @override
  Future<void> updatePassword({
    required AdminSession session,
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordUpdated = true;
  }

  @override
  Future<void> deleteAccount({
    required AdminSession session,
    required String currentPassword,
  }) async {
    accountDeleted = true;
  }

  @override
  String publicUrl(String value) {
    if (value.startsWith('/')) return 'http://localhost:4321$value';
    return value;
  }
}

class _FakeAdminUsersRepository implements AdminUsersRepository {
  _FakeAdminUsersRepository();

  static const _roles = [
    AdminUserRole(id: 'admin', name: 'admin', label: 'Süper Yönetici'),
    AdminUserRole(id: 'editor', name: 'editor', label: 'Editör'),
    AdminUserRole(id: 'member', name: 'member', label: 'Standart Üye'),
  ];

  final _users = <ManagedUser>[
    ManagedUser(
      id: '39740358-88fa-4150-acd0-523b751a68bd',
      rowNumber: 1,
      fullName: 'Pateez Niğde',
      username: 'nigdejournal',
      email: 'pateezcom@gmail.com',
      role: 'admin',
      roleLabel: 'Süper Yönetici',
      status: 'Aktif',
      rewardEnabled: false,
      createdAt: DateTime.utc(2026, 1, 16, 12, 47),
      avatarUrl: '',
    ),
    ManagedUser(
      id: '6c1a27d3-ce8e-4c42-bec1-fc092139e3ee',
      rowNumber: 2,
      fullName: 'Nasip Gündoğu',
      username: 'nasip',
      email: 'demo.user@gmail.com',
      role: 'admin',
      roleLabel: 'Süper Yönetici',
      status: 'Aktif',
      rewardEnabled: false,
      createdAt: DateTime.utc(2026, 1, 4, 8, 36),
      avatarUrl: '',
    ),
  ];
  UserFormData? createdUser;
  UserFormData? updatedUser;
  String? updatedUserId;
  List<String>? deletedUserIds;

  @override
  Future<void> createUser({
    required AdminSession session,
    required UserFormData data,
  }) async {
    createdUser = data;
    _users.add(
      ManagedUser(
        id: 'created-user-id',
        rowNumber: _users.length + 1,
        fullName: data.fullName,
        username: data.username,
        email: data.email,
        role: data.role,
        roleLabel: roleLabelFor(data.role, _roles),
        status: data.status,
        rewardEnabled: data.rewardEnabled,
        createdAt: DateTime.utc(2026, 5, 22, 9, 0),
        avatarUrl: '',
      ),
    );
  }

  @override
  Future<void> deleteUser({
    required AdminSession session,
    required String userId,
  }) async {
    _users.removeWhere((user) => user.id == userId);
  }

  @override
  Future<void> deleteUsers({
    required AdminSession session,
    required List<String> userIds,
  }) async {
    deletedUserIds = userIds;
    _users.removeWhere((user) => userIds.contains(user.id));
  }

  @override
  Future<UserMetrics> fetchMetrics() async {
    return UserMetrics(
      total: _users.length,
      rewardEnabled: _users.where((user) => user.rewardEnabled).length,
      active: _users.where((user) => user.active).length,
      pending: _users.where((user) => !user.active).length,
    );
  }

  @override
  Future<List<AdminUserRole>> fetchRoles() async => _roles;

  @override
  Future<UsersPageResult> fetchUsers({
    required String search,
    required String role,
    required String reward,
    required String status,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final term = search.trim().toLowerCase();
    var rows = _users.where((user) {
      final matchesSearch =
          term.isEmpty ||
          user.fullName.toLowerCase().contains(term) ||
          user.username.toLowerCase().contains(term) ||
          user.email.toLowerCase().contains(term);
      final matchesRole = role == 'Tümü' || user.role == role;
      final matchesReward =
          reward == 'Tümü' ||
          (reward == 'Aktif' && user.rewardEnabled) ||
          (reward == 'Pasif' && !user.rewardEnabled);
      final matchesStatus = status == 'Tümü' || user.status == status;
      return matchesSearch && matchesRole && matchesReward && matchesStatus;
    }).toList();
    rows.sort((a, b) => _compareUsers(a, b, sortKey, sortAscending));

    final total = rows.length;
    final from = (page - 1) * pageSize;
    rows = from >= rows.length
        ? const <ManagedUser>[]
        : rows.skip(from).take(pageSize).toList(growable: false);
    return UsersPageResult(users: rows, totalCount: total);
  }

  int _compareUsers(
    ManagedUser a,
    ManagedUser b,
    String sortKey,
    bool ascending,
  ) {
    final result = switch (sortKey) {
      'id' => a.rowNumber.compareTo(b.rowNumber),
      'user' => a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      ),
      'role' => a.roleLabel.toLowerCase().compareTo(b.roleLabel.toLowerCase()),
      'reward' =>
        a.rewardEnabled == b.rewardEnabled
            ? 0
            : a.rewardEnabled
            ? -1
            : 1,
      'status' => a.status.toLowerCase().compareTo(b.status.toLowerCase()),
      'created' =>
        (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
      _ => 0,
    };
    return ascending ? result : -result;
  }

  @override
  Future<void> updateUser({
    required AdminSession session,
    required String userId,
    required UserFormData data,
  }) async {
    updatedUserId = userId;
    updatedUser = data;
    final index = _users.indexWhere((user) => user.id == userId);
    if (index == -1) return;
    final current = _users[index];
    _users[index] = ManagedUser(
      id: current.id,
      rowNumber: current.rowNumber,
      fullName: data.fullName,
      username: data.username,
      email: data.email,
      role: data.role,
      roleLabel: roleLabelFor(data.role, _roles),
      status: data.status,
      rewardEnabled: data.rewardEnabled,
      createdAt: current.createdAt,
      avatarUrl: current.avatarUrl,
    );
  }
}

class _FakeAdminRolesRepository implements AdminRolesRepository {
  _FakeAdminRolesRepository();

  final _permissions = const <AdminPermission>[
    AdminPermission(
      id: 'perm-users',
      key: 'manage_users',
      label: 'Kullanıcı Yönetimi',
      groupName: 'system',
      description: 'Kullanıcı hesaplarını yönetme yetkisi.',
    ),
    AdminPermission(
      id: 'perm-roles',
      key: 'view_roles',
      label: 'Rol & Yetki Yönetimi',
      groupName: 'sidebar',
      description: 'Rol düzenleme sayfasını görme yetkisi.',
    ),
  ];

  final _roles = <ManagedRole>[
    ManagedRole(
      id: 'role-admin',
      rowNumber: 1,
      name: 'admin',
      label: 'Süper Yönetici',
      description: 'Tüm yetkilere sahip sistem yöneticisi.',
      color: '#EA4335',
      memberCount: 1,
      permissionKeys: ['manage_users', 'view_roles'],
      permissionLabels: ['Kullanıcı Yönetimi', 'Rol & Yetki Yönetimi'],
      createdAt: DateTime.utc(2026, 1, 1),
    ),
    ManagedRole(
      id: 'role-editor',
      rowNumber: 2,
      name: 'editor',
      label: 'Editör',
      description: 'İçerik üreticisi.',
      color: '#2C3E50',
      memberCount: 0,
      permissionKeys: const [],
      permissionLabels: const [],
      createdAt: DateTime.utc(2026, 1, 2),
    ),
  ];

  RoleFormData? createdRole;
  RoleFormData? updatedRole;
  String? updatedRoleId;
  String? deletedRoleId;
  String? savedPermissionsRoleId;
  List<String>? savedPermissionKeys;

  @override
  Future<void> createRole({
    required AdminSession session,
    required RoleFormData data,
  }) async {
    createdRole = data;
    _roles.add(
      ManagedRole(
        id: 'role-created',
        rowNumber: _roles.length + 1,
        name: data.name,
        label: data.label,
        description: data.description,
        color: data.color,
        memberCount: 0,
        permissionKeys: const [],
        permissionLabels: const [],
        createdAt: DateTime.utc(2026, 5, 22),
      ),
    );
  }

  @override
  Future<void> deleteRole({
    required AdminSession session,
    required String roleId,
  }) async {
    deletedRoleId = roleId;
    _roles.removeWhere((role) => role.id == roleId);
  }

  @override
  Future<Set<String>> fetchPermissionKeysForRole(String roleName) async {
    if (roleName == 'admin') return {'*'};
    final role = _roles.where((item) => item.name == roleName).firstOrNull;
    return role?.permissionKeys.toSet() ?? const {};
  }

  @override
  Future<RolesPermissionsPageResult> fetchRolesPermissions({
    required String search,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final term = search.trim().toLowerCase();
    final rows =
        (term.isEmpty
                ? _roles
                : _roles
                      .where(
                        (role) =>
                            role.name.contains(term) ||
                            role.label.toLowerCase().contains(term),
                      )
                      .toList(growable: false))
            .toList()
          ..sort((a, b) => _compareRoles(a, b, sortKey, sortAscending));
    return RolesPermissionsPageResult(
      roles: rows.take(pageSize).toList(growable: false),
      permissions: _permissions,
      totalCount: rows.length,
    );
  }

  int _compareRoles(
    ManagedRole a,
    ManagedRole b,
    String sortKey,
    bool ascending,
  ) {
    final result = switch (sortKey) {
      'order' => a.rowNumber.compareTo(b.rowNumber),
      'name' => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      'slug' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      'permissions' => a.permissionLabels.length.compareTo(
        b.permissionLabels.length,
      ),
      'status' =>
        a.systemLocked == b.systemLocked
            ? 0
            : a.systemLocked
            ? -1
            : 1,
      _ => a.rowNumber.compareTo(b.rowNumber),
    };
    final normalized = result == 0
        ? a.rowNumber.compareTo(b.rowNumber)
        : result;
    return ascending ? normalized : -normalized;
  }

  @override
  Future<void> saveRolePermissions({
    required AdminSession session,
    required String roleId,
    required List<String> permissionKeys,
  }) async {
    savedPermissionsRoleId = roleId;
    savedPermissionKeys = permissionKeys;
    final index = _roles.indexWhere((role) => role.id == roleId);
    if (index == -1) return;
    final role = _roles[index];
    _roles[index] = ManagedRole(
      id: role.id,
      rowNumber: role.rowNumber,
      name: role.name,
      label: role.label,
      description: role.description,
      color: role.color,
      memberCount: role.memberCount,
      permissionKeys: permissionKeys,
      permissionLabels: [
        for (final permission in _permissions)
          if (permissionKeys.contains(permission.key)) permission.label,
      ],
      createdAt: role.createdAt,
    );
  }

  @override
  Future<void> updateRole({
    required AdminSession session,
    required String roleId,
    required RoleFormData data,
  }) async {
    updatedRoleId = roleId;
    updatedRole = data;
    final index = _roles.indexWhere((role) => role.id == roleId);
    if (index == -1) return;
    final role = _roles[index];
    _roles[index] = ManagedRole(
      id: role.id,
      rowNumber: role.rowNumber,
      name: data.name,
      label: data.label,
      description: data.description,
      color: data.color,
      memberCount: role.memberCount,
      permissionKeys: role.permissionKeys,
      permissionLabels: role.permissionLabels,
      createdAt: role.createdAt,
    );
  }
}

class _FakeAdminCommentsRepository implements AdminCommentsRepository {
  _FakeAdminCommentsRepository();

  final _comments = <AdminComment>[
    AdminComment(
      id: '1',
      rowNumber: 1,
      content: 'İlk yorum onay bekliyor.',
      postId: '12',
      userId: '39740358-88fa-4150-acd0-523b751a68bd',
      status: 'pending',
      createdAt: DateTime.utc(2026, 5, 22, 19, 5),
      updatedAt: DateTime.utc(2026, 5, 22, 19, 5),
      likesCount: 2,
      repliesCount: 0,
      reportsCount: 1,
      isPinned: false,
      postTitle: 'Deneme haberi',
      userName: 'Pateez Niğde',
      userAvatar: '',
      guestName: '',
      guestEmail: '',
    ),
    AdminComment(
      id: '2',
      rowNumber: 2,
      content: 'Sabit onaylı yorum.',
      postId: '13',
      userId: '6c1a27d3-ce8e-4c42-bec1-fc092139e3ee',
      status: 'approved',
      createdAt: DateTime.utc(2026, 5, 21, 10, 15),
      updatedAt: DateTime.utc(2026, 5, 21, 10, 15),
      likesCount: 5,
      repliesCount: 1,
      reportsCount: 0,
      isPinned: true,
      postTitle: 'Onaylı haber',
      userName: 'Nasip Gündoğu',
      userAvatar: '',
      guestName: '',
      guestEmail: '',
    ),
  ];

  String? approvedCommentId;
  String? rejectedCommentId;
  String? toggledPinnedCommentId;
  bool? toggledPinnedValue;
  String? deletedCommentId;
  List<String>? deletedCommentIds;
  String? replyParentId;
  String? replyContent;

  @override
  Future<void> approveComment(String commentId) async {
    approvedCommentId = commentId;
    _updateStatus(commentId, 'approved');
  }

  @override
  Future<void> rejectComment(String commentId) async {
    rejectedCommentId = commentId;
    _updateStatus(commentId, 'rejected');
  }

  @override
  Future<void> deleteComment(String commentId) async {
    deletedCommentId = commentId;
    _comments.removeWhere((comment) => comment.id == commentId);
  }

  @override
  Future<void> deleteComments(List<String> commentIds) async {
    deletedCommentIds = commentIds;
    _comments.removeWhere((comment) => commentIds.contains(comment.id));
  }

  @override
  Future<AdminCommentsPageResult> fetchComments({
    required String search,
    required String status,
    required String postId,
    required String userId,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final term = search.trim().toLowerCase();
    var rows = _comments
        .where((comment) {
          final matchesSearch =
              term.isEmpty ||
              comment.content.toLowerCase().contains(term) ||
              comment.postTitle.toLowerCase().contains(term) ||
              comment.userName.toLowerCase().contains(term);
          final matchesStatus =
              status == 'Tümü' ||
              (status == 'Reported' && comment.reportsCount > 0) ||
              comment.status == status;
          final matchesPost = postId == 'Tümü' || comment.postId == postId;
          final matchesUser = userId == 'Tümü' || comment.userId == userId;
          return matchesSearch && matchesStatus && matchesPost && matchesUser;
        })
        .toList(growable: false);
    rows.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final compare = switch (sortKey) {
        'id' => _numericId(a.id).compareTo(_numericId(b.id)),
        'comment' => a.content.compareTo(b.content),
        'post' => a.postTitle.compareTo(b.postTitle),
        'status' => a.status.compareTo(b.status),
        'likes' => a.likesCount.compareTo(b.likesCount),
        'replies' => a.repliesCount.compareTo(b.repliesCount),
        'date' =>
          (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
        _ => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
      };
      return sortAscending ? compare : -compare;
    });

    final total = rows.length;
    final from = (page - 1) * pageSize;
    rows = from >= rows.length
        ? const <AdminComment>[]
        : rows.skip(from).take(pageSize).toList(growable: false);
    return AdminCommentsPageResult(
      comments: [
        for (var index = 0; index < rows.length; index++)
          _copyComment(rows[index], rowNumber: from + index + 1),
      ],
      totalCount: total,
    );
  }

  @override
  Future<AdminCommentFilterOptions> fetchFilterOptions() async {
    return AdminCommentFilterOptions(
      posts: [
        for (final comment in _comments)
          AdminCommentFilterItem(id: comment.postId, label: comment.postTitle),
      ],
      users: [
        for (final comment in _comments)
          AdminCommentFilterItem(id: comment.userId, label: comment.userName),
      ],
    );
  }

  @override
  Future<AdminCommentMetricData> fetchMetrics() async {
    return AdminCommentMetricData(
      total: _comments.length,
      approved: _comments
          .where((comment) => comment.status == 'approved')
          .length,
      pending: _comments.where((comment) => comment.status == 'pending').length,
      rejected: _comments
          .where((comment) => comment.status == 'rejected')
          .length,
      totalChange: '+0%',
      approvedChange: '+0%',
      pendingChange: '+0%',
      rejectedChange: '+0%',
    );
  }

  @override
  Future<void> replyToComment({
    required AdminSession session,
    required AdminComment comment,
    required String content,
  }) async {
    replyParentId = comment.id;
    replyContent = content;
    _comments.add(
      AdminComment(
        id: 'reply-${_comments.length + 1}',
        rowNumber: _comments.length + 1,
        content: content,
        postId: comment.postId,
        userId: session.user.id,
        status: 'approved',
        createdAt: DateTime.utc(2026, 5, 22, 20),
        updatedAt: DateTime.utc(2026, 5, 22, 20),
        likesCount: 0,
        repliesCount: 0,
        reportsCount: 0,
        isPinned: false,
        postTitle: comment.postTitle,
        userName: 'Nasip Gündoğu',
        userAvatar: '',
        guestName: '',
        guestEmail: '',
      ),
    );
  }

  @override
  Future<void> togglePinned({
    required String commentId,
    required bool pinned,
  }) async {
    toggledPinnedCommentId = commentId;
    toggledPinnedValue = pinned;
    final index = _comments.indexWhere((comment) => comment.id == commentId);
    if (index == -1) return;
    _comments[index] = _copyComment(_comments[index], isPinned: pinned);
  }

  void _updateStatus(String commentId, String status) {
    final index = _comments.indexWhere((comment) => comment.id == commentId);
    if (index == -1) return;
    _comments[index] = _copyComment(_comments[index], status: status);
  }

  int _numericId(String value) => int.tryParse(value) ?? 0;

  AdminComment _copyComment(
    AdminComment comment, {
    int? rowNumber,
    String? status,
    bool? isPinned,
  }) {
    return AdminComment(
      id: comment.id,
      rowNumber: rowNumber ?? comment.rowNumber,
      content: comment.content,
      postId: comment.postId,
      userId: comment.userId,
      status: status ?? comment.status,
      createdAt: comment.createdAt,
      updatedAt: comment.updatedAt,
      likesCount: comment.likesCount,
      repliesCount: comment.repliesCount,
      reportsCount: comment.reportsCount,
      isPinned: isPinned ?? comment.isPinned,
      postTitle: comment.postTitle,
      userName: comment.userName,
      userAvatar: comment.userAvatar,
      guestName: comment.guestName,
      guestEmail: comment.guestEmail,
    );
  }
}

class _FakeAdminSubscribersRepository implements AdminSubscribersRepository {
  _FakeAdminSubscribersRepository();

  final _subscribers = <AdminSubscriber>[
    AdminSubscriber(
      id: 'sub-1',
      fullName: 'Nasip Gündoğu',
      email: 'nasip@pateeznews.com',
      phone: '+90 555 010 20 26',
      active: true,
      createdAt: DateTime.utc(2026, 5, 24, 13, 37),
    ),
    AdminSubscriber(
      id: 'sub-2',
      fullName: 'Pasif Abone',
      email: 'pasif@example.com',
      phone: '+90 530 700 18 40',
      active: false,
      createdAt: DateTime.utc(2026, 5, 18, 14, 30),
    ),
  ];

  SubscriberFormData? savedSubscriber;
  String? savedSubscriberId;
  String? deletedSubscriberId;
  List<String>? deletedSubscriberIds;
  String? toggledSubscriberId;

  @override
  Future<AdminSubscribersPageResult> fetchSubscribers({
    required String search,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final term = search.trim().toLowerCase();
    var rows = _subscribers
        .where((subscriber) {
          if (term.isEmpty) return true;
          return [
            subscriber.fullName,
            subscriber.email,
            subscriber.phone,
            subscriber.ipAddress,
            subscriber.city,
            subscriber.active ? 'aktif' : 'pasif',
          ].join(' ').toLowerCase().contains(term);
        })
        .toList(growable: false);
    rows.sort((a, b) {
      final compare = switch (sortKey) {
        'name' => a.fullName.compareTo(b.fullName),
        'email' => a.email.compareTo(b.email),
        'phone' => a.phone.compareTo(b.phone),
        'ip' => a.ipAddress.compareTo(b.ipAddress),
        'city' => a.city.compareTo(b.city),
        'status' => a.active.toString().compareTo(b.active.toString()),
        'date' => a.createdAt.compareTo(b.createdAt),
        _ => a.createdAt.compareTo(b.createdAt),
      };
      return sortAscending ? compare : -compare;
    });

    final total = rows.length;
    final from = (page - 1) * pageSize;
    rows = from >= rows.length
        ? const <AdminSubscriber>[]
        : rows.skip(from).take(pageSize).toList(growable: false);
    return AdminSubscribersPageResult(subscribers: rows, totalCount: total);
  }

  @override
  Future<AdminSubscriber> saveSubscriber({
    String? id,
    required SubscriberFormData data,
  }) async {
    savedSubscriber = data;
    savedSubscriberId = id;
    final existingIndex = _subscribers.indexWhere(
      (subscriber) => subscriber.id == id,
    );
    final subscriber = AdminSubscriber(
      id: id ?? 'sub-${_subscribers.length + 1}',
      fullName: data.fullName,
      email: data.email,
      phone: data.phone,
      active: data.active,
      createdAt: existingIndex == -1
          ? DateTime.utc(2026, 5, 26, 10)
          : _subscribers[existingIndex].createdAt,
    );
    if (existingIndex == -1) {
      _subscribers.insert(0, subscriber);
    } else {
      _subscribers[existingIndex] = subscriber;
    }
    return subscriber;
  }

  @override
  Future<void> toggleStatus(AdminSubscriber subscriber) async {
    toggledSubscriberId = subscriber.id;
    final index = _subscribers.indexWhere((row) => row.id == subscriber.id);
    if (index == -1) return;
    _subscribers[index] = subscriber.copyWith(active: !subscriber.active);
  }

  @override
  Future<void> deleteSubscriber(String subscriberId) async {
    deletedSubscriberId = subscriberId;
    _subscribers.removeWhere((subscriber) => subscriber.id == subscriberId);
  }

  @override
  Future<void> deleteSubscribers(List<String> subscriberIds) async {
    deletedSubscriberIds = subscriberIds;
    _subscribers.removeWhere(
      (subscriber) => subscriberIds.contains(subscriber.id),
    );
  }
}

class _FakeAdminNewsRepository implements AdminNewsRepository {
  _FakeAdminNewsRepository();

  final _posts = <AdminNewsPost>[
    AdminNewsPost(
      id: '23',
      rowNumber: 1,
      title:
          'Niğde Ruhun Yüzde Kaç? Patates, Gazoz ve Şöyle Bi Merkeze İneyim Enerjini Ölçüyoruz!',
      category: 'Anketler',
      type: 'poll',
      status: 'published',
      slug: 'nigde-ruhun-yuzde-kac',
      createdAt: DateTime.utc(2026, 5, 1, 14, 33),
      thumbnailUrl: '',
      viewsCount: 0,
      commentsCount: 0,
      languageCode: 'tr',
      isPinned: true,
      publisherId: '6c1a27d3-ce8e-4c42-bec1-fc092139e3ee',
      publisherName: 'Nasip Gündoğu',
      publisherUsername: 'nasip',
      publisherEmail: 'demo.user@gmail.com',
      parentCategory: 'Niğde',
      videos: [
        AdminNewsVideo(
          id: 'video-1',
          title: 'Festival videosu',
          url: '/api/storage/file/video/2026-05-25/festival.mp4',
          thumbnailUrl:
              '/api/storage/file/video/2026-05-25/festival_thumb.webp',
          platformLabel: 'Yerel Depo · MP4',
          sizeLabel: '-',
          publishedAt: DateTime.utc(2025, 6, 13),
          viewsCount: 3,
        ),
      ],
    ),
    AdminNewsPost(
      id: '27',
      rowNumber: 2,
      title: 'Niğde Belediyesi 3. Tiyatro Festivali Başlıyor',
      category: 'Yaşam',
      type: 'article',
      status: 'draft',
      slug: 'nigde-belediyesi-tiyatro-festivali',
      createdAt: DateTime.utc(2026, 5, 1, 15, 33),
      thumbnailUrl: '',
      viewsCount: 4,
      commentsCount: 2,
      languageCode: 'tr',
      isPinned: false,
      publisherId: '6c1a27d3-ce8e-4c42-bec1-fc092139e3ee',
      publisherName: 'Nasip Gündoğu',
      publisherUsername: 'nasip',
      publisherEmail: 'demo.user@gmail.com',
      parentCategory: 'Niğde',
    ),
  ];

  String? toggledStatusPostId;
  String? toggledPinnedPostId;
  String? deletedPostId;
  List<String>? deletedPostIds;

  @override
  Future<int> countPinnedPosts({String? excludingPostId}) async {
    return _posts
        .where((post) => post.isPinned && post.id != (excludingPostId ?? ''))
        .length;
  }

  @override
  Future<void> deletePost(String postId) async {
    deletedPostId = postId;
    _posts.removeWhere((post) => post.id == postId);
  }

  @override
  Future<void> deletePosts(List<String> postIds) async {
    deletedPostIds = postIds;
    _posts.removeWhere((post) => postIds.contains(post.id));
  }

  @override
  Future<AdminNewsFilterOptions> fetchFilterOptions() async {
    return const AdminNewsFilterOptions(
      languages: [AdminNewsFilterItem(id: 'tr', label: 'Türkçe')],
      categories: [
        AdminNewsFilterItem(
          id: 'Anketler',
          label: 'Anketler',
          parentLabel: 'Niğde',
        ),
        AdminNewsFilterItem(id: 'Yaşam', label: 'Yaşam', parentLabel: 'Niğde'),
      ],
      types: [
        AdminNewsFilterItem(id: 'poll', label: 'poll'),
        AdminNewsFilterItem(id: 'article', label: 'article'),
      ],
      publishers: [
        AdminNewsFilterItem(
          id: '6c1a27d3-ce8e-4c42-bec1-fc092139e3ee',
          label: 'Nasip Gündoğu',
        ),
      ],
    );
  }

  @override
  Future<AdminNewsEditorBootstrap> fetchEditorBootstrap() async {
    return const AdminNewsEditorBootstrap(
      languages: [AdminNewsEditorLanguage(code: 'tr', name: 'Türkçe')],
      categories: [
        AdminNewsEditorCategory(
          id: 'cat-1',
          label: 'Niğde',
          parentId: '',
          languageCode: 'tr',
          orderIndex: 1,
        ),
        AdminNewsEditorCategory(
          id: 'cat-2',
          label: 'Anket',
          parentId: 'cat-1',
          languageCode: 'tr',
          orderIndex: 2,
          type: 'category',
          icon: 'poll',
        ),
        AdminNewsEditorCategory(
          id: 'cat-3',
          label: 'Testler',
          parentId: 'cat-1',
          languageCode: 'tr',
          orderIndex: 3,
          type: 'category',
          icon: 'quiz',
        ),
        AdminNewsEditorCategory(
          id: 'cat-4',
          label: 'Siyaset',
          parentId: 'cat-1',
          languageCode: 'tr',
          orderIndex: 4,
          type: 'category',
          icon: 'account_balance',
        ),
        AdminNewsEditorCategory(
          id: 'cat-5',
          label: 'Yaşam',
          parentId: 'cat-1',
          languageCode: 'tr',
          orderIndex: 5,
          type: 'category',
          icon: 'spa',
        ),
        AdminNewsEditorCategory(
          id: 'cat-6',
          label: 'Altunhisar',
          parentId: 'cat-1',
          languageCode: 'tr',
          orderIndex: 6,
          type: 'district',
        ),
        AdminNewsEditorCategory(
          id: 'cat-7',
          label: 'Bor',
          parentId: 'cat-1',
          languageCode: 'tr',
          orderIndex: 7,
          type: 'district',
        ),
        AdminNewsEditorCategory(
          id: 'cat-8',
          label: 'Video',
          parentId: 'cat-1',
          languageCode: 'tr',
          orderIndex: 8,
          type: 'category',
          icon: 'video_library',
        ),
        AdminNewsEditorCategory(
          id: 'cat-9',
          label: 'Anket',
          parentId: 'cat-6',
          languageCode: 'tr',
          orderIndex: 1,
          type: 'category',
          icon: 'poll',
        ),
      ],
      publishers: [
        AdminNewsEditorPublisher(
          id: '6c1a27d3-ce8e-4c42-bec1-fc092139e3ee',
          name: 'Nasip Gündoğu',
        ),
      ],
    );
  }

  @override
  Future<AdminNewsEditorPost> fetchEditorPost(String postId) async {
    final post = _posts.firstWhere((item) => item.id == postId);
    return AdminNewsEditorPost(
      id: post.id,
      title: post.title,
      summary: 'Test summary',
      category: post.category,
      type: post.type,
      thumbnailUrl: post.thumbnailUrl,
      thumbnailAlt: '',
      seoTitle: post.title,
      seoDescription: 'Test summary',
      keywords: '',
      slug: post.slug,
      status: post.status,
      languageCode: post.languageCode,
      publisherId: post.publisherId,
      isPinned: post.isPinned,
      showInManset: false,
      factChecked: false,
      schemaType: 'NewsArticle',
      publishedAt: post.createdAt,
      cardData: const {},
      items: const [
        {
          'id': 'item-1',
          'type': 'text',
          'title': 'Text',
          'description': '<p>Body</p>',
          'source': '',
          'orderNumber': 1,
        },
      ],
      faqData: const [],
    );
  }

  @override
  Future<AdminNewsEditorPost> saveEditorPost({
    required String? postId,
    required AdminNewsEditorSavePayload payload,
  }) async {
    final id = postId ?? '99';
    return AdminNewsEditorPost.fromJson({...payload.values, 'id': id});
  }

  @override
  Future<AdminNewsMetricData> fetchMetrics() async {
    return AdminNewsMetricData(
      total: _posts.length,
      published: _posts.where((post) => post.published).length,
      views: _posts.fold<int>(0, (sum, post) => sum + post.viewsCount),
      scheduled: 0,
    );
  }

  @override
  Future<AdminNewsPageResult> fetchPosts({
    required String search,
    required String language,
    required String category,
    required String type,
    required String status,
    required String publisher,
    required bool trash,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final term = search.trim().toLowerCase();
    var rows = _posts
        .where((post) {
          final matchesSearch =
              term.isEmpty ||
              post.title.toLowerCase().contains(term) ||
              post.slug.toLowerCase().contains(term) ||
              post.category.toLowerCase().contains(term);
          final matchesLanguage =
              language == 'Tümü' || post.languageCode == language;
          final matchesCategory =
              category == 'Tümü' || post.category == category;
          final matchesType = type == 'Tümü' || post.type == type;
          final matchesStatus = status == 'Tümü' || post.status == status;
          final matchesPublisher =
              publisher == 'Tümü' || post.publisherId == publisher;
          return matchesSearch &&
              matchesLanguage &&
              matchesCategory &&
              matchesType &&
              matchesStatus &&
              matchesPublisher;
        })
        .toList(growable: false);
    rows.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final compare = switch (sortKey) {
        'id' => _numericId(a.id).compareTo(_numericId(b.id)),
        'post' => a.title.compareTo(b.title),
        'category' => a.category.compareTo(b.category),
        'status' => a.status.compareTo(b.status),
        'language' => a.languageCode.compareTo(b.languageCode),
        'author' => a.publisherName.compareTo(b.publisherName),
        'views' => a.viewsCount.compareTo(b.viewsCount),
        'comments' => a.commentsCount.compareTo(b.commentsCount),
        'date' =>
          (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
        _ => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
      };
      return sortAscending ? compare : -compare;
    });

    final total = rows.length;
    final from = (page - 1) * pageSize;
    rows = from >= rows.length
        ? const <AdminNewsPost>[]
        : rows.skip(from).take(pageSize).toList(growable: false);
    return AdminNewsPageResult(
      posts: [
        for (var index = 0; index < rows.length; index++)
          _copyPost(rows[index], rowNumber: from + index + 1),
      ],
      totalCount: total,
    );
  }

  @override
  Future<void> togglePinned(AdminNewsPost post) async {
    toggledPinnedPostId = post.id;
    final index = _posts.indexWhere((item) => item.id == post.id);
    if (index == -1) return;
    _posts[index] = _copyPost(post, isPinned: !post.isPinned);
  }

  @override
  Future<void> toggleStatus(AdminNewsPost post) async {
    toggledStatusPostId = post.id;
    final index = _posts.indexWhere((item) => item.id == post.id);
    if (index == -1) return;
    _posts[index] = _copyPost(
      post,
      status: post.published ? 'draft' : 'published',
    );
  }

  int _numericId(String value) => int.tryParse(value) ?? 0;

  AdminNewsPost _copyPost(
    AdminNewsPost post, {
    int? rowNumber,
    String? status,
    bool? isPinned,
  }) {
    return AdminNewsPost(
      id: post.id,
      rowNumber: rowNumber ?? post.rowNumber,
      title: post.title,
      category: post.category,
      type: post.type,
      status: status ?? post.status,
      slug: post.slug,
      createdAt: post.createdAt,
      thumbnailUrl: post.thumbnailUrl,
      viewsCount: post.viewsCount,
      commentsCount: post.commentsCount,
      languageCode: post.languageCode,
      isPinned: isPinned ?? post.isPinned,
      publisherId: post.publisherId,
      publisherName: post.publisherName,
      publisherUsername: post.publisherUsername,
      publisherEmail: post.publisherEmail,
      parentCategory: post.parentCategory,
      videos: post.videos,
    );
  }
}

class _FakeAdminStoriesRepository implements AdminStoriesRepository {
  _FakeAdminStoriesRepository();

  final _stories = <AdminStory>[
    AdminStory(
      id: 'story-1',
      rowNumber: 1,
      title: 'Niğde sabah hikayesi',
      mediaUrl: '',
      mediaType: 'image',
      sourceName: 'Pateeznews',
      publisherId: '6c1a27d3-ce8e-4c42-bec1-fc092139e3ee',
      createdAt: DateTime.utc(2026, 5, 24, 10),
      expiresAt: DateTime.utc(2026, 5, 25, 10),
      isActive: true,
      viewCount: 120,
    ),
    AdminStory(
      id: 'story-2',
      rowNumber: 2,
      title: 'Festival video hikayesi',
      mediaUrl: '',
      mediaType: 'video',
      sourceName: 'Pateez Video',
      publisherId: '6c1a27d3-ce8e-4c42-bec1-fc092139e3ee',
      createdAt: DateTime.utc(2026, 5, 23, 11, 30),
      expiresAt: null,
      isActive: false,
      viewCount: 45,
    ),
  ];

  String? toggledStatusStoryId;
  String? deletedStoryId;
  List<String>? deletedStoryIds;
  StoryFormData? upsertedStory;
  String? upsertedStoryId;

  @override
  Future<void> deleteStory(String storyId) async {
    deletedStoryId = storyId;
    _stories.removeWhere((story) => story.id == storyId);
  }

  @override
  Future<void> deleteStories(List<String> storyIds) async {
    deletedStoryIds = storyIds;
    _stories.removeWhere((story) => storyIds.contains(story.id));
  }

  @override
  Future<AdminStoriesPageResult> fetchStories({
    required String search,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final term = search.trim().toLowerCase();
    var rows = _stories
        .where((story) {
          final matchesSearch =
              term.isEmpty ||
              story.title.toLowerCase().contains(term) ||
              story.sourceName.toLowerCase().contains(term) ||
              story.mediaType.toLowerCase().contains(term);
          return matchesSearch;
        })
        .toList(growable: false);
    rows.sort((a, b) {
      final compare = switch (sortKey) {
        'id' => a.id.compareTo(b.id),
        'story' => a.title.compareTo(b.title),
        'views' => a.viewCount.compareTo(b.viewCount),
        'expires' =>
          (a.expiresAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            b.expiresAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
        'status' => a.isActive.toString().compareTo(b.isActive.toString()),
        'date' =>
          (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
        _ => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
      };
      return sortAscending ? compare : -compare;
    });

    final total = rows.length;
    final from = (page - 1) * pageSize;
    rows = from >= rows.length
        ? const <AdminStory>[]
        : rows.skip(from).take(pageSize).toList(growable: false);
    return AdminStoriesPageResult(
      stories: [
        for (var index = 0; index < rows.length; index++)
          _copyStory(rows[index], rowNumber: from + index + 1),
      ],
      totalCount: total,
    );
  }

  @override
  Future<void> toggleStatus(AdminStory story) async {
    toggledStatusStoryId = story.id;
    final index = _stories.indexWhere((item) => item.id == story.id);
    if (index == -1) return;
    _stories[index] = _copyStory(story, isActive: !story.isActive);
  }

  @override
  Future<void> upsertStory({
    required AdminSession session,
    required StoryFormData data,
    String? storyId,
  }) async {
    upsertedStory = data;
    upsertedStoryId = storyId;
  }

  AdminStory _copyStory(AdminStory story, {int? rowNumber, bool? isActive}) {
    return AdminStory(
      id: story.id,
      rowNumber: rowNumber ?? story.rowNumber,
      title: story.title,
      mediaUrl: story.mediaUrl,
      mediaType: story.mediaType,
      sourceName: story.sourceName,
      publisherId: story.publisherId,
      createdAt: story.createdAt,
      expiresAt: story.expiresAt,
      isActive: isActive ?? story.isActive,
      viewCount: story.viewCount,
    );
  }
}

class _FakeAdminPagesRepository implements AdminPagesRepository {
  _FakeAdminPagesRepository();

  final _pages = <AdminPage>[
    AdminPage(
      id: 'page-1',
      rowNumber: 1,
      title: 'Hakkımızda',
      slug: 'hakkimizda',
      category: 'Kurumsal',
      categoryId: 'cat-corporate',
      parentCategory: 'Niğde',
      type: 'custom',
      status: 'active',
      languageCode: 'tr',
      location: 'top_menu',
      parentPageId: '',
      showTitle: true,
      showBreadcrumb: true,
      showSidebar: true,
      registeredOnly: false,
      menuOrder: 1,
      contentDeltaJson: '[{"insert":"Pateez kurumsal sayfası\\n"}]',
      contentPlainText: 'Pateez kurumsal sayfası',
      metaTitle: 'Hakkımızda',
      metaKeywords: 'pateez, kurumsal',
      metaDescription: 'Pateez hakkında',
      canonicalUrl: 'https://www.pateez.com/hakkimizda',
      createdAt: DateTime.utc(2026, 4, 16, 14),
    ),
    AdminPage(
      id: 'page-2',
      rowNumber: 2,
      title: 'Gizlilik Politikası',
      slug: 'gizlilik-politikasi',
      category: 'Yasal',
      categoryId: 'cat-legal',
      parentCategory: 'Footer',
      type: 'legal',
      status: 'passive',
      languageCode: 'tr',
      location: 'footer',
      parentPageId: '',
      showTitle: true,
      showBreadcrumb: true,
      showSidebar: false,
      registeredOnly: false,
      menuOrder: 2,
      contentDeltaJson: '[{"insert":"Gizlilik metni\\n"}]',
      contentPlainText: 'Gizlilik metni',
      metaTitle: '',
      metaKeywords: '',
      metaDescription: '',
      canonicalUrl: '',
      createdAt: DateTime.utc(2026, 4, 16, 13, 57),
    ),
  ];

  AdminPageFormData? savedPage;
  String? savedPageId;
  String? toggledStatusPageId;
  String? deletedPageId;

  @override
  Future<void> deletePage(String pageId) async {
    deletedPageId = pageId;
    _pages.removeWhere((page) => page.id == pageId);
  }

  @override
  Future<AdminPagesFilterOptions> fetchFilterOptions() async {
    return const AdminPagesFilterOptions(
      languages: [
        AdminPageLanguage(code: 'tr', name: 'Türkçe'),
        AdminPageLanguage(code: 'en', name: 'English'),
      ],
      categories: [
        AdminPageCategory(
          id: 'cat-nigde',
          label: 'Niğde',
          languageCode: 'tr',
          type: 'dropdown',
          menuLabel: 'Sol Sidebar',
        ),
        AdminPageCategory(
          id: 'cat-corporate',
          label: 'Kurumsal',
          languageCode: 'tr',
          type: 'category',
          parentId: 'cat-nigde',
          parentLabel: 'Niğde',
          menuLabel: 'Sol Sidebar',
        ),
        AdminPageCategory(
          id: 'cat-altunhisar',
          label: 'Altunhisar',
          languageCode: 'tr',
          type: 'district',
          parentId: 'cat-nigde',
          parentLabel: 'Niğde',
          menuLabel: 'Sol Sidebar',
        ),
        AdminPageCategory(
          id: 'cat-poll',
          label: 'Anket',
          languageCode: 'tr',
          type: 'category',
          parentId: 'cat-altunhisar',
          parentLabel: 'Niğde > Altunhisar',
          menuLabel: 'Sol Sidebar',
        ),
        AdminPageCategory(
          id: 'cat-legal',
          label: 'Yasal',
          languageCode: 'tr',
          type: 'category',
          parentLabel: 'Footer',
          menuLabel: 'Alt Menü',
        ),
      ],
      types: ['custom', 'legal'],
      parents: [
        AdminPageParentOption(
          id: 'page-1',
          title: 'Hakkımızda',
          languageCode: 'tr',
        ),
      ],
    );
  }

  @override
  Future<AdminPagesPageResult> fetchPages({
    required String search,
    required String category,
    required String type,
    required String status,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final term = search.trim().toLowerCase();
    var rows = _pages.where((item) {
      final matchesSearch =
          term.isEmpty ||
          item.title.toLowerCase().contains(term) ||
          item.slug.toLowerCase().contains(term) ||
          item.category.toLowerCase().contains(term);
      final matchesCategory = category == 'Tümü' || item.categoryId == category;
      final matchesType = type == 'Tümü' || item.type == type;
      final matchesStatus = status == 'Tümü' || item.status == status;
      return matchesSearch && matchesCategory && matchesType && matchesStatus;
    }).toList();

    rows.sort((a, b) {
      final compare = switch (sortKey) {
        'title' => a.title.compareTo(b.title),
        'category' => a.category.compareTo(b.category),
        'type' => a.type.compareTo(b.type),
        'status' => a.status.compareTo(b.status),
        'createdAt' =>
          (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
        _ => 0,
      };
      return sortAscending ? compare : -compare;
    });

    final total = rows.length;
    final from = (page - 1) * pageSize;
    rows = from >= rows.length
        ? const <AdminPage>[]
        : rows.skip(from).take(pageSize).toList(growable: false);
    return AdminPagesPageResult(
      pages: [
        for (var index = 0; index < rows.length; index++)
          _copyPage(rows[index], rowNumber: from + index + 1),
      ],
      totalCount: total,
    );
  }

  @override
  Future<AdminPage> savePage({
    String? id,
    required AdminPageFormData data,
  }) async {
    savedPageId = id;
    savedPage = data;
    final page = AdminPage(
      id: id ?? 'page-created',
      rowNumber: 1,
      title: data.title,
      slug: data.slug.isEmpty ? 'otomatik-sayfa' : data.slug,
      category: data.category,
      categoryId: data.categoryId,
      parentCategory: data.categoryId == 'cat-corporate' ? 'Niğde' : null,
      type: data.type,
      status: data.status,
      languageCode: data.languageCode,
      location: data.location,
      parentPageId: data.parentPageId,
      showTitle: data.showTitle,
      showBreadcrumb: data.showBreadcrumb,
      showSidebar: data.showSidebar,
      registeredOnly: data.registeredOnly,
      menuOrder: data.menuOrder,
      contentDeltaJson: data.contentDeltaJson,
      contentPlainText: data.contentPlainText,
      metaTitle: data.metaTitle,
      metaKeywords: data.metaKeywords,
      metaDescription: data.metaDescription,
      canonicalUrl: data.canonicalUrl,
      createdAt: DateTime.utc(2026, 5, 24, 14),
    );
    if (id == null) {
      _pages.add(page);
    }
    return page;
  }

  @override
  Future<void> toggleStatus(AdminPage page) async {
    toggledStatusPageId = page.id;
    final index = _pages.indexWhere((item) => item.id == page.id);
    if (index == -1) return;
    _pages[index] = _copyPage(page, status: page.active ? 'passive' : 'active');
  }

  AdminPage _copyPage(AdminPage page, {int? rowNumber, String? status}) {
    return AdminPage(
      id: page.id,
      rowNumber: rowNumber ?? page.rowNumber,
      title: page.title,
      slug: page.slug,
      category: page.category,
      categoryId: page.categoryId,
      parentCategory: page.parentCategory,
      type: page.type,
      status: status ?? page.status,
      languageCode: page.languageCode,
      location: page.location,
      parentPageId: page.parentPageId,
      showTitle: page.showTitle,
      showBreadcrumb: page.showBreadcrumb,
      showSidebar: page.showSidebar,
      registeredOnly: page.registeredOnly,
      menuOrder: page.menuOrder,
      contentDeltaJson: page.contentDeltaJson,
      contentPlainText: page.contentPlainText,
      metaTitle: page.metaTitle,
      metaKeywords: page.metaKeywords,
      metaDescription: page.metaDescription,
      canonicalUrl: page.canonicalUrl,
      createdAt: page.createdAt,
    );
  }
}

class _FakeAdminNavigationRepository implements AdminNavigationRepository {
  _FakeAdminNavigationRepository();

  final _menus = <AdminNavigationMenu>[
    const AdminNavigationMenu(
      id: 'menu-sidebar',
      code: 'sidebar_main',
      name: 'Ana Sidebar',
      description: 'Sol taraftaki ana navigasyon menüsü.',
    ),
    const AdminNavigationMenu(
      id: 'menu-top-navbar',
      code: 'top_navbar',
      name: 'Üst Navbar',
      description: 'Önyüz üst navigasyon menüsü.',
    ),
  ];

  final _items = <AdminNavigationItem>[
    const AdminNavigationItem(
      id: 'item-nigde',
      menuId: 'menu-sidebar',
      parentId: null,
      label: 'Niğde',
      type: 'dropdown',
      value: 'nigde',
      icon: 'location_on',
      orderIndex: 0,
      isActive: true,
      languageCode: 'tr',
    ),
    const AdminNavigationItem(
      id: 'item-trends',
      menuId: 'menu-sidebar',
      parentId: 'item-nigde',
      label: 'Haftanın Trendleri',
      type: 'trends',
      value: 'weekly_trends',
      icon: 'trending_up',
      orderIndex: 1,
      isActive: true,
      languageCode: 'tr',
    ),
    const AdminNavigationItem(
      id: 'item-polls',
      menuId: 'menu-sidebar',
      parentId: 'item-nigde',
      label: 'Anketler',
      type: 'category',
      value: 'anketler',
      icon: 'poll',
      orderIndex: 2,
      isActive: true,
      languageCode: 'tr',
    ),
    const AdminNavigationItem(
      id: 'item-home',
      menuId: 'menu-top-navbar',
      parentId: null,
      label: 'Ana Sayfa',
      type: 'link',
      value: '/',
      icon: 'home',
      orderIndex: 0,
      isActive: true,
      languageCode: 'tr',
    ),
    const AdminNavigationItem(
      id: 'item-poll-top',
      menuId: 'menu-top-navbar',
      parentId: null,
      label: 'Anket',
      type: 'category',
      value: 'anketler',
      icon: 'poll',
      orderIndex: 1,
      isActive: true,
      languageCode: 'tr',
    ),
  ];

  NavigationItemFormData? createdItem;
  String? createdMenuId;
  String? updatedItemId;
  List<String>? deletedItemIds;
  List<String>? reorderedItemIds;

  @override
  Future<AdminNavigationMenu> createDefaultMenu() async {
    return _menus.first;
  }

  @override
  Future<AdminNavigationMenu> ensureDefaultMenu(String code) async {
    return _menus.firstWhere((menu) => menu.code == code);
  }

  @override
  Future<void> createItem({
    required String menuId,
    required NavigationItemFormData data,
    required int orderIndex,
  }) async {
    createdItem = data;
    createdMenuId = menuId;
    _items.add(
      AdminNavigationItem(
        id: 'created-navigation-item',
        menuId: menuId,
        parentId: data.parentId,
        label: data.label,
        type: data.type,
        value: data.value,
        icon: data.icon,
        orderIndex: orderIndex,
        isActive: true,
        languageCode: data.languageCode,
      ),
    );
  }

  @override
  Future<void> deleteItems(List<String> itemIds) async {
    deletedItemIds = itemIds;
    _items.removeWhere((item) => itemIds.contains(item.id));
  }

  @override
  Future<AdminNavigationInitialData> fetchInitialData() async {
    return AdminNavigationInitialData(
      menus: _menus,
      languages: const [
        AdminNavigationLanguage(code: 'tr', name: 'Türkçe'),
        AdminNavigationLanguage(code: 'en', name: 'English'),
      ],
    );
  }

  @override
  Future<List<AdminNavigationItem>> fetchItems(String menuId) async {
    return (_items.where((item) => item.menuId == menuId).toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)))
        .toList(growable: false);
  }

  @override
  Future<void> reorderItems(List<AdminNavigationItem> items) async {
    reorderedItemIds = [for (final item in items) item.id];
    for (final item in items) {
      final index = _items.indexWhere((row) => row.id == item.id);
      if (index == -1) continue;
      _items[index] = _items[index].copyWith(orderIndex: item.orderIndex);
    }
  }

  @override
  Future<void> updateItem({
    required String itemId,
    required String menuId,
    required int orderIndex,
    required NavigationItemFormData data,
  }) async {
    updatedItemId = itemId;
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;
    _items[index] = AdminNavigationItem(
      id: itemId,
      menuId: menuId,
      parentId: data.parentId,
      label: data.label,
      type: data.type,
      value: data.value,
      icon: data.icon,
      orderIndex: orderIndex,
      isActive: true,
      languageCode: data.languageCode,
    );
  }
}

class _FakeAdminLanguagesRepository implements AdminLanguagesRepository {
  _FakeAdminLanguagesRepository();

  final _languages = <AdminLanguage>[...fallbackAdminLanguages];
  final _translations = <String, Map<String, String>>{
    'tr': defaultTranslationsFor('tr'),
    'en': defaultTranslationsFor('en'),
    'ar': defaultTranslationsFor('ar'),
  };

  LanguageFormData? upsertedLanguage;
  String? deletedLanguageCode;
  String? defaultLanguageCode;
  String? savedTranslationsCode;
  Map<String, String>? savedTranslations;
  String? importedLanguageCode;
  String? exportedLanguageCode;

  @override
  Future<List<AdminLanguage>> fetchActiveLanguages() async {
    return _renumber(
      _languages.where((language) => language.active).toList(growable: false),
      0,
    );
  }

  @override
  Future<LanguagesPageResult> fetchLanguages({
    required String search,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final term = search.trim().toLowerCase();
    final filtered =
        (term.isEmpty
                ? _languages
                : _languages
                      .where(
                        (language) =>
                            language.code.contains(term) ||
                            language.name.toLowerCase().contains(term),
                      )
                      .toList(growable: false))
            .toList()
          ..sort((a, b) => _compareLanguages(a, b, sortKey, sortAscending));
    final from = (page - 1) * pageSize;
    final rows = from >= filtered.length
        ? const <AdminLanguage>[]
        : filtered.skip(from).take(pageSize).toList(growable: false);
    return LanguagesPageResult(
      languages: _renumber(rows, from),
      totalCount: filtered.length,
    );
  }

  int _compareLanguages(
    AdminLanguage a,
    AdminLanguage b,
    String sortKey,
    bool ascending,
  ) {
    final result = switch (sortKey) {
      'order' => a.rowNumber.compareTo(b.rowNumber),
      'name' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      'default' =>
        a.isDefault == b.isDefault
            ? 0
            : a.isDefault
            ? -1
            : 1,
      'status' => a.status.compareTo(b.status),
      _ => a.rowNumber.compareTo(b.rowNumber),
    };
    final normalized = result == 0
        ? a.rowNumber.compareTo(b.rowNumber)
        : result;
    return ascending ? normalized : -normalized;
  }

  @override
  Future<void> upsertLanguage({
    required AdminSession session,
    required LanguageFormData data,
  }) async {
    upsertedLanguage = data;
    final index = _languages.indexWhere(
      (language) => language.code == data.code,
    );
    final status = coreAdminLanguageCodes.contains(data.code)
        ? 'active'
        : data.status;
    if (index == -1) {
      _languages.add(
        AdminLanguage(
          code: data.code,
          name: data.name,
          direction: data.direction,
          status: status,
          flagCode: data.flagCode,
          isDefault: false,
          rowNumber: _languages.length + 1,
        ),
      );
      _translations[data.code] = defaultTranslationsFor(data.code);
      return;
    }
    final current = _languages[index];
    _languages[index] = current.copyWith(
      name: data.name,
      direction: data.direction,
      status: status,
      flagCode: data.flagCode,
    );
  }

  @override
  Future<void> deleteLanguage({
    required AdminSession session,
    required String code,
  }) async {
    if (coreAdminLanguageCodes.contains(code)) {
      throw const AdminLanguagesException('Çekirdek dil silinemez');
    }
    deletedLanguageCode = code;
    _languages.removeWhere((language) => language.code == code);
    _translations.remove(code);
  }

  @override
  Future<void> setDefaultLanguage({
    required AdminSession session,
    required String code,
  }) async {
    defaultLanguageCode = code;
    for (var index = 0; index < _languages.length; index++) {
      final language = _languages[index];
      _languages[index] = language.copyWith(isDefault: language.code == code);
    }
  }

  @override
  Future<Map<String, String>> fetchTranslations(String code) async {
    return normalizeAdminTranslationMapKeys({
      ...defaultTranslationsFor(code),
      ...?_translations[code],
    });
  }

  @override
  Future<void> saveTranslations({
    required AdminSession session,
    required String code,
    required Map<String, String> translations,
  }) async {
    savedTranslationsCode = code;
    savedTranslations = translations;
    _translations[code] = normalizeAdminTranslationMapKeys(translations);
  }

  @override
  Future<String> exportLanguagePack(AdminLanguage language) async {
    exportedLanguageCode = language.code;
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'meta': language.toJson(),
      'translations': await fetchTranslations(language.code),
    });
  }

  @override
  Future<void> importLanguagePack({
    required AdminSession session,
    required String jsonContent,
  }) async {
    final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
    final meta = decoded['meta'] as Map<String, dynamic>;
    final code = meta['code'].toString();
    importedLanguageCode = code;
    await upsertLanguage(
      session: session,
      data: LanguageFormData(
        code: code,
        name: meta['name'].toString(),
        direction: meta['direction']?.toString() == 'rtl' ? 'rtl' : 'ltr',
        status: meta['status']?.toString() == 'passive' ? 'passive' : 'active',
        flagCode: meta['flag_code']?.toString() ?? code,
      ),
    );
    final translations = decoded['translations'];
    if (translations is Map) {
      _translations[code] = translations.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    }
  }

  List<AdminLanguage> _renumber(List<AdminLanguage> rows, int offset) {
    return [
      for (var index = 0; index < rows.length; index++)
        rows[index].copyWith(rowNumber: offset + index + 1),
    ];
  }
}

class _FakeAdminGeneralSettingsRepository
    implements AdminGeneralSettingsRepository {
  _FakeAdminGeneralSettingsRepository();

  final _settingsByLanguage = <String, GeneralSettingsData>{
    'tr': GeneralSettingsData.empty('tr').copyWith(
      siteName: 'Pateeznews.com',
      timezone: 'Europe/Istanbul',
      footerAbout: 'Pateeznews footer metni',
      optionalUrlButtonName: '',
      copyrightText: '2026 Pateez',
      logoUrl: '',
      footerLogoUrl: '',
      darkLogoUrl: '',
      emailLogoUrl: '',
      faviconUrl: '',
      homeTitle: 'Pateez: İç Anadolu Haber',
      metaDescription: 'Pateez meta açıklaması',
      metaKeywords: 'pateez, haber',
      canonicalUrl: 'https://www.pateez.com/',
      ogImageUrl: '',
      twitterUsername: '@pateezcom',
      robotsTxt: 'User-agent: *\nDisallow: /admin/\nAllow: /',
    ),
  };

  GeneralSettingsData? savedSettings;
  GeneralSettingsLogoField? uploadedLogoField;

  @override
  Future<GeneralSettingsData> fetchSettings(String languageCode) async {
    return _settingsByLanguage[languageCode] ??
        GeneralSettingsData.empty(languageCode);
  }

  @override
  Future<GeneralSettingsData> saveSettings({
    required AdminSession session,
    required GeneralSettingsData settings,
  }) async {
    savedSettings = settings;
    _settingsByLanguage[settings.languageCode] = settings;
    return settings;
  }

  @override
  Future<String> uploadLogo({
    required String languageCode,
    required GeneralSettingsLogoField field,
    required String fileName,
    required List<int> bytes,
  }) async {
    uploadedLogoField = field;
    return '/api/storage/file/logo/$languageCode/${field.uploadFilename}';
  }

  @override
  String publicUrl(String value) {
    if (value.startsWith('http')) return value;
    return 'http://localhost:4321$value';
  }
}

class _FakeAdminFontSettingsRepository implements AdminFontSettingsRepository {
  _FakeAdminFontSettingsRepository();

  final _settingsByLanguage = <String, AdminFontSettingsData>{
    'tr': AdminFontSettingsData.empty('tr'),
  };

  AdminFontSettingsData? savedSettings;
  AdminFontFormData? addedFont;
  AdminFontFormData? updatedFont;

  @override
  Future<AdminFontSettingsBundle> fetchSettings(String languageCode) async {
    return AdminFontSettingsBundle(
      settings:
          _settingsByLanguage[languageCode] ??
          AdminFontSettingsData.empty(languageCode),
      fonts: fallbackSiteFonts,
    );
  }

  @override
  Future<AdminFontSettingsData> saveSettings({
    required AdminSession session,
    required AdminFontSettingsData settings,
  }) async {
    savedSettings = settings;
    _settingsByLanguage[settings.languageCode] = settings;
    return settings;
  }

  @override
  Future<AdminFontRow> addFont({
    required AdminSession session,
    required AdminFontFormData data,
  }) async {
    addedFont = data;
    return AdminFontRow(
      id: 100,
      name: data.name,
      family: data.name.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''),
      type: data.type,
      source: 'local',
      webFontPath: '/api/storage/file/font/site/test.woff2',
      flutterFamily: data.name.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''),
      fallbackStack: "'${data.name}', Arial, sans-serif",
      fontFiles: const {'400': '/api/storage/file/font/site/test.woff2'},
      active: true,
      sortOrder: 100,
    );
  }

  @override
  Future<AdminFontRow> updateFont({
    required AdminSession session,
    required AdminFontRow font,
    required AdminFontFormData data,
  }) async {
    updatedFont = data;
    return AdminFontRow(
      id: font.id,
      name: data.name,
      family: font.family,
      type: data.type,
      source: font.source,
      webFontPath: font.webFontPath,
      flutterFamily: font.flutterFamily,
      fallbackStack: font.fallbackStack,
      fontFiles: font.fontFiles,
      active: font.active,
      sortOrder: font.sortOrder,
    );
  }
}

class _FakeAdminContentSettingsRepository
    implements AdminContentSettingsRepository {
  _FakeAdminContentSettingsRepository();

  final _settingsByLanguage = <String, ContentGeneralSettingsData>{
    'tr': ContentGeneralSettingsData.defaults('tr'),
  };
  final _postSettingsByLanguage = <String, ContentPostSettingsData>{
    'tr': ContentPostSettingsData.defaults('tr'),
  };
  final _formatSettingsByLanguage = <String, ContentPostFormatSettingsData>{
    'tr': ContentPostFormatSettingsData.defaults('tr'),
  };
  final _uploadSettingsByLanguage = <String, ContentUploadSettingsData>{
    'tr': ContentUploadSettingsData.defaults('tr'),
  };
  final _featuredSettingsByLanguage = <String, ContentFeaturedSettingsData>{
    'tr': ContentFeaturedSettingsData.defaults('tr'),
  };
  final _trashCleanupSettingsByLanguage =
      <String, ContentTrashCleanupSettingsData>{
        'tr': ContentTrashCleanupSettingsData.defaults('tr'),
      };

  ContentGeneralSettingsData? savedSettings;
  ContentPostSettingsData? savedPostSettings;
  ContentPostFormatSettingsData? savedFormatSettings;
  ContentUploadSettingsData? savedUploadSettings;
  ContentFeaturedSettingsData? savedFeaturedSettings;
  ContentTrashCleanupSettingsData? savedTrashCleanupSettings;

  @override
  Future<ContentSettingsSnapshot> fetchAllSettings(String languageCode) async {
    return ContentSettingsSnapshot(
      languageCode: languageCode,
      general: await fetchGeneralSettings(languageCode),
      posts: await fetchPostSettings(languageCode),
      postFormats: await fetchPostFormatSettings(languageCode),
      upload: await fetchUploadSettings(languageCode),
      featured: await fetchFeaturedSettings(languageCode),
      trashCleanup: await fetchTrashCleanupSettings(languageCode),
    );
  }

  @override
  Future<ContentGeneralSettingsData> fetchGeneralSettings(
    String languageCode,
  ) async {
    return _settingsByLanguage[languageCode] ??
        ContentGeneralSettingsData.defaults(languageCode);
  }

  @override
  Future<ContentGeneralSettingsData> saveGeneralSettings({
    required AdminSession session,
    required ContentGeneralSettingsData settings,
  }) async {
    savedSettings = settings;
    _settingsByLanguage[settings.languageCode] = settings;
    return settings;
  }

  @override
  Future<ContentPostSettingsData> fetchPostSettings(String languageCode) async {
    return _postSettingsByLanguage[languageCode] ??
        ContentPostSettingsData.defaults(languageCode);
  }

  @override
  Future<ContentPostSettingsData> savePostSettings({
    required AdminSession session,
    required ContentPostSettingsData settings,
  }) async {
    savedPostSettings = settings;
    _postSettingsByLanguage[settings.languageCode] = settings;
    return settings;
  }

  @override
  Future<ContentPostFormatSettingsData> fetchPostFormatSettings(
    String languageCode,
  ) async {
    return _formatSettingsByLanguage[languageCode] ??
        ContentPostFormatSettingsData.defaults(languageCode);
  }

  @override
  Future<ContentPostFormatSettingsData> savePostFormatSettings({
    required AdminSession session,
    required ContentPostFormatSettingsData settings,
  }) async {
    savedFormatSettings = settings;
    _formatSettingsByLanguage[settings.languageCode] = settings;
    return settings;
  }

  @override
  Future<ContentUploadSettingsData> fetchUploadSettings(
    String languageCode,
  ) async {
    return _uploadSettingsByLanguage[languageCode] ??
        ContentUploadSettingsData.defaults(languageCode);
  }

  @override
  Future<ContentUploadSettingsData> saveUploadSettings({
    required AdminSession session,
    required ContentUploadSettingsData settings,
  }) async {
    savedUploadSettings = settings;
    _uploadSettingsByLanguage[settings.languageCode] = settings;
    return settings;
  }

  @override
  Future<ContentFeaturedSettingsData> fetchFeaturedSettings(
    String languageCode,
  ) async {
    return _featuredSettingsByLanguage[languageCode] ??
        ContentFeaturedSettingsData.defaults(languageCode);
  }

  @override
  Future<ContentFeaturedSettingsData> saveFeaturedSettings({
    required AdminSession session,
    required ContentFeaturedSettingsData settings,
  }) async {
    savedFeaturedSettings = settings;
    _featuredSettingsByLanguage[settings.languageCode] = settings;
    return settings;
  }

  @override
  Future<ContentTrashCleanupSettingsData> fetchTrashCleanupSettings(
    String languageCode,
  ) async {
    return _trashCleanupSettingsByLanguage[languageCode] ??
        ContentTrashCleanupSettingsData.defaults(languageCode);
  }

  @override
  Future<ContentTrashCleanupSettingsData> saveTrashCleanupSettings({
    required AdminSession session,
    required ContentTrashCleanupSettingsData settings,
  }) async {
    savedTrashCleanupSettings = settings;
    _trashCleanupSettingsByLanguage[settings.languageCode] = settings;
    return settings;
  }
}

class _FakeAdminAiSettingsRepository implements AdminAiSettingsRepository {
  _FakeAdminAiSettingsRepository();

  final _settingsByLanguage = <String, AdminAiSettingsData>{
    'tr': const AdminAiSettingsData(
      languageCode: 'tr',
      googleAiApiKey: 'test-gemini-key',
      googleAiModel: 'gemini-3-pro-preview',
      googleAiActive: true,
    ),
  };
  final _promptsByLanguage = <String, List<AdminAiPrompt>>{
    'tr': [
      AdminAiPrompt(
        id: 'format-1',
        title: 'Haber Hazırla 1',
        prompt: 'Canlı veritabanından gelen haber hazırlama promptu.',
        languageCode: 'tr',
        isActive: true,
      ),
    ],
  };

  AdminAiSettingsData? savedSettings;
  AiPromptFormData? savedPrompt;
  String? savedPromptId;
  String? deletedPromptId;
  String? testedApiKey;

  @override
  Future<AdminAiSettingsData> fetchSettings(String languageCode) async {
    return _settingsByLanguage[languageCode] ??
        AdminAiSettingsData.empty(languageCode);
  }

  @override
  Future<AdminAiSettingsData> saveSettings({
    required AdminSession session,
    required AdminAiSettingsData settings,
  }) async {
    savedSettings = settings;
    _settingsByLanguage[settings.languageCode] = settings;
    return settings;
  }

  @override
  Future<List<AdminAiPrompt>> fetchPrompts(String languageCode) async {
    return [...?_promptsByLanguage[languageCode]];
  }

  @override
  Future<AdminAiPrompt> savePrompt({
    required AdminSession session,
    required String languageCode,
    required AiPromptFormData data,
    String? id,
  }) async {
    savedPrompt = data;
    savedPromptId = id;
    final prompts = _promptsByLanguage.putIfAbsent(languageCode, () => []);
    final prompt = AdminAiPrompt(
      id: id?.trim().isNotEmpty == true ? id! : 'format-created',
      title: data.title,
      prompt: data.prompt,
      languageCode: languageCode,
      isActive: true,
    );
    final index = prompts.indexWhere((item) => item.id == prompt.id);
    if (index == -1) {
      prompts.insert(0, prompt);
    } else {
      prompts[index] = prompt;
    }
    return prompt;
  }

  @override
  Future<void> deletePrompt({
    required AdminSession session,
    required String id,
  }) async {
    deletedPromptId = id;
    for (final prompts in _promptsByLanguage.values) {
      prompts.removeWhere((prompt) => prompt.id == id);
    }
  }

  @override
  Future<List<String>> fetchGeminiModels(String apiKey) async {
    testedApiKey = apiKey;
    return const ['gemini-2.5-flash', 'gemini-3-pro-preview'];
  }
}

class _FakeAdminSecuritySettingsRepository
    implements AdminSecuritySettingsRepository {
  var settings = AdminSecuritySettingsData.defaults('tr');
  AdminSecuritySettingsData? savedSettings;
  bool? includeSecretKey;

  @override
  Future<AdminSecuritySettingsData> fetchSettings(String languageCode) async {
    return settings.copyWith(languageCode: languageCode);
  }

  @override
  Future<AdminSecuritySettingsData> saveSettings({
    required AdminSession session,
    required AdminSecuritySettingsData settings,
    required bool includeSecretKey,
  }) async {
    this.includeSecretKey = includeSecretKey;
    savedSettings = settings;
    this.settings = settings.copyWith(
      captchaSecretConfigured:
          includeSecretKey && settings.captchaSecretKey.trim().isNotEmpty,
    );
    return this.settings;
  }
}

class _FakeAdminStorageSettingsRepository
    implements AdminStorageSettingsRepository {
  var settings = AdminStorageSettingsData.empty();

  @override
  Future<AdminStorageSettingsData> fetchSettings() async {
    return settings;
  }

  @override
  Future<AdminStorageSettingsData> saveSettings(
    AdminStorageSettingsData settings,
  ) async {
    this.settings = settings;
    return settings;
  }
}

class _FakeAdminModuleSettingsRepository
    implements AdminModuleSettingsRepository {
  WeatherSettingsData weatherSettings = const WeatherSettingsData(
    languageCode: 'tr',
    enabled: true,
    locationName: 'Niğde',
    locationCountry: 'Türkiye',
    latitude: 37.96583,
    longitude: 34.67935,
    timezone: 'Europe/Istanbul',
    updateIntervalMinutes: 30,
  );

  WeatherSettingsData? savedWeatherSettings;
  AnnouncementPreviewItem? savedAnnouncement;
  String? toggledAnnouncementId;
  bool? toggledAnnouncementActive;
  String? deletedAnnouncementId;
  MarketSettingsData marketSettings = const MarketSettingsData(
    languageCode: 'tr',
    enabled: true,
    provider: 'genelpara',
    altinApiKey: '',
    altinApiBaseUrl: 'https://altinapi.com/api/v1',
    genelParaBaseUrl: 'https://api.genelpara.com/json/',
    updateIntervalSeconds: 300,
    currencySymbols: [
      'USD',
      'EUR',
      'BTC',
      'GBP',
      'CHF',
      'CAD',
      'AUD',
      'JPY',
      'SAR',
      'KWD',
      'NOK',
      'SEK',
      'DKK',
      'RUB',
      'CNY',
      'AED',
    ],
    goldSymbols: [
      'HAS',
      'ONS',
      'AYAR22',
      'GRAM',
      'ALTINGUMUS',
      'CEYREK',
      'YARIM',
      'TAM',
      'CUMHURIYET',
      'GREMSE',
      'AYAR14',
      'GUMUS',
      'AYAR18',
      'RESAT',
      'ATA',
      'BESLI',
      'HAMIT',
      'IKIBUCUK',
    ],
  );
  MarketSettingsData? savedMarketSettings;
  PrayerSettingsData prayerSettings = const PrayerSettingsData(
    languageCode: 'tr',
    enabled: true,
    diyanetBaseUrl: 'https://namazvakitleri.diyanet.gov.tr',
    locationName: 'Niğde',
    locationCountry: 'Türkiye',
    locationStateId: 561,
    locationCityId: 9766,
    timezone: 'Europe/Istanbul',
    refreshLeadDays: 3,
    cacheDays: 370,
    ayahEnabled: true,
    ayahStartDate: '2026-06-05',
    quranApiBaseUrl: 'https://t061.diyanet.gov.tr/apigateway/acikkaynakkuran',
    quranApiToken: '',
  );
  PrayerSettingsData? savedPrayerSettings;
  var dutyRefreshCount = 0;
  var deathRefreshCount = 0;

  @override
  Future<WeatherSettingsData> fetchWeatherSettings(String languageCode) async {
    return weatherSettings;
  }

  @override
  Future<WeatherSettingsData> saveWeatherSettings({
    required AdminSession session,
    required WeatherSettingsData settings,
  }) async {
    savedWeatherSettings = settings;
    weatherSettings = settings;
    return settings;
  }

  @override
  Future<List<WeatherLocationSearchResult>> searchWeatherLocations({
    required String query,
    required String languageCode,
  }) async {
    return const [
      WeatherLocationSearchResult(
        name: 'Niğde',
        latitude: 37.96583,
        longitude: 34.67935,
        timezone: 'Europe/Istanbul',
        country: 'Türkiye',
      ),
    ];
  }

  @override
  Future<DutyPharmacyPreviewData> fetchDutyPharmacyPreview({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) dutyRefreshCount++;
    return const DutyPharmacyPreviewData(
      city: 'Niğde',
      source: 'Niğde Eczacı Odası',
      sourceUrl: 'https://www.neo.org.tr/nobetci-eczaneler',
      serviceDateLabel: '22 Mayıs 2026',
      updateIntervalMinutes: 15,
      districts: ['MERKEZ', 'BOR'],
      pharmacies: [
        DutyPharmacyItem(
          id: 'deva',
          name: 'DEVA ECZANESİ',
          district: 'MERKEZ',
          address: 'Selçuk Mah. Ethem Onbaşı Cad. Niğde',
          phone: '0388 213 53 04',
          directionUrl: 'https://www.google.com/maps',
          note: '!! GECE 00:00’A KADAR NÖBETÇİDİR !!',
        ),
        DutyPharmacyItem(
          id: 'ozturk',
          name: 'ÖZTÜRK ECZANESİ',
          district: 'MERKEZ',
          address: 'Hastaneler Cad. Niğde',
          phone: '0388 221 02 03',
          directionUrl: 'https://www.google.com/maps',
        ),
      ],
      total: 2,
      cache: ModuleCacheInfo(source: 'database', hit: true, stale: false),
    );
  }

  @override
  Future<DeathNoticePreviewData> fetchDeathNoticePreview({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) deathRefreshCount++;
    return const DeathNoticePreviewData(
      city: 'Niğde',
      source: 'Niğde Belediyesi',
      sourceUrl: 'https://nigde.bel.tr/vefat-edenler',
      serviceDateLabel: '22 Mayıs 2026',
      updateIntervalMinutes: 30,
      notices: [
        DeathNoticeItem(
          id: 'notice-1',
          name: 'ŞABAN EFE ÇAVUŞ',
          deathDateLabel: '22 Mayıs 2026',
          prayerTime: 'ÖĞLE',
          burialPlace: 'HIDIRLIK',
          description:
              'Çavuşoğulları Mobilya Sahiplerinden Mehmet Çavuş’un Oğlu Şaban Efe Çavuş Vefat Etmiştir.',
        ),
      ],
      total: 1,
      cache: ModuleCacheInfo(source: 'database', hit: true, stale: false),
    );
  }

  @override
  Future<MarketSettingsData> fetchMarketSettings(String languageCode) async {
    return marketSettings.copyWith(languageCode: languageCode);
  }

  @override
  Future<MarketSettingsData> saveMarketSettings({
    required AdminSession session,
    required MarketSettingsData settings,
  }) async {
    savedMarketSettings = settings;
    marketSettings = settings;
    return settings;
  }

  @override
  Future<MarketPreviewData> fetchMarketPreview({
    bool forceRefresh = false,
  }) async {
    return const MarketPreviewData(
      enabled: true,
      provider: 'genelpara',
      source: 'GenelPara',
      serviceDateLabel: '5 Haziran 2026',
      fetchedAt: '2026-06-05T19:30:00.000Z',
      updateIntervalSeconds: 300,
      currencies: [
        MarketPreviewRate(
          id: 'currency-usd',
          symbol: 'USD',
          name: 'Amerikan Doları',
          bid: 32.41,
          ask: 32.48,
          changePercent: 0.32,
          isUp: true,
          currencySymbol: '₺',
        ),
      ],
      gold: [
        MarketPreviewRate(
          id: 'gold-gram',
          symbol: 'GRAM',
          name: 'Gram Altın',
          bid: 2460.12,
          ask: 2468.44,
          changePercent: 0.74,
          isUp: true,
          currencySymbol: '₺',
        ),
      ],
      cache: ModuleCacheInfo(source: 'database', hit: true, stale: false),
    );
  }

  @override
  Future<PrayerSettingsData> fetchPrayerSettings(String languageCode) async {
    return prayerSettings.copyWith(languageCode: languageCode);
  }

  @override
  Future<PrayerSettingsData> savePrayerSettings({
    required AdminSession session,
    required PrayerSettingsData settings,
  }) async {
    savedPrayerSettings = settings;
    prayerSettings = settings;
    return settings;
  }

  @override
  Future<PrayerPreviewData> fetchPrayerPreview({
    bool forceRefresh = false,
  }) async {
    return const PrayerPreviewData(
      enabled: true,
      source: 'Diyanet Namaz Vakitleri',
      location: 'Niğde',
      country: 'Türkiye',
      timezone: 'Europe/Istanbul',
      serviceDateLabel: '5 Haziran 2026',
      fetchedAt: '2026-06-05T19:30:00.000Z',
      today: PrayerPreviewDay(
        date: '2026-06-05',
        gregorianDateLabel: '5 Haziran 2026',
        hijriDateLabel: '19 Zilhicce 1447',
        qiblaAngle: '147°',
        times: [
          PrayerPreviewTime(key: 'imsak', name: 'İmsak', time: '03:38'),
          PrayerPreviewTime(key: 'gunes', name: 'Güneş', time: '05:21'),
          PrayerPreviewTime(key: 'ogle', name: 'Öğle', time: '12:58'),
          PrayerPreviewTime(key: 'ikindi', name: 'İkindi', time: '16:54'),
          PrayerPreviewTime(key: 'aksam', name: 'Akşam', time: '20:22'),
          PrayerPreviewTime(key: 'yatsi', name: 'Yatsı', time: '21:58'),
        ],
      ),
      days: [],
      dailyAyah: PrayerPreviewAyah(
        surahName: 'Fâtiha',
        verseNumber: 1,
        arabicText: '',
        translation: 'Rahmân ve Rahîm olan Allah’ın adıyla.',
        source: 'Diyanet Kur’an API',
      ),
      cache: ModuleCacheInfo(source: 'database', hit: true, stale: false),
    );
  }

  @override
  Future<List<AnnouncementSourceData>> fetchAnnouncementSources({
    bool includeInactive = true,
  }) async {
    return const [
      AnnouncementSourceData(
        id: 'source-1',
        sourceKey: 'nigde-valiligi',
        name: 'Niğde Valiliği',
        sourceType: 'institution',
        categoryHint: 'official',
        district: 'merkez',
        websiteUrl: 'https://www.nigde.gov.tr',
        listUrl: 'https://www.nigde.gov.tr/duyurular',
        socialUrl: '',
        facebookUrl: '',
        instagramUrl: '',
        crawlStrategy: 'auto',
        isActive: true,
        crawlIntervalMinutes: 20,
        lastCheckedAt: '2026-06-06T09:00:00.000Z',
        lastSuccessAt: '2026-06-06T09:00:00.000Z',
        lastError: '',
        sortOrder: 10,
      ),
    ];
  }

  @override
  Future<AnnouncementSourceData> saveAnnouncementSource({
    required AdminSession session,
    required AnnouncementSourceData source,
  }) async {
    return source;
  }

  @override
  Future<void> deleteAnnouncementSource({
    required AdminSession session,
    required String id,
  }) async {}

  @override
  Future<AnnouncementPreviewData> fetchAnnouncementPreview() async {
    return const AnnouncementPreviewData(
      city: 'Niğde',
      source: 'Niğde Duyuru Ağı',
      serviceDateLabel: '6 Haziran 2026',
      fetchedAt: '2026-06-06T09:00:00.000Z',
      updateIntervalMinutes: 20,
      announcements: [
        AnnouncementPreviewItem(
          id: 'announcement-1',
          category: 'official',
          district: 'merkez',
          source: 'Niğde Valiliği',
          sourceKey: 'nigde-valiligi',
          title: 'Kuvvetli Rüzgâr Uyarısı',
          summary: 'Meteoroloji değerlendirmesine göre uyarı yapılmıştır.',
          body:
              'Meteoroloji değerlendirmesine göre Niğde genelinde kuvvetli rüzgâr beklenmektedir.',
          place: 'Niğde geneli',
          timeLabel: 'Bugün 10:30',
          statusLabel: 'Uyarı',
          scheduleLabel: '',
          imageUrl: '',
          sourceUrl: 'https://www.nigde.gov.tr/duyurular',
          canonicalUrl: 'https://www.nigde.gov.tr/duyurular',
          linkedPostId: '',
          linkedPostTitle: '',
          linkedPostSlug: '',
          linkedPostThumbnailUrl: '',
          publishedAt: '2026-06-06T09:00:00.000Z',
          startsAt: '',
          endsAt: '',
          isActive: true,
        ),
      ],
      total: 1,
      officialCount: 1,
      powerCount: 0,
      roadCount: 0,
      activeSources: 1,
    );
  }

  @override
  Future<AnnouncementRefreshResult> refreshAnnouncements({
    required AdminSession session,
  }) async {
    return AnnouncementRefreshResult(
      preview: await fetchAnnouncementPreview(),
      sourcesChecked: 1,
      candidatesFound: 1,
      insertedCount: 1,
      updatedCount: 0,
      skippedCount: 0,
      errors: const [],
    );
  }

  @override
  Future<List<AnnouncementRunData>> fetchAnnouncementRuns() async {
    return const [
      AnnouncementRunData(
        id: 'run-1',
        runType: 'manual',
        status: 'success',
        startedAt: '2026-06-06T09:00:00.000Z',
        finishedAt: '2026-06-06T09:01:00.000Z',
        candidatesFound: 1,
        insertedCount: 1,
        updatedCount: 0,
        skippedCount: 0,
        errorMessage: '',
        sourceName: '',
      ),
    ];
  }

  @override
  Future<AnnouncementPreviewItem> saveAnnouncement({
    required AdminSession session,
    required AnnouncementPreviewItem announcement,
  }) async {
    savedAnnouncement = announcement;
    return announcement;
  }

  @override
  Future<AnnouncementPreviewItem> setAnnouncementActive({
    required AdminSession session,
    required String id,
    required bool isActive,
  }) async {
    toggledAnnouncementId = id;
    toggledAnnouncementActive = isActive;
    if (savedAnnouncement?.id == id) {
      return savedAnnouncement!.copyWith(isActive: isActive);
    }
    final preview = await fetchAnnouncementPreview();
    final item = preview.announcements.firstWhere(
      (announcement) => announcement.id == id,
    );
    return item.copyWith(isActive: isActive);
  }

  @override
  Future<void> deleteAnnouncement({
    required AdminSession session,
    required String id,
  }) async {
    deletedAnnouncementId = id;
  }
}

class _FakeAdminSocialRepository implements AdminSocialRepository {
  final settings = <AdminSocialAccount>[
    AdminSocialAccount(
      id: 7001,
      accountName: 'Bundle Social Canli',
      workspaceName: 'Haber merkezi',
      platforms: 'Instagram, X, LinkedIn',
      providerId: 'bundle_social',
      providerName: 'Bundle.social',
      mode: AdminSocialConnectionMode.bundle,
      apiBaseUrl: 'https://api.bundle.social/api/v1',
      teamId: 'team_test',
      clientId: '',
      redirectUrl: 'https://admin.test/social/callback',
      webhookUrl: '',
      scopes: 'post.create, upload.create',
      dailyLimit: 10000,
      monthlyLimit: 100000,
      hourlyLimit: 700,
      sentToday: 0,
      apiReady: true,
      oauthReady: true,
      webhookReady: false,
      requiresApproval: false,
      active: true,
      createdAt: DateTime(2026, 5, 26, 12),
      hasApiKey: true,
    ),
  ];

  final connectedAccounts = <AdminSocialConnectedAccount>[
    AdminSocialConnectedAccount(
      id: 1,
      socialAccountId: 7001,
      platform: SocialPlatform.instagram,
      platformType: 'INSTAGRAM',
      accountName: 'Bundle Social Canli',
      displayName: 'Canli Instagram',
      username: 'canli_instagram',
      channelId: '',
      channelName: 'Feed',
      status: 'connected',
      connectedAt: DateTime(2026, 5, 26),
    ),
    AdminSocialConnectedAccount(
      id: 2,
      socialAccountId: 7001,
      platform: SocialPlatform.twitter,
      platformType: 'TWITTER',
      accountName: 'Bundle Social Canli',
      displayName: 'Canli X',
      username: 'canli_x',
      channelId: '',
      channelName: '',
      status: 'connected',
      connectedAt: DateTime(2026, 5, 26),
    ),
  ];

  @override
  Future<AdminSocialAccount> checkSetting(
    AdminSession session,
    int accountId,
  ) async {
    final account = settings.firstWhere((item) => item.id == accountId);
    return account.copyWith(apiReady: true, oauthReady: true);
  }

  @override
  Future<String> createPortalLink(
    AdminSession session, {
    int? socialAccountId,
    required Iterable<SocialPlatform> platforms,
    String? redirectUrl,
  }) async {
    return 'https://bundle.social/connect-test';
  }

  @override
  Future<void> deleteSettings(AdminSession session, Iterable<int> ids) async {
    settings.removeWhere((item) => ids.contains(item.id));
  }

  @override
  Future<List<AdminSocialConnectedAccount>> fetchConnectedAccounts(
    AdminSession session,
  ) async {
    return connectedAccounts;
  }

  @override
  Future<List<AdminSocialAccount>> fetchSettings(AdminSession session) async {
    return settings;
  }

  @override
  Future<AdminSocialPublishResult> publishPost(
    AdminSession session, {
    int? socialAccountId,
    required SocialPublishData data,
    DateTime? scheduledAt,
  }) async {
    return const AdminSocialPublishResult(
      id: '1',
      bundlePostId: 'post_test',
      status: 'SCHEDULED',
    );
  }

  @override
  Future<AdminSocialAccount> saveSetting(
    AdminSession session, {
    int? id,
    required AdminSocialAccount account,
    String apiKey = '',
    String clientSecret = '',
  }) async {
    final saved = AdminSocialAccount(
      id: id ?? 7002,
      accountName: account.accountName,
      workspaceName: account.workspaceName,
      platforms: account.platforms,
      providerId: account.providerId,
      providerName: account.providerName,
      mode: account.mode,
      apiBaseUrl: account.apiBaseUrl,
      teamId: account.teamId,
      clientId: '',
      redirectUrl: account.redirectUrl,
      webhookUrl: account.webhookUrl,
      scopes: account.scopes,
      dailyLimit: account.dailyLimit,
      monthlyLimit: account.monthlyLimit,
      hourlyLimit: account.hourlyLimit,
      sentToday: account.sentToday,
      apiReady: apiKey.isNotEmpty || account.apiReady,
      oauthReady: account.oauthReady,
      webhookReady: account.webhookReady,
      requiresApproval: account.requiresApproval,
      active: account.active,
      createdAt: account.createdAt,
      hasApiKey: apiKey.isNotEmpty || account.hasApiKey,
    );
    settings
      ..removeWhere((item) => item.id == saved.id)
      ..insert(0, saved);
    return saved;
  }

  @override
  Future<AdminSocialAccount> updateSetting(
    AdminSession session,
    AdminSocialAccount account,
    Map<String, Object?> values,
  ) async {
    final updated = account.copyWith(
      active: values['is_active'] is bool
          ? values['is_active'] as bool
          : account.active,
    );
    settings
      ..removeWhere((item) => item.id == account.id)
      ..insert(0, updated);
    return updated;
  }
}

Future<void> _pumpAdminApp(
  WidgetTester tester, {
  AdminAuthRepository? authRepository,
  AdminNewsRepository? newsRepository,
  AdminStoriesRepository? storiesRepository,
  AdminPagesRepository? pagesRepository,
  AdminCommentsRepository? commentsRepository,
  AdminNavigationRepository? navigationRepository,
  AdminUsersRepository? usersRepository,
  AdminRolesRepository? rolesRepository,
  AdminLanguagesRepository? languagesRepository,
  AdminGeneralSettingsRepository? generalSettingsRepository,
  AdminFontSettingsRepository? fontSettingsRepository,
  AdminAiSettingsRepository? aiSettingsRepository,
  AdminContentSettingsRepository? contentSettingsRepository,
  AdminModuleSettingsRepository? moduleSettingsRepository,
  AdminSecuritySettingsRepository? securitySettingsRepository,
  AdminStorageSettingsRepository? storageSettingsRepository,
  AdminAccountSettingsRepository? accountSettingsRepository,
  AdminSubscribersRepository? subscribersRepository,
  AdminSocialRepository? socialRepository,
}) async {
  await tester.pumpWidget(
    PateeznewsAdminApp(
      authRepository: authRepository ?? _FakeAdminAuthRepository(),
      newsRepository: newsRepository ?? _FakeAdminNewsRepository(),
      storiesRepository: storiesRepository ?? _FakeAdminStoriesRepository(),
      pagesRepository: pagesRepository ?? _FakeAdminPagesRepository(),
      commentsRepository: commentsRepository ?? _FakeAdminCommentsRepository(),
      navigationRepository:
          navigationRepository ?? _FakeAdminNavigationRepository(),
      usersRepository: usersRepository ?? _FakeAdminUsersRepository(),
      rolesRepository: rolesRepository ?? _FakeAdminRolesRepository(),
      languagesRepository:
          languagesRepository ?? _FakeAdminLanguagesRepository(),
      generalSettingsRepository:
          generalSettingsRepository ?? _FakeAdminGeneralSettingsRepository(),
      fontSettingsRepository:
          fontSettingsRepository ?? _FakeAdminFontSettingsRepository(),
      aiSettingsRepository:
          aiSettingsRepository ?? _FakeAdminAiSettingsRepository(),
      contentSettingsRepository:
          contentSettingsRepository ?? _FakeAdminContentSettingsRepository(),
      moduleSettingsRepository:
          moduleSettingsRepository ?? _FakeAdminModuleSettingsRepository(),
      securitySettingsRepository:
          securitySettingsRepository ?? _FakeAdminSecuritySettingsRepository(),
      storageSettingsRepository:
          storageSettingsRepository ?? _FakeAdminStorageSettingsRepository(),
      accountSettingsRepository:
          accountSettingsRepository ?? _FakeAdminAccountSettingsRepository(),
      subscribersRepository:
          subscribersRepository ?? _FakeAdminSubscribersRepository(),
      socialRepository: socialRepository ?? _FakeAdminSocialRepository(),
    ),
  );
  await tester.pumpAndSettle();
}

bool _isTextAbove(WidgetTester tester, String upperText, String lowerText) {
  final upper = tester.getTopLeft(find.text(upperText).first).dy;
  final lower = tester.getTopLeft(find.text(lowerText).first).dy;
  return upper < lower;
}

Future<TestGesture> _hoverAdminSidebar(WidgetTester tester) async {
  final sidebar = find.byKey(const ValueKey('admin-sidebar'));
  final gesture = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
  await gesture.addPointer(location: const Offset(900, 40));
  await gesture.moveTo(tester.getCenter(sidebar));
  await tester.pumpAndSettle();
  return gesture;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _secureStorageValues.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _secureStorageChannel,
          _handleSecureStorageCall,
        );
  });

  test('Desktop auth client localhost API adresini kullanır', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    final requestedUrls = <String>[];
    final client = SupabaseAuthClient(
      httpClient: MockClient((request) async {
        requestedUrls.add(request.url.toString());
        if (request.url.path == '/api/supabase/auth') {
          return http.Response(
            jsonEncode({
              'data': {'session': _testSession.toJson()},
              'error': null,
            }),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'data': _testProfile.toJson(), 'error': null}),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }),
    );

    final authState = await client.signInWithPassword(
      email: 'demo.user@gmail.com',
      password: '123456',
    );

    expect(authState.session.user.email, 'demo.user@gmail.com');
    expect(
      requestedUrls,
      containsAllInOrder([
        'http://127.0.0.1:4321/api/supabase/auth',
        'http://127.0.0.1:4321/api/admin/query',
      ]),
    );
  });

  test('Android auth client emulator API adresini kullanır', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    final requestedUrls = <String>[];
    final client = SupabaseAuthClient(
      httpClient: MockClient((request) async {
        requestedUrls.add(request.url.toString());
        if (request.url.path == '/api/supabase/auth') {
          return http.Response(
            jsonEncode({
              'data': {'session': _testSession.toJson()},
              'error': null,
            }),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'data': _testProfile.toJson(), 'error': null}),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }),
    );

    await client.signInWithPassword(
      email: 'demo.user@gmail.com',
      password: '123456',
    );

    expect(
      requestedUrls,
      containsAllInOrder([
        'http://10.0.2.2:4321/api/supabase/auth',
        'http://10.0.2.2:4321/api/admin/query',
      ]),
    );
  });

  test(
    'Auth client verilen API adresini platformdan bağımsız kullanır',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });

      final requestedUrls = <String>[];
      final client = SupabaseAuthClient(
        apiBaseUrl: 'https://example.com',
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          if (request.url.path == '/api/supabase/auth') {
            return http.Response(
              jsonEncode({
                'data': {'session': _testSession.toJson()},
                'error': null,
              }),
              200,
              headers: {'Content-Type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'data': _testProfile.toJson(), 'error': null}),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }),
      );

      await client.signInWithPassword(
        email: 'demo.user@gmail.com',
        password: '123456',
      );

      expect(
        requestedUrls,
        containsAllInOrder([
          'https://example.com/api/supabase/auth',
          'https://example.com/api/admin/query',
        ]),
      );
    },
  );

  testWidgets('Giriş ekranı temel alanları gösterir', (tester) async {
    await _pumpAdminApp(tester);

    expect(find.text('Pateeznews admin'), findsOneWidget);
    expect(find.text('Yönetim girişi'), findsOneWidget);
    expect(find.text('E-posta adresi'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
    expect(find.text('Giriş yap'), findsOneWidget);
    expect(find.text('Şifremi unuttum'), findsNothing);
  });

  testWidgets('Input örnekleri placeholder, yazılan metin koyu renktir', (
    tester,
  ) async {
    await _pumpAdminApp(tester);

    final emailField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).at(0),
        matching: find.byType(TextField),
      ),
    );
    final passwordField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).at(1),
        matching: find.byType(TextField),
      ),
    );

    expect(emailField.decoration?.hintText, 'editor@pateeznews.com');
    expect(passwordField.decoration?.hintText, 'Güvenli şifreniz');
    expect(emailField.style?.color, AppColors.deepOcean);
    expect(passwordField.style?.color, AppColors.deepOcean);
  });

  testWidgets('Boş form doğrulama mesajı üretir', (tester) async {
    await _pumpAdminApp(tester);

    await tester.ensureVisible(find.text('Giriş yap'));
    await tester.tap(find.text('Giriş yap'));
    await tester.pump();

    expect(find.text('Geçerli bir e-posta adresi girin'), findsOneWidget);
    expect(find.text('Şifre en az 6 karakter olmalı'), findsOneWidget);
  });

  testWidgets('Hatalı giriş mesajı inputların altında gösterilir', (
    tester,
  ) async {
    await _pumpAdminApp(
      tester,
      authRepository: _FakeAdminAuthRepository(
        signInException: const AdminAuthException('Invalid login credentials'),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'admin@gmail.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(find.text('Giriş yapılamadı. Lütfen tekrar deneyin.'), findsNothing);
    expect(find.text('Şifremi unuttum'), findsNothing);
    expect(
      find.text('E-posta veya şifre bulunamadı ya da hatalı.'),
      findsNWidgets(2),
    );
  });

  testWidgets('Geçerli giriş dashboard ekranını açar', (tester) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Sayfa'), findsWidgets);
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Ana Sayfa Menüsü'), findsNothing);
    expect(find.text('Dil Ayarları'), findsNothing);
    expect(find.text('Yayın akışı'), findsOneWidget);
    expect(find.text('Son durum'), findsOneWidget);
  });

  testWidgets(
    'Sidebar açılır menüleri tek açık grup ve seçili alt menüyü korur',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpAdminApp(tester);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'editor@pateeznews.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ayarlar'));
      await tester.pumpAndSettle();
      expect(find.text('Genel Ayarlar'), findsOneWidget);
      expect(find.text('Dil Ayarları'), findsOneWidget);

      await tester.tap(find.text('Modüller'));
      await tester.pumpAndSettle();
      expect(find.text('Depo'), findsOneWidget);
      expect(find.text('Google News'), findsOneWidget);
      expect(find.text('Yapay Zeka Ayarları'), findsOneWidget);
      expect(_isTextAbove(tester, 'Depo', 'Google News'), isTrue);
      expect(
        _isTextAbove(tester, 'Google News', 'Yapay Zeka Ayarları'),
        isTrue,
      );
      expect(find.text('Genel Ayarlar'), findsNothing);
      expect(find.text('Dil Ayarları'), findsNothing);

      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(find.text('Depo'), findsNothing);
      expect(find.text('Google News'), findsNothing);
      expect(find.text('Yapay Zeka Ayarları'), findsNothing);

      await tester.tap(find.text('Ayarlar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dil Ayarları'));
      await tester.tap(find.text('Dil Ayarları'));
      await tester.pumpAndSettle();
      expect(find.text('Dil Ayarları'), findsOneWidget);

      final hoverGesture = await _hoverAdminSidebar(tester);
      expect(find.text('Dil Ayarları'), findsNWidgets(2));
      await tester.tap(find.text('Modüller'));
      await tester.pumpAndSettle();
      expect(find.text('Depo'), findsOneWidget);
      expect(find.text('Google News'), findsOneWidget);
      expect(find.text('Yapay Zeka Ayarları'), findsOneWidget);
      expect(_isTextAbove(tester, 'Depo', 'Google News'), isTrue);
      expect(
        _isTextAbove(tester, 'Google News', 'Yapay Zeka Ayarları'),
        isTrue,
      );
      expect(find.text('Genel Ayarlar'), findsNothing);

      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(find.text('Yapay Zeka Ayarları'), findsNothing);
      expect(find.text('Genel Ayarlar'), findsOneWidget);
      expect(find.text('Dil Ayarları'), findsNWidgets(2));
      await hoverGesture.removePointer();
    },
  );

  testWidgets(
    'Sidebar seçimden sonra kapanır, hover ile açılır ve sabitlenir',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpAdminApp(tester);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'editor@pateeznews.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();

      final sidebar = find.byKey(const ValueKey('admin-sidebar'));
      final expandedWidth = tester.getSize(sidebar).width;
      expect(expandedWidth, greaterThan(280));

      await tester.tap(find.text('Kullanıcılar'));
      await tester.pumpAndSettle();
      expect(tester.getSize(sidebar).width, lessThan(140));

      final hoverGesture = await _hoverAdminSidebar(tester);
      expect(tester.getSize(sidebar).width, closeTo(expandedWidth, 0.1));
      expect(find.text('Yorumlar'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('admin-sidebar-pin-switch')));
      await tester.pumpAndSettle();
      await hoverGesture.moveTo(const Offset(900, 40));
      await tester.pumpAndSettle();

      expect(tester.getSize(sidebar).width, closeTo(expandedWidth, 0.1));
      await hoverGesture.removePointer();
    },
  );

  testWidgets('Kullanıcılar ana menüsü tablo ekranını açar', (tester) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kullanıcılar'));
    await tester.pumpAndSettle();

    expect(find.text('Kullanıcılar'), findsWidgets);
    expect(find.text('Oturum'), findsOneWidget);
    expect(find.text('Toplam kullanıcı sayısı'), findsOneWidget);
    expect(find.text('Ödül Sistemi'), findsWidgets);
    expect(find.text('Aktif Kullanıcılar'), findsOneWidget);
    expect(find.text('Onay Bekleyenler'), findsOneWidget);
    expect(find.text('Rol'), findsWidgets);
    expect(find.text('Durum'), findsWidgets);
    expect(find.text('Tümü'), findsWidgets);
    expect(find.text('Ara...'), findsWidgets);
    expect(find.text('Kullanıcı Ekle'), findsOneWidget);
    expect(find.text('ID'), findsOneWidget);
    expect(find.text('Kullanıcı'), findsOneWidget);
    expect(find.text('Oluşturma'), findsOneWidget);
    expect(find.text('İşlem'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('Pateez Niğde'), findsOneWidget);
    expect(find.text('@nigdejournal'), findsOneWidget);
    expect(find.text('pateezcom@gmail.com'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Nasip Gündoğu'), findsOneWidget);
    expect(find.text('@nasip'), findsOneWidget);
    expect(find.text('demo.user@gmail.com'), findsOneWidget);
    expect(find.text('Süper Yönetici'), findsWidgets);
    expect(find.text('Aktif'), findsNWidgets(2));
    expect(find.text('16 Ocak 2026 Cuma'), findsOneWidget);
    expect(find.text('4 Ocak 2026 Pazar'), findsOneWidget);
    expect(find.text('1 - 2 / 2 kayıt gösteriliyor'), findsOneWidget);
    expect(find.byTooltip('Kullanıcı işlemleri'), findsNWidgets(2));

    await tester.tap(find.text('Kullanıcı'));
    await tester.pumpAndSettle();
    expect(_isTextAbove(tester, 'Nasip Gündoğu', 'Pateez Niğde'), isTrue);

    await tester.tap(find.text('Kullanıcı'));
    await tester.pumpAndSettle();
    expect(_isTextAbove(tester, 'Pateez Niğde', 'Nasip Gündoğu'), isTrue);

    await tester.tap(find.text('...').first);
    await tester.pumpAndSettle();

    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.text('Pasifleştir'), findsOneWidget);
    expect(find.text('Ödülü aç'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);

    await tester.tap(find.text('Kullanıcılar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pateez Niğde'));
    await tester.pumpAndSettle();

    expect(find.text('Seçili 1 kaydı sil'), findsOneWidget);

    await tester.tap(find.text('Seçili 1 kaydı sil'));
    await tester.pumpAndSettle();

    expect(find.text('Seçili kullanıcılar silinsin mi?'), findsOneWidget);
    expect(find.text('1 kullanıcı kalıcı olarak silinecek.'), findsOneWidget);
  });

  testWidgets('Avatar menüsü hesap ayarları sayfasını açar', (tester) async {
    tester.view.physicalSize = const Size(1366, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final accountRepository = _FakeAdminAccountSettingsRepository();
    await _pumpAdminApp(tester, accountSettingsRepository: accountRepository);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pateez Niğde'));
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Hesap Ayarları'), findsOneWidget);
    expect(find.text('Çıkış'), findsOneWidget);

    await tester.tap(find.text('Hesap Ayarları'));
    await tester.pumpAndSettle();

    expect(find.text('Hesap Ayarları'), findsWidgets);
    expect(find.text('Profil Bilgileri'), findsWidgets);
    expect(find.text('Sosyal Hesaplar'), findsOneWidget);
    expect(find.text('Tercihler'), findsOneWidget);
    expect(find.text('Şifre Değiştir'), findsOneWidget);
    expect(find.text('Hesabı Sil'), findsOneWidget);
    expect(find.text('Ayarların Dili'), findsNothing);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Pateez Niğde Güncel',
    );
    await tester.tap(find.text('Değişiklikleri Kaydet'));
    await tester.pumpAndSettle();

    expect(accountRepository.savedProfile?.fullName, 'Pateez Niğde Güncel');
    expect(accountRepository.savedProfile?.socialLinks['facebook'], 'pateez');
  });

  testWidgets('Yorumlar menüsü kullanıcıların üzerinde yorum yönetimini açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2560, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final commentsRepository = _FakeAdminCommentsRepository();
    await _pumpAdminApp(tester, commentsRepository: commentsRepository);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(find.text('Yorumlar'), findsOneWidget);
    expect(_isTextAbove(tester, 'Yorumlar', 'Kullanıcılar'), isTrue);

    await tester.tap(find.text('Yorumlar'));
    await tester.pumpAndSettle();

    expect(find.text('Yorumlar'), findsWidgets);
    expect(find.text('Toplam Yorumlar'), findsOneWidget);
    expect(find.text('Onaylanan'), findsOneWidget);
    expect(find.text('Beklemede'), findsWidgets);
    expect(find.text('Reddedilen'), findsOneWidget);
    expect(find.text('Durum'), findsWidgets);
    expect(find.text('Haber'), findsWidgets);
    expect(find.text('Kullanıcı'), findsOneWidget);
    expect(find.text('Ara...'), findsWidgets);
    expect(find.text('ID'), findsOneWidget);
    expect(find.text('Yorum'), findsOneWidget);
    expect(find.text('Beğeni'), findsOneWidget);
    expect(find.text('Yanıt'), findsOneWidget);
    expect(find.text('Tarih'), findsOneWidget);
    expect(find.text('İşlem'), findsOneWidget);
    expect(find.text('Sabit onaylı yorum.'), findsOneWidget);
    expect(find.text('İlk yorum onay bekliyor.'), findsOneWidget);
    expect(find.text('Onaylı haber'), findsOneWidget);
    expect(find.text('Deneme haberi'), findsOneWidget);
    expect(find.text('1 Şikayet'), findsOneWidget);
    expect(find.text('1 - 2 / 2 kayıt gösteriliyor'), findsOneWidget);
    expect(find.byTooltip('Yorum işlemleri'), findsNWidgets(2));

    await tester.tap(find.text('...').first);
    await tester.pumpAndSettle();

    expect(find.text('Onayla'), findsOneWidget);
    expect(find.text('Reddet'), findsOneWidget);
    expect(find.text('Sabitlemeyi kaldır'), findsOneWidget);
    expect(find.text('Yanıtla'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);

    await tester.tap(find.text('Reddet'));
    await tester.pumpAndSettle();

    expect(commentsRepository.rejectedCommentId, '2');
    expect(find.text('Reddedildi'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Seçili 1 yorumu sil'), findsOneWidget);

    await tester.tap(find.text('Seçili 1 yorumu sil'));
    await tester.pumpAndSettle();

    expect(find.text('Seçili yorumlar silinsin mi?'), findsOneWidget);
    expect(find.text('1 yorum kalıcı olarak silinecek.'), findsOneWidget);
  });

  testWidgets('Aboneler sayfası Supabase repository CRUD akışını kullanır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final subscribersRepository = _FakeAdminSubscribersRepository();
    await _pumpAdminApp(tester, subscribersRepository: subscribersRepository);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aboneler'));
    await tester.pumpAndSettle();

    expect(find.text('Aboneler'), findsOneWidget);
    expect(find.text('Nasip Gündoğu'), findsOneWidget);
    expect(find.text('nasip@pateeznews.com'), findsOneWidget);
    expect(find.text('Pasif Abone'), findsOneWidget);
    expect(find.text('IP'), findsOneWidget);
    expect(find.text('Şehir'), findsOneWidget);
    expect(find.text('1 - 2 / 2 kayıt gösteriliyor'), findsOneWidget);

    await tester.tap(find.text('Abone Ekle'));
    await tester.pumpAndSettle();

    var dialogFields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(dialogFields.at(0), 'Yeni Abone');
    await tester.enterText(dialogFields.at(1), '+90 500 000 00 00');
    await tester.enterText(dialogFields.at(2), 'yeni@pateeznews.com');
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(TextButton, 'Kaydet'),
      ),
    );
    await tester.pumpAndSettle();

    expect(subscribersRepository.savedSubscriberId, isNull);
    expect(subscribersRepository.savedSubscriber?.fullName, 'Yeni Abone');
    expect(find.text('Abone başarıyla eklendi'), findsOneWidget);
    expect(find.text('Yeni Abone'), findsOneWidget);

    await tester.tap(find.text('...').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();

    dialogFields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(dialogFields.at(0), 'Yeni Abone Güncel');
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(TextButton, 'Kaydet'),
      ),
    );
    await tester.pumpAndSettle();

    expect(subscribersRepository.savedSubscriberId, isNotNull);
    expect(
      subscribersRepository.savedSubscriber?.fullName,
      'Yeni Abone Güncel',
    );
    expect(find.text('Abone başarıyla güncellendi'), findsOneWidget);

    await tester.tap(find.text('...').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Abone silinsin mi?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(TextButton, 'Sil'),
      ),
    );
    await tester.pumpAndSettle();

    expect(subscribersRepository.deletedSubscriberId, isNotNull);
    expect(find.text('Abone başarıyla silindi'), findsOneWidget);
  });

  testWidgets('Haberler menüsü yorumların üzerinde haber yönetimini açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final newsRepository = _FakeAdminNewsRepository();
    await _pumpAdminApp(tester, newsRepository: newsRepository);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(find.text('Haberler'), findsOneWidget);
    expect(find.text('Haber Ekle'), findsOneWidget);
    expect(_isTextAbove(tester, 'Haber Ekle', 'Haberler'), isTrue);
    expect(_isTextAbove(tester, 'Haberler', 'Yorumlar'), isTrue);

    await tester.tap(find.text('Haberler'));
    await tester.pumpAndSettle();

    expect(find.text('Haberler'), findsWidgets);
    expect(find.text('Okunma'), findsWidgets);
    expect(find.text('Dil'), findsWidgets);
    expect(find.text('Kategori'), findsWidgets);
    expect(find.text('Tür'), findsOneWidget);
    expect(find.text('Yayıncı'), findsOneWidget);
    expect(find.text('Ara...'), findsWidgets);
    expect(find.text('Haber Ekle'), findsOneWidget);
    expect(find.text('Durum'), findsWidgets);
    expect(find.text('Ekleyen'), findsOneWidget);
    expect(find.text('Yorum'), findsOneWidget);
    expect(find.text('Video içerikleri'), findsNothing);
    await tester.tap(find.byTooltip('Video detaylarını aç').first);
    await tester.pumpAndSettle();
    expect(find.text('Video içerikleri'), findsOneWidget);
    expect(find.text('Festival videosu'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(
      find.text(
        'Niğde Ruhun Yüzde Kaç? Patates, Gazoz ve Şöyle Bi Merkeze İneyim Enerjini Ölçüyoruz!',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Niğde Belediyesi 3. Tiyatro Festivali Başlıyor'),
      findsOneWidget,
    );
    expect(find.text('Anket'), findsOneWidget);
    expect(find.text('Makale'), findsOneWidget);
    expect(find.text('Yayında'), findsOneWidget);
    expect(find.text('Taslak'), findsWidgets);
    expect(find.text('@nasip'), findsNWidgets(2));
    expect(find.text('demo.user@gmail.com'), findsNWidgets(2));
    expect(find.byTooltip('Haber işlemleri'), findsNWidgets(2));

    await tester.tap(find.text('...').first);
    await tester.pumpAndSettle();

    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.text('Yayından kaldır'), findsOneWidget);
    expect(find.text('Sabitlemeyi kaldır'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);

    await tester.tap(find.text('Yayından kaldır'));
    await tester.pumpAndSettle();

    expect(newsRepository.toggledStatusPostId, '23');
  });

  testWidgets('Boş içindekiler tabında AI modalı yeni taslak olarak açılır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Haber Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni Haber'), findsOneWidget);

    await tester.tap(find.text('İçindekiler').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yapay Zeka İle Üret'));
    await tester.pumpAndSettle();

    expect(find.text('Yapay Zeka İçerik Üretici'), findsOneWidget);
    expect(find.text('İçerik Taslağı Oluştur'), findsOneWidget);
    expect(find.text('Düzelt'), findsNothing);
    expect(find.textContaining('Blok tipi: toc'), findsNothing);
    expect(
      find.textContaining('Blok başlığı: Table of Contents'),
      findsNothing,
    );
  });

  testWidgets('Etkinlik tabında AI modalı item planner ile açılır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Haber Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni Haber'), findsOneWidget);

    await tester.tap(find.text('Etkinlik').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yapay Zeka İle Üret'));
    await tester.pumpAndSettle();

    expect(find.text('Yapay Zeka İçerik Üretici'), findsOneWidget);
    expect(find.text('Etkinlik'), findsWidgets);
    expect(find.text('Etkinlik Görselleri'), findsOneWidget);
    expect(find.text('AI ile Eklenecek Itemler'), findsOneWidget);
    expect(find.text('Metin Ekle'), findsWidgets);
    expect(find.text('Toplam item: 0'), findsOneWidget);
  });

  testWidgets('Manşet slider görsel olmadan aktif kalmaz', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Haber Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni Haber'), findsOneWidget);

    Finder mansetSwitch() => find
        .byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_ToggleSwitch',
        )
        .first;

    await tester.tap(mansetSwitch());
    await tester.pumpAndSettle();

    expect(find.text('Manşet Slider Görseli'), findsOneWidget);
    expect(
      find.textContaining('Görsel eklenmeden switch açık kalmaz'),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('İptal')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Manşet Slider Görseli'), findsNothing);

    await tester.tap(mansetSwitch());
    await tester.pumpAndSettle();
    expect(find.text('Manşet Slider Görseli'), findsOneWidget);
  });

  testWidgets('Boş yapı sekmelerinden çıkarken format onayı gösterilmez', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Haber Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni Haber'), findsOneWidget);

    Future<void> expectCleanTabSwitch(String tabLabel) async {
      await tester.tap(find.text(tabLabel).first);
      await tester.pumpAndSettle();
      expect(
        find.text('Format değiştirilsin mi?'),
        findsNothing,
        reason: '$tabLabel sekmesine geçerken onay açılmamalı',
      );

      await tester.tap(find.text('Makale').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Format değiştirilsin mi?'),
        findsNothing,
        reason:
            '$tabLabel sekmesinden Makale sekmesine dönerken onay açılmamalı',
      );
    }

    await expectCleanTabSwitch('Anket');
    await expectCleanTabSwitch('İçindekiler');
    await expectCleanTabSwitch('Tarif');
    await expectCleanTabSwitch('Etkinlik');
  });

  testWidgets('Sekmeler varsayılan Schema.org türünü doğru seçer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Haber Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Haber Makalesi (NewsArticle)'), findsOneWidget);

    Future<void> expectTabSchema(String tabLabel, String schemaLabel) async {
      await tester.tap(find.text(tabLabel).first);
      await tester.pumpAndSettle();
      expect(
        find.text(schemaLabel),
        findsOneWidget,
        reason: '$tabLabel sekmesi $schemaLabel varsayılanını göstermeli',
      );
      expect(
        find.text('Format değiştirilsin mi?'),
        findsNothing,
        reason: '$tabLabel sekmesine geçerken onay açılmamalı',
      );
    }

    await expectTabSchema('Test (Quiz)', 'Quiz/Test (Quiz)');
    await expectTabSchema('Anket', 'Haber Makalesi (NewsArticle)');
    await expectTabSchema('Video', 'Video (VideoObject)');
    await expectTabSchema('İçindekiler', 'Haber Makalesi (NewsArticle)');
    await expectTabSchema('Tarif', 'Tarif (Recipe)');
    await expectTabSchema('Etkinlik', 'Etkinlik (Event)');
  });

  testWidgets('Haber ekle kategorileri aktif sekmeye göre filtrelenir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Haber Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni Haber'), findsOneWidget);

    Finder dropdownWithValue(String value) {
      return find.byWidgetPredicate(
        (widget) => widget is DropdownButton<String> && widget.value == value,
      );
    }

    final articleSubDropdown = find.ancestor(
      of: find.text('Alt Kategori Seçin').first,
      matching: find.byType(DropdownButton<String>),
    );
    await tester.tap(articleSubDropdown);
    await tester.pumpAndSettle();

    expect(find.text('Siyaset'), findsOneWidget);
    expect(find.text('Yaşam'), findsOneWidget);
    expect(find.text('Testler'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anket').first);
    await tester.pumpAndSettle();
    expect(find.text('Niğde > Anket'), findsOneWidget);

    await tester.tap(dropdownWithValue('Anket').first);
    await tester.pumpAndSettle();

    expect(find.text('Siyaset'), findsNothing);
    expect(find.text('Yaşam'), findsNothing);
    expect(find.text('Testler'), findsNothing);
    expect(find.text('Altunhisar'), findsOneWidget);
    expect(find.text('Bor'), findsOneWidget);

    await tester.tap(find.text('Bor').last);
    await tester.pumpAndSettle();
    expect(find.text('Niğde > Bor'), findsOneWidget);

    final thirdDropdown = find.ancestor(
      of: find.text('Alt Kategori Seçin').first,
      matching: find.byType(DropdownButton<String>),
    );
    await tester.tap(thirdDropdown);
    await tester.pumpAndSettle();

    expect(find.text('Siyaset'), findsNothing);
    expect(find.text('Yaşam'), findsNothing);
    expect(find.text('Testler'), findsNothing);
    expect(find.text('Anket'), findsWidgets);

    await tester.tap(find.text('Anket').last);
    await tester.pumpAndSettle();
    expect(find.text('Niğde > Bor > Anket'), findsOneWidget);
  });

  testWidgets('Hikayeler menüsü yorumların üzerinde hikaye yönetimini açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storiesRepository = _FakeAdminStoriesRepository();
    await _pumpAdminApp(tester, storiesRepository: storiesRepository);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(find.text('Haberler'), findsOneWidget);
    expect(find.text('Hikayeler'), findsOneWidget);
    expect(find.text('Yorumlar'), findsOneWidget);
    expect(_isTextAbove(tester, 'Haberler', 'Hikayeler'), isTrue);
    expect(_isTextAbove(tester, 'Hikayeler', 'Yorumlar'), isTrue);

    await tester.tap(find.text('Hikayeler'));
    await tester.pumpAndSettle();

    expect(find.text('Hikayeler'), findsWidgets);
    expect(find.text('Ara...'), findsWidgets);
    expect(find.text('Hikaye Ekle'), findsOneWidget);
    expect(find.text('ID'), findsWidgets);
    expect(find.text('Hikaye'), findsWidgets);
    expect(find.text('İzlenme'), findsOneWidget);
    expect(find.text('Bitiş Tarihi'), findsOneWidget);
    expect(find.text('Durum'), findsWidgets);
    expect(find.text('İşlem'), findsOneWidget);
    expect(find.text('Niğde sabah hikayesi'), findsOneWidget);
    expect(find.text('Festival video hikayesi'), findsOneWidget);
    expect(find.text('Görsel'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Yayında'), findsOneWidget);
    expect(find.text('Pasif'), findsOneWidget);
    expect(find.textContaining('Pateeznews'), findsOneWidget);
    expect(find.text('Belirtilmedi'), findsOneWidget);
    expect(find.text('1 - 2 / 2 kayıt gösteriliyor'), findsOneWidget);
    expect(find.byTooltip('Hikaye işlemleri'), findsNWidgets(2));

    await tester.tap(find.text('...').first);
    await tester.pumpAndSettle();

    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.text('Yayından kaldır'), findsOneWidget);
    expect(find.text('Medyayı gör'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);

    await tester.tap(find.text('Yayından kaldır'));
    await tester.pumpAndSettle();

    expect(storiesRepository.toggledStatusStoryId, 'story-1');

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Seçili 1 hikayeyi sil'), findsOneWidget);

    await tester.tap(find.text('Seçili 1 hikayeyi sil'));
    await tester.pumpAndSettle();

    expect(find.text('Seçili hikayeler silinsin mi?'), findsOneWidget);
    expect(find.text('1 hikaye kalıcı olarak silinecek.'), findsOneWidget);
  });

  testWidgets(
    'Sayfalar menüsü navigasyon üzerinde liste ve tam sayfa formu açar',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pagesRepository = _FakeAdminPagesRepository();
      await _pumpAdminApp(tester, pagesRepository: pagesRepository);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'editor@pateeznews.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();

      expect(find.text('Sayfalar'), findsOneWidget);
      expect(find.text('Navigasyon'), findsOneWidget);
      expect(_isTextAbove(tester, 'Sayfalar', 'Navigasyon'), isTrue);

      await tester.tap(find.text('Sayfalar'));
      await tester.pumpAndSettle();

      expect(find.text('Sayfalar'), findsWidgets);
      expect(find.text('Ara...'), findsWidgets);
      expect(find.text('Sayfa Ekle'), findsOneWidget);
      expect(find.text('Başlık'), findsOneWidget);
      expect(find.text('Kategori'), findsWidgets);
      expect(find.text('Tip'), findsWidgets);
      expect(find.text('Durum'), findsWidgets);
      expect(find.text('Ekleme zamanı'), findsOneWidget);
      expect(find.text('İşlemler'), findsOneWidget);
      expect(find.text('Hakkımızda'), findsOneWidget);
      expect(find.text('hakkimizda • tr'), findsOneWidget);
      expect(find.text('Niğde'), findsOneWidget);
      expect(find.text('↳'), findsWidgets);
      expect(find.text('Kurumsal'), findsWidgets);
      expect(find.text('Özel'), findsWidgets);
      expect(find.text('Yasal'), findsWidgets);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Pasif'), findsOneWidget);
      expect(find.text('16 Nisan 2026 Perşembe'), findsWidgets);
      expect(find.text('1 - 2 / 2 kayıt gösteriliyor'), findsOneWidget);

      await tester.tap(find.text('...').first);
      await tester.pumpAndSettle();

      expect(find.text('Düzenle'), findsOneWidget);
      expect(find.text('Pasif yap'), findsOneWidget);
      expect(find.text('Sil'), findsOneWidget);

      await tester.tap(find.text('Pasif yap'));
      await tester.pumpAndSettle();
      expect(pagesRepository.toggledStatusPageId, 'page-1');

      await tester.tap(find.text('Sayfa Ekle'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Sayfa Ekle'), findsWidgets);
      expect(find.text('Kategori Ayarları'), findsOneWidget);
      expect(find.text('Sayfa Ayarları'), findsOneWidget);
      expect(find.text('Genel'), findsOneWidget);
      expect(find.text('Haber Dili'), findsOneWidget);
      expect(find.text('Ana Kategori'), findsOneWidget);
      expect(find.text('Üst Sayfa'), findsNothing);
      expect(find.text('Konum'), findsNothing);
      expect(find.text('Üst Menü'), findsNothing);
      expect(find.text('Başlığı Göster'), findsOneWidget);
      expect(find.text('Breadcrumb Göster'), findsOneWidget);
      expect(find.text('Sidebar Göster'), findsOneWidget);
      expect(find.text('Sadece Kayıtlı Kullanıcılar'), findsNothing);
      expect(find.text('Menü Sırası'), findsOneWidget);
      expect(find.text('Metin İçerik Bloğu'), findsNothing);
      expect(find.text('Başlık Girin (Opsiyonel)...'), findsNothing);
      expect(find.text('Daha Fazla'), findsNothing);
      expect(find.text('Önizleme'), findsNothing);
      expect(find.text('Meta Seçenekleri'), findsNothing);
    },
  );

  testWidgets('Navigasyon menüsü modüllerin üzerinde yönetimi açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigationRepository = _FakeAdminNavigationRepository();
    await _pumpAdminApp(tester, navigationRepository: navigationRepository);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(find.text('Navigasyon'), findsOneWidget);
    expect(_isTextAbove(tester, 'Navigasyon', 'Modüller'), isTrue);

    await tester.tap(find.text('Navigasyon'));
    await tester.pumpAndSettle();

    expect(find.text('Navigasyon Yönetimi'), findsOneWidget);
    expect(find.text('Sol Sidebar'), findsOneWidget);
    expect(find.text('Üst Navbar'), findsOneWidget);
    expect(find.text('Öğe Ekle'), findsOneWidget);
    expect(find.text('Niğde'), findsWidgets);
    expect(find.text('Haftanın Trendleri'), findsWidgets);
    expect(find.text('Anketler'), findsOneWidget);
    expect(find.text('Haftanın Genel Trendleri (Karma)'), findsOneWidget);
    expect(find.text('Kategori Filtresi'), findsOneWidget);
    expect(find.byTooltip('Düzenle'), findsNWidgets(3));
    expect(find.byTooltip('Sil'), findsNWidgets(3));

    await tester.tap(find.text('Üst Navbar'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Sayfa'), findsWidgets);
    expect(find.text('Anket'), findsWidgets);
    expect(find.byTooltip('Düzenle'), findsNWidgets(2));

    await tester.tap(find.text('Öğe Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Görünen Ad'), findsOneWidget);
    expect(find.text('Konum'), findsOneWidget);
    expect(find.text('Türkçe'), findsWidgets);
    await tester.enterText(
      find.ancestor(
        of: find.text('Görünen Ad'),
        matching: find.byType(TextFormField),
      ),
      'Yeni Menü',
    );
    expect(find.text('Yeni Menü'), findsOneWidget);
    await tester.tap(find.text('Örn: location_on, poll, quiz'));
    await tester.pumpAndSettle();
    expect(find.text('İkon Adı (Material Symbols)'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.text('home').last));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Kaydet').last);
    await tester.pumpAndSettle();

    expect(find.text('Görünen ad zorunlu'), findsNothing);
    expect(find.text('Görünen Ad'), findsNothing);
    expect(navigationRepository.createdItem?.label, 'Yeni Menü');
    expect(navigationRepository.createdMenuId, 'menu-top-navbar');
    expect(find.text('Yeni Menü'), findsOneWidget);
  });

  testWidgets('Sosyal medya paylaşım menüsü editör ekranını açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sosyal Medya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paylaşım Yap'));
    await tester.pumpAndSettle();

    expect(find.text('Sosyal medya paylaşımı'), findsOneWidget);
    expect(find.text('Sosyal hesaplar'), findsOneWidget);
    expect(find.text('Gönderi metni'), findsOneWidget);
    expect(find.text('Facebook'), findsWidgets);
  });

  testWidgets('Sosyal medya ayarları menüsü ayar ekranını açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sosyal Medya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sosyal Medya Ayarları'));
    await tester.pumpAndSettle();

    expect(find.text('Sosyal Medya Ayar Merkezi'), findsOneWidget);
    expect(find.text('Platform'), findsOneWidget);
    expect(find.text('Servis'), findsNothing);
    expect(find.text('Takım / API'), findsNothing);
    expect(find.text('API ve OAuth Bağlantısı'), findsNothing);

    await tester.tap(find.text('API Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Servis türünü seçin'), findsOneWidget);
    expect(find.text('Tek API katmanı'), findsOneWidget);
  });

  testWidgets('Sosyal medya hesap ekle menüsü hesap dialogunu açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sosyal Medya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hesap Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Sosyal Medya Hesapları'), findsOneWidget);
    expect(find.text('Canli Instagram'), findsOneWidget);
    expect(find.text('X / Twitter'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Hesap Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Sosyal medya hesabı bağla'), findsOneWidget);
    expect(find.text('Instagram ile giriş yap'), findsOneWidget);
    expect(find.text('Google Business Profile ile giriş yap'), findsOneWidget);
    expect(find.text('Slack ile giriş yap'), findsOneWidget);
  });

  testWidgets('Kullanıcı ekleme düzenleme silme modalları çalışır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final usersRepository = _FakeAdminUsersRepository();
    await _pumpAdminApp(tester, usersRepository: usersRepository);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kullanıcılar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kullanıcı Ekle'));
    await tester.pumpAndSettle();
    final addDialogFields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextFormField),
    );
    final addNameField = tester.widget<TextField>(
      find.descendant(
        of: addDialogFields.at(0),
        matching: find.byType(TextField),
      ),
    );
    expect(addNameField.mouseCursor, SystemMouseCursors.text);
    await tester.enterText(find.byType(TextFormField).at(0), 'Can Test');
    await tester.enterText(find.byType(TextFormField).at(1), 'can_test');
    await tester.enterText(find.byType(TextFormField).at(2), 'gizli123');
    await tester.enterText(
      find.byType(TextFormField).at(3),
      'can.test@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(4), 'gizli123');
    await tester.tap(find.text('Kaydet').last);
    await tester.pumpAndSettle();

    expect(usersRepository.createdUser?.email, 'can.test@pateeznews.com');
    expect(find.text('Can Test'), findsOneWidget);

    await tester.tap(find.text('...').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Can Test Güncel');
    await tester.tap(find.text('Kaydet').last);
    await tester.pumpAndSettle();

    expect(usersRepository.updatedUserId, 'created-user-id');
    expect(usersRepository.updatedUser?.fullName, 'Can Test Güncel');

    await tester.tap(find.text('Can Test Güncel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seçili 1 kaydı sil'));
    await tester.pumpAndSettle();
    expect(find.text('Seçili kullanıcılar silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Sil').last);
    await tester.pumpAndSettle();

    expect(usersRepository.deletedUserIds, contains('created-user-id'));
    expect(find.text('Can Test Güncel'), findsNothing);
  });

  testWidgets('Rol ve izin modalları repository akışını çalıştırır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rolesRepository = _FakeAdminRolesRepository();
    await _pumpAdminApp(tester, rolesRepository: rolesRepository);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rol & İzinler'));
    await tester.pumpAndSettle();

    expect(find.text('Süper Yönetici'), findsOneWidget);
    expect(find.text('Editör'), findsOneWidget);

    await tester.tap(find.text('Rol Adı'));
    await tester.pumpAndSettle();
    expect(_isTextAbove(tester, 'Editör', 'Süper Yönetici'), isTrue);

    await tester.tap(find.text('Sıra No'));
    await tester.pumpAndSettle();
    expect(_isTextAbove(tester, 'Süper Yönetici', 'Editör'), isTrue);

    await tester.tap(find.text('Rol Ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Test Rolü');
    await tester.enterText(find.byType(TextFormField).at(1), 'test_rolu');
    await tester.enterText(find.byType(TextFormField).at(2), '#2C3E50');
    await tester.tap(find.text('Kaydet').last);
    await tester.pumpAndSettle();

    expect(rolesRepository.createdRole?.name, 'test_rolu');
    expect(find.text('Test Rolü'), findsOneWidget);

    await tester.tap(find.text('...').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Test Rolü Güncel',
    );
    await tester.tap(find.text('Kaydet').last);
    await tester.pumpAndSettle();

    expect(rolesRepository.updatedRoleId, 'role-created');
    expect(rolesRepository.updatedRole?.label, 'Test Rolü Güncel');

    await tester.tap(find.text('...').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yetkileri Yönet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kullanıcı Yönetimi').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet').last);
    await tester.pumpAndSettle();

    expect(rolesRepository.savedPermissionsRoleId, 'role-created');
    expect(rolesRepository.savedPermissionKeys, contains('manage_users'));

    await tester.tap(find.text('...').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil').last);
    await tester.pumpAndSettle();
    expect(find.text('Rol silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Sil').last);
    await tester.pumpAndSettle();

    expect(rolesRepository.deletedRoleId, 'role-created');
    expect(find.text('Test Rolü Güncel'), findsNothing);
  });

  testWidgets('Dil ayarları alt menüsü ekranı açar', (tester) async {
    tester.view.physicalSize = const Size(1366, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dil Ayarları'));
    await tester.tap(find.text('Dil Ayarları'));
    await tester.pumpAndSettle();

    expect(find.text('Dil Ayarları'), findsOneWidget);
    expect(find.text('Listeyi Yazdır'), findsOneWidget);
    expect(find.text('Dil indir'), findsOneWidget);
    expect(find.text('İçe Aktar'), findsOneWidget);
    expect(find.text('Dil Ekle'), findsOneWidget);
    expect(find.text('Ara...'), findsWidgets);
    expect(find.text('Sıra No'), findsOneWidget);
    expect(find.text('Dil Adı'), findsOneWidget);
    expect(find.text('Varsayılan'), findsNWidgets(2));
    expect(find.text('İşlemler'), findsOneWidget);
    expect(find.text('Durum'), findsOneWidget);
    expect(find.text('İşlem'), findsOneWidget);
    expect(find.text('Türkçe'), findsWidgets);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('Varsayılan yap'), findsNWidgets(2));
    expect(find.text('Çevirileri Düzenle'), findsNWidgets(3));
    expect(find.text('Dili Dışa Aktar'), findsNWidgets(3));
    expect(find.text('Aktif'), findsNWidgets(3));
    expect(find.text('1 - 3 / 3 kayıt gösteriliyor'), findsOneWidget);
    expect(find.text('Seçili 1 kaydı sil'), findsNothing);

    await tester.tap(find.text('Dil Adı'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('English').first).dy <
          tester.getTopLeft(find.text('Türkçe').last).dy,
      isTrue,
    );

    await tester.tap(find.text('Sıra No'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Türkçe').last).dy <
          tester.getTopLeft(find.text('English').first).dy,
      isTrue,
    );

    await tester.tap(find.text('Türkçe').last);
    await tester.pumpAndSettle();

    expect(find.text('Seçili 1 kaydı sil'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('Seçili 3 kaydı sil'), findsOneWidget);

    await tester.tap(find.text('...').first);
    await tester.pumpAndSettle();

    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.text('Pasifleştir'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);
  });

  testWidgets('Dil ayarları repository modalları çalışır', (tester) async {
    tester.view.physicalSize = const Size(1366, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final languagesRepository = _FakeAdminLanguagesRepository();
    await _pumpAdminApp(tester, languagesRepository: languagesRepository);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dil Ayarları'));
    await tester.tap(find.text('Dil Ayarları'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dil Ekle'));
    await tester.pumpAndSettle();
    var dialogFields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(dialogFields.at(0), 'Testçe');
    await tester.enterText(dialogFields.at(1), 'tt');
    await tester.enterText(dialogFields.at(3), 'tt');
    await tester.tap(find.text('Kaydet').last);
    await tester.pumpAndSettle();

    expect(languagesRepository.upsertedLanguage?.code, 'tt');
    expect(find.text('Testçe'), findsOneWidget);

    await tester.tap(find.text('...').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
    dialogFields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(dialogFields.at(0), 'Testçe Güncel');
    await tester.tap(find.text('Kaydet').last);
    await tester.pumpAndSettle();

    expect(languagesRepository.upsertedLanguage?.name, 'Testçe Güncel');

    await tester.tap(find.text('Varsayılan yap').last);
    await tester.pumpAndSettle();
    expect(languagesRepository.defaultLanguageCode, 'tt');

    await tester.tap(find.text('Çevirileri Düzenle').last);
    await tester.pumpAndSettle();
    dialogFields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(dialogFields.at(1), 'Test panel');
    await tester.tap(find.text('Kaydet').last);
    await tester.pumpAndSettle();

    expect(languagesRepository.savedTranslationsCode, 'tt');
    expect(languagesRepository.savedTranslations, isNotEmpty);

    await tester.tap(find.text('Dili Dışa Aktar').last);
    await tester.pumpAndSettle();
    expect(languagesRepository.exportedLanguageCode, 'tt');
    expect(find.text('Dili Dışa Aktar'), findsWidgets);
    await tester.tap(
      find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byIcon(Symbols.close),
          )
          .first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('İçe Aktar'));
    await tester.pumpAndSettle();
    final importJson = jsonEncode({
      'meta': {
        'code': 'de',
        'name': 'Deutsch',
        'direction': 'ltr',
        'status': 'active',
        'flag_code': 'de',
      },
      'translations': {'login.title': 'Admin Login'},
    });
    await tester.enterText(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
          .first,
      importJson,
    );
    await tester.tap(find.text('Yükle'));
    await tester.pumpAndSettle();

    expect(languagesRepository.importedLanguageCode, 'de');
    expect(find.text('Deutsch'), findsOneWidget);

    await tester.tap(find.text('...').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil').last);
    await tester.pumpAndSettle();
    expect(find.text('Dil silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Sil').last);
    await tester.pumpAndSettle();

    expect(languagesRepository.deletedLanguageCode, 'de');
    expect(find.text('Deutsch'), findsNothing);
  });

  testWidgets('Genel ayarlar alt menüsü tablı ekranı açar', (tester) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final generalSettingsRepository = _FakeAdminGeneralSettingsRepository();
    await _pumpAdminApp(
      tester,
      generalSettingsRepository: generalSettingsRepository,
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Genel Ayarlar'));
    await tester.pumpAndSettle();

    expect(find.text('Genel Ayarlar'), findsOneWidget);
    expect(find.text('Ayarları Dili'), findsOneWidget);
    expect(find.text('Genel & Logo'), findsWidgets);
    expect(find.text('SEO Ayarları'), findsOneWidget);
    expect(find.text('Kurumsal (EEAT)'), findsOneWidget);
    expect(find.text('Google & Servisler'), findsOneWidget);
    expect(find.text('Özel Kodlar'), findsOneWidget);
    expect(find.text('Robots & Teknik'), findsOneWidget);
    expect(find.text('Site Adı'), findsOneWidget);
    expect(find.text('Pateeznews.com'), findsOneWidget);
    expect(find.text('Logo Ayarları'), findsOneWidget);
    expect(find.text('Logo Değiştir'), findsNWidgets(5));
    expect(find.text('Değişiklikleri Kaydet'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pateeznews.com'),
      'Pateeznews Test',
    );
    await tester.ensureVisible(find.text('Değişiklikleri Kaydet').last);
    await tester.tap(find.text('Değişiklikleri Kaydet').last);
    await tester.pumpAndSettle();

    expect(
      generalSettingsRepository.savedSettings?.siteName,
      'Pateeznews Test',
    );
    expect(find.text('Ayarlar başarıyla kaydedildi'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TextButton, 'SEO Ayarları'));
    await tester.tap(find.widgetWithText(TextButton, 'SEO Ayarları'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Sayfa Başlığı (SEO Title)'), findsOneWidget);
    expect(find.text('Global Paylaşım Görseli (OG Image)'), findsOneWidget);
    expect(find.text('Sitemap'), findsWidgets);
    expect(_findRichTextContaining('Sıklık'), findsOneWidget);
    expect(_findRichTextContaining('Son değişiklik'), findsOneWidget);
    expect(_findRichTextContaining('Öncelik'), findsOneWidget);
    expect(find.text('Otomatik hesapla'), findsNWidgets(3));
    expect(find.text('Sitemap Oluştur'), findsOneWidget);
    expect(find.text('Oluşturulan Sitemapler'), findsOneWidget);
    expect(find.text('sitemap.xml'), findsOneWidget);
    expect(
      find.text('https://www.pateez.com/service/cron/main?token=YOUR_TOKEN'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.widgetWithText(TextButton, 'Kurumsal (EEAT)'),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Kurumsal (EEAT)'));
    await tester.pumpAndSettle();

    expect(find.text('Resmi Kurum/Şirket Adı'), findsOneWidget);
    expect(find.text('Resmi Adres'), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(TextButton, 'Google & Servisler'),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Google & Servisler'));
    await tester.pumpAndSettle();

    expect(find.text('Google Analytics (GA4) ID'), findsOneWidget);
    expect(find.text('Google Search Console Doğrulama Kodu'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Özel Kodlar'));
    await tester.tap(find.widgetWithText(TextButton, 'Özel Kodlar'));
    await tester.pumpAndSettle();

    expect(find.text('Header Özel Kodlar (<head> içine)'), findsOneWidget);
    expect(find.text('Footer Özel Kodlar (</body> öncesi)'), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(TextButton, 'Robots & Teknik'),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Robots & Teknik'));
    await tester.pumpAndSettle();

    expect(find.text('Robots.txt İçeriği'), findsOneWidget);
  });

  testWidgets('Güvenlik ayarları alt menüsü tasarım ekranını açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Güvenlik Ayarları'));
    await tester.tap(find.text('Güvenlik Ayarları'));
    await tester.pumpAndSettle();

    expect(find.text('Güvenlik Ayarları'), findsOneWidget);
    expect(find.text('Giriş güvenliği'), findsOneWidget);
    expect(find.text('Maksimum giriş denemesi'), findsOneWidget);
    expect(find.text('Şifre güvenliği'), findsOneWidget);
    expect(find.text('Spam koruması'), findsOneWidget);
    expect(find.text('Captcha ayarları'), findsOneWidget);
    expect(find.text('Cloudflare Turnstile'), findsOneWidget);
    expect(find.text('Google reCAPTCHA'), findsOneWidget);
    expect(find.text('Uyarı'), findsOneWidget);
  });

  testWidgets('İçerik ayarları alt menüsü tasarım ekranını açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('İçerik Ayarları'));
    await tester.tap(find.text('İçerik Ayarları'));
    await tester.pumpAndSettle();

    expect(find.text('İçerik Ayarları'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Genel'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Gönderiler'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'Gönderi Formatları'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Dosya Yükleme'), findsOneWidget);
    expect(find.text('Manşet bölümünü göster'), findsOneWidget);
    expect(find.text('Ana sayfada son gönderileri göster'), findsNothing);
    expect(find.text('Öne Çıkan İçerik Ayarları'), findsOneWidget);
    expect(find.text('Manşet'), findsOneWidget);
    expect(find.text('Otomatik çöp kutusu temizleme'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Gönderiler'));
    await tester.pumpAndSettle();
    expect(find.text('Gönderi URL yapısı'), findsOneWidget);
    expect(find.text('Popüler gönderi limiti'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Gönderi Formatları'));
    await tester.pumpAndSettle();
    expect(find.text('Makale'), findsOneWidget);
    expect(find.text('Etkinlik'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Dosya Yükleme'));
    await tester.pumpAndSettle();
    expect(find.text('Görsel dosya formatı'), findsOneWidget);
    expect(find.text('İzin verilen dosya uzantıları'), findsOneWidget);
  });

  testWidgets('Font ayarları alt menüsü haber tablosu standardında açılır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1914, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Font Ayarları'));
    await tester.tap(find.text('Font Ayarları'));
    await tester.pumpAndSettle();

    expect(find.text('Font Ayarları'), findsOneWidget);
    expect(find.text('Site Fontu'), findsOneWidget);
    expect(find.text('Font Boyutu'), findsOneWidget);
    expect(find.text('Font Kaynağı'), findsOneWidget);
    expect(find.text('İşlem'), findsOneWidget);
    expect(find.text('Nunito Sans'), findsOneWidget);
    expect(find.text('Baloo 2 ExtraBold'), findsOneWidget);
    expect(find.text('Fredoka'), findsOneWidget);
    expect(find.text('Work Sans'), findsOneWidget);
    expect(find.text('1 - 25 / 25 kayıt gösteriliyor'), findsOneWidget);
    expect(find.text('Font Ekle'), findsOneWidget);

    await tester.tap(find.text('...').first);
    await tester.pumpAndSettle();

    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.text('Birincil font yap'), findsNothing);
    expect(find.text('Başlık fontu yap'), findsNothing);
    expect(find.text('İçerik fontu yap'), findsNothing);

    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();

    expect(find.text('Font Düzenle'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Kaydet'), findsOneWidget);

    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Font Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Font Ekle'), findsWidgets);
    expect(_findRichTextContaining('Font tipi'), findsOneWidget);
    expect(find.text('Sans Serif'), findsOneWidget);
    expect(_findRichTextContaining('Font dosyası (.woff2)'), findsOneWidget);
    expect(_findRichTextContaining('400 (Regular)'), findsOneWidget);
    expect(_findRichTextContaining('600 (Semi-Bold)'), findsOneWidget);
    expect(_findRichTextContaining('700 (Bold)'), findsOneWidget);
    expect(find.text('Dosya seç'), findsNWidgets(3));
  });

  testWidgets('Google News alt menüsü tasarım ekranını açar', (tester) async {
    tester.view.physicalSize = const Size(1660, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modüller'));
    await tester.pumpAndSettle();
    expect(_isTextAbove(tester, 'Google News', 'Yapay Zeka Ayarları'), isTrue);

    await tester.tap(find.text('Google News'));
    await tester.pumpAndSettle();

    expect(find.text('Google News'), findsWidgets);
    expect(find.text('Ayarlar'), findsWidgets);
    expect(find.text('Durum'), findsOneWidget);
    expect(
      find.textContaining('Google News Yayın Adı', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('RSS İçeriği', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Feed gönderi limiti', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Feed Link Oluşturucu'), findsOneWidget);
    expect(find.text('Dil'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Oluşturulan Feed URL'), findsOneWidget);
    expect(find.text('Kopyala'), findsOneWidget);
    expect(find.text('Entegrasyon Uçları'), findsOneWidget);
    expect(find.text('News Sitemap (SEO & Botlar için)'), findsOneWidget);
    expect(find.text('Publisher Center Feed (Uygulama için)'), findsOneWidget);
    expect(
      find.text('https://www.pateez.com/sitemap-news.xml'),
      findsOneWidget,
    );
    expect(
      find.text('https://www.pateez.com/service/feed/google-news?lang=1'),
      findsWidgets,
    );
    expect(find.text('Görüntüle'), findsNWidgets(2));

    await tester.tap(find.text('Değişiklikleri Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Google News ayarları kaydedildi'), findsOneWidget);
  });

  testWidgets('Depo alt menüsü tasarım ekranını açar', (tester) async {
    tester.view.physicalSize = const Size(1660, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modüller'));
    await tester.pumpAndSettle();
    expect(_isTextAbove(tester, 'Depo', 'Google News'), isTrue);
    expect(_isTextAbove(tester, 'Google News', 'Yapay Zeka Ayarları'), isTrue);

    await tester.tap(find.text('Depo'));
    await tester.pumpAndSettle();

    expect(find.text('Depo'), findsWidgets);
    expect(find.text('Aktif Depo'), findsOneWidget);
    expect(find.text('Yerel Depo'), findsOneWidget);
    expect(find.text('AWS S3'), findsOneWidget);
    expect(find.text('Cloudflare R2'), findsOneWidget);
    expect(find.text('Backblaze B2'), findsOneWidget);
    expect(find.text('Bunny.net'), findsOneWidget);
    expect(find.text('Google Drive'), findsOneWidget);
    expect(find.text('Access Key'), findsWidgets);
    expect(find.text('Secret Key'), findsWidgets);
    expect(find.text('Bucket Name'), findsWidgets);
    expect(find.text('Region'), findsOneWidget);

    await tester.tap(find.text('Bunny.net'));
    await tester.pumpAndSettle();

    expect(find.text('Storage Zone Name'), findsOneWidget);
    expect(find.text('Hostname'), findsOneWidget);
    expect(find.text('Pull Zone URL'), findsOneWidget);

    await tester.tap(find.text('Google Drive'));
    await tester.pumpAndSettle();

    expect(find.text('Client ID'), findsOneWidget);
    expect(find.text('Client Secret'), findsOneWidget);
    expect(find.text('Refresh Token'), findsOneWidget);
    expect(find.text('Folder ID'), findsOneWidget);

    await tester.tap(find.text('Değişiklikleri Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Depo ayarları kaydedildi'), findsOneWidget);
  });

  testWidgets('Yapay zeka ayarları sayfası ve promt modalı açılır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final aiRepository = _FakeAdminAiSettingsRepository();
    await _pumpAdminApp(tester, aiSettingsRepository: aiRepository);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modüller'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Yapay Zeka Ayarları'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yapay Zeka Ayarları'));
    await tester.pumpAndSettle();

    expect(find.text('Yapay Zeka Ayarları'), findsOneWidget);
    expect(find.text('Ayarları Dili'), findsNothing);
    expect(
      find.text(
        'Yapay zeka modellerini ve API anahtarlarınızı buradan yapılandırın.',
      ),
      findsOneWidget,
    );
    expect(find.text('Google AI (Gemini)'), findsWidgets);
    expect(find.text('Yapay Zeka Hazır Promtlar'), findsWidgets);
    expect(find.text('Google AI Aktif'), findsOneWidget);
    expect(find.text('Google AI API Key'), findsOneWidget);
    expect(find.text('API Bağlantısını Test Et'), findsOneWidget);
    expect(find.text('Google AI Modeli'), findsOneWidget);
    expect(find.text('Ücretsizleri göster'), findsOneWidget);
    expect(find.text('gemini-3-pro-preview'), findsOneWidget);
    expect(find.text('Değişiklikleri Kaydet'), findsOneWidget);

    final apiKeyField = find.byType(TextFormField).last;
    final testConnectionButton = find.widgetWithText(
      OutlinedButton,
      'API Bağlantısını Test Et',
    );
    expect(
      tester.getSize(apiKeyField).height,
      tester.getSize(testConnectionButton).height,
    );
    final apiKeyEditable = find.descendant(
      of: apiKeyField,
      matching: find.byType(EditableText),
    );
    expect(find.byTooltip('API anahtarını göster'), findsOneWidget);
    expect(tester.widget<EditableText>(apiKeyEditable).obscureText, isTrue);

    await tester.tap(find.byTooltip('API anahtarını göster'));
    await tester.pump();

    expect(find.byTooltip('API anahtarını gizle'), findsOneWidget);
    expect(tester.widget<EditableText>(apiKeyEditable).obscureText, isFalse);

    await tester.enterText(apiKeyField, 'updated-api-key');
    await tester.tap(find.text('API Bağlantısını Test Et'));
    await tester.pumpAndSettle();

    expect(aiRepository.testedApiKey, 'updated-api-key');
    expect(find.text('gemini-3-pro-preview'), findsOneWidget);

    await tester.tap(find.text('Değişiklikleri Kaydet'));
    await tester.pumpAndSettle();

    expect(aiRepository.savedSettings?.googleAiApiKey, 'updated-api-key');
    expect(aiRepository.savedSettings?.googleAiModel, 'gemini-3-pro-preview');

    await tester.tap(
      find.widgetWithText(TextButton, 'Yapay Zeka Hazır Promtlar'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yapay Zeka Hazır Promtlar'), findsWidgets);
    expect(find.text('Yeni Promt Ekle'), findsOneWidget);
    expect(find.text('Testi Geliştirerek Hazırla'), findsNothing);
    expect(find.text('Testi Metne Sadık Yerleştir'), findsNothing);
    expect(find.text('Anketi Geliştirerek Hazırla'), findsNothing);
    expect(find.text('Anketi Metne Sadık Yerleştir'), findsNothing);
    expect(find.text('Videoyu Geliştirerek Hazırla'), findsNothing);
    expect(find.text('Video İçerik Üretici'), findsOneWidget);
    expect(find.text('İçindekiler İçerik Üretici'), findsOneWidget);
    expect(find.text('Tarif İçerik Üretici'), findsOneWidget);
    expect(find.text('Etkinlik İçerik Üretici'), findsOneWidget);
    expect(find.text('Haber Hazırla 1'), findsOneWidget);
    expect(find.byTooltip('Promtu düzenle'), findsNWidgets(7));
    expect(find.byTooltip('Promtu sil'), findsNWidgets(7));

    await tester.ensureVisible(find.text('Haber Hazırla 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Promtu düzenle').last);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Promt Düzenle'),
      ),
      findsOneWidget,
    );
    expect(find.text('Promt Başlığı'), findsOneWidget);
    expect(find.text('Sistem Komutu (Promt)'), findsOneWidget);
    expect(find.text('İptal'), findsOneWidget);
    expect(find.text('Kaydet'), findsOneWidget);

    final dialogFields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(dialogFields.at(0), 'Düzenlenmiş Promt');
    await tester.enterText(dialogFields.at(1), 'Düzenlenmiş sistem talimatı.');
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(TextButton, 'Kaydet'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Düzenlenmiş Promt'), findsOneWidget);
    expect(aiRepository.savedPromptId, 'format-1');
    expect(aiRepository.savedPrompt?.prompt, 'Düzenlenmiş sistem talimatı.');

    await tester.tap(find.byTooltip('Promtu sil').last);
    await tester.pumpAndSettle();

    expect(find.text('Düzenlenmiş Promt'), findsNothing);
    expect(aiRepository.deletedPromptId, 'format-1');

    await tester.ensureVisible(find.text('Yeni Promt Ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni Promt Ekle'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Yeni Promt Ekle'),
      ),
      findsOneWidget,
    );
    expect(find.text('Promt Başlığı'), findsOneWidget);
    expect(find.text('Sistem Komutu (Promt)'), findsOneWidget);
    expect(find.text('İptal'), findsOneWidget);
    expect(find.text('Kaydet'), findsOneWidget);

    final addDialogFields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(addDialogFields.at(0), 'Yeni Canlı Promt');
    await tester.enterText(
      addDialogFields.at(1),
      'Yeni canlı sistem talimatı.',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(TextButton, 'Kaydet'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yeni Canlı Promt'), findsOneWidget);
    expect(aiRepository.savedPromptId, isNull);
    expect(aiRepository.savedPrompt?.title, 'Yeni Canlı Promt');

    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Nöbetçi eczane ayarları bölge ve önizleme ekranlarını açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modüller'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nöbetçi Eczane Ayarları'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nöbetçi Eczane Ayarları'));
    await tester.pumpAndSettle();

    expect(find.text('Nöbetçi Eczane Ayarları'), findsOneWidget);
    expect(find.text('Ayarları Dili'), findsNothing);
    expect(find.text('Genel Ayarlar'), findsNothing);
    expect(find.text('Şehir Yönetimi'), findsWidgets);
    expect(find.text('Canlı Önizleme'), findsOneWidget);
    expect(find.text('Nöbetçi Eczane Aktif'), findsOneWidget);
    expect(find.text('Varsayılan Bölge'), findsNothing);
    expect(find.text('Türkiye / Niğde'), findsOneWidget);
    expect(find.text('Open cache • 15 dk'), findsOneWidget);
    expect(find.text('Gece 00:00 Koruması'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Türkiye / Niğde')).dx,
      greaterThan(tester.getTopLeft(find.text('Veri Kaynağı')).dx),
    );
    expect(
      tester.getTopLeft(find.text('Cache Süresi')).dy,
      greaterThan(tester.getTopLeft(find.text('Veri Kaynağı')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Open cache • 15 dk')).dy,
      greaterThan(tester.getTopLeft(find.text('Cache Süresi')).dy),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Şehir Yönetimi'));
    await tester.pumpAndSettle();

    expect(find.text('Bölge Ekle'), findsWidgets);
    expect(find.text('Türkiye / Niğde'), findsWidgets);
    expect(find.text('Türkiye / İstanbul'), findsNothing);
    expect(find.text('Almanya / Berlin'), findsNothing);
    expect(find.text('Varsayılan konum'), findsOneWidget);
    expect(find.text('Aktif'), findsWidgets);
    expect(find.byTooltip('Bölgeyi düzenle'), findsOneWidget);
    expect(find.byTooltip('Bölgeyi sil'), findsOneWidget);

    await tester.tap(find.text('Bölge Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Bölge Ekle'), findsWidgets);
    expect(find.text('Ülke'), findsOneWidget);
    expect(find.text('Şehir'), findsOneWidget);
    expect(find.text('İlçeler / Bölgeler'), findsWidgets);
    expect(find.text('Semt / Mahalle'), findsNothing);
    expect(find.text('Tümünü seç'), findsOneWidget);
    expect(find.text('Bölge Aktif'), findsOneWidget);
    expect(find.text('Varsayılan Bölge'), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byIcon(Symbols.close),
          )
          .first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Canlı Önizleme'));
    await tester.pumpAndSettle();

    expect(find.text('Veriyi Yenile'), findsOneWidget);
    expect(find.text('Niğde Canlı Önizleme'), findsOneWidget);
    expect(find.text('database'), findsOneWidget);
    expect(find.text('İstanbul'), findsNothing);
    expect(find.text('Berlin'), findsNothing);
    expect(find.text('MERKEZ'), findsWidgets);
    expect(find.text('DEVA ECZANESİ'), findsOneWidget);
    expect(find.text('ÖZTÜRK ECZANESİ'), findsOneWidget);
    expect(find.text('Yol Tarifi'), findsWidgets);
  });

  testWidgets(
    'Hava durumu ayarları şehir yönetimi ve önizleme ekranlarını açar',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpAdminApp(tester);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'editor@pateeznews.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Modüller'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Hava Durumu Ayarları'));
      await tester.tap(find.text('Hava Durumu Ayarları'));
      await tester.pumpAndSettle();

      expect(find.text('Hava Durumu Ayarları'), findsOneWidget);
      expect(find.text('Ayarları Dili'), findsNothing);
      expect(find.text('Genel Ayarlar'), findsNothing);
      expect(find.text('Şehir Yönetimi'), findsWidgets);
      expect(find.text('Canlı Önizleme'), findsOneWidget);
      expect(find.text('Hava Durumu Aktif'), findsOneWidget);
      expect(find.text('Şehir Ara'), findsNothing);
      expect(find.text('Varsayılan Şehir'), findsNothing);
      expect(find.text('Veri Kaynağı'), findsNothing);
      expect(find.text('Enlem'), findsNothing);
      expect(find.text('Boylam'), findsNothing);
      expect(find.text('Saat Dilimi'), findsNothing);
      expect(find.text('Open-Meteo'), findsNothing);
      expect(find.text('Europe/Istanbul'), findsNothing);
      expect(find.text('Yenileme Aralığı'), findsOneWidget);
      expect(find.text('Türkiye / Niğde'), findsOneWidget);
      expect(find.text('Değişiklikleri Kaydet'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Türkiye / Niğde')).dx,
        greaterThan(tester.getTopLeft(find.text('Yenileme Aralığı')).dx),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Şehir Yönetimi'));
      await tester.pumpAndSettle();

      expect(find.text('Şehir Ekle'), findsWidgets);
      expect(find.text('Türkiye / Niğde'), findsOneWidget);
      expect(find.text('Türkiye / İstanbul'), findsNothing);
      expect(find.text('Almanya / Berlin'), findsNothing);
      expect(find.text('Varsayılan şehir'), findsOneWidget);
      expect(find.byTooltip('Şehri düzenle'), findsOneWidget);
      expect(find.byTooltip('Şehri sil'), findsOneWidget);

      await tester.tap(find.text('Şehir Ekle'));
      await tester.pumpAndSettle();

      expect(find.text('Şehir Ekle'), findsWidgets);
      expect(find.text('Ülke'), findsOneWidget);
      expect(find.text('Şehir'), findsOneWidget);
      expect(find.text('Enlem'), findsWidgets);
      expect(find.text('Boylam'), findsWidgets);
      expect(find.text('Saat Dilimi'), findsWidgets);
      expect(find.text('Kaynak'), findsOneWidget);
      expect(find.text('Şehir Aktif'), findsOneWidget);
      expect(find.text('Varsayılan Şehir'), findsOneWidget);
      expect(find.text('İptal'), findsOneWidget);
      expect(find.text('Kaydet'), findsOneWidget);

      await tester.tap(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byIcon(Symbols.close),
            )
            .first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Canlı Önizleme'));
      await tester.pumpAndSettle();

      expect(find.text('Niğde Canlı Önizleme'), findsOneWidget);
      expect(find.text('22°'), findsOneWidget);
      expect(find.text('Parçalı bulutlu'), findsOneWidget);
      expect(find.text('Yenileme Aralığı'), findsOneWidget);
      expect(
        find.text('Open-Meteo isteği 30 dakikada bir yenilenir.'),
        findsOneWidget,
      );
      expect(find.text('İstanbul'), findsNothing);
      expect(find.text('Berlin'), findsNothing);
    },
  );

  testWidgets('Namaz vakitleri ayarları Diyanet kaynak formunu açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modüller'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Namaz Vakitleri Ayarları'));
    await tester.tap(find.text('Namaz Vakitleri Ayarları'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Namaz Vakitleri Ayarları'), findsOneWidget);
    expect(find.text('Şehir Yönetimi'), findsWidgets);
    expect(find.text('Canlı Önizleme'), findsOneWidget);
    expect(find.text('Namaz Vakitleri Aktif'), findsOneWidget);
    expect(find.text('Diyanet kaynak URL'), findsOneWidget);
    expect(find.text('Diyanet il ID'), findsOneWidget);
    expect(find.text('Diyanet şehir ID'), findsOneWidget);
    expect(find.text('Türkiye / Niğde'), findsOneWidget);
    expect(find.text('Diyanet şehir ID 9766'), findsOneWidget);
    expect(find.text('Değişiklikleri Kaydet'), findsOneWidget);
    expect(find.textContaining('Awqat'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Canlı Önizleme'));
    await tester.pumpAndSettle();

    expect(find.text('Veriyi Yenile'), findsOneWidget);
    expect(find.text('Niğde'), findsWidgets);
    expect(find.text('Günün Ayeti'), findsOneWidget);
    expect(find.text('İmsak'), findsOneWidget);
    expect(find.text('Yatsı'), findsOneWidget);
  });

  testWidgets(
    'Ölüm ilanları ayarı konum yönetimi ve önizleme ekranlarını açar',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpAdminApp(tester);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'editor@pateeznews.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Modüller'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('admin-sidebar')),
        const Offset(0, -90),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ölüm İlanları Ayarı'));
      await tester.pumpAndSettle();

      expect(find.text('Ölüm İlanları Ayarı'), findsOneWidget);
      expect(find.text('Ayarları Dili'), findsNothing);
      expect(find.text('Genel Ayarlar'), findsNothing);
      expect(find.text('Şehir Yönetimi'), findsWidgets);
      expect(find.text('Canlı Önizleme'), findsOneWidget);
      expect(find.text('Ölüm İlanları Aktif'), findsOneWidget);
      expect(find.text('Varsayılan Konum'), findsNothing);
      expect(find.text('Türkiye / Niğde'), findsOneWidget);
      expect(find.text('nigde.bel.tr/vefat-edenler'), findsWidgets);
      expect(find.text('Open cache • 30 dk'), findsOneWidget);
      expect(find.text('Gün Tarihi Koruması'), findsOneWidget);
      expect(find.text('Değişiklikleri Kaydet'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Türkiye / Niğde')).dx,
        greaterThan(tester.getTopLeft(find.text('Veri Kaynağı')).dx),
      );
      expect(
        tester.getTopLeft(find.text('Cache Süresi')).dy,
        greaterThan(tester.getTopLeft(find.text('Veri Kaynağı')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Open cache • 30 dk')).dy,
        greaterThan(tester.getTopLeft(find.text('Cache Süresi')).dy),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Şehir Yönetimi'));
      await tester.pumpAndSettle();

      expect(find.text('Konum Ekle'), findsWidgets);
      expect(find.text('Türkiye / Niğde'), findsWidgets);
      expect(find.text('Türkiye / İstanbul'), findsNothing);
      expect(find.text('Almanya / Berlin'), findsNothing);
      expect(find.text('Varsayılan konum'), findsOneWidget);
      expect(find.byTooltip('Konumu düzenle'), findsOneWidget);
      expect(find.byTooltip('Konumu sil'), findsOneWidget);
      expect(find.text('Hıdırlık'), findsWidgets);
      expect(find.text('Merkez'), findsNothing);

      await tester.tap(find.text('Konum Ekle'));
      await tester.pumpAndSettle();

      expect(find.text('Konum Ekle'), findsWidgets);
      expect(find.text('Ülke'), findsOneWidget);
      expect(find.text('Şehir'), findsOneWidget);
      expect(find.text('Kaynak'), findsOneWidget);
      expect(find.text('İlçeler'), findsWidgets);
      expect(find.text('Tümünü seç'), findsOneWidget);
      expect(find.text('Konum Aktif'), findsOneWidget);
      expect(find.text('Varsayılan Konum'), findsOneWidget);
      expect(find.text('İptal'), findsOneWidget);
      expect(find.text('Kaydet'), findsOneWidget);

      await tester.tap(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byIcon(Symbols.close),
            )
            .first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Canlı Önizleme'));
      await tester.pumpAndSettle();

      expect(find.text('Veriyi Yenile'), findsOneWidget);
      expect(find.text('Niğde Canlı Önizleme'), findsOneWidget);
      expect(find.text('database'), findsOneWidget);
      expect(find.text('İstanbul'), findsNothing);
      expect(find.text('Berlin'), findsNothing);
      expect(find.text('ŞABAN EFE ÇAVUŞ'), findsOneWidget);
      expect(find.text('22 Mayıs 2026'), findsWidgets);
      expect(find.text('ÖĞLE - HIDIRLIK'), findsOneWidget);
    },
  );

  testWidgets('Duyuru ayarları yayındaki haberi duyuruya bağlar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final moduleRepository = _FakeAdminModuleSettingsRepository();
    final newsRepository = _FakeAdminNewsRepository();

    await _pumpAdminApp(
      tester,
      moduleSettingsRepository: moduleRepository,
      newsRepository: newsRepository,
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modüller'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('admin-sidebar')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Duyuru Ayarları'));
    await tester.tap(find.text('Duyuru Ayarları'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Canlı Önizleme'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Düzenle'));
    await tester.pumpAndSettle();

    expect(find.text('Bağlı haber'), findsOneWidget);
    await tester.ensureVisible(find.text('Haber Seç'));
    await tester.tap(find.text('Haber Seç'));
    await tester.pumpAndSettle();

    expect(find.text('Duyuruya Haber Bağla'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'ruh');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Niğde Ruhun').last);
    await tester.pumpAndSettle();

    expect(find.text('Değiştir'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet').last);
    await tester.pumpAndSettle();

    expect(moduleRepository.savedAnnouncement?.linkedPostId, '23');
    expect(
      moduleRepository.savedAnnouncement?.linkedPostTitle,
      contains('Niğde Ruhun'),
    );
  });

  testWidgets('Beni hatırla giriş bilgilerini kaydeder', (tester) async {
    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    final rememberedLogin = await const RememberedLoginStore().read();
    expect(rememberedLogin.enabled, isTrue);
    expect(rememberedLogin.email, 'editor@pateeznews.com');
    expect(rememberedLogin.password, 'gizli123');
  });

  testWidgets('Kayıtlı giriş bilgilerini forma yükler', (tester) async {
    await const RememberedLoginStore().save(
      email: 'editor@pateeznews.com',
      password: 'gizli123',
    );

    await _pumpAdminApp(tester);
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(0),
    );
    final passwordField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );

    expect(emailField.controller?.text, 'editor@pateeznews.com');
    expect(passwordField.controller?.text, 'gizli123');
  });

  testWidgets('Enter giriş butonunu çalıştırır', (tester) async {
    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.tap(find.byType(TextFormField).at(1));
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Yayın akışı'), findsOneWidget);
  });

  testWidgets('Üst bar dil seçiciyi site önizleme yanında gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.text('Türkçe'), findsOneWidget);
    expect(find.text('Siteyi Görüntüle'), findsOneWidget);

    final searchField = find.byType(TextField).first;
    final searchRight = tester.getTopRight(searchField).dx;
    final languageLeft = tester.getTopLeft(find.text('Türkçe')).dx;
    final languageRight = tester.getTopRight(find.text('Türkçe')).dx;
    final sitePreviewLeft = tester.getTopLeft(find.text('Siteyi Görüntüle')).dx;

    expect(tester.getSize(searchField).width, greaterThan(320));
    expect(tester.getSize(searchField).height, lessThan(40));
    expect(searchRight < languageLeft, isTrue);
    expect(languageRight < sitePreviewLeft, isTrue);
  });

  testWidgets(
    'Çevirileri Düzenle modal penceresini açar, satır ekler ve kapatır',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpAdminApp(tester);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'editor@pateeznews.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ayarlar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dil Ayarları'));
      await tester.tap(find.text('Dil Ayarları'));
      await tester.pumpAndSettle();

      // Click "Çevirileri Düzenle" on the first row
      await tester.tap(find.text('Çevirileri Düzenle').first);
      await tester.pumpAndSettle();

      // Verify modal is open and has correct text
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Çevirileri Düzenle'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Seçilen dil için metin çevirilerini güncelleyin.'),
        findsOneWidget,
      );
      expect(find.text('Türkçe (tr)'), findsOneWidget);
      expect(find.text('Anahtar / İngilizce'), findsOneWidget);
      expect(find.text('Çeviri'), findsOneWidget);

      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextFormField),
        ),
        findsWidgets,
      );

      // Tap "Çeviri satırı ekle"
      await tester.tap(find.text('Çeviri satırı ekle'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);

      // Close the dialog using Cancel
      await tester.tap(find.widgetWithText(TextButton, 'İptal'));
      await tester.pumpAndSettle();

      // Verify modal is closed
      expect(
        find.text('Seçilen dil için metin çevirilerini güncelleyin.'),
        findsNothing,
      );
    },
  );

  testWidgets('Dil İçe Aktar modal penceresini açar ve kapatır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAdminApp(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'editor@pateeznews.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dil Ayarları'));
    await tester.tap(find.text('Dil Ayarları'));
    await tester.pumpAndSettle();

    // Click "İçe Aktar" in toolbar
    await tester.tap(find.text('İçe Aktar'));
    await tester.pumpAndSettle();

    // Verify modal is open and has correct text
    expect(find.text('Dil İçe Aktar'), findsOneWidget);
    expect(
      find.text('JSON dil dosyasını yapıştırın veya bir dosya seçin.'),
      findsOneWidget,
    );
    expect(find.text('JSON İçeriği'), findsOneWidget);
    expect(find.text('{}'), findsOneWidget);
    expect(find.text('Dosya Seç'), findsOneWidget);
    expect(find.text('Örnek JSON indir'), findsOneWidget);

    // Close using close icon at top right
    await tester.tap(find.byIcon(Symbols.close));
    await tester.pumpAndSettle();

    // Verify modal is closed
    expect(find.text('Dil İçe Aktar'), findsNothing);
  });
}

Finder _findRichTextContaining(String text) {
  return find.byWidgetPredicate((widget) {
    return widget is RichText && widget.text.toPlainText().contains(text);
  });
}
