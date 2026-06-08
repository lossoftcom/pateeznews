import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';
import '../presentation/users_models.dart';

abstract class AdminRolesRepository {
  Future<RolesPermissionsPageResult> fetchRolesPermissions({
    required String search,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  });

  Future<Set<String>> fetchPermissionKeysForRole(String roleName);

  Future<void> createRole({
    required AdminSession session,
    required RoleFormData data,
  });

  Future<void> updateRole({
    required AdminSession session,
    required String roleId,
    required RoleFormData data,
  });

  Future<void> deleteRole({
    required AdminSession session,
    required String roleId,
  });

  Future<void> saveRolePermissions({
    required AdminSession session,
    required String roleId,
    required List<String> permissionKeys,
  });
}

class SupabaseAdminRolesRepository implements AdminRolesRepository {
  const SupabaseAdminRolesRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<RolesPermissionsPageResult> fetchRolesPermissions({
    required String search,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final responses = await Future.wait([
      _postJson('/api/admin/query', {
        'table': 'roles',
        'method': 'select',
        'select': 'id,name,label,description,color,created_at',
        'orders': [
          {'column': 'created_at', 'ascending': true},
        ],
      }),
      _postJson('/api/admin/query', {
        'table': 'permissions',
        'method': 'select',
        'select': 'id,key,label,group_name,description',
        'orders': [
          {'column': 'group_name', 'ascending': true},
          {'column': 'label', 'ascending': true},
        ],
      }),
      _postJson('/api/admin/query', {
        'table': 'role_permissions',
        'method': 'select',
        'select': 'role_id,permission_key',
      }),
      _postJson('/api/admin/query', {
        'table': 'profiles',
        'method': 'select',
        'select': 'role',
        'filters': [
          {
            'type': 'comparison',
            'op': 'neq',
            'column': 'role',
            'value': 'publisher',
          },
        ],
      }),
    ]);

    for (final response in responses) {
      _throwIfApiError(response, fallbackMessage: 'Rol verileri alınamadı');
    }

    final permissions = _permissionsFromData(responses[1]['data']);
    final permissionByKey = {
      for (final permission in permissions) permission.key: permission,
    };
    final permissionKeysByRoleId = _permissionKeysByRoleId(
      responses[2]['data'],
    );
    final memberCounts = _memberCountsByRole(responses[3]['data']);
    final allRoles = _rolesFromData(
      responses[0]['data'],
      permissionKeysByRoleId,
      permissionByKey,
      memberCounts,
    );

    final term = search.trim().toLowerCase();
    final filtered = term.isEmpty
        ? allRoles
        : allRoles
              .where(
                (role) =>
                    role.name.toLowerCase().contains(term) ||
                    role.label.toLowerCase().contains(term) ||
                    role.description.toLowerCase().contains(term),
              )
              .toList(growable: false);

    final sorted = filtered.toList(growable: false)
      ..sort((a, b) => _compareRoles(a, b, sortKey, sortAscending));
    final safePage = page < 1 ? 1 : page;
    final from = (safePage - 1) * pageSize;
    final paged = from >= sorted.length
        ? const <ManagedRole>[]
        : sorted.skip(from).take(pageSize).toList(growable: false);

    return RolesPermissionsPageResult(
      roles: paged,
      permissions: permissions,
      totalCount: sorted.length,
    );
  }

  @override
  Future<Set<String>> fetchPermissionKeysForRole(String roleName) async {
    final safeRoleName = roleName.trim();
    if (safeRoleName.isEmpty) return const {};
    if (safeRoleName == 'admin' || safeRoleName == 'super_admin') {
      return {'*'};
    }

    final roleResult = await _postJson('/api/admin/query', {
      'table': 'roles',
      'method': 'select',
      'select': 'id',
      'filters': [
        {
          'type': 'comparison',
          'op': 'eq',
          'column': 'name',
          'value': safeRoleName,
        },
      ],
      'single': 'maybeSingle',
    });
    _throwIfApiError(roleResult, fallbackMessage: 'Rol bilgisi alınamadı');
    final roleData = roleResult['data'];
    if (roleData is! Map) return const {};
    final roleId = roleData['id']?.toString() ?? '';
    if (roleId.isEmpty) return const {};

    final permissionResult = await _postJson('/api/admin/query', {
      'table': 'role_permissions',
      'method': 'select',
      'select': 'permission_key',
      'filters': [
        {
          'type': 'comparison',
          'op': 'eq',
          'column': 'role_id',
          'value': roleId,
        },
      ],
    });
    _throwIfApiError(
      permissionResult,
      fallbackMessage: 'Rol izinleri alınamadı',
    );
    final data = permissionResult['data'];
    if (data is! List) return const {};
    return data
        .whereType<Map>()
        .map((item) => item['permission_key']?.toString() ?? '')
        .where((key) => key.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> createRole({
    required AdminSession session,
    required RoleFormData data,
  }) {
    return _accountAction(session, 'admin-create-role', _rolePayload(data));
  }

  @override
  Future<void> updateRole({
    required AdminSession session,
    required String roleId,
    required RoleFormData data,
  }) {
    return _accountAction(session, 'admin-update-role', {
      'roleId': roleId,
      ..._rolePayload(data),
    });
  }

  @override
  Future<void> deleteRole({
    required AdminSession session,
    required String roleId,
  }) {
    return _accountAction(session, 'admin-delete-role', {'roleId': roleId});
  }

  @override
  Future<void> saveRolePermissions({
    required AdminSession session,
    required String roleId,
    required List<String> permissionKeys,
  }) {
    return _accountAction(session, 'admin-set-role-permissions', {
      'roleId': roleId,
      'permissionKeys': permissionKeys,
    });
  }

  Map<String, Object?> _rolePayload(RoleFormData data) {
    return {
      'name': data.name.trim().toLowerCase(),
      'label': data.label.trim(),
      'description': data.description.trim(),
      'color': data.color.trim(),
    };
  }

  Future<void> _accountAction(
    AdminSession session,
    String action,
    Map<String, Object?> payload,
  ) async {
    final result = await _postJson('/api/app/account', {
      'action': action,
      'token': session.accessToken,
      ...payload,
    }, token: session.accessToken);
    _throwIfApiError(result, fallbackMessage: 'Rol işlemi tamamlanamadı');
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body, {
    String? token,
  }) async {
    final headers = await adminJsonHeaders(token: token);

    final response =
        await (httpClient?.post(
                  _uri(path),
                  headers: headers,
                  body: jsonEncode(body),
                ) ??
                adminHttpClient.post(
                  _uri(path),
                  headers: headers,
                  body: jsonEncode(body),
                ))
            .timeout(_requestTimeout);

    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminRolesException('Geçersiz sunucu yanıtı');
    }

    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfApiError(result, fallbackMessage: 'Sunucu isteği başarısız');
    }
    return result;
  }

  Uri _uri(String path) {
    final baseUrl = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (baseUrl.isNotEmpty) return Uri.parse(baseUrl).resolve(path);
    if (!kIsWeb) return _defaultLocalApiBaseUrl().resolve(path);
    return Uri.base.resolve(path);
  }

  Uri _defaultLocalApiBaseUrl() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse('http://10.0.2.2:4321'),
      _ => Uri.parse('http://127.0.0.1:4321'),
    };
  }

  List<AdminPermission> _permissionsFromData(Object? data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(_asStringKeyMap)
        .map(
          (item) => AdminPermission(
            id: item['id']?.toString() ?? '',
            key: item['key']?.toString() ?? '',
            label: item['label']?.toString() ?? '',
            groupName: item['group_name']?.toString() ?? 'system',
            description: item['description']?.toString() ?? '',
          ),
        )
        .where((permission) => permission.key.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, List<String>> _permissionKeysByRoleId(Object? data) {
    final byRoleId = <String, List<String>>{};
    if (data is! List) return byRoleId;
    for (final row in data.whereType<Map>()) {
      final item = _asStringKeyMap(row);
      final roleId = item['role_id']?.toString() ?? '';
      final permissionKey = item['permission_key']?.toString() ?? '';
      if (roleId.isEmpty || permissionKey.isEmpty) continue;
      byRoleId.putIfAbsent(roleId, () => <String>[]).add(permissionKey);
    }
    return byRoleId;
  }

  Map<String, int> _memberCountsByRole(Object? data) {
    final counts = <String, int>{};
    if (data is! List) return counts;
    for (final row in data.whereType<Map>()) {
      final role = row['role']?.toString() ?? 'member';
      if (role.isEmpty) continue;
      counts[role] = (counts[role] ?? 0) + 1;
    }
    return counts;
  }

  List<ManagedRole> _rolesFromData(
    Object? data,
    Map<String, List<String>> permissionKeysByRoleId,
    Map<String, AdminPermission> permissionByKey,
    Map<String, int> memberCounts,
  ) {
    if (data is! List) return const [];
    final roles = data
        .whereType<Map>()
        .map(_asStringKeyMap)
        .map((item) {
          final id = item['id']?.toString() ?? '';
          final name = item['name']?.toString() ?? '';
          final permissionKeys = permissionKeysByRoleId[id] ?? const <String>[];
          final permissionLabels = permissionKeys
              .map((key) => permissionByKey[key]?.label ?? key)
              .where((label) => label.trim().isNotEmpty)
              .toList(growable: false);
          return ManagedRole(
            id: id,
            rowNumber: 0,
            name: name,
            label: item['label']?.toString() ?? name,
            description: item['description']?.toString() ?? '',
            color: item['color']?.toString() ?? '#2C3E50',
            memberCount: memberCounts[name] ?? 0,
            permissionKeys: List.unmodifiable(permissionKeys),
            permissionLabels: permissionLabels,
            createdAt: DateTime.tryParse(item['created_at']?.toString() ?? ''),
          );
        })
        .where((role) => role.id.isNotEmpty && role.name.isNotEmpty)
        .toList();

    roles.sort((a, b) {
      if (a.name == 'admin') return -1;
      if (b.name == 'admin') return 1;
      return a.label.compareTo(b.label);
    });

    return [
      for (var index = 0; index < roles.length; index++)
        ManagedRole(
          id: roles[index].id,
          rowNumber: index + 1,
          name: roles[index].name,
          label: roles[index].label,
          description: roles[index].description,
          color: roles[index].color,
          memberCount: roles[index].memberCount,
          permissionKeys: roles[index].permissionKeys,
          permissionLabels: roles[index].permissionLabels,
          createdAt: roles[index].createdAt,
        ),
    ];
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

  void _throwIfApiError(
    Map<String, Object?> result, {
    required String fallbackMessage,
  }) {
    final error = result['error'];
    if (error == null) return;
    if (error is Map) {
      final message = error['message']?.toString();
      if (message != null && message.isNotEmpty) {
        throw AdminRolesException(message);
      }
    }
    throw AdminRolesException(fallbackMessage);
  }
}

class AdminRolesException implements Exception {
  const AdminRolesException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}
