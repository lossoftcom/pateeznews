import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/social_action.dart';

/// Detay sayfası kaydırıldıkça sağ üstte beliren, iki durumlu paylaşım
/// & aksiyon çubuğu.
///
/// Durumlar:
///   - Kapalı (ilk açılış varsayılanı): Sağ üstte küçük, dikkat çekici
///     "PAYLAŞ" kırmızı pil butonu. Tıklayınca dock açılır.
///   - Açık: Tam dock — paylaşım sayım header'ı, 4 marka butonu (Instagram,
///     Facebook, X, WhatsApp), beğen/beğenme + ribbon aksiyon butonları, en altta
///     küçük "KAPAT" mikro butonu.
///
/// State session boyunca hatırlanır (sınıf-seviyesi statik değişken).
/// İlk kurulumda kapalıdır; kullanıcı açtıysa açık, kapattıysa kapalı kalır.
class DetailFloatingDock extends StatefulWidget {
  const DetailFloatingDock({
    super.key,
    required this.onInstagram,
    required this.onFacebook,
    required this.onX,
    required this.onWhatsApp,
    required this.onLike,
    required this.onDislike,
    required this.onSave,
    this.shareCount = 0,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.saveCount = 0,
  });

  final VoidCallback onInstagram;
  final VoidCallback onFacebook;
  final VoidCallback onX;
  final VoidCallback onWhatsApp;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onSave;
  final int shareCount;
  final int likeCount;
  final int dislikeCount;
  final int saveCount;

  @override
  State<DetailFloatingDock> createState() => _DetailFloatingDockState();
}

class _DetailFloatingDockState extends State<DetailFloatingDock> {
  /// Session-seviyesi hafıza. Detay sayfaları arasında geçişlerde state
  /// korunur; uygulama yeniden açıldığında varsayılan (false) ile başlar
  /// — kullanıcının istediği "ilk kurulumda kapalı" davranışına uyar.
  static bool _sessionOpen = false;

  late bool _isOpen;

  @override
  void initState() {
    super.initState();
    _isOpen = _sessionOpen;
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() {
      _isOpen = !_isOpen;
      _sessionOpen = _isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topRight,
          clipBehavior: Clip.none,
          children: [...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, anim) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final openingDock = child.key == const ValueKey('dock-open');
        if (!openingDock) {
          return FadeTransition(opacity: curved, child: child);
        }

        // Mirrors NewsDetailScreen's scroll reveal: 0.35 right offset + fade.
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.35, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: _isOpen
          ? _OpenDockContent(
              key: const ValueKey('dock-open'),
              shareCount: widget.shareCount,
              likeCount: widget.likeCount,
              dislikeCount: widget.dislikeCount,
              saveCount: widget.saveCount,
              onInstagram: widget.onInstagram,
              onFacebook: widget.onFacebook,
              onX: widget.onX,
              onWhatsApp: widget.onWhatsApp,
              onLike: widget.onLike,
              onDislike: widget.onDislike,
              onSave: widget.onSave,
              onClose: _toggle,
            )
          : _ClosedShareTrigger(
              key: const ValueKey('dock-closed'),
              onTap: _toggle,
            ),
    );
  }
}

/// Açık durumda gösterilen tam dock içeriği.
class _OpenDockContent extends StatelessWidget {
  const _OpenDockContent({
    super.key,
    required this.shareCount,
    required this.likeCount,
    required this.dislikeCount,
    required this.saveCount,
    required this.onInstagram,
    required this.onFacebook,
    required this.onX,
    required this.onWhatsApp,
    required this.onLike,
    required this.onDislike,
    required this.onSave,
    required this.onClose,
  });

  final int shareCount;
  final int likeCount;
  final int dislikeCount;
  final int saveCount;
  final VoidCallback onInstagram;
  final VoidCallback onFacebook;
  final VoidCallback onX;
  final VoidCallback onWhatsApp;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onSave;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ShareCountHeader(count: shareCount),
        const SizedBox(height: 10),
        _BrandDot(brand: _Brand.instagram, onTap: onInstagram),
        const SizedBox(height: 6),
        _BrandDot(brand: _Brand.facebook, onTap: onFacebook),
        const SizedBox(height: 6),
        _BrandDot(brand: _Brand.x, onTap: onX),
        const SizedBox(height: 6),
        _BrandDot(brand: _Brand.whatsapp, onTap: onWhatsApp),
        const SizedBox(height: 14),
        _PateezDot(
          glyph: PateezSocialGlyph.sparkUp,
          accent: AppColors.deepOcean,
          semantics: 'Beğen',
          baseCount: likeCount,
          onTap: onLike,
        ),
        const SizedBox(height: 6),
        _PateezDot(
          glyph: PateezSocialGlyph.sparkDown,
          accent: AppColors.actionRed,
          semantics: 'Beğenme',
          baseCount: dislikeCount,
          onTap: onDislike,
        ),
        const SizedBox(height: 6),
        _PateezDot(
          glyph: PateezSocialGlyph.ribbon,
          accent: AppColors.warmHorizon,
          semantics: 'Kaydet',
          baseCount: saveCount,
          onTap: onSave,
        ),
        const SizedBox(height: 10),
        _CloseMicroButton(onTap: onClose),
      ],
    );
  }
}

/// Kapalı durumda gösterilen küçük, dikkat çekici paylaşım tetikleyicisi.
class _ClosedShareTrigger extends StatefulWidget {
  const _ClosedShareTrigger({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ClosedShareTrigger> createState() => _ClosedShareTriggerState();
}

class _ClosedShareTriggerState extends State<_ClosedShareTrigger> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paylaşım menüsünü aç',
      button: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.actionRed.withValues(
                    alpha: _pressed ? 0.28 : 0.42,
                  ),
                  blurRadius: _pressed ? 14 : 22,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: const Color(0xFFE63420).withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                children: [
                  // Ana zemin: çapraz koyu kırmızı gradient.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF4A33),
                          AppColors.actionRed,
                          Color(0xFFC92A18),
                        ],
                        stops: [0, 0.55, 1],
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Symbols.share_2_line,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'PAYLAŞ',
                          style: TextStyle(
                            fontFamily: 'PateezInter',
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Üstte ince beyaz parlama — cam/3D his.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 14,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.22),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // İnce iç çerçeve highlight — kontur netliği.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Açık dock'un altında yer alan küçük "KAPAT" mikro butonu.
class _CloseMicroButton extends StatelessWidget {
  const _CloseMicroButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paylaşım menüsünü kapat',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Symbols.close_rounded,
                  size: 10,
                  color: AppColors.support,
                ),
                const SizedBox(width: 3),
                Text(
                  'KAPAT',
                  style: TextStyle(
                    fontFamily: 'PateezInter',
                    color: AppColors.support,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    height: 1,
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

class _ShareCountHeader extends StatelessWidget {
  const _ShareCountHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          CountFormat.compact(count),
          style: const TextStyle(
            fontFamily: 'PateezInter',
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.inkStrong,
            height: 1,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'PAYLAŞIM',
          style: TextStyle(
            fontFamily: 'PateezInter',
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.support,
            height: 1,
          ),
        ),
      ],
    );
  }
}

enum _Brand { instagram, facebook, x, whatsapp }

class _BrandDot extends StatefulWidget {
  const _BrandDot({required this.brand, required this.onTap});

  final _Brand brand;
  final VoidCallback onTap;

  @override
  State<_BrandDot> createState() => _BrandDotState();
}

class _BrandDotState extends State<_BrandDot> {
  bool _pressed = false;

  static const double _size = 32;

  void _handleTapDown(_) => setState(() => _pressed = true);
  void _handleTapUp(_) => setState(() => _pressed = false);
  void _handleTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _semanticsFor(widget.brand),
      button: true,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            width: _size,
            height: _size,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1C52A9FF),
                  blurRadius: 22,
                  offset: Offset(-2, 5),
                  spreadRadius: -3,
                ),
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              _iconFor(widget.brand),
              color: _colorFor(widget.brand),
              size: _size * 0.58,
            ),
          ),
        ),
      ),
    );
  }

  static String _semanticsFor(_Brand b) {
    switch (b) {
      case _Brand.instagram:
        return 'Instagram\'da paylaş';
      case _Brand.facebook:
        return 'Facebook\'ta paylaş';
      case _Brand.x:
        return 'X\'te paylaş';
      case _Brand.whatsapp:
        return 'WhatsApp\'ta paylaş';
    }
  }

  static IconData _iconFor(_Brand b) {
    switch (b) {
      case _Brand.instagram:
        return Symbols.instagram_fill;
      case _Brand.facebook:
        return Symbols.facebook_fill;
      case _Brand.x:
        return Symbols.twitter_x_fill;
      case _Brand.whatsapp:
        return Symbols.whatsapp_fill;
    }
  }

  static Color _colorFor(_Brand b) {
    switch (b) {
      case _Brand.instagram:
        return const Color(0xFFE1306C);
      case _Brand.facebook:
        return const Color(0xFF1877F2);
      case _Brand.x:
        return const Color(0xFF0F1419);
      case _Brand.whatsapp:
        return const Color(0xFF25D366);
    }
  }
}

class _PateezDot extends StatefulWidget {
  const _PateezDot({
    required this.glyph,
    required this.accent,
    required this.semantics,
    required this.baseCount,
    required this.onTap,
  });

  final PateezSocialGlyph glyph;
  final Color accent;
  final String semantics;
  final int baseCount;
  final VoidCallback onTap;

  @override
  State<_PateezDot> createState() => _PateezDotState();
}

class _PateezDotState extends State<_PateezDot> {
  bool _active = false;
  bool _pressed = false;

  static const double _size = 32;

  void _handleTap() {
    HapticFeedback.selectionClick();
    setState(() => _active = !_active);
    if (_active) widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final isActive = _active;
    final count = widget.baseCount + (isActive ? 1 : 0);

    return Semantics(
      label: widget.semantics,
      button: true,
      selected: isActive,
      child: SizedBox(
        width: _size + 14,
        height: _size + 8,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: _handleTap,
              child: AnimatedScale(
                scale: _pressed ? 0.92 : 1.0,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    color: isActive ? accent : AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF52A9FF).withValues(alpha: 0.11),
                        blurRadius: 22,
                        offset: const Offset(-2, 5),
                        spreadRadius: -3,
                      ),
                      BoxShadow(
                        color: isActive
                            ? accent.withValues(alpha: 0.38)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                        CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: SizedBox.square(
                      key: ValueKey<bool>(isActive),
                      dimension: 16,
                      child: Icon(
                        _pateezIconFor(widget.glyph, filled: isActive),
                        color: isActive ? Colors.white : accent,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                top: -3,
                right: -1,
                child: _CountBadge(count: count, color: accent),
              ),
          ],
        ),
      ),
    );
  }
}

IconData _pateezIconFor(PateezSocialGlyph glyph, {required bool filled}) {
  switch (glyph) {
    case PateezSocialGlyph.sparkUp:
      return filled ? Symbols.thumb_up_fill : Symbols.thumb_up_line;
    case PateezSocialGlyph.sparkDown:
      return filled ? Symbols.thumb_down_fill : Symbols.thumb_down_line;
    case PateezSocialGlyph.conversation:
      return filled ? Symbols.chat_3_fill : Symbols.chat_3_line;
    case PateezSocialGlyph.orbitShare:
      return filled ? Symbols.share_2_fill : Symbols.share_2_line;
    case PateezSocialGlyph.forwardShare:
      return Symbols.share_forward_line;
    case PateezSocialGlyph.ribbon:
      return filled ? Symbols.bookmark_fill : Symbols.bookmark_line;
    case PateezSocialGlyph.heart:
      return filled ? Symbols.heart_3_fill : Symbols.heart_3_line;
  }
}

/// Pateez aksiyon butonlarının sağ üst köşesinde duran küçük sayım rozeti.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        CountFormat.compact(count),
        style: const TextStyle(
          fontFamily: 'PateezInter',
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
