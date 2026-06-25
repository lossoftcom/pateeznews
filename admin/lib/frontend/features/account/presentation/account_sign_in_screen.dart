import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pateeznews_admin/shared/constants/turkey_cities.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/brand/default_brand_assets.dart';
import '../data/frontend_auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/adaptive_city_select_field.dart';
import '../../../shared/widgets/back_circle_button.dart';
import '../../shell/data/app_shell_repository.dart';

enum _AccountMode { signIn, signUp }

typedef FrontendSignInCallback =
    Future<FrontendAuthState> Function({
      required String identifier,
      required String password,
    });

typedef FrontendSignUpCallback =
    Future<FrontendAuthState> Function({
      required String fullName,
      required String email,
      required String password,
      required String passwordAgain,
      required String city,
    });

typedef FrontendSignUpVerificationCallback =
    Future<FrontendSignupVerificationState> Function({
      required String fullName,
      required String email,
      required String password,
      required String passwordAgain,
      required String city,
    });

typedef FrontendVerifySignUpCallback =
    Future<FrontendAuthState> Function({
      required String fullName,
      required String email,
      required String password,
      required String passwordAgain,
      required String city,
      required String verificationCode,
    });

typedef FrontendSocialSignInCallback =
    Future<FrontendAuthState> Function(FrontendSocialAuthProvider provider);

class AccountSignInScreen extends StatefulWidget {
  const AccountSignInScreen({
    super.key,
    this.onBack,
    this.authState,
    this.authLoading = false,
    this.onSignIn,
    this.onSignUp,
    this.onRequestSignUpVerification,
    this.onVerifySignUp,
    this.onSocialSignIn,
    this.onSignOut,
    this.shellSettings = const AppShellSettings.empty(),
  });

  final VoidCallback? onBack;
  final FrontendAuthState? authState;
  final bool authLoading;
  final FrontendSignInCallback? onSignIn;
  final FrontendSignUpCallback? onSignUp;
  final FrontendSignUpVerificationCallback? onRequestSignUpVerification;
  final FrontendVerifySignUpCallback? onVerifySignUp;
  final FrontendSocialSignInCallback? onSocialSignIn;
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
                              onSignUp: widget.onSignUp,
                              onRequestSignUpVerification:
                                  widget.onRequestSignUpVerification,
                              onVerifySignUp: widget.onVerifySignUp,
                              onSocialSignIn: widget.onSocialSignIn,
                              shellSettings: widget.shellSettings,
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
      semanticLabel: settings.siteName.isEmpty ? 'Pateez' : settings.siteName,
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
        label: settings.siteName.isEmpty ? 'Pateez' : settings.siteName,
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
    required this.onSignUp,
    required this.onRequestSignUpVerification,
    required this.onVerifySignUp,
    required this.onSocialSignIn,
    required this.shellSettings,
  });

  final _AccountMode mode;
  final bool authLoading;
  final ValueChanged<_AccountMode> onModeChanged;
  final FrontendSignInCallback? onSignIn;
  final FrontendSignUpCallback? onSignUp;
  final FrontendSignUpVerificationCallback? onRequestSignUpVerification;
  final FrontendVerifySignUpCallback? onVerifySignUp;
  final FrontendSocialSignInCallback? onSocialSignIn;
  final AppShellSettings shellSettings;

  @override
  State<_AuthPanel> createState() => _AuthPanelState();
}

class _PendingSignUp {
  const _PendingSignUp({
    required this.fullName,
    required this.email,
    required this.password,
    required this.passwordAgain,
    required this.city,
  });

  final String fullName;
  final String email;
  final String password;
  final String passwordAgain;
  final String city;
}

class _AuthPanelState extends State<_AuthPanel> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _newPassword = TextEditingController();
  final _newPasswordAgain = TextEditingController();
  final _verificationCode = TextEditingController();

  var _city = defaultTurkeyCity;
  var _submitting = false;
  _PendingSignUp? _pendingSignUp;
  DateTime? _resendAvailableAt;
  DateTime? _expiresAt;
  Timer? _countdownTimer;
  String? _error;
  String? _notice;

  bool get _isSignUp => widget.mode == _AccountMode.signUp;
  bool get _isVerificationStep => _isSignUp && _pendingSignUp != null;
  bool get _busy => _submitting || widget.authLoading;
  int get _resendSeconds {
    final target = _resendAvailableAt;
    if (target == null) return 0;
    return target.difference(DateTime.now()).inSeconds.clamp(0, 999).toInt();
  }

  int get _expiresSeconds {
    final target = _expiresAt;
    if (target == null) return 0;
    return target.difference(DateTime.now()).inSeconds.clamp(0, 999).toInt();
  }

  @override
  void initState() {
    super.initState();
    _newPassword.addListener(_refreshPasswordStrength);
  }

  @override
  void dispose() {
    _newPassword.removeListener(_refreshPasswordStrength);
    _identifier.dispose();
    _password.dispose();
    _name.dispose();
    _email.dispose();
    _newPassword.dispose();
    _newPasswordAgain.dispose();
    _verificationCode.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _refreshPasswordStrength() {
    if (mounted) setState(() {});
  }

  String _formatSeconds(int seconds) {
    final safe = seconds.clamp(0, 999).toInt();
    final minutes = safe ~/ 60;
    final rest = safe % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _clearVerificationStep() {
    _countdownTimer?.cancel();
    setState(() {
      _pendingSignUp = null;
      _resendAvailableAt = null;
      _expiresAt = null;
      _verificationCode.clear();
      _error = null;
      _notice = null;
    });
  }

  void _applyVerificationState(
    _PendingSignUp pending,
    FrontendSignupVerificationState verification,
  ) {
    setState(() {
      _pendingSignUp = pending;
      _verificationCode.clear();
      _resendAvailableAt = DateTime.now().add(
        Duration(
          seconds: verification.resendAfterSeconds > 0
              ? verification.resendAfterSeconds
              : 120,
        ),
      );
      _expiresAt =
          verification.expiresAt ??
          DateTime.now().add(const Duration(seconds: 150));
      _error = null;
      _notice = verification.message ?? 'Doğrulama kodunu e-postana gönderdik.';
    });
    _startCountdown();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (_isSignUp) {
      final pending =
          _pendingSignUp ??
          _PendingSignUp(
            fullName: _name.text.trim(),
            email: _email.text.trim().toLowerCase(),
            password: _newPassword.text,
            passwordAgain: _newPasswordAgain.text,
            city: _city,
          );
      if (pending.fullName.isEmpty ||
          pending.email.isEmpty ||
          pending.password.isEmpty) {
        setState(() => _error = 'Ad soyad, e-posta, şifre ve şehir zorunlu.');
        return;
      }
      if (!isTurkeyCity(pending.city)) {
        setState(() => _error = 'Şehir seçimi zorunlu.');
        return;
      }
      if (pending.password != pending.passwordAgain) {
        setState(() => _error = 'Şifreler eşleşmiyor.');
        return;
      }
      setState(() {
        _submitting = true;
        _error = null;
        _notice = null;
      });
      try {
        if (_isVerificationStep) {
          final code = _verificationCode.text.replaceAll(RegExp(r'\D'), '');
          if (code.length != 6) {
            setState(() => _error = '6 haneli doğrulama kodunu gir.');
            return;
          }
          final onVerify = widget.onVerifySignUp;
          if (onVerify == null) {
            setState(() => _error = 'Doğrulama servisi hazır değil.');
            return;
          }
          await onVerify(
            fullName: pending.fullName,
            email: pending.email,
            password: pending.password,
            passwordAgain: pending.passwordAgain,
            city: pending.city,
            verificationCode: code,
          );
        } else if (widget.onRequestSignUpVerification != null &&
            widget.onVerifySignUp != null) {
          final verification = await widget.onRequestSignUpVerification!(
            fullName: pending.fullName,
            email: pending.email,
            password: pending.password,
            passwordAgain: pending.passwordAgain,
            city: pending.city,
          );
          if (!mounted) return;
          _applyVerificationState(pending, verification);
          return;
        } else {
          final onSignUp = widget.onSignUp;
          if (onSignUp == null) {
            setState(() => _error = 'Kayıt servisi hazır değil.');
            return;
          }
          await onSignUp(
            fullName: pending.fullName,
            email: pending.email,
            password: pending.password,
            passwordAgain: pending.passwordAgain,
            city: pending.city,
          );
        }
        if (!mounted) return;
        Navigator.of(context).maybePop();
      } on FrontendAuthException catch (error) {
        if (!mounted) return;
        setState(() => _error = error.message);
      } catch (_) {
        if (!mounted) return;
        setState(() => _error = 'Kayıt oluşturulamadı. Lütfen tekrar dene.');
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
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
      _notice = null;
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

  Future<void> _resendVerificationCode() async {
    if (_busy || _pendingSignUp == null || _resendSeconds > 0) return;
    final onRequest = widget.onRequestSignUpVerification;
    if (onRequest == null) {
      setState(() => _error = 'Doğrulama servisi hazır değil.');
      return;
    }
    final pending = _pendingSignUp!;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final verification = await onRequest(
        fullName: pending.fullName,
        email: pending.email,
        password: pending.password,
        passwordAgain: pending.passwordAgain,
        city: pending.city,
      );
      if (!mounted) return;
      _applyVerificationState(pending, verification);
    } on FrontendAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Kod yeniden gönderilemedi. Lütfen tekrar dene.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitSocial(FrontendSocialAuthProvider provider) async {
    if (_busy) return;
    final onSocialSignIn = widget.onSocialSignIn;
    if (onSocialSignIn == null) {
      setState(() => _error = 'Sosyal giriş servisi hazır değil.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await onSocialSignIn(provider);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } on FrontendAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Sosyal giriş tamamlanamadı. Lütfen tekrar dene.',
      );
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
            _ProviderButtons(
              mode: widget.mode,
              settings: widget.shellSettings.socialAuth,
              enabled: !_busy,
              onSelected: _submitSocial,
            ),
            if (widget.shellSettings.socialAuth.hasAny) ...[
              const SizedBox(height: AppSpacing.md),
              const _DividerLabel(),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_isSignUp) ...[
              if (_isVerificationStep) ...[
                _VerificationCard(
                  email: _pendingSignUp?.email ?? '',
                  expiresLabel: _formatSeconds(_expiresSeconds),
                ),
                const SizedBox(height: AppSpacing.sm),
                _TextInputField(
                  label: 'Doğrulama kodu',
                  hint: '6 haneli kod',
                  icon: Symbols.verified_user_outlined,
                  controller: _verificationCode,
                  enabled: !_busy,
                  autofillHints: [AutofillHints.oneTimeCode],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _InlineTextButton(
                        label: _resendSeconds > 0
                            ? 'Tekrar gönder ${_formatSeconds(_resendSeconds)}'
                            : 'Kodu tekrar gönder',
                        onTap: _busy || _resendSeconds > 0
                            ? null
                            : _resendVerificationCode,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _InlineTextButton(
                        label: 'Bilgileri düzenle',
                        onTap: _busy ? null : _clearVerificationStep,
                      ),
                    ),
                  ],
                ),
              ] else ...[
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
                AdaptiveCitySelectField(
                  label: 'Şehir',
                  value: _city,
                  enabled: !_busy,
                  onChanged: (value) {
                    setState(() => _city = normalizeTurkeyCity(value));
                  },
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
                const SizedBox(height: AppSpacing.sm),
                _PasswordStrengthBar(password: _newPassword.text),
              ],
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
            if (_notice != null && _error == null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _notice!,
                style: AppTypography.meta.copyWith(
                  color: const Color(0xFF0D8A5B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _PrimaryButton(
              label: _busy
                  ? (_isSignUp
                        ? (_isVerificationStep
                              ? 'Doğrulanıyor'
                              : 'Kod gönderiliyor')
                        : 'Giriş yapılıyor')
                  : _isSignUp
                  ? (_isVerificationStep ? 'Hesabı doğrula' : 'Kayıt ol')
                  : 'Giriş yap',
              loading: _busy,
              onTap: _submit,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ModeTextAction(
              label: _isSignUp ? 'Giriş yap' : 'Üye ol',
              onTap: _busy
                  ? null
                  : () {
                      _countdownTimer?.cancel();
                      _pendingSignUp = null;
                      _resendAvailableAt = null;
                      _expiresAt = null;
                      _verificationCode.clear();
                      _notice = null;
                      _error = null;
                      widget.onModeChanged(
                        _isSignUp ? _AccountMode.signIn : _AccountMode.signUp,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderButtons extends StatelessWidget {
  const _ProviderButtons({
    required this.mode,
    required this.settings,
    required this.enabled,
    required this.onSelected,
  });

  final _AccountMode mode;
  final AppSocialAuthSettings settings;
  final bool enabled;
  final ValueChanged<FrontendSocialAuthProvider> onSelected;

  bool get _isSignUp => mode == _AccountMode.signUp;

  @override
  Widget build(BuildContext context) {
    final providers = <_ProviderButtonData>[
      if (settings.googleEnabled)
        _ProviderButtonData(
          provider: FrontendSocialAuthProvider.google,
          label: _isSignUp ? 'Google ile kayıt ol' : 'Google ile giriş',
          leading: const _GoogleGlyph(),
        ),
      if (settings.appleEnabled)
        _ProviderButtonData(
          provider: FrontendSocialAuthProvider.apple,
          label: _isSignUp ? 'Apple ile kayıt ol' : 'Apple ile giriş',
          leading: const Icon(
            Symbols.apple_rounded,
            color: Colors.black,
            size: 20,
          ),
        ),
      if (settings.facebookEnabled)
        _ProviderButtonData(
          provider: FrontendSocialAuthProvider.facebook,
          label: _isSignUp ? 'Facebook ile kayıt ol' : 'Facebook ile giriş',
          leading: SvgPicture.asset(
            'assets/images/social/facebook.svg',
            width: 18,
            height: 18,
          ),
        ),
      if (settings.xEnabled)
        _ProviderButtonData(
          provider: FrontendSocialAuthProvider.x,
          label: _isSignUp ? 'X ile kayıt ol' : 'X ile giriş',
          leading: SvgPicture.asset(
            'assets/images/social/x.svg',
            width: 17,
            height: 17,
          ),
        ),
    ];
    if (providers.isEmpty) return const SizedBox.shrink();

    Widget button(_ProviderButtonData data) {
      return _ProviderButton(
        label: data.label,
        semanticLabel: data.label,
        leading: data.leading,
        onTap: enabled ? () => onSelected(data.provider) : null,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < providers.length; index++) ...[
                if (index > 0) const SizedBox(height: AppSpacing.sm),
                button(providers[index]),
              ],
            ],
          );
        }

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final provider in providers)
              SizedBox(
                width: (constraints.maxWidth - AppSpacing.sm) / 2,
                child: button(provider),
              ),
          ],
        );
      },
    );
  }
}

class _ProviderButtonData {
  const _ProviderButtonData({
    required this.provider,
    required this.label,
    required this.leading,
  });

  final FrontendSocialAuthProvider provider;
  final String label;
  final Widget leading;
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
  final VoidCallback? onTap;

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

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.email, required this.expiresLabel});

  final String email;
  final String expiresLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Column(
        children: [
          Icon(
            Symbols.mark_email_read_outlined,
            color: AppColors.actionRed,
            size: 24,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'E-posta doğrulama',
            style: AppTypography.titleS.copyWith(
              color: AppColors.inkStrong,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              color: AppColors.deepOcean,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kod $expiresLabel içinde geçerli.',
            style: AppTypography.meta.copyWith(
              color: AppColors.support,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineTextButton extends StatelessWidget {
  const _InlineTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.deepOcean,
        disabledForegroundColor: AppColors.support.withValues(alpha: 0.6),
        padding: EdgeInsets.zero,
        textStyle: AppTypography.meta.copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.password});

  final String password;

  int get _score {
    final checks = [
      password.length >= 8,
      RegExp(r'[a-zçğıöşü]').hasMatch(password) &&
          RegExp(r'[A-ZÇĞİÖŞÜ]').hasMatch(password),
      RegExp(r'\d').hasMatch(password),
      RegExp(r'[^A-Za-z0-9ÇĞİÖŞÜçğıöşü]').hasMatch(password),
      password.length >= 12,
    ];
    return checks.where((item) => item).length;
  }

  String get _label {
    if (password.isEmpty) return 'Güçlü şifre oluştur';
    if (_score <= 2) return 'Daha güçlü olabilir';
    if (_score <= 4) return 'Güçlü şifre';
    return 'Çok güçlü şifre';
  }

  Color get _color {
    if (password.isEmpty) return AppColors.softLine;
    if (_score <= 2) return const Color(0xFFF59F00);
    if (_score <= 4) return const Color(0xFF10A76F);
    return const Color(0xFF07885A);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var index = 1; index <= 5; index++) ...[
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: index <= _score ? _color : AppColors.softLine,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                if (index < 5) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _label,
            style: AppTypography.meta.copyWith(
              color: AppColors.support,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
