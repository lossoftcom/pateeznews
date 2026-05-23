import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/admin_auth_repository.dart';
import '../../data/remembered_login_store.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import 'login_mark.dart';
import 'remember_toggle.dart';

const _fieldErrorStyle = TextStyle(
  color: AppColors.actionRed,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.18,
  letterSpacing: 0,
);

class LoginForm extends StatefulWidget {
  const LoginForm({super.key, required this.onLogin});

  final Future<void> Function(String email, String password) onLogin;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rememberedLoginStore = const RememberedLoginStore();
  var _rememberMe = true;
  var _obscurePassword = true;
  var _isSubmitting = false;
  String? _emailAuthError;
  String? _passwordAuthError;

  @override
  void initState() {
    super.initState();
    _loadRememberedLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedLogin() async {
    final rememberedLogin = await _rememberedLoginStore.read();
    if (!mounted || !rememberedLogin.enabled) return;

    setState(() {
      _rememberMe = true;
      _emailController.text = rememberedLogin.email;
      _passwordController.text = rememberedLogin.password;
    });
  }

  Future<void> _setRememberMe(bool value) async {
    setState(() {
      _rememberMe = value;
    });

    if (!value) {
      await _rememberedLoginStore.clear();
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _clearAuthErrors();
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      await widget.onLogin(email, password);

      if (_rememberMe) {
        await _rememberedLoginStore.save(email: email, password: password);
      } else {
        await _rememberedLoginStore.clear();
      }
    } on AdminAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _setAuthErrors(error.message);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _setAuthErrors('');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _localizedError(String message) {
    if (message == 'Invalid login credentials') {
      return context.t('login.authError');
    }
    return context.t('login.authError');
  }

  void _setAuthErrors(String message) {
    final errorText = _localizedError(message);
    _emailAuthError = errorText;
    _passwordAuthError = errorText;
  }

  void _clearAuthErrors() {
    _emailAuthError = null;
    _passwordAuthError = null;
  }

  void _clearEmailAuthError() {
    if (_emailAuthError == null) return;
    setState(() {
      _emailAuthError = null;
    });
  }

  void _clearPasswordAuthError() {
    if (_passwordAuthError == null) return;
    setState(() {
      _passwordAuthError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: AppColors.deepOcean,
      fontWeight: FontWeight.w700,
      height: 1.08,
      letterSpacing: 0,
    );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.deepOcean.withValues(alpha: 0.62),
      height: 1.42,
      letterSpacing: 0,
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const LoginMark(),
          const SizedBox(height: 30),
          Text(context.t('login.title'), style: titleStyle),
          const SizedBox(height: 8),
          Text(context.t('login.subtitle'), style: bodyStyle),
          const SizedBox(height: 26),
          TextFormField(
            controller: _emailController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            mouseCursor: SystemMouseCursors.text,
            cursorColor: AppColors.placeholder,
            onChanged: (_) => _clearEmailAuthError(),
            onFieldSubmitted: (_) => _submit(),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: context.t('login.emailLabel'),
              hintText: context.t('login.emailHint'),
              prefixIcon: const SymbolIcon(Symbols.alternate_email),
              errorText: _emailAuthError,
              errorStyle: _fieldErrorStyle,
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty || !email.contains('@')) {
                return context.t('login.emailInvalid');
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            enabled: !_isSubmitting,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            mouseCursor: SystemMouseCursors.text,
            cursorColor: AppColors.placeholder,
            onChanged: (_) => _clearPasswordAuthError(),
            onFieldSubmitted: (_) => _submit(),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: context.t('login.passwordLabel'),
              hintText: context.t('login.passwordHint'),
              prefixIcon: const SymbolIcon(Symbols.lock),
              errorText: _passwordAuthError,
              errorStyle: _fieldErrorStyle,
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? context.t('login.showPassword')
                    : context.t('login.hidePassword'),
                mouseCursor: SystemMouseCursors.click,
                onPressed: () {
                  if (_isSubmitting) return;
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: SymbolIcon(
                  _obscurePassword
                      ? Symbols.visibility
                      : Symbols.visibility_off,
                ),
              ),
            ),
            validator: (value) {
              if ((value ?? '').trim().length < 6) {
                return context.t('login.passwordShort');
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RememberToggle(
                  value: _rememberMe,
                  onChanged: _setRememberMe,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const SymbolIcon(Symbols.arrow_forward, size: 19),
            label: Text(context.t('login.submit')),
          ),
        ],
      ),
    );
  }
}
