import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/feature_app_bar.dart';
import '../data/markets_mock.dart';

const Color _up = Color(0xFF22A565);
const Color _down = AppColors.actionRed;

/// Döviz & Altın sayfası — sade, ferah, Apple Stocks disiplininde: segment
/// (Döviz / Altın), her satırda kod + ad, küçük trend grafiği (sparkline) ve
/// yön renkli değişim rozeti. Veriler örnektir.
class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final rates = _segment == 0 ? MarketsMock.currencies : MarketsMock.gold;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            const FeatureAppBar(title: 'Döviz & Altın'),
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
                  Row(
                    children: [
                      const Icon(Symbols.refresh_line, size: 14, color: AppColors.support),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          MarketsMock.updatedLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.meta.copyWith(color: AppColors.support),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Segmented(
                    value: _segment,
                    onChanged: (v) => setState(() => _segment = v),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RatesCard(
                    key: ValueKey<int>(_segment),
                    rates: rates,
                  ).animate().fadeIn(duration: 280.ms, curve: Curves.easeOutCubic),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceInk,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          _Seg(label: 'Döviz', active: value == 0, onTap: () => onChanged(0)),
          _Seg(label: 'Altın', active: value == 1, onTap: () => onChanged(1)),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.deepOcean.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.titleS.copyWith(
              color: active ? AppColors.inkStrong : AppColors.inkSoft,
              fontSize: 13.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RatesCard extends StatelessWidget {
  const _RatesCard({super.key, required this.rates});
  final List<MarketRate> rates;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          for (var i = 0; i < rates.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.softLine),
            _RateRow(rate: rates[i]),
          ],
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.rate});
  final MarketRate rate;

  @override
  Widget build(BuildContext context) {
    final color = rate.up ? _up : _down;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rate.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleS.copyWith(
                    color: AppColors.inkStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rate.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(color: AppColors.support),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 54,
            height: 28,
            child: CustomPaint(painter: _SparkPainter(rate.spark, color)),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rate.price,
                style: AppTypography.titleS.copyWith(
                  color: AppColors.inkStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              _ChangePill(text: rate.changePct, up: rate.up),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChangePill extends StatelessWidget {
  const _ChangePill({required this.text, required this.up});
  final String text;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final color = up ? _up : _down;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Symbols.arrow_up_s_fill : Symbols.arrow_down_s_fill,
            size: 13,
            color: color,
          ),
          Text(
            text,
            style: AppTypography.meta.copyWith(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.points, this.color);
  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minV = points.reduce((a, b) => a < b ? a : b);
    final maxV = points.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final dx = size.width / (points.length - 1);
    const pad = 3.0;
    final h = size.height - pad * 2;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = dx * i;
      final y = pad + h - ((points[i] - minV) / span) * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.points != points || old.color != color;
}
