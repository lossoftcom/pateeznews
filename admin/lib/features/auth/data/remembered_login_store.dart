import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  const RememberedLoginStore({
    this._secureStorage = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  });

  static const _enabledKey = 'pateeznews.remember_login.enabled';
  static const _emailKey = 'pateeznews.remember_login.email';
  static const _passwordKey = 'pateeznews.remember_login.password';

  final FlutterSecureStorage _secureStorage;

  Future<RememberedLogin> read() async {
    final preferences = await SharedPreferences.getInstance();
    final enabled = preferences.getBool(_enabledKey) ?? false;

    if (!enabled) {
      return const RememberedLogin(enabled: false, email: '', password: '');
    }

    var email = await _secureStorage.read(key: _emailKey);
    var password = await _secureStorage.read(key: _passwordKey);
    if ((email == null || password == null) &&
        (preferences.containsKey(_emailKey) ||
            preferences.containsKey(_passwordKey))) {
      email ??= preferences.getString(_emailKey);
      password ??= preferences.getString(_passwordKey);
      await _writeSecure(email: email ?? '', password: password ?? '');
      await preferences.remove(_emailKey);
      await preferences.remove(_passwordKey);
    }

    return RememberedLogin(
      enabled: true,
      email: email ?? '',
      password: password ?? '',
    );
  }

  Future<void> save({required String email, required String password}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, true);
    await _writeSecure(email: email, password: password);
    await preferences.remove(_emailKey);
    await preferences.remove(_passwordKey);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, false);
    await _secureStorage.delete(key: _emailKey);
    await _secureStorage.delete(key: _passwordKey);
    await preferences.remove(_emailKey);
    await preferences.remove(_passwordKey);
  }

  Future<void> _writeSecure({
    required String email,
    required String password,
  }) async {
    await _secureStorage.write(key: _emailKey, value: email);
    await _secureStorage.write(key: _passwordKey, value: password);
  }
}
