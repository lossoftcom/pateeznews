import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sdk;

import '../../features/auth/data/admin_session_store.dart';

final http.Client adminHttpClient = http.Client();

bool shouldCloseAdminHttpClient(
  http.Client client,
  http.Client? providedClient,
) {
  return providedClient == null && !identical(client, adminHttpClient);
}

Future<Map<String, String>> adminAuthHeaders({String? token}) async {
  final liveAccessToken = _currentSupabaseAccessToken();
  final providedToken = token?.trim() ?? '';
  final session = liveAccessToken.isEmpty && providedToken.isEmpty
      ? await const AdminSessionStore().readSession()
      : null;
  final accessToken = liveAccessToken.isNotEmpty
      ? liveAccessToken
      : providedToken.isNotEmpty
      ? providedToken
      : session?.accessToken.trim() ?? '';

  return {
    'Accept': 'application/json',
    if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
  };
}

Future<Map<String, String>> adminJsonHeaders({String? token}) async {
  return {
    ...await adminAuthHeaders(token: token),
    'Content-Type': 'application/json; charset=UTF-8',
  };
}

String _currentSupabaseAccessToken() {
  try {
    return sdk.Supabase.instance.client.auth.currentSession?.accessToken
            .trim() ??
        '';
  } catch (_) {
    return '';
  }
}
