import 'package:shared_preferences/shared_preferences.dart';

class RememberedLogin {
  const RememberedLogin({
    required this.enabled,
    required this.email,
    required this.password,
  });

  final bool enabled;
  final String email;
  final String password;
}

class RememberedLoginStore {
  const RememberedLoginStore();

  static const _enabledKey = 'pateeznews.remember_login.enabled';
  static const _emailKey = 'pateeznews.remember_login.email';
  static const _passwordKey = 'pateeznews.remember_login.password';

  Future<RememberedLogin> read() async {
    final preferences = await SharedPreferences.getInstance();
    final enabled = preferences.getBool(_enabledKey) ?? false;

    if (!enabled) {
      return const RememberedLogin(enabled: false, email: '', password: '');
    }

    return RememberedLogin(
      enabled: true,
      email: preferences.getString(_emailKey) ?? '',
      password: preferences.getString(_passwordKey) ?? '',
    );
  }

  Future<void> save({required String email, required String password}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, true);
    await preferences.setString(_emailKey, email);
    await preferences.setString(_passwordKey, password);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, false);
    await preferences.remove(_emailKey);
    await preferences.remove(_passwordKey);
  }
}
