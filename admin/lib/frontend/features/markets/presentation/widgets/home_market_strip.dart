import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/markets_repository.dart';

/// Ana sayfada manşetin hemen altında duran "Piyasa" şeridi.
///
/// Tasarım hedefi: kullanıcı parmağıyla **sağa–sola** kaydırdıkça döviz ve
/// altın kalemleri akar; widget kendiliğinden hareket etmez (auto-scroll yok).
/// Her kalem markasına özgü renkli bir ikon çipi, kalın fiyatı, yön rozeti ve
/// minik bir trend grafiği (sparkline) taşır.
///
/// Canlı veri varsa [MarketsData] üzerinden beslenir; eksik kalemlerde aynı
/// kart sırasını korumak için yalnızca ilgili kalem fallback değerde kalır.
class HomeMarketStrip extends StatelessWidget {
  const HomeMarketStrip({
    super.key,
    this.marketsData = const MarketsData.empty(),
    this.onSeeAll,
  });

  final MarketsData marketsData;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final items = _MarketTile.fromMarkets(marketsData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StripHeader(onSeeAll: onSeeAll),
        SizedBox(
          height: 102,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              2,
              AppSpacing.pageHorizontal,
              2,
            ),
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, index) => _MarketCard(item: items[index]),
          ),
        ),
      ],
    );
  }
}

class _StripHeader extends StatelessWidget {
  const _StripHeader({this.onSeeAll});

  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
        AppSpacing.pageHorizontal,
        AppSpacing.md + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _LivePulse(),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Piyasa',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleM.copyWith(
                      color: AppColors.inkStrong,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      'Serbest',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleM.copyWith(
                        color: AppColors.support,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SeeAllLink(onTap: onSeeAll),
        ],
      ),
    );
  }
}

/// Canlı veri vurgusu — yumuşak yeşil bir nabız noktası.
class _LivePulse extends StatelessWidget {
  const _LivePulse();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: _up,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _up.withValues(alpha: 0.45),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _SeeAllLink extends StatelessWidget {
  const _SeeAllLink({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Döviz & Altın',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.meta.copyWith(
                  color: AppColors.support,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Symbols.arrow_forward_rounded,
                size: 13,
                color: AppColors.support,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({required this.item});

  final _MarketTile item;

  @override
  Widget build(BuildContext context) {
    final trend = item.up ? _up : _down;
    return Container(
      width: 121,
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconChip(icon: item.icon, color: item.color),
              const Spacer(),
              _ChangePill(up: item.up, label: item.changePct),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleS.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.16,
            ),
          ),
          Text(
            item.code,
            style: AppTypography.meta.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.support,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  item.price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleM.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkStrong,
                    height: 1.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 27,
                height: 15,
                child: CustomPaint(
                  painter: _SparkPainter(values: item.spark, color: trend),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Markaya özel renkli ikon çipi — yumuşak gradient zemin + renkli ikon.
class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 15, color: color),
    );
  }
}

class _ChangePill extends StatelessWidget {
  const _ChangePill({required this.up, required this.label});

  final bool up;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = up ? _up : _down;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 6, 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Symbols.arrow_up_s_fill : Symbols.arrow_down_s_fill,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 1),
          Text(
            label,
            style: AppTypography.meta.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Minik trend grafiği — dolgulu, yumuşak köşeli sparkline.
class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    const pad = 2.0;
    final h = size.height - pad * 2;

    Offset point(int i) {
      final x = size.width * (i / (values.length - 1));
      final norm = (values[i] - minV) / span;
      final y = pad + (1 - norm) * h;
      return Offset(x, y);
    }

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      final prev = point(i - 1);
      final curr = point(i);
      final midX = (prev.dx + curr.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.color != color;
}

const _up = Color(0xFF16A34A);
const _down = Color(0xFFE5484D);

/// Şeritte gösterilen tek bir piyasa kalemi (sunum modeli).
@immutable
class _MarketTile {
  const _MarketTile({
    required this.code,
    required this.name,
    required this.price,
    required this.changePct,
    required this.up,
    required this.icon,
    required this.color,
    required this.spark,
  });

  final String code;
  final String name;
  final String price;
  final String changePct;
  final bool up;
  final IconData icon;
  final Color color;
  final List<double> spark;

  static List<_MarketTile> fromMarkets(MarketsData data) {
    if (!data.hasMarkets) return sample;

    final live = <_MarketTile>[];
    _MarketTile addFromRate(_MarketTile fallback, MarketRate? rate) {
      if (rate == null) return fallback;
      return fallback.copyWith(
        price: rate.price,
        changePct: rate.changePct,
        up: rate.up,
        spark: rate.spark,
      );
    }

    live.add(addFromRate(sample[0], _findRate(data.currencies, 'USD')));
    live.add(addFromRate(sample[1], _findRate(data.currencies, 'EUR')));
    live.add(sample[2]);
    live.add(addFromRate(sample[3], _findRate(data.gold, 'GRAM')));
    live.add(addFromRate(sample[4], _findRate(data.gold, 'CEYREK')));
    live.add(addFromRate(sample[5], _findRate(data.currencies, 'BTC')));
    return live;
  }

  _MarketTile copyWith({
    String? price,
    String? changePct,
    bool? up,
    List<double>? spark,
  }) {
    return _MarketTile(
      code: code,
      name: name,
      price: price ?? this.price,
      changePct: changePct ?? this.changePct,
      up: up ?? this.up,
      icon: icon,
      color: color,
      spark: spark ?? this.spark,
    );
  }

  /// Sunum amaçlı örnek piyasa (Haziran 2026). Sıra kullanıcının istediği gibi:
  /// Dolar → Euro → Borsa → Gram Altın → Çeyrek Altın → Bitcoin.
  static const sample = <_MarketTile>[
    _MarketTile(
      code: 'USD/TRY',
      name: 'Dolar',
      price: '₺48,2040',
      changePct: '%0,12',
      up: true,
      icon: Symbols.money_dollar_circle_fill,
      color: Color(0xFF16A34A),
      spark: [3.0, 3.1, 3.05, 3.2, 3.18, 3.32, 3.4],
    ),
    _MarketTile(
      code: 'EUR/TRY',
      name: 'Euro',
      price: '₺53,4500',
      changePct: '%0,06',
      up: true,
      icon: Symbols.money_euro_circle_fill,
      color: Color(0xFF2563EB),
      spark: [4.0, 4.05, 4.02, 4.12, 4.1, 4.2, 4.26],
    ),
    _MarketTile(
      code: 'BIST 100',
      name: 'Borsa',
      price: '14.827,4',
      changePct: '%2,82',
      up: true,
      icon: Symbols.line_chart_fill,
      color: Color(0xFF7C3AED),
      spark: [5.0, 4.9, 5.1, 5.0, 5.3, 5.45, 5.7],
    ),
    _MarketTile(
      code: 'TL / gram',
      name: 'Gram Altın',
      price: '₺6.593,8',
      changePct: '%0,53',
      up: false,
      icon: Symbols.coins_fill,
      color: Color(0xFFF59E0B),
      spark: [6.4, 6.5, 6.35, 6.2, 6.28, 6.05, 5.95],
    ),
    _MarketTile(
      code: 'TL / adet',
      name: 'Çeyrek Altın',
      price: '₺10.747',
      changePct: '%0,74',
      up: false,
      icon: Symbols.medal_fill,
      color: Color(0xFFD97706),
      spark: [6.5, 6.45, 6.5, 6.2, 6.3, 6.1, 5.9],
    ),
    _MarketTile(
      code: 'BTC/USD',
      name: 'Bitcoin',
      price: r'$104.250',
      changePct: '%3,73',
      up: false,
      icon: Symbols.btc_fill,
      color: Color(0xFFF7931A),
      spark: [6.0, 6.2, 6.05, 5.7, 5.85, 5.5, 5.3],
    ),
  ];
}

MarketRate? _findRate(List<MarketRate> rates, String key) {
  final normalized = key.trim().toUpperCase();
  for (final rate in rates) {
    final id = rate.id.toUpperCase();
    final symbol = rate.symbol.toUpperCase();
    if (symbol == normalized ||
        id == normalized ||
        id.endsWith(':$normalized')) {
      return rate;
    }
  }
  return null;
}
