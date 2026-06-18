import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pateeznews_admin/shared/constants/turkey_cities.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/back_circle_button.dart';
import '../../../shared/widgets/adaptive_city_select_field.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/frontend_toast.dart';
import '../data/profile_content.dart';
import '../data/profile_repository.dart';

/// Profili Düzenle ekranı.
///
/// Astro önyüzdeki düzenleme formunun tüm bölümlerini taşır: fotoğraflar
/// (avatar + kapak), hesap bilgileri, profil/hakkında, sosyal bağlantılar,
/// tercihler, şifre değiştirme ve hesap silme. Tasarım dili uygulamayla
/// birebir aynıdır (4px keskin radius, PateezInter, deepOcean/actionRed).
///
/// Alanlar [ProfileData] ile ön-doldurulur. Kaydetme akışı arayüz olarak
/// eksiksizdir; gerçek kalıcılık için backend `update-profile` app uç noktası
/// gerekir (şifre için `update-password` uç noktası mevcuttur).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.data,
    this.authToken = '',
    this.repository = const ProfileRepository(),
    this.onProfileUpdated,
  });

  final ProfileData data;
  final String authToken;
  final ProfileRepository repository;
  final ValueChanged<ProfileSaveResult>? onProfileUpdated;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _fullName;
  late final TextEditingController _username;
  late final TextEditingController _email;
  late final TextEditingController _expertise;
  late final TextEditingController _about;
  late final TextEditingController _website;
  late final TextEditingController _address;
  late final TextEditingController _instagram;
  late final TextEditingController _x;
  late final TextEditingController _facebook;
  late final TextEditingController _youtube;
  late final TextEditingController _whatsapp;
  late final TextEditingController _linkedin;
  late final TextEditingController _tiktok;
  late final TextEditingController _pinterest;
  late final TextEditingController _snapchat;
  late final TextEditingController _telegram;
  late final TextEditingController _discord;
  late final TextEditingController _reddit;
  late final TextEditingController _bluesky;
  late final TextEditingController _twitch;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _newPasswordAgain = TextEditingController();

  late bool _showEmail;
  bool _rssFeeds = false;
  bool _saving = false;
  bool _passwordSaving = false;
  String? _photoBusyKind;
  String? _passwordMessage;
  bool _passwordOk = false;
  late String _avatarUrl;
  late String _coverUrl;
  late String _avatarPath;
  late String _coverPath;
  late String _city;

  @override
  void initState() {
    super.initState();
    final data = widget.data;
    _fullName = TextEditingController(text: data.name);
    _username = TextEditingController(
      text: data.handle.replaceFirst(RegExp(r'^@'), ''),
    );
    _email = TextEditingController(text: data.email);
    _expertise = TextEditingController(text: data.roleLabel);
    _about = TextEditingController(text: data.hasAbout ? data.aboutMe : '');
    _website = TextEditingController(text: data.website);
    _address = TextEditingController(text: data.address);
    _city = normalizeTurkeyCity(data.city);
    _x = TextEditingController(text: _linkFor(data, 'x'));
    _instagram = TextEditingController(text: _linkFor(data, 'instagram'));
    _facebook = TextEditingController(text: _linkFor(data, 'facebook'));
    _youtube = TextEditingController(text: _linkFor(data, 'youtube'));
    _whatsapp = TextEditingController(text: _linkFor(data, 'whatsapp'));
    _linkedin = TextEditingController(text: _linkFor(data, 'linkedin'));
    _tiktok = TextEditingController(text: _linkFor(data, 'tiktok'));
    _pinterest = TextEditingController(text: _linkFor(data, 'pinterest'));
    _snapchat = TextEditingController(text: _linkFor(data, 'snapchat'));
    _telegram = TextEditingController(text: _linkFor(data, 'telegram'));
    _discord = TextEditingController(text: _linkFor(data, 'discord'));
    _reddit = TextEditingController(text: _linkFor(data, 'reddit'));
    _bluesky = TextEditingController(text: _linkFor(data, 'bluesky'));
    _twitch = TextEditingController(text: _linkFor(data, 'twitch'));
    _showEmail = data.showEmail;
    _rssFeeds = data.rssFeeds;
    _avatarUrl = data.avatarUrl;
    _coverUrl = data.coverUrl;
    _avatarPath = data.avatarPath;
    _coverPath = data.coverPath;
  }

  static String _linkFor(ProfileData data, String key) {
    for (final link in data.socialLinks) {
      if (link.key == key) return link.url;
    }
    return '';
  }

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _username,
      _email,
      _expertise,
      _about,
      _website,
      _address,
      _instagram,
      _x,
      _facebook,
      _youtube,
      _whatsapp,
      _linkedin,
      _tiktok,
      _pinterest,
      _snapchat,
      _telegram,
      _discord,
      _reddit,
      _bluesky,
      _twitch,
      _currentPassword,
      _newPassword,
      _newPasswordAgain,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toast(
    String message, {
    FrontendToastTone tone = FrontendToastTone.info,
  }) {
    FrontendToast.show(context, message: message, tone: tone);
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (_username.text.trim().isEmpty || _email.text.trim().isEmpty) {
      _toast(
        'Kullanıcı adı ve e‑posta zorunlu.',
        tone: FrontendToastTone.error,
      );
      return;
    }
    if (!isTurkeyCity(_city)) {
      _toast('Şehir seçimi zorunlu.', tone: FrontendToastTone.error);
      return;
    }
    final token = widget.authToken.trim();
    if (token.isEmpty) {
      _toast(
        'Profilini güncellemek için giriş yapmalısın.',
        tone: FrontendToastTone.error,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await widget.repository.updateProfile(
        token: token,
        input: ProfileUpdateInput(
          fullName: _fullName.text,
          username: _username.text,
          email: _email.text,
          expertise: _expertise.text,
          aboutMe: _about.text,
          website: _website.text,
          address: _address.text,
          city: _city,
          instagram: _instagram.text,
          x: _x.text,
          facebook: _facebook.text,
          youtube: _youtube.text,
          whatsapp: _whatsapp.text,
          linkedin: _linkedin.text,
          tiktok: _tiktok.text,
          pinterest: _pinterest.text,
          snapchat: _snapchat.text,
          telegram: _telegram.text,
          discord: _discord.text,
          reddit: _reddit.text,
          bluesky: _bluesky.text,
          twitch: _twitch.text,
          showEmail: _showEmail,
          rssFeeds: _rssFeeds,
          avatarPath: _avatarPath,
          coverPath: _coverPath,
        ),
      );
      if (!mounted) return;
      widget.onProfileUpdated?.call(result);
      _toast('Profil kaydedildi.', tone: FrontendToastTone.success);
      Navigator.of(context).pop(result);
    } on ProfileException catch (error) {
      if (!mounted) return;
      _toast(error.message, tone: FrontendToastTone.error);
    } catch (_) {
      if (!mounted) return;
      _toast('Profil güncellenemedi.', tone: FrontendToastTone.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updatePassword() async {
    if (_passwordSaving) return;
    FocusScope.of(context).unfocus();
    final token = widget.authToken.trim();
    final current = _currentPassword.text;
    final next = _newPassword.text;
    final confirm = _newPasswordAgain.text;
    if (current.isEmpty || next.isEmpty) {
      setState(() {
        _passwordOk = false;
        _passwordMessage = 'Mevcut ve yeni şifre zorunlu.';
      });
      return;
    }
    if (next.length < 6) {
      setState(() {
        _passwordOk = false;
        _passwordMessage = 'Yeni şifre en az 6 karakter olmalı.';
      });
      return;
    }
    if (next != confirm) {
      setState(() {
        _passwordOk = false;
        _passwordMessage = 'Yeni şifreler eşleşmiyor.';
      });
      return;
    }
    if (token.isEmpty) {
      setState(() {
        _passwordOk = false;
        _passwordMessage = 'Şifre güncellemek için giriş yapmalısın.';
      });
      return;
    }
    setState(() => _passwordSaving = true);
    try {
      await widget.repository.updatePassword(
        token: token,
        currentPassword: current,
        newPassword: next,
      );
      _currentPassword.clear();
      _newPassword.clear();
      _newPasswordAgain.clear();
      if (!mounted) return;
      setState(() {
        _passwordOk = true;
        _passwordMessage = 'Şifren güncellendi.';
      });
    } on ProfileException catch (error) {
      if (!mounted) return;
      setState(() {
        _passwordOk = false;
        _passwordMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _passwordOk = false;
        _passwordMessage = 'Şifre güncellenemedi.';
      });
    } finally {
      if (mounted) setState(() => _passwordSaving = false);
    }
  }

  Future<void> _pickProfileImage(String kind) async {
    if (_photoBusyKind != null) return;
    final token = widget.authToken.trim();
    if (token.isEmpty) {
      _toast(
        'Fotoğraf yüklemek için giriş yapmalısın.',
        tone: FrontendToastTone.error,
      );
      return;
    }
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: kind == 'cover' ? 2400 : 1400,
        maxHeight: kind == 'cover' ? 1600 : 1400,
        imageQuality: 92,
        requestFullMetadata: false,
      );
    } catch (_) {
      if (!mounted) return;
      _toast('Galeri açılamadı.', tone: FrontendToastTone.error);
      return;
    }
    if (file == null) return;
    final length = await file.length();
    if (length > 5 * 1024 * 1024) {
      _toast(
        'Profil görseli en fazla 5 MB olabilir.',
        tone: FrontendToastTone.error,
      );
      return;
    }
    setState(() => _photoBusyKind = kind);
    try {
      final result = await widget.repository.uploadProfileImage(
        token: token,
        kind: kind,
        fileName: file.name,
        bytes: await file.readAsBytes(),
      );
      if (!mounted) return;
      setState(() {
        if (kind == 'cover') {
          _coverUrl = result.displayUrl;
          _coverPath = result.publicSrc;
        } else {
          _avatarUrl = result.displayUrl;
          _avatarPath = result.publicSrc;
        }
      });
      _toast(
        kind == 'cover'
            ? 'Kapak görseli yüklendi.'
            : 'Profil fotoğrafı yüklendi.',
        tone: FrontendToastTone.success,
      );
    } on ProfileException catch (error) {
      if (!mounted) return;
      _toast(error.message, tone: FrontendToastTone.error);
    } catch (_) {
      if (!mounted) return;
      _toast('Görsel yüklenemedi.', tone: FrontendToastTone.error);
    } finally {
      if (mounted) setState(() => _photoBusyKind = null);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        title: Text(
          'Hesabı sil',
          style: AppTypography.titleM.copyWith(color: AppColors.inkStrong),
        ),
        content: Text(
          'Hesabın ve tüm içeriğin kalıcı olarak silinir. Bu işlem geri alınamaz.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Vazgeç',
              style: AppTypography.titleS.copyWith(color: AppColors.inkSoft),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Sil',
              style: AppTypography.titleS.copyWith(color: AppColors.actionRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) _toast('Hesap silme isteği alındı.');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            _EditAppBar(saving: _saving, onSave: _save),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.lg,
                  AppSpacing.pageHorizontal,
                  AppSpacing.xxxl + bottomInset,
                ),
                children: [
                  _PhotosSection(
                    avatarUrl: _avatarUrl,
                    coverUrl: _coverUrl,
                    avatarUploading: _photoBusyKind == 'avatar',
                    coverUploading: _photoBusyKind == 'cover',
                    onPickAvatar: () => _pickProfileImage('avatar'),
                    onPickCover: () => _pickProfileImage('cover'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Hesap Bilgileri',
                    children: [
                      _Field(
                        label: 'Ad Soyad',
                        hint: 'Adını yaz',
                        icon: Symbols.person_rounded,
                        controller: _fullName,
                        textCapitalization: TextCapitalization.words,
                      ),
                      _Field(
                        label: 'Kullanıcı Adı',
                        hint: 'kullaniciadi',
                        icon: Symbols.alternate_email_rounded,
                        controller: _username,
                      ),
                      _Field(
                        label: 'E‑posta',
                        hint: 'mail@ornek.com',
                        icon: Symbols.alternate_email_rounded,
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Profil',
                    children: [
                      _Field(
                        label: 'Uzmanlık / Unvan',
                        hint: 'ör. Yayıncı, Editör',
                        icon: Symbols.sparkling_fill,
                        controller: _expertise,
                      ),
                      AdaptiveCitySelectField(
                        value: _city,
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        onChanged: (value) {
                          setState(() => _city = normalizeTurkeyCity(value));
                        },
                      ),
                      _Field(
                        label: 'Hakkında',
                        hint: 'Kendinden kısaca bahset',
                        icon: Symbols.short_text,
                        controller: _about,
                        maxLines: 4,
                      ),
                      _Field(
                        label: 'Adres',
                        hint: 'Şehir / ilçe',
                        icon: Symbols.location_on_rounded,
                        controller: _address,
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Sosyal Bağlantılar',
                    children: [
                      _Field(
                        label: 'X (Twitter)',
                        hint: 'https://x.com/...',
                        icon: Symbols.twitter_x_fill,
                        iconColor: const Color(0xFF000000),
                        controller: _x,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'Instagram',
                        hint: 'https://www.instagram.com/...',
                        icon: Symbols.instagram_fill,
                        iconColor: const Color(0xFFE4405F),
                        controller: _instagram,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'Facebook',
                        hint: 'https://www.facebook.com/...',
                        icon: Symbols.facebook_fill,
                        iconColor: const Color(0xFF1877F2),
                        controller: _facebook,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'YouTube',
                        hint: 'https://www.youtube.com/...',
                        icon: Symbols.youtube_fill,
                        iconColor: const Color(0xFFFF0000),
                        controller: _youtube,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'WhatsApp',
                        hint: 'https://wa.me/...',
                        icon: Symbols.whatsapp_fill,
                        iconColor: const Color(0xFF25D366),
                        controller: _whatsapp,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'LinkedIn',
                        hint: 'https://www.linkedin.com/in/...',
                        icon: Symbols.linkedin_fill,
                        iconColor: const Color(0xFF0A66C2),
                        controller: _linkedin,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'TikTok',
                        hint: 'https://www.tiktok.com/@...',
                        icon: Symbols.tiktok_fill,
                        iconColor: const Color(0xFF000000),
                        controller: _tiktok,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'Pinterest',
                        hint: 'https://www.pinterest.com/...',
                        icon: Symbols.pinterest_fill,
                        iconColor: const Color(0xFFE60023),
                        controller: _pinterest,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'Snapchat',
                        hint: 'https://www.snapchat.com/add/...',
                        icon: Symbols.snapchat_fill,
                        iconColor: const Color(0xFFFFC400),
                        controller: _snapchat,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'Telegram',
                        hint: 'https://t.me/...',
                        icon: Symbols.telegram_fill,
                        iconColor: const Color(0xFF26A5E4),
                        controller: _telegram,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'Discord',
                        hint: 'https://discord.com/...',
                        icon: Symbols.discord_fill,
                        iconColor: const Color(0xFF5865F2),
                        controller: _discord,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'Reddit',
                        hint: 'https://www.reddit.com/user/...',
                        icon: Symbols.reddit_fill,
                        iconColor: const Color(0xFFFF4500),
                        controller: _reddit,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'Bluesky',
                        hint: 'https://bsky.app/profile/...',
                        icon: Symbols.bluesky_fill,
                        iconColor: const Color(0xFF1185FE),
                        controller: _bluesky,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'Twitch',
                        hint: 'https://www.twitch.tv/...',
                        icon: Symbols.twitch_fill,
                        iconColor: const Color(0xFF9146FF),
                        controller: _twitch,
                        keyboardType: TextInputType.url,
                      ),
                      _Field(
                        label: 'Personal Website URL',
                        hint: 'https://...',
                        icon: Symbols.public_rounded,
                        controller: _website,
                        keyboardType: TextInputType.url,
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Tercihler',
                    children: [
                      _ToggleRow(
                        label: 'E‑postamı profilimde göster',
                        value: _showEmail,
                        onChanged: (v) => setState(() => _showEmail = v),
                      ),
                      const Divider(height: 1, color: AppColors.softLine),
                      _ToggleRow(
                        label: 'RSS akışlarına izin ver',
                        value: _rssFeeds,
                        onChanged: (v) => setState(() => _rssFeeds = v),
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PrimaryButton(
                    label: _saving ? 'Kaydediliyor…' : 'Değişiklikleri Kaydet',
                    loading: _saving,
                    onTap: _save,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Section(
                    title: 'Şifre Değiştir',
                    children: [
                      _PasswordField(
                        label: 'Mevcut Şifre',
                        hint: 'Mevcut şifren',
                        controller: _currentPassword,
                      ),
                      _PasswordField(
                        label: 'Yeni Şifre',
                        hint: 'En az 6 karakter',
                        controller: _newPassword,
                      ),
                      _PasswordField(
                        label: 'Yeni Şifre (Tekrar)',
                        hint: 'Yeni şifreni tekrar yaz',
                        controller: _newPasswordAgain,
                        isLast: true,
                      ),
                      if (_passwordMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _passwordMessage!,
                          style: AppTypography.meta.copyWith(
                            color: _passwordOk
                                ? const Color(0xFF22A565)
                                : AppColors.actionRed,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _SecondaryButton(
                        label: _passwordSaving
                            ? 'Güncelleniyor'
                            : 'Şifreyi Güncelle',
                        icon: Symbols.lock_outline_rounded,
                        onTap: _updatePassword,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _DangerSection(onDelete: _confirmDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditAppBar extends StatelessWidget {
  const _EditAppBar({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback onSave;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Container(
      height: _height + topInset,
      padding: EdgeInsets.only(top: topInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.softLine, width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          _SaveTextButton(saving: saving, onTap: onSave),
          Expanded(
            child: Center(
              child: Text(
                'Profili Düzenle',
                style: AppTypography.titleM.copyWith(
                  color: AppColors.inkStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          BackCircleButton(onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _SaveTextButton extends StatelessWidget {
  const _SaveTextButton({required this.saving, required this.onTap});

  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: saving ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.deepOcean,
        disabledForegroundColor: AppColors.support,
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'Kaydet',
        style: AppTypography.titleS.copyWith(
          fontWeight: FontWeight.w800,
          color: saving ? AppColors.support : AppColors.deepOcean,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 15,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.actionRed,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title,
                style: AppTypography.titleS.copyWith(
                  color: AppColors.inkStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.iconColor,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.obscureText = false,
    this.suffix,
    this.isLast = false,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final Color? iconColor;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final bool obscureText;
  final Widget? suffix;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLines: obscureText ? 1 : maxLines,
        obscureText: obscureText,
        style: AppTypography.titleS.copyWith(
          color: AppColors.inkStrong,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: maxLines > 1
              ? null
              : Icon(icon, color: iconColor ?? AppColors.iconMuted, size: 18),
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
            borderSide: const BorderSide(
              color: AppColors.deepOcean,
              width: 1.2,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
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
    this.isLast = false,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool isLast;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  var _obscured = true;

  @override
  Widget build(BuildContext context) {
    return _Field(
      label: widget.label,
      hint: widget.hint,
      icon: Symbols.lock_outline_rounded,
      controller: widget.controller,
      obscureText: _obscured,
      isLast: widget.isLast,
      suffix: IconButton(
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured
              ? Symbols.visibility_outlined
              : Symbols.visibility_off_outlined,
          color: AppColors.iconMuted,
          size: 18,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isLast ? 4 : 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.actionRed
                  : AppColors.placeholderSoft,
            ),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({
    required this.avatarUrl,
    required this.coverUrl,
    required this.avatarUploading,
    required this.coverUploading,
    required this.onPickAvatar,
    required this.onPickCover,
  });

  final String avatarUrl;
  final String coverUrl;
  final bool avatarUploading;
  final bool coverUploading;
  final VoidCallback onPickAvatar;
  final VoidCallback onPickCover;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Fotoğraflar',
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.value),
          child: Stack(
            children: [
              SizedBox(
                height: 116,
                width: double.infinity,
                child: ColoredBox(
                  color: AppColors.surfaceInk,
                  child: CachedImage(
                    url: coverUrl,
                    fit: BoxFit.cover,
                    errorWidget: const ColoredBox(color: AppColors.surfaceInk),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: _CameraButton(
                  label: coverUploading ? 'Yükleniyor' : 'Kapak',
                  loading: coverUploading,
                  onTap: onPickCover,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.line),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: ColoredBox(
                        color: AppColors.surfaceInk,
                        child: CachedImage(
                          url: avatarUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 160,
                          placeholderColor: AppColors.surfaceInk,
                          errorWidget: const Icon(
                            Symbols.person_rounded,
                            color: AppColors.support,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profil fotoğrafı',
                    style: AppTypography.titleS.copyWith(
                      color: AppColors.inkStrong,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'JPG veya PNG · en fazla 5 MB',
                    style: AppTypography.meta.copyWith(
                      color: AppColors.support,
                    ),
                  ),
                ],
              ),
            ),
            _CameraButton(
              label: avatarUploading ? 'Yükleniyor' : 'Değiştir',
              loading: avatarUploading,
              onTap: onPickAvatar,
            ),
          ],
        ),
      ],
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.deepOcean,
      borderRadius: BorderRadius.circular(AppRadius.value),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Symbols.photo_camera,
                      size: 14,
                      color: Colors.white,
                    ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.eyebrow.copyWith(
                  color: Colors.white,
                  fontSize: 10.5,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
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
        color: AppColors.actionRed,
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.value),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: AppTypography.titleS.copyWith(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceInk,
      borderRadius: BorderRadius.circular(AppRadius.value),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: AppColors.deepOcean),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.titleS.copyWith(
                  color: AppColors.deepOcean,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerSection extends StatelessWidget {
  const _DangerSection({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.30)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tehlikeli Alan',
            style: AppTypography.titleS.copyWith(
              color: AppColors.actionRed,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hesabını silersen profilin, gönderilerin ve tüm verilerin kalıcı '
            'olarak kaldırılır.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(AppRadius.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.value),
                    border: Border.all(color: AppColors.actionRed),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.delete,
                        size: 16,
                        color: AppColors.actionRed,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Hesabı Sil',
                        style: AppTypography.titleS.copyWith(
                          color: AppColors.actionRed,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
