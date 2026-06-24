import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/icons/symbols.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
import '../../../../shared/widgets/admin_toast.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import '../../../auth/data/admin_auth_models.dart';
import '../../../social/data/admin_social_repository.dart';
import '../../../social/presentation/social_platform_data.dart';

const _red = AppColors.actionRed;
const _ink = AppColors.deepOcean;
const _soft = AppColors.inkSoft;
const _muted = AppColors.iconMuted;
const _line = AppColors.line;
const _surface = AppColors.surface;
const _redTint = Color(0xFFFDECEA);
const _redTintSoft = Color(0xFFFFF7F6);
const _green = Color(0xFF16A34A);
const _greenBg = Color(0xFFE9FBEF);

const _rInput = 12.0;
const _rCard = 16.0;

/// Yayınla sonrası paylaşım/bildirim akışına aktarılan haber verisi.
class NewsPublishShareData {
  const NewsPublishShareData({
    required this.title,
    required this.summary,
    required this.link,
    required this.mansetImageUrl,
    required this.imageUrls,
  });

  final String title;
  final String summary;
  final String link;
  final String mansetImageUrl;
  final List<String> imageUrls;
}

Future<void> showNewsPublishShareDialog(
  BuildContext context, {
  required AdminSession session,
  required NewsPublishShareData data,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Paylaşım',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, _, _) =>
        _NewsPublishShareDialog(session: session, data: data),
    transitionBuilder: (ctx, anim, _, child) {
      final mobile = MediaQuery.of(ctx).size.width < 720;
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      if (mobile) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      }
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ShareAccount {
  _ShareAccount({
    required this.platform,
    required this.name,
    required this.handle,
    required this.avatarUrl,
  });

  final SocialPlatform platform;
  final String name;
  final String handle;
  final String avatarUrl;
  bool selected = true;
}

class _PlatformMeta {
  const _PlatformMeta(this.label, this.icon, this.color, {this.letter});

  final String label;
  final IconData? icon;
  final Color color;
  final String? letter;
}

_PlatformMeta _platformMeta(SocialPlatform platform) {
  switch (platform.name) {
    case 'instagram':
      return const _PlatformMeta(
        'Instagram',
        Symbols.instagram_fill,
        Color(0xFFDD2A7B),
      );
    case 'facebook':
      return const _PlatformMeta(
        'Facebook',
        Symbols.facebook_fill,
        Color(0xFF1877F2),
      );
    case 'twitter':
      return const _PlatformMeta('X', null, Color(0xFF111111), letter: '𝕏');
    case 'linkedin':
      return const _PlatformMeta(
        'LinkedIn',
        Symbols.public,
        Color(0xFF0A66C2),
      );
    case 'youtube':
      return const _PlatformMeta('YouTube', Symbols.public, Color(0xFFFF0000));
    case 'tiktok':
      return const _PlatformMeta('TikTok', null, Color(0xFF111111), letter: '♪');
    case 'pinterest':
      return const _PlatformMeta(
        'Pinterest',
        Symbols.public,
        Color(0xFFE60023),
      );
    default:
      final raw = platform.name;
      final label = raw.isEmpty
          ? 'Sosyal'
          : '${raw[0].toUpperCase()}${raw.substring(1)}';
      return _PlatformMeta(label, Symbols.public, _ink);
  }
}

enum _Step { intro, social, notif, done }

class _NewsPublishShareDialog extends StatefulWidget {
  const _NewsPublishShareDialog({required this.session, required this.data});

  final AdminSession session;
  final NewsPublishShareData data;

  @override
  State<_NewsPublishShareDialog> createState() =>
      _NewsPublishShareDialogState();
}

class _NewsPublishShareDialogState extends State<_NewsPublishShareDialog> {
  bool _shareSocial = true;
  bool _notify = true;
  bool _allImages = true;
  late List<bool> _imgSel;

  List<_ShareAccount> _accounts = [];
  bool _loadingAccounts = true;

  late final TextEditingController _postText;
  late final TextEditingController _nfTitle;
  late final TextEditingController _nfBody;

  SocialPlatform _previewPlatform = SocialPlatform.instagram;
  String _format = 'feed';
  final Set<String> _platforms = {'android', 'ios', 'flutter', 'astro'};

  _Step _step = _Step.intro;
  String _mobileView = 'edit';

  List<String> get _images => widget.data.imageUrls;

  @override
  void initState() {
    super.initState();
    _imgSel = List<bool>.filled(_images.length, true);
    final d = widget.data;
    _postText = TextEditingController(
      text: d.summary.trim().isNotEmpty
          ? '${d.title}\n\n${d.summary}'
          : d.title,
    );
    _nfTitle = TextEditingController(text: d.title);
    _nfBody = TextEditingController(
      text: d.summary.trim().isEmpty ? d.title : d.summary,
    );
    unawaited(_loadAccounts());
  }

  @override
  void dispose() {
    _postText.dispose();
    _nfTitle.dispose();
    _nfBody.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final raw = await const SupabaseAdminSocialRepository()
          .fetchConnectedAccounts(widget.session);
      if (!mounted) return;
      final list = raw
          .map(
            (a) => _ShareAccount(
              platform: a.platform,
              name: a.resolvedDisplayName,
              handle: a.resolvedUsername,
              avatarUrl: a.avatarUrl,
            ),
          )
          .toList();
      setState(() {
        _accounts = list;
        _loadingAccounts = false;
        if (list.isNotEmpty) _previewPlatform = list.first.platform;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAccounts = false);
    }
  }

  List<_Step> get _stepFlow => [
    _Step.intro,
    if (_shareSocial) _Step.social,
    if (_notify) _Step.notif,
    _Step.done,
  ];

  List<SocialPlatform> get _previewPlatforms {
    final seen = <SocialPlatform>[];
    for (final a in _accounts) {
      if (a.selected && !seen.contains(a.platform)) seen.add(a.platform);
    }
    return seen;
  }

  int get _selectedImageCount => _imgSel.where((e) => e).length;

  int get _primaryImageIndex {
    final manset = widget.data.mansetImageUrl.trim();
    for (var i = 0; i < _images.length; i++) {
      if (_imgSel[i] && _images[i].trim() == manset && manset.isNotEmpty) {
        return i;
      }
    }
    for (var i = 0; i < _imgSel.length; i++) {
      if (_imgSel[i]) return i;
    }
    return _images.isEmpty ? -1 : 0;
  }

  bool _isManset(int index) {
    final manset = widget.data.mansetImageUrl.trim();
    if (manset.isEmpty) return index == 0;
    return _images[index].trim() == manset;
  }

  void _goNext() {
    final flow = _stepFlow;
    final i = flow.indexOf(_step);
    if (i >= 0 && i < flow.length - 1) {
      setState(() {
        _step = flow[i + 1];
        _mobileView = 'edit';
      });
    }
  }

  void _goPrev() {
    final flow = _stepFlow;
    final i = flow.indexOf(_step);
    if (i > 0) {
      setState(() {
        _step = flow[i - 1];
        _mobileView = 'edit';
      });
    }
  }

  void _finish() {
    AdminToast.show(
      context,
      message: 'Paylaşım ve bildirim hazırlandı.',
      tone: AdminToastTone.success,
    );
    Navigator.of(context).maybePop();
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 720;
    final screenH = MediaQuery.of(context).size.height;

    final shell = Material(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(24),
        bottom: Radius.circular(mobile ? 0 : 24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _topBar(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _stepBody(mobile),
                ),
              ),
            ),
          ),
          _footer(),
        ],
      ),
    );

    if (mobile) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenH * 0.92),
          child: shell,
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 660,
            maxHeight: screenH * 0.88,
          ),
          child: shell,
        ),
      ),
    );
  }

  Widget _topBar() {
    final titles = switch (_step) {
      _Step.intro => ('Haber yayınlandı', 'Sırada paylaşım ve bildirim var'),
      _Step.social => (
        'Sosyal medya paylaşımı',
        'Üst sekmeden platform önizlemesini seç',
      ),
      _Step.notif => ('Bildirim gönder', 'Önizle ve kullanıcılara ulaştır'),
      _Step.done => ('İşlem tamam', 'Özet'),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text(
              'P',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles.$1,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  titles.$2,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          _IconBtn(icon: Symbols.close, onTap: _close),
        ],
      ),
    );
  }

  Widget _stepBody(bool mobile) {
    return switch (_step) {
      _Step.intro => _introBody(),
      _Step.social => _socialBody(mobile),
      _Step.notif => _notifBody(mobile),
      _Step.done => _doneBody(),
    };
  }

  // ---------------------------------------------------------------- intro
  Widget _introBody() {
    final d = widget.data;
    final primary = _images.isNotEmpty ? _images.first : d.mansetImageUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF1EF), Color(0xFFFDF6EC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_rCard),
            border: Border.all(color: const Color(0xFFF6E2DD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
                child: const SymbolIcon(
                  Symbols.check,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Haber yayına alındı',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                d.title.trim().isEmpty
                    ? 'Haber yayında. Şimdi okuyuculara ulaştıralım.'
                    : '“${d.title.trim()}” artık yayında. Şimdi okuyuculara ulaştıralım.',
                style: const TextStyle(color: _soft, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  children: [
                    _Thumb(url: primary, size: 52),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.title.trim().isEmpty ? 'Yeni haber' : d.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Yayında · Az önce · ${_images.length} görsel',
                            style: const TextStyle(color: _muted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 18, 2, 11),
          child: Text(
            'Bu haber için ne yapalım?',
            style: TextStyle(
              color: _soft,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        _ActionCard(
          icon: Symbols.send_rounded,
          title: 'Sosyal medyada paylaş',
          subtitle: 'Aktif hesaplarda paylaşım oluştur, önizle',
          value: _shareSocial,
          onTap: () => setState(() => _shareSocial = !_shareSocial),
        ),
        const SizedBox(height: 11),
        _ActionCard(
          icon: Symbols.notifications,
          title: 'Bildirim gönder',
          subtitle: 'Mobil ve web kullanıcılarına anlık bildirim',
          value: _notify,
          onTap: () => setState(() => _notify = !_notify),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- social
  Widget _socialBody(bool mobile) {
    final compose = _socialCompose();
    final preview = _socialPreview();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _progress(),
        if (mobile) ...[
          _MobileViewTabs(
            value: _mobileView,
            onChanged: (v) => setState(() => _mobileView = v),
          ),
          const SizedBox(height: 13),
          if (_mobileView == 'edit') compose else preview,
        ] else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: compose),
                const SizedBox(width: 16),
                SizedBox(width: 250, child: preview),
              ],
            ),
          ),
      ],
    );
  }

  Widget _socialCompose() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Label(icon: Symbols.image_outlined, text: 'Görseller', trailing: '$_selectedImageCount / ${_images.length} seçili'),
        const SizedBox(height: 8),
        _SwitchRow(
          title: 'Haberdeki tüm görselleri kullan',
          subtitle: 'Manşet dahil ${_images.length} görsel otomatik eklensin',
          value: _allImages,
          onTap: () {
            setState(() {
              _allImages = !_allImages;
              if (_allImages) {
                for (var i = 0; i < _imgSel.length; i++) {
                  _imgSel[i] = true;
                }
              }
            });
          },
        ),
        const SizedBox(height: 11),
        _imageGrid(),
        const SizedBox(height: 18),
        _Label(icon: Symbols.public, text: 'Paylaşılacak hesaplar', trailing: 'aktif olanlar'),
        const SizedBox(height: 8),
        _accountList(),
        const SizedBox(height: 18),
        _Label(
          icon: Symbols.auto_awesome,
          text: 'Gönderi metni',
          trailing: '${_postText.text.length} karakter',
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _postText,
          minLines: 3,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13, color: _ink, height: 1.4),
          decoration: _fieldDecoration('Her platformda kullanılacak metin...'),
        ),
      ],
    );
  }

  Widget _imageGrid() {
    if (_images.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(_rInput),
          border: Border.all(color: _line),
        ),
        child: const Text(
          'Haberde görsel bulunamadı',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth < 280 ? 3 : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
          ),
          itemCount: _images.length,
          itemBuilder: (context, i) => _imageTile(i),
        );
      },
    );
  }

  Widget _imageTile(int i) {
    final selected = _imgSel[i];
    final manset = _isManset(i);
    return GestureDetector(
      onTap: _allImages
          ? null
          : () {
              setState(() {
                if (selected && _selectedImageCount <= 1) return;
                _imgSel[i] = !selected;
              });
            },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? _red : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AdminCachedImage(url: _images[i]),
              if (manset)
                Positioned(
                  left: 5,
                  top: 5,
                  child: _badge('Manşet'),
                ),
              Positioned(
                right: 5,
                top: 5,
                child: Container(
                  width: 19,
                  height: 19,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? _red
                        : Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: SymbolIcon(
                    Symbols.check,
                    color: selected ? Colors.white : _soft,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountList() {
    if (_loadingAccounts) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: _red),
        ),
      );
    }
    if (_accounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(_rInput),
          border: Border.all(color: _line),
        ),
        child: const Text(
          'Bağlı sosyal hesap bulunamadı. Sosyal Medya modülünden hesap bağlayabilirsin.',
          style: TextStyle(color: _soft, fontSize: 12, height: 1.4),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _accounts.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _accountTile(_accounts[i]),
        ],
      ],
    );
  }

  Widget _accountTile(_ShareAccount a) {
    final meta = _platformMeta(a.platform);
    final selected = a.selected;
    return GestureDetector(
      onTap: () {
        setState(() {
          final selectedCount = _accounts.where((e) => e.selected).length;
          if (selected && selectedCount <= 1) return;
          a.selected = !selected;
          if (!_previewPlatforms.contains(_previewPlatform) &&
              _previewPlatforms.isNotEmpty) {
            _previewPlatform = _previewPlatforms.first;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _redTintSoft : Colors.white,
          borderRadius: BorderRadius.circular(_rInput),
          border: Border.all(
            color: selected ? _red : _line,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            _PlatformAvatar(meta: meta, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name.isEmpty ? meta.label : a.name,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    a.handle.isEmpty ? meta.label : '@${a.handle}',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? _redTint : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? const Color(0xFFFBD9D4) : _line),
              ),
              child: Text(
                selected ? 'Seçili' : 'Seç',
                style: TextStyle(
                  color: selected ? _red : _muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialPreview() {
    final platforms = _previewPlatforms;
    if (platforms.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(_rCard),
          border: Border.all(color: _line),
        ),
        child: const Text(
          'Önizleme için en az bir hesap seç.',
          style: TextStyle(color: _soft, fontSize: 12),
        ),
      );
    }
    if (!platforms.contains(_previewPlatform)) {
      _previewPlatform = platforms.first;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < platforms.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _previewTab(platforms[i])),
            ],
          ],
        ),
        const SizedBox(height: 11),
        _previewAccountRow(),
        if (_previewPlatform == SocialPlatform.instagram) ...[
          const SizedBox(height: 11),
          const Text(
            'Format',
            style: TextStyle(
              color: _soft,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 7),
          _formatTabs(),
        ],
        const SizedBox(height: 11),
        _previewCard(),
      ],
    );
  }

  Widget _previewTab(SocialPlatform p) {
    final meta = _platformMeta(p);
    final active = p == _previewPlatform;
    return GestureDetector(
      onTap: () => setState(() => _previewPlatform = p),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? meta.color.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? meta.color.withValues(alpha: 0.45) : _line,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _platformGlyph(meta, active ? meta.color : _muted, 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                meta.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? meta.color : _soft,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewAccountRow() {
    final meta = _platformMeta(_previewPlatform);
    final account = _accounts.firstWhere(
      (a) => a.platform == _previewPlatform && a.selected,
      orElse: () => _ShareAccount(
        platform: _previewPlatform,
        name: 'Pateez',
        handle: 'pateezcom',
        avatarUrl: '',
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_rInput),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          _PlatformAvatar(meta: meta, size: 30),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name.isEmpty ? 'Pateez' : account.name,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  account.handle.isEmpty ? meta.label : '@${account.handle}',
                  style: const TextStyle(color: _muted, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Seçili',
              style: TextStyle(
                color: meta.color,
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatTabs() {
    Widget tab(String key, String label, IconData icon) {
      final active = _format == key;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _format = key),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? _redTint : _surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: active ? _red : _line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SymbolIcon(icon, color: active ? _red : _soft, size: 13),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? _red : _soft,
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('feed', 'Akış', Symbols.image_outlined),
        const SizedBox(width: 6),
        tab('story', 'Hikaye', Symbols.image_outlined),
        const SizedBox(width: 6),
        tab('reels', 'Reels', Symbols.image_outlined),
      ],
    );
  }

  Widget _previewCard() {
    final idx = _primaryImageIndex;
    final imageUrl = idx >= 0 ? _images[idx] : widget.data.mansetImageUrl;
    final story =
        _previewPlatform == SocialPlatform.instagram && _format != 'feed';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    'P',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'pateezcom',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SymbolIcon(Symbols.more_vert, color: _muted, size: 16),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: story ? 4 / 5 : 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.trim().isNotEmpty)
                  AdminCachedImage(url: imageUrl)
                else
                  Container(color: _surface),
                if (idx >= 0)
                  Positioned(
                    left: 7,
                    top: 7,
                    child: _badge(_isManset(idx) ? 'Manşet' : 'Görsel ${idx + 1}'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 3),
            child: Row(
              children: const [
                SymbolIcon(Symbols.heart_3_line, color: _ink, size: 16),
                SizedBox(width: 13),
                SymbolIcon(Symbols.chat_3_line, color: _ink, size: 16),
                SizedBox(width: 13),
                SymbolIcon(Symbols.send_rounded, color: _ink, size: 16),
                Spacer(),
                SymbolIcon(Symbols.bookmark_line, color: _ink, size: 16),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 2),
            child: Text(
              '1.234 beğenme',
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 9),
            child: RichText(
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                  color: _ink,
                  fontSize: 10.5,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(
                    text: 'pateezcom ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: _postText.text.replaceAll('\n', ' ')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- notif
  Widget _notifBody(bool mobile) {
    final compose = _notifCompose();
    final preview = _notifPreview();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _progress(),
        if (mobile) ...[
          _MobileViewTabs(
            value: _mobileView,
            onChanged: (v) => setState(() => _mobileView = v),
          ),
          const SizedBox(height: 13),
          if (_mobileView == 'edit') compose else preview,
        ] else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: compose),
                const SizedBox(width: 16),
                SizedBox(width: 250, child: preview),
              ],
            ),
          ),
      ],
    );
  }

  Widget _notifCompose() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          margin: const EdgeInsets.only(bottom: 13),
          decoration: BoxDecoration(
            color: _greenBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SymbolIcon(Symbols.auto_awesome, color: _green, size: 14),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Haber bilgileri otomatik dolduruldu',
                  style: TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        _Label(icon: Symbols.image_outlined, text: 'Bildirim görseli'),
        const SizedBox(height: 8),
        _SwitchRow(
          leading: _Thumb(url: widget.data.mansetImageUrl, size: 38),
          title: 'Manşet görseli',
          subtitle: 'Bildirimde küçük görsel olarak çıkar',
          value: true,
          onTap: () {},
        ),
        const SizedBox(height: 16),
        _Label(icon: Symbols.auto_awesome, text: 'Başlık'),
        const SizedBox(height: 8),
        TextField(
          controller: _nfTitle,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13, color: _ink),
          decoration: _fieldDecoration('Bildirim başlığı'),
        ),
        const SizedBox(height: 16),
        _Label(icon: Symbols.auto_awesome, text: 'Açıklama'),
        const SizedBox(height: 8),
        TextField(
          controller: _nfBody,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13, color: _ink, height: 1.4),
          decoration: _fieldDecoration('Bildirim açıklaması'),
        ),
        const SizedBox(height: 16),
        _Label(icon: Symbols.phone_iphone_outlined, text: 'Platformlar'),
        const SizedBox(height: 9),
        _platformPills(),
      ],
    );
  }

  Widget _platformPills() {
    const items = [
      ('all', 'Tümü', Symbols.public),
      ('android', 'Android', Symbols.phone_iphone_outlined),
      ('ios', 'iOS', Symbols.apple_rounded),
      ('flutter', 'Flutter Web', Symbols.phone_iphone_outlined),
      ('astro', 'Astro Web', Symbols.public),
    ];
    bool isOn(String key) =>
        key == 'all' ? _platforms.length == 4 : _platforms.contains(key);
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final item in items)
          GestureDetector(
            onTap: () {
              setState(() {
                if (item.$1 == 'all') {
                  if (_platforms.length == 4) {
                    _platforms.clear();
                  } else {
                    _platforms
                      ..clear()
                      ..addAll(['android', 'ios', 'flutter', 'astro']);
                  }
                } else if (_platforms.contains(item.$1)) {
                  _platforms.remove(item.$1);
                } else {
                  _platforms.add(item.$1);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isOn(item.$1) ? _redTint : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isOn(item.$1) ? _red : _line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SymbolIcon(
                    item.$3,
                    color: isOn(item.$1) ? _red : _soft,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.$2,
                    style: TextStyle(
                      color: isOn(item.$1) ? _red : _soft,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _notifPreview() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF11161C), width: 6),
        color: const Color(0xFF11161C),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 30, 14, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF243042), Color(0xFF11161C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Çarşamba, 24 Haziran',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
                const SizedBox(height: 2),
                const Text(
                  '14:09',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'P',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _nfTitle.text.isEmpty
                                        ? 'Pateez'
                                        : _nfTitle.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                                const Text(
                                  'şimdi',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _nfBody.text,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 9),
                      _Thumb(url: widget.data.mansetImageUrl, size: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- done
  Widget _doneBody() {
    final accountCount = _accounts.where((a) => a.selected).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _greenBg,
              shape: BoxShape.circle,
            ),
            child: const SymbolIcon(Symbols.check, color: _green, size: 34),
          ),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Her şey hazır',
            style: TextStyle(
              color: _ink,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Haber yayında. İşlemler sıraya alındı.',
            style: TextStyle(color: _soft, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        if (_shareSocial)
          _recapRow(
            icon: Symbols.send_rounded,
            title: 'Sosyal medya paylaşımı',
            subtitle: '$accountCount hesapta · $_selectedImageCount görsel sıraya alındı',
          ),
        if (_notify)
          _recapRow(
            icon: Symbols.notifications,
            title: 'Bildirim',
            subtitle: '${_platforms.length} platforma gönderildi',
          ),
      ],
    );
  }

  Widget _recapRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _greenBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SymbolIcon(icon, color: _green, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SymbolIcon(Symbols.check, color: _green, size: 18),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- shared
  Widget _progress() {
    final steps = <_Step>[
      if (_shareSocial) _Step.social,
      if (_notify) _Step.notif,
    ];
    if (steps.length < 2) return const SizedBox.shrink();
    final flow = _stepFlow;
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _progressSeg(
                index: i + 1,
                label: steps[i] == _Step.social ? 'Sosyal medya' : 'Bildirim',
                active: steps[i] == _step,
                done: flow.indexOf(steps[i]) < flow.indexOf(_step),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _progressSeg({
    required int index,
    required String label,
    required bool active,
    required bool done,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _redTint : _surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 19,
            height: 19,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? _green : (active ? _red : const Color(0xFFD5DBDD)),
              shape: BoxShape.circle,
            ),
            child: done
                ? const SymbolIcon(Symbols.check, color: Colors.white, size: 11)
                : Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? _ink : _muted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    final children = <Widget>[];
    switch (_step) {
      case _Step.intro:
        children.add(
          _Btn(
            label: 'Şimdilik geç',
            icon: Symbols.schedule,
            onTap: _close,
          ),
        );
        children.add(const Spacer());
        children.add(
          _Btn(
            label: 'Devam et',
            icon: Symbols.arrow_forward,
            primary: true,
            trailingIcon: true,
            onTap: (_shareSocial || _notify) ? _goNext : null,
          ),
        );
      case _Step.social:
        children.add(_Btn(label: 'Geri', icon: Symbols.arrow_back, onTap: _goPrev));
        children.add(const Spacer());
        children.add(
          _Btn(
            label: 'Devam',
            icon: Symbols.arrow_forward,
            primary: true,
            trailingIcon: true,
            onTap: _goNext,
          ),
        );
      case _Step.notif:
        children.add(_Btn(label: 'Geri', icon: Symbols.arrow_back, onTap: _goPrev));
        children.add(const Spacer());
        children.add(
          _Btn(
            label: 'Şimdi gönder',
            icon: Symbols.send_rounded,
            primary: true,
            onTap: _goNext,
          ),
        );
      case _Step.done:
        children.add(_Btn(label: 'Yeni haber', icon: Symbols.add, onTap: _close));
        children.add(const Spacer());
        children.add(
          _Btn(label: 'Bitir', icon: Symbols.check, primary: true, onTap: _finish),
        );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: const BoxDecoration(
        color: Color(0xFFFCFDFD),
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(children: children),
    );
  }

  Widget _platformGlyph(_PlatformMeta meta, Color color, double size) {
    if (meta.icon != null) {
      return SymbolIcon(meta.icon!, color: color, size: size);
    }
    return Text(
      meta.letter ?? meta.label.substring(0, 1),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: size,
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.placeholder, fontSize: 13),
      filled: true,
      fillColor: _surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_rInput),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_rInput),
        borderSide: const BorderSide(color: _red, width: 1.4),
      ),
    );
  }
}

class _PlatformAvatar extends StatelessWidget {
  const _PlatformAvatar({required this.meta, required this.size});

  final _PlatformMeta meta;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: meta.color,
        borderRadius: BorderRadius.circular(9),
      ),
      child: meta.icon != null
          ? SymbolIcon(meta.icon!, color: Colors.white, size: size * 0.55)
          : Text(
              meta.letter ?? meta.label.substring(0, 1),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.5,
              ),
            ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: url.trim().isEmpty
            ? Container(color: _surface)
            : AdminCachedImage(url: url),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _line),
        ),
        child: SymbolIcon(icon, color: _soft, size: 17),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.icon, required this.text, this.trailing});

  final IconData icon;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SymbolIcon(icon, color: _soft, size: 15),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: _soft,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Text(
            trailing!,
            style: const TextStyle(color: _muted, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.leading,
  });

  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: value ? _redTintSoft : _surface,
          borderRadius: BorderRadius.circular(_rInput),
          border: Border.all(color: value ? const Color(0xFFF6D4CF) : _line),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 11)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _MiniSwitch(value: value),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: value ? _redTintSoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value ? _red : _line, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value ? _redTint : _surface,
                borderRadius: BorderRadius.circular(11),
              ),
              child: SymbolIcon(
                icon,
                color: value ? _red : _soft,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _MiniSwitch(value: value),
          ],
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: value ? _red : const Color(0xFFD5DBDD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _MobileViewTabs extends StatelessWidget {
  const _MobileViewTabs({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String key, String label, IconData icon) {
      final active = value == key;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(key),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _ink.withValues(alpha: 0.12),
                        blurRadius: 3,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SymbolIcon(icon, color: active ? _ink : _soft, size: 15),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? _ink : _soft,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          tab('edit', 'Düzenle', Symbols.auto_awesome),
          tab('preview', 'Önizleme', Symbols.image_outlined),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.icon,
    this.onTap,
    this.primary = false,
    this.trailingIcon = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool trailingIcon;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bg = primary
        ? (disabled ? const Color(0xFFF2B4AE) : _red)
        : Colors.white;
    final fg = primary ? Colors.white : _ink;
    final children = <Widget>[
      if (!trailingIcon) ...[SymbolIcon(icon, color: fg, size: 16), const SizedBox(width: 7)],
      Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
      ),
      if (trailingIcon) ...[const SizedBox(width: 7), SymbolIcon(icon, color: fg, size: 16)],
    ];
    return Opacity(
      opacity: disabled ? 0.9 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: primary ? bg : _line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}
