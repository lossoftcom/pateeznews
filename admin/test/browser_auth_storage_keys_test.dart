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
    expect(keys, contains('flutter.supabase-auth-token'));
    expect(keys, contains('flutter.pateez_profile_cache'));
    expect(keys, contains('pateez_profile_cache'));
  });
}
