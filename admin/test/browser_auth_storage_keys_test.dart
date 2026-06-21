import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/features/auth/data/browser_auth_storage_keys.dart';

void main() {
  test('Supabase auth storage key project id ile hesaplanir', () {
    expect(
      supabaseAuthStorageKey(
        supabaseUrl: 'https://debgdvrkcqhtwdyrqves.supabase.co',
      ),
      'sb-debgdvrkcqhtwdyrqves-auth-token',
    );
  });

  test('browserAuthStorageKeys public ve admin web oturumlarini kapsar', () {
    final keys = browserAuthStorageKeys(
      supabaseUrl: 'https://debgdvrkcqhtwdyrqves.supabase.co',
    );

    expect(keys, contains('pateez-app-auth-session'));
    expect(keys, contains('sb-debgdvrkcqhtwdyrqves-auth-token'));
    expect(keys, contains('FlutterSecureStorage.supabase-auth-token'));
    expect(keys, contains('FlutterSecureStorage.pateez_frontend_auth_session'));
    expect(keys, contains(flutterAdminSharedAuthStorageKey));
    expect(keys, contains('flutter.pateez_profile_cache'));
    expect(keys, contains('pateez_profile_cache'));
  });

  test('browserAuthSessionPayload public oturum formatini olusturur', () {
    final payload = browserAuthSessionPayload({
      'access_token': ' token ',
      'token_type': '',
      'expires_at': '4102444800',
      'user': {
        'id': 'user-1',
        'email': 'nasip@example.com',
        'role': 'authenticated',
        'aud': 'authenticated',
        'user_metadata': {'full_name': 'Nasip'},
        'app_metadata': {'provider': 'email'},
      },
    });

    expect(payload['access_token'], 'token');
    expect(payload['refresh_token'], '');
    expect(payload['token_type'], 'bearer');
    expect(payload['expires_at'], 4102444800);

    final session = payload['session'];
    expect(session, isA<Map<String, Object?>>());
    expect((session as Map<String, Object?>)['access_token'], 'token');
    expect(payload['currentSession'], session);
  });
}
