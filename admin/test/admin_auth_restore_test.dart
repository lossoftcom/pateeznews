import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pateeznews_admin/features/auth/data/admin_auth_models.dart';
import 'package:pateeznews_admin/features/auth/data/admin_session_store.dart';
import 'package:pateeznews_admin/features/auth/data/supabase_auth_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          if (call.method == 'readAll') return <String, String>{};
          if (call.method == 'containsKey') return false;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  test('restoreSession stored admin session ile oturumu geri yukler', () async {
    final requestedUrls = <String>[];
    final store = _MemoryAdminSessionStore(_testSession);
    final client = SupabaseAuthClient(
      apiBaseUrl: 'https://api.test',
      sessionStore: store,
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
        if (request.url.path == '/api/admin/query') {
          return http.Response(
            jsonEncode({'data': _testProfile.toJson(), 'error': null}),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );

    final authState = await client.restoreSession();

    expect(authState?.session.accessToken, _testSession.accessToken);
    expect(authState?.profile?.role, 'admin');
    expect(store.session?.accessToken, _testSession.accessToken);
    expect(store.profile?.id, _testProfile.id);
    expect(
      requestedUrls,
      containsAllInOrder([
        'https://api.test/api/supabase/auth',
        'https://api.test/api/admin/query',
      ]),
    );
  });
}

const _testSession = AdminSession(
  accessToken: 'stored-token',
  tokenType: 'bearer',
  expiresAt: 4102444800,
  user: AdminUser(
    id: 'user-1',
    email: 'nasip@example.com',
    role: 'authenticated',
    aud: 'authenticated',
    userMetadata: {},
    appMetadata: {},
  ),
);

const _testProfile = AdminProfile(
  id: 'user-1',
  username: 'nasip',
  fullName: 'Nasip Gundogdu',
  avatarUrl: '',
  role: 'admin',
  email: 'nasip@example.com',
);

class _MemoryAdminSessionStore extends AdminSessionStore {
  _MemoryAdminSessionStore(this.session);

  AdminSession? session;
  AdminProfile? profile;

  @override
  Future<AdminSession?> readSession() async => session;

  @override
  Future<void> saveSession(AdminSession session) async {
    this.session = session;
  }

  @override
  Future<void> clearAuth() async {
    session = null;
    profile = null;
  }

  @override
  Future<AdminProfile?> readProfileCache() async => profile;

  @override
  Future<void> saveProfileCache(AdminProfile profile) async {
    this.profile = profile;
  }
}
