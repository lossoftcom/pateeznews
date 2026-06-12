import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/data_unavailable_state.dart';
import '../../../shared/widgets/feature_app_bar.dart';
import '../data/markets_repository.dart';

/// Sayfanın sakin "finans" vurgusu (hero ikon + segment), trendden bağımsızdır.
const Color _accent = AppColors.deepOcean;

/// Trend renkleri.
const Color _up = Color(0xFF22A565);

/// Döviz & Altın — canlı piyasa. Veri/iş mantığı [MarketsRepository]
/// içinde kalır; bu ekran yalnızca sunumdur.
class MarketsScreen extends StatefulWidget {
  const MarketsScreen({
    super.key,
    this.initialData = const MarketsData.empty(),
    this.repository = const MarketsRepository(),
    this.onSearch,
  });

  final MarketsData initialData;
  final MarketsRepository repository;
  final VoidCallback? onSearch;

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  int _segment = 0;
  late MarketsData _data;
  var _refreshing = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
  }

  @override
  void didUpdateWidget(covariant MarketsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_data.hasMarkets || !widget.initialData.hasMarkets) return;
    _data = widget.initialData;
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final data = await widget.repository.fetch(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _data = data;
      _refreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final rates = _segment == 0 ? _data.currencies : _data.gold;
    final updatedLabel = '${_data.updateIntervalSeconds} sn güncelleme';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            FeatureAppBar(title: 'Döviz & Altın', onSearch: widget.onSearch),
            Expanded(
              child: RefreshIndicator(
                color: _accent,
                backgroundColor: AppColors.surface,
                displacement: 32,
                onRefresh: _refresh,
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
                    if (!_data.hasMarkets)
                      const DataUnavailableState()
                    else
                      Column(
                        children: [
                          _MarketHero(updatedLabel: updatedLabel, live: true),
                          const SizedBox(height: AppSpacing.lg),
                          _Segmented(
                            value: _segment,
                            onChanged: (v) => setState(() => _segment = v),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          KeyedSubtree(
                            key: ValueKey<int>(_segment),
                            child: Column(
                              children: [
                                if (rates.isEmpty)
                                  const DataUnavailableState(minHeight: 220)
                                else ...[
                                  const _RateHeader(),
                                  const SizedBox(height: 7),
                                  for (var i = 0; i < rates.length; i++) ...[
                                    if (i > 0)
                                      const SizedBox(height: AppSpacing.sm + 2),
                                    _RateCard(rate: rates[i]),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero bilgi kartı
// ---------------------------------------------------------------------------

class _MarketHero extends StatelessWidget {
  const _MarketHero({required this.updatedLabel, required this.live});

  final String updatedLabel;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: const Icon(Symbols.coins_fill, size: 23, color: _accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: live ? _up : AppColors.support,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        updatedLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.meta.copyWith(
                          color: AppColors.support,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Canlı Piyasa',
                  style: AppTypography.titleL.copyWith(
                    color: AppColors.inkStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Anlık döviz kuru ve altın fiyatları',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.inkSoft,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (live) ...[
            const SizedBox(width: AppSpacing.sm),
            const _LiveBadge(),
          ],
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _up.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: _up, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            'Canlı',
            style: AppTypography.eyebrow.copyWith(
              color: _up,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Döviz / Altın segmenti
// ---------------------------------------------------------------------------

class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceInk,
        borderRadius: BorderRadius.circular(10),
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
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
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

// ---------------------------------------------------------------------------
// Tek kur/altın kartı + alış/satış sütunları
// ---------------------------------------------------------------------------

class _RateCard extends StatelessWidget {
  const _RateCard({required this.rate});

  final MarketRate rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rate.code,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: AppTypography.titleM.copyWith(
                    color: AppColors.inkStrong,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rate.name,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.support,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.12,
                  ),
                ),
                if (rate.code.toUpperCase() == 'BTC' &&
                    rate.hasSecondaryAsk) ...[
                  const SizedBox(height: 4),
                  Text(
                    'USD ${rate.secondaryAskLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.meta.copyWith(
                      color: _accent,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 7, child: _BidAskColumns(rate: rate)),
        ],
      ),
    );
  }
}

class _RateHeader extends StatelessWidget {
  const _RateHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Expanded(flex: 4, child: SizedBox.shrink()),
          const SizedBox(width: 12),
          Expanded(
            flex: 7,
            child: Row(
              children: [
                Expanded(child: _RateHeaderLabel('Alış')),
                const SizedBox(width: 10),
                Expanded(child: _RateHeaderLabel('Satış')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RateHeaderLabel extends StatelessWidget {
  const _RateHeaderLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.right,
      style: AppTypography.meta.copyWith(
        color: AppColors.support,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _BidAskColumns extends StatelessWidget {
  const _BidAskColumns({required this.rate});

  final MarketRate rate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PriceColumn(rate: rate, value: rate.bidLabel),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PriceColumn(rate: rate, value: rate.askLabel),
        ),
      ],
    );
  }
}

class _PriceColumn extends StatelessWidget {
  const _PriceColumn({required this.rate, required this.value});

  final MarketRate rate;
  final String value;

  @override
  Widget build(BuildContext context) {
    final changeColor = rate.up ? _up : AppColors.actionRed;
    final hasChange = rate.changePercent != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: AppTypography.titleS.copyWith(
            color: AppColors.inkStrong,
            fontSize: 12.6,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (hasChange) ...[
          const SizedBox(height: 3),
          Text(
            rate.changePct,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppTypography.meta.copyWith(
              color: changeColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}
