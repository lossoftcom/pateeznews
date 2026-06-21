const fallbackSupabaseUrl = 'https://debgdvrkcqhtwdyrqves.supabase.co';
const pateezAuthStorageKey = 'pateez-app-auth-session';
const flutterSecureStoragePublicKey = 'FlutterSecureStorage';
const flutterAdminSharedAuthStorageKey = 'flutter.supabase-auth-token';

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
    flutterAdminSharedAuthStorageKey,
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

Map<String, Object?> browserAuthSessionPayload(Map<String, Object?> session) {
  final accessToken = _cleanString(session['access_token']);
  if (accessToken.isEmpty) return const <String, Object?>{};

  final tokenType = _cleanString(session['token_type']);
  final normalizedSession = <String, Object?>{
    ...session,
    'access_token': accessToken,
    'refresh_token': _cleanString(session['refresh_token']),
    'token_type': tokenType.isEmpty ? 'bearer' : tokenType,
    'user': _asObjectMap(session['user']),
  };

  final expiresAt = _asNullableInt(session['expires_at']);
  if (expiresAt != null) {
    normalizedSession['expires_at'] = expiresAt;
  }

  final expiresIn = _asNullableInt(session['expires_in']);
  if (expiresIn != null) {
    normalizedSession['expires_in'] = expiresIn;
  }

  return {
    ...normalizedSession,
    'session': normalizedSession,
    'currentSession': normalizedSession,
  };
}

String _cleanString(Object? value) => value?.toString().trim() ?? '';

Map<String, Object?> _asObjectMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map(
      (key, nestedValue) => MapEntry(key.toString(), nestedValue),
    );
  }
  return const <String, Object?>{};
}

int? _asNullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
