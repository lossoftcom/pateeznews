import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

enum _AccountMode { signIn, signUp }

class AccountSignInScreen extends StatefulWidget {
  const AccountSignInScreen({super.key});

  @override
  State<AccountSignInScreen> createState() => _AccountSignInScreenState();
}

class _AccountSignInScreenState extends State<AccountSignInScreen> {
  var _mode = _AccountMode.signIn;

  void _setMode(_AccountMode mode) => setState(() => _mode = mode);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.xl,
                    AppSpacing.pageHorizontal,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AccountIntro(mode: _mode),
                      const SizedBox(height: AppSpacing.xl),
                      _AuthPanel(mode: _mode, onModeChanged: _setMode),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AccountIntro extends StatelessWidget {
  const _AccountIntro({required this.mode});

  final _AccountMode mode;

  bool get _isSignUp => mode == _AccountMode.signUp;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Column(
        key: ValueKey<_AccountMode>(mode),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepOcean.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              _isSignUp ? Symbols.add : Symbols.person_rounded,
              color: AppColors.deepOcean,
              size: 21,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _isSignUp ? 'Hesabını oluştur' : 'Hesabına giriş yap',
            style: AppTypography.display.copyWith(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: AppColors.inkStrong,
              letterSpacing: 0,
              height: 1.08,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _isSignUp
                ? 'Pateez deneyimini kişiselleştir, yorumlarını ve kayıtlarını tek yerde tut.'
                : 'Kaydettiğin haberler, takip ettiklerin ve tercihlerin tek yerde kalsın.',
            style: AppTypography.body.copyWith(
              color: AppColors.inkSoft,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({required this.mode, required this.onModeChanged});

  final _AccountMode mode;
  final ValueChanged<_AccountMode> onModeChanged;

  bool get _isSignUp => mode == _AccountMode.signUp;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: Column(
          key: ValueKey<_AccountMode>(mode),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProviderButtons(mode: mode),
            const SizedBox(height: AppSpacing.md),
            const _DividerLabel(),
            const SizedBox(height: AppSpacing.md),
            if (_isSignUp) ...[
              const _TextInputField(
                label: 'Ad soyad',
                hint: 'Adını yaz',
                icon: Symbols.person_rounded,
                autofillHints: [AutofillHints.name],
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.sm),
              const _TextInputField(
                label: 'E-posta',
                hint: 'mail@ornek.com',
                icon: Symbols.alternate_email_rounded,
                autofillHints: [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),
              const _PasswordField(
                label: 'Şifre',
                hint: 'Güçlü şifre oluştur',
                autofillHints: [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),
              const _PasswordField(
                label: 'Şifre tekrar',
                hint: 'Şifreni tekrar yaz',
                autofillHints: [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
              ),
            ] else ...[
              const _TextInputField(
                label: 'Kullanıcı adı',
                hint: '@kullaniciadi',
                icon: Symbols.alternate_email_rounded,
                autofillHints: [AutofillHints.username],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),
              const _PasswordField(
                label: 'Şifre',
                hint: 'Şifreni yaz',
                autofillHints: [AutofillHints.password],
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Şifremi unuttum',
                  style: AppTypography.meta.copyWith(
                    color: AppColors.deepOcean,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _PrimaryButton(
              label: _isSignUp ? 'Kayıt ol' : 'Giriş yap',
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            _ModeTextAction(
              label: _isSignUp ? 'Giriş yap' : 'Üye ol',
              onTap: () => onModeChanged(
                _isSignUp ? _AccountMode.signIn : _AccountMode.signUp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderButtons extends StatelessWidget {
  const _ProviderButtons({required this.mode});

  final _AccountMode mode;

  bool get _isSignUp => mode == _AccountMode.signUp;

  @override
  Widget build(BuildContext context) {
    final google = _ProviderButton(
      label: _isSignUp ? 'Google ile kayıt ol' : 'Google ile giriş',
      semanticLabel: _isSignUp ? 'Google ile kayıt ol' : 'Google ile giriş',
      leading: const _GoogleGlyph(),
      onTap: () {},
    );
    final apple = _ProviderButton(
      label: _isSignUp ? 'Apple ile kayıt ol' : 'Apple ile giriş',
      semanticLabel: _isSignUp ? 'Apple ile kayıt ol' : 'Apple ile giriş',
      leading: const Icon(Symbols.apple_rounded, color: Colors.black, size: 20),
      onTap: () {},
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              google,
              const SizedBox(height: AppSpacing.sm),
              apple,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: google),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: apple),
          ],
        );
      },
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.semanticLabel,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.value),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 22, child: Center(child: leading)),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleS.copyWith(
                      color: AppColors.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const Icon(Symbols.google_fill, color: Color(0xFFEA4335), size: 19);
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.softLine, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'veya',
            style: AppTypography.meta.copyWith(
              color: AppColors.support,
              fontSize: 11,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.softLine, height: 1)),
      ],
    );
  }
}

class _TextInputField extends StatelessWidget {
  const _TextInputField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.autofillHints,
    required this.textInputAction,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final String hint;
  final IconData icon;
  final List<String> autofillHints;
  final TextInputAction textInputAction;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      textInputAction: textInputAction,
      style: AppTypography.titleS.copyWith(
        color: AppColors.inkStrong,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.iconMuted, size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: AppTypography.meta.copyWith(color: AppColors.support),
        hintStyle: AppTypography.bodySmall.copyWith(
          color: AppColors.placeholder,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
          borderSide: const BorderSide(color: AppColors.softLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
          borderSide: const BorderSide(color: AppColors.deepOcean, width: 1.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.label,
    required this.hint,
    required this.autofillHints,
    required this.textInputAction,
  });

  final String label;
  final String hint;
  final List<String> autofillHints;
  final TextInputAction textInputAction;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  var _isObscured = true;

  @override
  Widget build(BuildContext context) {
    return _TextInputField(
      label: widget.label,
      hint: widget.hint,
      icon: Symbols.lock_outline_rounded,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      obscureText: _isObscured,
      suffix: IconButton(
        onPressed: () => setState(() => _isObscured = !_isObscured),
        icon: Icon(
          _isObscured
              ? Symbols.visibility_outlined
              : Symbols.visibility_off_outlined,
          color: AppColors.iconMuted,
          size: 18,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.value),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.actionRed,
              borderRadius: BorderRadius.circular(AppRadius.value),
              boxShadow: [
                BoxShadow(
                  color: AppColors.actionRed.withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: AppTypography.titleS.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Symbols.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTextAction extends StatelessWidget {
  const _ModeTextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.titleS.copyWith(
                  color: AppColors.actionRed,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
