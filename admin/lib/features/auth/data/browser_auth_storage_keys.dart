const fallbackSupabaseUrl = 'https://debgdvrkcqhtwdyrqves.supabase.co';
const pateezAuthStorageKey = 'pateez-app-auth-session';
const flutterSecureStoragePublicKey = 'FlutterSecureStorage';

const legacySupabaseAuthStorageKeys = [
  'pateeznews-supabase-auth',
  'supabase-auth-token',
];

const flutterSecureAuthStorageKeys = [
  'supabase-auth-token',
  'pateez_frontend_auth_session',
];

const flutterSharedAuthStorageKeys = [
  'supabase-auth-token',
  'pateez_profile_cache',
  'pateez_frontend_auth_session',
  'pateez_frontend_profile_cache',
];

List<String> browserAuthStorageKeys({
  String supabaseUrl = const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: fallbackSupabaseUrl,
  ),
}) {
  final keys = <String>{
    pateezAuthStorageKey,
    supabaseAuthStorageKey(supabaseUrl: supabaseUrl),
    ...legacySupabaseAuthStorageKeys,
    ...flutterSecureAuthStorageKeys.map(
      (key) => '$flutterSecureStoragePublicKey.$key',
    ),
    ...flutterSharedAuthStorageKeys.map((key) => 'flutter.$key'),
    'pateez_profile_cache',
  };

  return [
    for (final key in keys) ...[key, '$key-code-verifier', '$key-user'],
  ];
}

String supabaseAuthStorageKey({String supabaseUrl = fallbackSupabaseUrl}) {
  final host = Uri.tryParse(supabaseUrl.trim())?.host ?? '';
  final projectId = host.split('.').first.trim();
  return projectId.isEmpty
      ? 'sb-debgdvrkcqhtwdyrqves-auth-token'
      : 'sb-$projectId-auth-token';
}
