import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/brand/default_brand_assets.dart';
import '../data/frontend_auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/back_circle_button.dart';
import '../../shell/data/app_shell_repository.dart';

enum _AccountMode { signIn, signUp }

typedef FrontendSignInCallback =
    Future<FrontendAuthState> Function({
      required String identifier,
      required String password,
    });

class AccountSignInScreen extends StatefulWidget {
  const AccountSignInScreen({
    super.key,
    this.onBack,
    this.authState,
    this.authLoading = false,
    this.onSignIn,
    this.onSignOut,
    this.shellSettings = const AppShellSettings.empty(),
  });

  final VoidCallback? onBack;
  final FrontendAuthState? authState;
  final bool authLoading;
  final FrontendSignInCallback? onSignIn;
  final Future<void> Function()? onSignOut;
  final AppShellSettings shellSettings;

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
      child: Column(
        children: [
          _AccountAppBar(
            onBack: widget.onBack,
            shellSettings: widget.shellSettings,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.pageHorizontal,
                        AppSpacing.xl,
                        AppSpacing.pageHorizontal,
                        AppSpacing.xl + keyboardInset,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AccountIntro(
                            mode: _mode,
                            authState: widget.authState,
                          ),
                          const SizedBox(height: AppSpacing.xxxl),
                          if (widget.authState != null)
                            _SignedInPanel(
                              authState: widget.authState!,
                              onSignOut: widget.onSignOut,
                              onBack: widget.onBack,
                            )
                          else
                            _AuthPanel(
                              mode: _mode,
                              authLoading: widget.authLoading,
                              onModeChanged: _setMode,
                              onSignIn: widget.onSignIn,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Hesap sekmesinin üst başlığı.
///
/// Ana sayfadaki app bar diliyle uyumludur: yüzey zemini, ince alt çizgi ve
/// üst güvenli alanı kendi içinde yöneten sabit yükseklik. Ortada marka
/// wordmark'ı yer alır; böylece sekmeler arası kimlik bütünlüğü korunur.
class _AccountAppBar extends StatelessWidget {
  const _AccountAppBar({this.onBack, required this.shellSettings});

  final VoidCallback? onBack;
  final AppShellSettings shellSettings;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final back =
        onBack ??
        (Navigator.canPop(context)
            ? () => Navigator.of(context).maybePop()
            : null);
    return Container(
      height: _height + topInset,
      padding: EdgeInsets.only(top: topInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.softLine, width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 56),
          Expanded(
            child: Center(child: _AccountBrandMark(settings: shellSettings)),
          ),
          SizedBox(
            width: 56,
            child: Align(
              alignment: Alignment.centerRight,
              child: back == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.lg),
                      child: BackCircleButton(onTap: back),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountBrandMark extends StatelessWidget {
  const _AccountBrandMark({required this.settings});

  final AppShellSettings settings;
  static const double _height = 34;
  static const double _width = 132;

  @override
  Widget build(BuildContext context) {
    final logoUrl = settings.lightSurfaceLogoUrl;
    final fallbackLogo = Image.asset(
      DefaultBrandAssets.logo,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: settings.siteName.isEmpty
          ? 'Pateeznews'
          : settings.siteName,
      errorBuilder: (_, _, _) => _AccountWordmark(siteName: settings.siteName),
    );
    if (logoUrl.isEmpty) {
      return SizedBox(width: _width, height: _height, child: fallbackLogo);
    }
    return SizedBox(
      width: _width,
      height: _height,
      child: Semantics(
        image: true,
        label: settings.siteName.isEmpty ? 'Pateeznews' : settings.siteName,
        child: CachedNetworkImage(
          imageUrl: logoUrl,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          fadeInDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          placeholder: (context, url) => fallbackLogo,
          errorWidget: (_, _, _) => fallbackLogo,
        ),
      ),
    );
  }
}

class _AccountWordmark extends StatelessWidget {
  const _AccountWordmark({required this.siteName});

  final String siteName;

  @override
  Widget build(BuildContext context) {
    final normalized = siteName.toLowerCase().replaceAll(' ', '');
    if (normalized.isNotEmpty && !normalized.contains('pateez')) {
      return Text(
        siteName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'PateezInter',
          color: AppColors.inkStrong,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1,
        ),
      );
    }

    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'pateez',
            style: TextStyle(
              fontFamily: 'PateezInter',
              color: AppColors.inkStrong,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          TextSpan(
            text: 'news',
            style: TextStyle(
              fontFamily: 'PateezInter',
              color: AppColors.accentAction,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          TextSpan(
            text: '.',
            style: TextStyle(
              fontFamily: 'PateezInter',
              color: AppColors.warmHorizon,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountIntro extends StatelessWidget {
  const _AccountIntro({required this.mode, required this.authState});

  final _AccountMode mode;
  final FrontendAuthState? authState;

  bool get _isSignUp => mode == _AccountMode.signUp;

  @override
  Widget build(BuildContext context) {
    final signedIn = authState != null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Column(
        key: ValueKey<Object>(signedIn ? authState!.session.user.id : mode),
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
              signedIn
                  ? Symbols.person_rounded
                  : _isSignUp
                  ? Symbols.add
                  : Symbols.person_rounded,
              color: AppColors.deepOcean,
              size: 21,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            signedIn
                ? 'Profilim'
                : _isSignUp
                ? 'Hesabını oluştur'
                : 'Hesabına giriş yap',
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
            signedIn
                ? 'Hesap bilgilerin, kayıtların ve tercihlerin tek yerde.'
                : _isSignUp
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

class _SignedInPanel extends StatelessWidget {
  const _SignedInPanel({
    required this.authState,
    required this.onSignOut,
    required this.onBack,
  });

  final FrontendAuthState authState;
  final Future<void> Function()? onSignOut;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _AccountAvatar(authState: authState, size: 54),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authState.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleS.copyWith(
                        color: AppColors.inkStrong,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      authState.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta.copyWith(
                        color: AppColors.support,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _ProfileActionButton(
            label: 'Geri dön',
            icon: Symbols.arrow_left_line,
            onTap: onBack,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ProfileActionButton(
            label: 'Çıkış yap',
            icon: Symbols.logout,
            destructive: true,
            onTap: onSignOut == null
                ? null
                : () {
                    () async {
                      await onSignOut!();
                      if (context.mounted) Navigator.of(context).maybePop();
                    }();
                  },
          ),
        ],
      ),
    );
  }
}

class _AuthPanel extends StatefulWidget {
  const _AuthPanel({
    required this.mode,
    required this.authLoading,
    required this.onModeChanged,
    required this.onSignIn,
  });

  final _AccountMode mode;
  final bool authLoading;
  final ValueChanged<_AccountMode> onModeChanged;
  final FrontendSignInCallback? onSignIn;

  @override
  State<_AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends State<_AuthPanel> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _newPassword = TextEditingController();
  final _newPasswordAgain = TextEditingController();

  var _submitting = false;
  String? _error;

  bool get _isSignUp => widget.mode == _AccountMode.signUp;
  bool get _busy => _submitting || widget.authLoading;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _name.dispose();
    _email.dispose();
    _newPassword.dispose();
    _newPasswordAgain.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (_isSignUp) {
      setState(() => _error = 'Üyelik sistemi şu an aktif değil.');
      return;
    }

    final identifier = _identifier.text.trim();
    final password = _password.text;
    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _error = 'Kullanıcı adı ve şifre zorunlu.');
      return;
    }
    final onSignIn = widget.onSignIn;
    if (onSignIn == null) {
      setState(() => _error = 'Giriş servisi hazır değil.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await onSignIn(identifier: identifier, password: password);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } on FrontendAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Giriş yapılamadı. Lütfen tekrar dene.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: Column(
          key: ValueKey<_AccountMode>(widget.mode),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProviderButtons(mode: widget.mode),
            const SizedBox(height: AppSpacing.md),
            const _DividerLabel(),
            const SizedBox(height: AppSpacing.md),
            if (_isSignUp) ...[
              _TextInputField(
                label: 'Ad soyad',
                hint: 'Adını yaz',
                icon: Symbols.person_rounded,
                controller: _name,
                enabled: !_busy,
                autofillHints: [AutofillHints.name],
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.sm),
              _TextInputField(
                label: 'E-posta',
                hint: 'mail@ornek.com',
                icon: Symbols.alternate_email_rounded,
                controller: _email,
                enabled: !_busy,
                autofillHints: [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),
              _PasswordField(
                label: 'Şifre',
                hint: 'Güçlü şifre oluştur',
                controller: _newPassword,
                enabled: !_busy,
                autofillHints: [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),
              _PasswordField(
                label: 'Şifre tekrar',
                hint: 'Şifreni tekrar yaz',
                controller: _newPasswordAgain,
                enabled: !_busy,
                autofillHints: [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ] else ...[
              _TextInputField(
                label: 'Kullanıcı adı veya e-posta',
                hint: '@kullaniciadi / mail@ornek.com',
                icon: Symbols.alternate_email_rounded,
                controller: _identifier,
                enabled: !_busy,
                autofillHints: [AutofillHints.username],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),
              _PasswordField(
                label: 'Şifre',
                hint: 'Şifreni yaz',
                controller: _password,
                enabled: !_busy,
                autofillHints: [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
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
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: AppTypography.meta.copyWith(
                  color: AppColors.actionRed,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _PrimaryButton(
              label: _busy
                  ? (_isSignUp ? 'Bekleniyor' : 'Giriş yapılıyor')
                  : _isSignUp
                  ? 'Kayıt ol'
                  : 'Giriş yap',
              loading: _busy,
              onTap: _submit,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ModeTextAction(
              label: _isSignUp ? 'Giriş yap' : 'Üye ol',
              onTap: _busy
                  ? null
                  : () => widget.onModeChanged(
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

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.authState, required this.size});

  final FrontendAuthState authState;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = authState.avatarUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceSoft,
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isEmpty
          ? Center(
              child: Text(
                authState.initials,
                style: AppTypography.titleS.copyWith(
                  color: AppColors.deepOcean,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: avatarUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              fadeInDuration: Duration.zero,
              placeholderFadeInDuration: Duration.zero,
              errorWidget: (_, _, _) => Center(
                child: Text(
                  authState.initials,
                  style: AppTypography.titleS.copyWith(
                    color: AppColors.deepOcean,
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.actionRed : AppColors.deepOcean;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: destructive
                ? AppColors.actionRed.withValues(alpha: 0.06)
                : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: destructive
                  ? AppColors.actionRed.withValues(alpha: 0.16)
                  : AppColors.softLine,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.titleS.copyWith(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    required this.controller,
    required this.enabled,
    required this.autofillHints,
    required this.textInputAction,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffix,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool enabled;
  final List<String> autofillHints;
  final TextInputAction textInputAction;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
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
    required this.controller,
    required this.enabled,
    required this.autofillHints,
    required this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final List<String> autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

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
      controller: widget.controller,
      enabled: widget.enabled,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      obscureText: _isObscured,
      onSubmitted: widget.onSubmitted,
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
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;

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
                if (loading) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  label,
                  style: AppTypography.titleS.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                if (!loading) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Symbols.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
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
  final VoidCallback? onTap;

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
