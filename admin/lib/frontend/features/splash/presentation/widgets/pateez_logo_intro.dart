import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Markanın resmi açılış logosu animasyonu — splash, onboarding, boş durum gibi
/// her yerde kullanılabilen, kendi içinde çalışan tek parça widget.
///
/// Koreografi (2026 tarzı, sade ama zengin):
///   1. Arkadan yumuşak bir ışık (bloom) açılır.
///   2. Logonun ardından markanın "sinyal/yayın" motifine selam eden halkalar
///      dışa doğru yayılır.
///   3. Logo bulanıktan nete, hafifçe yaylanarak (spring) belirir.
///   4. Üzerinden bir ışık parıltısı (sheen) soldan sağa süzülür.
///   5. Sonrasında halkalar yavaşça nabız atmaya, logo belli belirsiz nefes
///      almaya devam eder — yükleme sürdüğü sürece logo "canlı" durur.
class PateezLogoIntro extends StatefulWidget {
  const PateezLogoIntro({super.key, this.width});

  /// Logonun genişliği. Verilmezse ekran genişliğinin %66'sı (200–320 arası)
  /// kullanılır.
  final double? width;

  @override
  State<PateezLogoIntro> createState() => _PateezLogoIntroState();
}

class _PateezLogoIntroState extends State<PateezLogoIntro>
    with TickerProviderStateMixin {
  // Tek seferlik giriş koreografisi.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..forward();

  // Yükleme sürerken devam eden sessiz yaşam (yayın nabzı + nefes).
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  late final Animation<double> _bloom = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
  );
  late final Animation<double> _reveal = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.12, 0.62, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _spring = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.12, 0.80, curve: Curves.easeOutBack),
  );
  late final Animation<double> _sheen = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.55, 1.0, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final logoW = (widget.width ?? (screenW * 0.66).clamp(200.0, 320.0))
        .toDouble();
    final logoH = logoW * 360 / 1200; // logo en/boy oranı ≈ 1200x360
    // Bloom + halkaların radyal olarak yayıldığı kare alan.
    final field = math.min(screenW * 0.92, logoW * 1.5);

    return SizedBox.square(
      dimension: field,
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _loop]),
        builder: (context, _) {
          final loopT = _loop.value;
          final breathe = 1 + 0.014 * math.sin(loopT * 2 * math.pi);
          final springScale = 0.86 + 0.14 * _spring.value;
          final blur = (1 - _reveal.value) * 7;
          final opacity = _reveal.value.clamp(0.0, 1.0);
          final sheenT = _sheen.value;
          final showSheen = sheenT > 0.0 && sheenT < 1.0;

          Widget logo = Image.asset(
            'assets/images/pateez_logo.png',
            width: logoW,
            height: logoH,
            filterQuality: FilterQuality.high,
          );
          if (showSheen) {
            logo = ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (rect) => _sheenShader(rect, sheenT),
              child: logo,
            );
          }
          if (blur > 0.05) {
            logo = ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blur,
                sigmaY: blur,
                tileMode: TileMode.decal,
              ),
              child: logo,
            );
          }

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1) Arka ışık (bloom)
              Opacity(
                opacity: 0.55 * _bloom.value,
                child: Transform.scale(
                  scale: 0.6 + 0.55 * _bloom.value,
                  child: Container(
                    width: field,
                    height: field,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.deepOcean.withValues(alpha: 0.10),
                          AppColors.deepOcean.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2) Yayın halkaları (sürekli nabız)
              CustomPaint(
                size: Size.square(field),
                painter: _BroadcastRingsPainter(
                  progress: loopT,
                  color: AppColors.deepOcean,
                ),
              ),

              // 3) Logo: spring + bulanıktan net + fade + nefes; üstünde sheen
              Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: springScale * breathe,
                  child: logo,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Logo üzerinden soldan sağa süzülen beyaz ışık bandı (premium parıltı).
  Shader _sheenShader(Rect rect, double t) {
    final dx = (-0.2 + 1.4 * t) * rect.width;
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.white.withValues(alpha: 0.0),
        Colors.white.withValues(alpha: 0.5),
        Colors.white.withValues(alpha: 0.0),
      ],
      stops: const [0.32, 0.5, 0.68],
      transform: _SweepTransform(dx),
    ).createShader(rect);
  }
}

/// Lineer gradyanı yatayda kaydırarak ışık bandını süzdüren dönüşüm.
class _SweepTransform extends GradientTransform {
  const _SweepTransform(this.dx);

  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// Merkezden dışa yayılan, soluklaşan eşmerkezli "yayın" halkaları.
class _BroadcastRingsPainter extends CustomPainter {
  _BroadcastRingsPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final minR = size.height * 0.16;
    final maxR = size.width * 0.5;
    for (var i = 0; i < 3; i++) {
      final p = (progress + i / 3) % 1.0;
      final r = minR + (maxR - minR) * p;
      final alpha = (1 - p) * 0.16;
      if (alpha <= 0.001) continue;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_BroadcastRingsPainter old) =>
      old.progress != progress || old.color != color;
}
