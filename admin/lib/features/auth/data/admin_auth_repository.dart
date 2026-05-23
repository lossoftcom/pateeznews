import 'admin_auth_models.dart';

abstract interface class AdminAuthRepository {
  Future<AdminAuthState?> restoreSession();

  Future<AdminAuthState> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

class AdminAuthException implements Exception {
  const AdminAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
