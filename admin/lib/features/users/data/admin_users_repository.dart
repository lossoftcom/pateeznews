import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';
import 'package:pateeznews_admin/shared/constants/turkey_cities.dart';

import '../../auth/data/admin_auth_models.dart';
import '../presentation/users_models.dart';

abstract class AdminUsersRepository {
  Future<List<AdminUserRole>> fetchRoles();

  Future<UserMetrics> fetchMetrics();

  Future<UsersPageResult> fetchUsers({
    required String search,
    required String role,
    required String reward,
    required String status,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  });

  Future<void> createUser({
    required AdminSession session,
    required UserFormData data,
  });

  Future<void> updateUser({
    required AdminSession session,
    required String userId,
    required UserFormData data,
  });

  Future<void> deleteUser({
    required AdminSession session,
    required String userId,
  });

  Future<void> deleteUsers({
    required AdminSession session,
    required List<String> userIds,
  });
}

class SupabaseAdminUsersRepository implements AdminUsersRepository {
  const SupabaseAdminUsersRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 8);
  static const _all = 'Tümü';
  static const _fallbackRoles = [
    AdminUserRole(id: 'admin', name: 'admin', label: 'Süper Yönetici'),
    AdminUserRole(id: 'editor', name: 'editor', label: 'Editör'),
    AdminUserRole(id: 'moderator', name: 'moderator', label: 'Moderatör'),
    AdminUserRole(id: 'member', name: 'member', label: 'Standart Üye'),
  ];

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<List<AdminUserRole>> fetchRoles() async {
    final result = await _postJson('/api/admin/query', {
      'table': 'roles',
      'method': 'select',
      'select': 'id,name,label',
      'filters': [
        {
          'type': 'comparison',
          'op': 'neq',
          'column': 'name',
          'value': 'publisher',
        },
      ],
      'orders': [
        {'column': 'created_at', 'ascending': true},
      ],
    });

    _throwIfApiError(result, fallbackMessage: 'Roller alınamadı');
    final data = result['data'];
    if (data is! List) return _fallbackRoles;

    final roles = data
        .whereType<Map>()
        .map(_asStringKeyMap)
        .map(
          (item) => AdminUserRole(
            id: item['id']?.toString() ?? '',
            name: item['name']?.toString() ?? '',
            label: item['label']?.toString() ?? '',
          ),
        )
        .where((role) => role.name.isNotEmpty && role.name != 'publisher')
        .toList(growable: false);

    return roles.isEmpty ? _fallbackRoles : roles;
  }

  @override
  Future<UserMetrics> fetchMetrics() async {
    final base = _baseUserFilters();
    final counts = await Future.wait([
      _countProfiles(base),
      _countProfiles([
        ...base,
        {
          'type': 'comparison',
          'op': 'eq',
          'column': 'reward_system',
          'value': true,
        },
      ]),
      _countProfiles([
        ...base,
        {
          'type': 'comparison',
          'op': 'eq',
          'column': 'status',
          'value': 'Aktif',
        },
      ]),
      _countProfiles([
        ...base,
        {
          'type': 'comparison',
          'op': 'neq',
          'column': 'status',
          'value': 'Aktif',
        },
      ]),
    ]);

    return UserMetrics(
      total: counts[0],
      rewardEnabled: counts[1],
      active: counts[2],
      pending: counts[3],
    );
  }

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
    final filters = _baseUserFilters();
    if (role != _all) {
      filters.add({
        'type': 'comparison',
        'op': 'eq',
        'column': 'role',
        'value': role,
      });
    }
    if (reward == 'Aktif' || reward == 'Pasif') {
      filters.add({
        'type': 'comparison',
        'op': 'eq',
        'column': 'reward_system',
        'value': reward == 'Aktif',
      });
    }
    if (status != _all) {
      filters.add({
        'type': 'comparison',
        'op': 'eq',
        'column': 'status',
        'value': status,
      });
    }

    final term = _safeSearchTerm(search);
    if (term.isNotEmpty) {
      final pattern = '%$term%';
      filters.add({
        'type': 'or',
        'value':
            'full_name.ilike.$pattern,username.ilike.$pattern,email.ilike.$pattern,auth_provider.ilike.$pattern',
      });
    }

    final safePage = page < 1 ? 1 : page;
    final from = (safePage - 1) * pageSize;
    final to = from + pageSize - 1;
    final result = await _postJson('/api/admin/query', {
      'table': 'profiles',
      'method': 'select',
      'select':
          'id,username,full_name,email,city,auth_provider,role,status,reward_system,avatar_url,created_at',
      'filters': filters,
      'orders': _userOrders(sortKey, sortAscending),
      'range': {'from': from, 'to': to},
      'count': 'exact',
    });

    _throwIfApiError(result, fallbackMessage: 'Kullanıcılar alınamadı');
    final data = result['data'];
    final rows = data is List ? data.whereType<Map>().toList() : const <Map>[];
    final users = <ManagedUser>[];
    for (var index = 0; index < rows.length; index++) {
      users.add(_managedUserFromJson(rows[index], from + index + 1));
    }

    return UsersPageResult(users: users, totalCount: _asInt(result['count']));
  }

  @override
  Future<void> createUser({
    required AdminSession session,
    required UserFormData data,
  }) async {
    await _accountAction(session, 'admin-create-user', _formPayload(data));
  }

  @override
  Future<void> updateUser({
    required AdminSession session,
    required String userId,
    required UserFormData data,
  }) async {
    await _accountAction(session, 'admin-update-user', {
      'userId': userId,
      ..._formPayload(data),
    });
  }

  @override
  Future<void> deleteUser({
    required AdminSession session,
    required String userId,
  }) async {
    await _accountAction(session, 'admin-delete-user', {'userId': userId});
  }

  @override
  Future<void> deleteUsers({
    required AdminSession session,
    required List<String> userIds,
  }) async {
    await _accountAction(session, 'admin-delete-users', {'userIds': userIds});
  }

  Future<int> _countProfiles(List<Map<String, Object?>> filters) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'profiles',
      'method': 'select',
      'select': 'id',
      'filters': filters,
      'count': 'exact',
      'head': true,
    });
    _throwIfApiError(result, fallbackMessage: 'Kullanıcı sayısı alınamadı');
    return _asInt(result['count']);
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
    _throwIfApiError(result, fallbackMessage: 'Kullanıcı işlemi tamamlanamadı');
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
      throw const AdminUsersException('Geçersiz sunucu yanıtı');
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

  List<Map<String, Object?>> _baseUserFilters() {
    return [
      {
        'type': 'comparison',
        'op': 'neq',
        'column': 'role',
        'value': 'publisher',
      },
    ];
  }

  List<Map<String, Object?>> _userOrders(String sortKey, bool ascending) {
    final column = switch (sortKey) {
      'user' => 'full_name',
      'role' => 'role',
      'authProvider' => 'auth_provider',
      'reward' => 'reward_system',
      'status' => 'status',
      'id' || 'created' => 'created_at',
      _ => 'created_at',
    };
    return [
      {'column': column, 'ascending': ascending},
      if (column != 'created_at') {'column': 'created_at', 'ascending': false},
      {'column': 'id', 'ascending': true},
    ];
  }

  Map<String, Object?> _formPayload(UserFormData data) {
    return {
      'email': data.email.trim().toLowerCase(),
      'password': data.password,
      'fullName': data.fullName.trim(),
      'username': data.username.trim(),
      'city': normalizeTurkeyCity(data.city),
      'role': data.role,
      'status': data.status,
      'rewardEnabled': data.rewardEnabled,
    };
  }

  ManagedUser _managedUserFromJson(Map<dynamic, dynamic> json, int rowNumber) {
    final item = _asStringKeyMap(json);
    final role = item['role']?.toString() ?? 'member';
    return ManagedUser(
      id: item['id']?.toString() ?? '',
      rowNumber: rowNumber,
      fullName: item['full_name']?.toString() ?? '',
      username: item['username']?.toString() ?? '',
      email: item['email']?.toString() ?? '',
      city: normalizeTurkeyCity(item['city']?.toString() ?? defaultTurkeyCity),
      authProvider: item['auth_provider']?.toString() ?? 'email',
      role: role,
      roleLabel: roleLabelFor(role, _fallbackRoles),
      status: item['status']?.toString() ?? 'Aktif',
      rewardEnabled: item['reward_system'] == true,
      createdAt: DateTime.tryParse(item['created_at']?.toString() ?? ''),
      avatarUrl: item['avatar_url']?.toString() ?? '',
    );
  }

  String _safeSearchTerm(String value) {
    return value.trim().replaceAll(',', ' ');
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
        throw AdminUsersException(message);
      }
    }
    throw AdminUsersException(fallbackMessage);
  }
}

class AdminUsersException implements Exception {
  const AdminUsersException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
