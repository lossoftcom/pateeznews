import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
///     Facebook, X, WhatsApp), heart + ribbon aksiyon butonları, en altta
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
    required this.onSave,
    this.shareCount = 0,
    this.likeCount = 0,
    this.saveCount = 0,
  });

  final VoidCallback onInstagram;
  final VoidCallback onFacebook;
  final VoidCallback onX;
  final VoidCallback onWhatsApp;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final int shareCount;
  final int likeCount;
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
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topRight,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.16, 0),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          );
        },
        child: _isOpen
            ? _OpenDockContent(
                key: const ValueKey('dock-open'),
                shareCount: widget.shareCount,
                likeCount: widget.likeCount,
                saveCount: widget.saveCount,
                onInstagram: widget.onInstagram,
                onFacebook: widget.onFacebook,
                onX: widget.onX,
                onWhatsApp: widget.onWhatsApp,
                onLike: widget.onLike,
                onSave: widget.onSave,
                onClose: _toggle,
              )
            : _ClosedShareTrigger(
                key: const ValueKey('dock-closed'),
                onTap: _toggle,
              ),
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
    required this.saveCount,
    required this.onInstagram,
    required this.onFacebook,
    required this.onX,
    required this.onWhatsApp,
    required this.onLike,
    required this.onSave,
    required this.onClose,
  });

  final int shareCount;
  final int likeCount;
  final int saveCount;
  final VoidCallback onInstagram;
  final VoidCallback onFacebook;
  final VoidCallback onX;
  final VoidCallback onWhatsApp;
  final VoidCallback onLike;
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
          glyph: PateezSocialGlyph.heart,
          accent: AppColors.actionRed,
          semantics: 'Beğen',
          baseCount: likeCount,
          onTap: onLike,
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
                        SizedBox.square(
                          dimension: 13,
                          child: CustomPaint(
                            painter: _ShareIconPainter(color: Colors.white),
                          ),
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
                  Icons.close_rounded,
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

/// "PAYLAŞ" tetikleyici butonundaki paylaşım ikonu.
/// Kutudan diyagonal çıkan ok silüeti — modern "share to external" stili.
/// Kutunun sağ-üst köşesinde boşluk, oradan diyagonal yukarı-sağ uzanan ok.
class _ShareIconPainter extends CustomPainter {
  const _ShareIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Kutu silüeti — sağ-üst köşede ok için boşluk bırakılır.
    // Sol-üstten başlar, saat yönünün tersinde: aşağı → sağ → yarı yukarı.
    // Üst kenar yarısı eksiktir, ok oradan çıkar.
    final box = Path()
      ..moveTo(s * 0.52, s * 0.22)
      ..lineTo(s * 0.22, s * 0.22)
      ..lineTo(s * 0.22, s * 0.78)
      ..lineTo(s * 0.78, s * 0.78)
      ..lineTo(s * 0.78, s * 0.52);
    canvas.drawPath(box, stroke);

    // Ok şaftı — kutu içinden çıkıp diyagonal yukarı-sağa uzanır.
    final shaft = Path()
      ..moveTo(s * 0.46, s * 0.54)
      ..lineTo(s * 0.86, s * 0.14);
    canvas.drawPath(shaft, stroke);

    // Ok başı — sağ-üst köşede, "L" şeklinde iki kenar.
    final head = Path()
      ..moveTo(s * 0.58, s * 0.14)
      ..lineTo(s * 0.86, s * 0.14)
      ..lineTo(s * 0.86, s * 0.42);
    canvas.drawPath(head, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
            child: SizedBox.square(
              dimension: _size * 0.54,
              child: CustomPaint(painter: _painterFor(widget.brand)),
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

  static CustomPainter _painterFor(_Brand b) {
    switch (b) {
      case _Brand.instagram:
        return _InstagramGlyph();
      case _Brand.facebook:
        return _FacebookGlyph();
      case _Brand.x:
        return _XGlyph();
      case _Brand.whatsapp:
        return _WhatsAppGlyph();
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
                      child: CustomPaint(
                        painter: PateezSocialGlyphPainter(
                          glyph: widget.glyph,
                          color: isActive ? Colors.white : accent,
                          filled: isActive,
                        ),
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

/// Heart ve ribbon butonlarının sağ üst köşesinde duran küçük sayım rozeti.
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

// ─────────────────────────────────────────────────────────────────────────
// MARKA SİMGELERİ — orjinal logolar, beyaz zeminde marka renginde.
// ─────────────────────────────────────────────────────────────────────────

/// Resmi Instagram logosu: çok renkli gradient stroke ile kamera silüeti.
class _InstagramGlyph extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFEDA77),
        Color(0xFFF58529),
        Color(0xFFDD2A7B),
        Color(0xFF8134AF),
        Color(0xFF515BD4),
      ],
      stops: [0, 0.25, 0.55, 0.8, 1],
    ).createShader(Rect.fromLTWH(0, 0, s, s));

    final stroke = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..shader = shader;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.08, s * 0.08, s * 0.84, s * 0.84),
        Radius.circular(s * 0.24),
      ),
      stroke,
    );
    canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.22, stroke);
    canvas.drawCircle(Offset(s * 0.74, s * 0.26), s * 0.06, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Resmi Facebook logosu: kıvrımlı "f" silüeti, marka mavisinde.
class _FacebookGlyph extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final fill = Paint()..color = const Color(0xFF1877F2);

    final path = Path()
      ..moveTo(s * 0.46, s * 0.96)
      ..lineTo(s * 0.46, s * 0.55)
      ..lineTo(s * 0.30, s * 0.55)
      ..lineTo(s * 0.30, s * 0.42)
      ..lineTo(s * 0.46, s * 0.42)
      ..lineTo(s * 0.46, s * 0.32)
      ..cubicTo(s * 0.46, s * 0.12, s * 0.58, s * 0.04, s * 0.78, s * 0.06)
      ..lineTo(s * 0.78, s * 0.22)
      ..cubicTo(s * 0.66, s * 0.21, s * 0.62, s * 0.24, s * 0.62, s * 0.34)
      ..lineTo(s * 0.62, s * 0.42)
      ..lineTo(s * 0.78, s * 0.42)
      ..lineTo(s * 0.76, s * 0.55)
      ..lineTo(s * 0.62, s * 0.55)
      ..lineTo(s * 0.62, s * 0.96)
      ..close();

    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Resmi X.com logosu — simple-icons 24x24 viewBox SVG path data'sı
/// birebir Flutter Path'e taşındı.
///
/// SVG kaynak:
///   M18.901 1.153h3.68l-8.04 9.19L24 22.846h-7.406l-5.8-7.584
///   -6.638 7.584H.474l8.6-9.83L0 1.154h7.594l5.243 6.932Z
///   M17.61 20.644h2.039L6.486 3.24H4.298Z
///
/// İki subpath + evenOdd fill ile X harfinin iç negatif boşluğu kesiliyor.
class _XGlyph extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final fill = Paint()..color = const Color(0xFF0F1419);

    double x(double v) => v / 24 * s;
    double y(double v) => v / 24 * s;

    final path = Path()..fillType = PathFillType.evenOdd;

    // Dış silüet — X harfinin tüm çevresi (12 köşeli polygon).
    path.moveTo(x(18.901), y(1.153));
    path.lineTo(x(22.581), y(1.153)); // h3.68
    path.lineTo(x(14.541), y(10.343)); // l-8.04 9.19
    path.lineTo(x(24), y(22.846)); // L24 22.846
    path.lineTo(x(16.594), y(22.846)); // h-7.406
    path.lineTo(x(10.794), y(15.262)); // l-5.8 -7.584
    path.lineTo(x(4.156), y(22.846)); // l-6.638 7.584
    path.lineTo(x(0.474), y(22.846)); // H.474
    path.lineTo(x(9.074), y(13.016)); // l8.6 -9.83
    path.lineTo(0, y(1.154)); // L0 1.154
    path.lineTo(x(7.594), y(1.154)); // h7.594
    path.lineTo(x(12.837), y(8.086)); // l5.243 6.932
    path.close();

    // İç ince diyagonal slot — iki çapraz çubuğun "kesişim" hissini veren
    // negatif boşluk.
    path.moveTo(x(17.61), y(20.644));
    path.lineTo(x(19.649), y(20.644)); // h2.039
    path.lineTo(x(6.486), y(3.24)); // L6.486 3.24
    path.lineTo(x(4.298), y(3.24)); // H4.298
    path.close();

    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Resmi WhatsApp logosu — simple-icons 24x24 viewBox SVG path data'sı
/// birebir Flutter Path'e taşındı.
///
/// SVG kaynak:
///   M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67
///   .15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15
///   -1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297
///   -.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298
///   -.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242
///   -.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792
///   .372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074
///   .149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36
///   .195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173
///   -1.413-.074-.124-.272-.198-.57-.347 (handset)
///   m8.413-18.297A11.815 11.815 0 0 0 12.05 0C5.495 0 .16 5.335 .157
///   11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882
///   0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893A11.821 11.821
///   0 0 0 20.465 3.488 (outer bubble silüeti)
///
/// İki subpath ayrı renklerle çizilir: yeşil balon + beyaz ahize (üstte).
class _WhatsAppGlyph extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final green = Paint()..color = const Color(0xFF25D366);
    final white = Paint()..color = Colors.white;

    double x(double v) => v / 24 * s;
    double y(double v) => v / 24 * s;
    Radius r(double v) => Radius.circular(v / 24 * s);

    // ─── Dış balon silüeti (yeşil) ───
    // Başlangıç noktası: handset bitişinden (~17.472, 14.382) "m 8.413
    // -18.297" relative move → mutlak (20.463, 3.488). Path'i ayrı çizdiğimiz
    // için doğrudan moveTo ile başlatıyoruz.
    final bubble = Path();
    bubble.moveTo(x(20.463), y(3.488));
    // A11.815 11.815 0 0 0 12.05 0
    bubble.arcToPoint(
      Offset(x(12.05), y(0)),
      radius: r(11.815),
      largeArc: false,
      clockwise: false,
    );
    // C5.495 0 .16 5.335 .157 11.892
    bubble.cubicTo(x(5.495), y(0), x(.16), y(5.335), x(.157), y(11.892));
    // c0 2.096 .547 4.142 1.588 5.945
    bubble.relativeCubicTo(0, y(2.096), x(.547), y(4.142), x(1.588), y(5.945));
    // L.057 24
    bubble.lineTo(x(.057), y(24));
    // l6.305 -1.654
    bubble.relativeLineTo(x(6.305), y(-1.654));
    // a11.882 11.882 0 0 0 5.683 1.448
    bubble.relativeArcToPoint(
      Offset(x(5.683), y(1.448)),
      radius: r(11.882),
      largeArc: false,
      clockwise: false,
    );
    // h.005
    bubble.relativeLineTo(x(.005), 0);
    // c6.554 0 11.89 -5.335 11.893 -11.893
    bubble.relativeCubicTo(
      x(6.554),
      0,
      x(11.89),
      y(-5.335),
      x(11.893),
      y(-11.893),
    );
    // A11.821 11.821 0 0 0 20.465 3.488
    bubble.arcToPoint(
      Offset(x(20.465), y(3.488)),
      radius: r(11.821),
      largeArc: false,
      clockwise: false,
    );
    bubble.close();
    canvas.drawPath(bubble, green);

    // ─── Telefon ahizesi (beyaz, balonun üstüne çizilir) ───
    // Başlangıç: (17.472, 14.382). Toplam 22 ardışık relative cubic.
    final handset = Path();
    handset.moveTo(x(17.472), y(14.382));
    handset.relativeCubicTo(
      x(-.297),
      y(-.149),
      x(-1.758),
      y(-.867),
      x(-2.03),
      y(-.967),
    );
    handset.relativeCubicTo(
      x(-.273),
      y(-.099),
      x(-.471),
      y(-.148),
      x(-.67),
      y(.15),
    );
    handset.relativeCubicTo(
      x(-.197),
      y(.297),
      x(-.767),
      y(.966),
      x(-.94),
      y(1.164),
    );
    handset.relativeCubicTo(
      x(-.173),
      y(.199),
      x(-.347),
      y(.223),
      x(-.644),
      y(.075),
    );
    handset.relativeCubicTo(
      x(-.297),
      y(-.15),
      x(-1.255),
      y(-.463),
      x(-2.39),
      y(-1.475),
    );
    handset.relativeCubicTo(
      x(-.883),
      y(-.788),
      x(-1.48),
      y(-1.761),
      x(-1.653),
      y(-2.059),
    );
    handset.relativeCubicTo(
      x(-.173),
      y(-.297),
      x(-.018),
      y(-.458),
      x(.13),
      y(-.606),
    );
    handset.relativeCubicTo(
      x(.134),
      y(-.133),
      x(.298),
      y(-.347),
      x(.446),
      y(-.52),
    );
    handset.relativeCubicTo(
      x(.149),
      y(-.174),
      x(.198),
      y(-.298),
      x(.298),
      y(-.497),
    );
    handset.relativeCubicTo(
      x(.099),
      y(-.198),
      x(.05),
      y(-.371),
      x(-.025),
      y(-.52),
    );
    handset.relativeCubicTo(
      x(-.075),
      y(-.149),
      x(-.669),
      y(-1.612),
      x(-.916),
      y(-2.207),
    );
    handset.relativeCubicTo(
      x(-.242),
      y(-.579),
      x(-.487),
      y(-.5),
      x(-.669),
      y(-.51),
    );
    handset.relativeCubicTo(
      x(-.173),
      y(-.008),
      x(-.371),
      y(-.01),
      x(-.57),
      y(-.01),
    );
    handset.relativeCubicTo(
      x(-.198),
      0,
      x(-.52),
      y(.074),
      x(-.792),
      y(.372),
    );
    handset.relativeCubicTo(
      x(-.272),
      y(.297),
      x(-1.04),
      y(1.016),
      x(-1.04),
      y(2.479),
    );
    handset.relativeCubicTo(
      0,
      y(1.462),
      x(1.065),
      y(2.875),
      x(1.213),
      y(3.074),
    );
    handset.relativeCubicTo(
      x(.149),
      y(.198),
      x(2.096),
      y(3.2),
      x(5.077),
      y(4.487),
    );
    handset.relativeCubicTo(
      x(.709),
      y(.306),
      x(1.262),
      y(.489),
      x(1.694),
      y(.625),
    );
    handset.relativeCubicTo(
      x(.712),
      y(.227),
      x(1.36),
      y(.195),
      x(1.871),
      y(.118),
    );
    handset.relativeCubicTo(
      x(.571),
      y(-.085),
      x(1.758),
      y(-.719),
      x(2.006),
      y(-1.413),
    );
    handset.relativeCubicTo(
      x(.248),
      y(-.694),
      x(.248),
      y(-1.289),
      x(.173),
      y(-1.413),
    );
    handset.relativeCubicTo(
      x(-.074),
      y(-.124),
      x(-.272),
      y(-.198),
      x(-.57),
      y(-.347),
    );
    handset.close();
    canvas.drawPath(handset, white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
