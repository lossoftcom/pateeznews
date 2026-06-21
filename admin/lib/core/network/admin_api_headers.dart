import 'package:http/http.dart' as http;

import '../../features/auth/data/admin_session_store.dart';

final http.Client adminHttpClient = http.Client();

bool shouldCloseAdminHttpClient(
  http.Client client,
  http.Client? providedClient,
) {
  return providedClient == null && !identical(client, adminHttpClient);
}

Future<Map<String, String>> adminAuthHeaders({String? token}) async {
  final providedToken = token?.trim() ?? '';
  final session = providedToken.isEmpty
      ? await const AdminSessionStore().readSession()
      : null;
  final accessToken = providedToken.isNotEmpty
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
