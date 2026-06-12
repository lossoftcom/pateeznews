import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/feature_app_bar.dart';
import '../data/etkinlik_mock.dart';
import '../data/etkinlik_repository.dart';

/// Etkinlik sayfası accent rengi (uygulama ikonuyla aynı mor).
const Color _violet = Color(0xFF6C5CE7);
const Color _tabDark = AppColors.deepOcean;
const Color _freeGreen = Color(0xFF1FA971);

/// Şehir etkinlikleri: festival, konser, tiyatro, spor, sergi... Duyurular ile
/// aynı tasarım dilinde (hero kart → renkli filtre çipleri → yatay gün şeridi →
/// sol renk şeritli kartlar). Az okuyan kullanıcı için her etkinlik; büyük tarih
/// kutusu, kategori ikonu/rengi ve sade "BUGÜN / YARIN / N GÜN SONRA" rozetiyle
/// bakar bakmaz anlaşılır.
class EtkinlikScreen extends StatefulWidget {
  const EtkinlikScreen({
    super.key,
    this.events,
    this.repository = const EtkinlikRepository(),
    this.onSearch,
  });

  final List<EtkinlikEvent>? events;
  final EtkinlikRepository repository;
  final VoidCallback? onSearch;

  @override
  State<EtkinlikScreen> createState() => _EtkinlikScreenState();
}

class _EtkinlikScreenState extends State<EtkinlikScreen> {
  EtkinlikCategory? _category; // null = Tümü
  DateTime? _selectedDay; // null = tüm günler
  List<EtkinlikEvent> _events = const [];
  var _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.events == null) {
      _loadEvents();
    } else {
      _events = widget.events!;
    }
  }

  @override
  void didUpdateWidget(covariant EtkinlikScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.events != oldWidget.events && widget.events != null) {
      _events = widget.events!;
      return;
    }
    if (widget.repository != oldWidget.repository && widget.events == null) {
      _loadEvents();
    }
  }

  Future<void> _loadEvents() async {
    if (_loading) return;
    setState(() => _loading = true);
    final events = await widget.repository.fetch();
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final source = widget.events ?? _events;

    final upcoming =
        source
            .where(
              (e) => !DateTime(
                e.date.year,
                e.date.month,
                e.date.day,
              ).isBefore(_dateBase),
            )
            .toList(growable: false)
          ..sort((a, b) => a.date.compareTo(b.date));

    final byCategory = _category == null
        ? upcoming
        : upcoming
              .where((e) => e.category == _category)
              .toList(growable: false);

    final visible = _selectedDay == null
        ? byCategory
        : byCategory
              .where((e) => _sameDay(e.date, _selectedDay!))
              .toList(growable: false);

    final featured = visible.isNotEmpty ? visible.first : null;
    final rest = visible.length > 1
        ? visible.sublist(1)
        : const <EtkinlikEvent>[];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            FeatureAppBar(title: 'Etkinlikler', onSearch: widget.onSearch),
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
                  if (_loading && upcoming.isEmpty)
                    const _LoadingState()
                  else if (upcoming.isEmpty)
                    const _EmptyState(
                      title: 'Etkinlik',
                      message: 'Veri yüklenemedi',
                    )
                  else ...[
                    _HeroBanner(total: upcoming.length)
                        .animate()
                        .fadeIn(duration: 340.ms, curve: Curves.easeOutCubic)
                        .slideY(
                          begin: 0.05,
                          end: 0,
                          duration: 340.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    if (featured != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _FeaturedEvent(event: featured)
                          .animate()
                          .fadeIn(
                            delay: 80.ms,
                            duration: 360.ms,
                            curve: Curves.easeOutCubic,
                          )
                          .slideY(
                            begin: 0.06,
                            end: 0,
                            delay: 80.ms,
                            duration: 360.ms,
                            curve: Curves.easeOutCubic,
                          ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _CategorySelect(
                      events: upcoming,
                      selected: _category,
                      onSelect: (category) => setState(() {
                        _category = category;
                        _selectedDay = null;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DateStrip(
                      events: byCategory,
                      selected: _selectedDay,
                      onSelect: (date) => setState(
                        () => _selectedDay =
                            (_selectedDay != null &&
                                _sameDay(_selectedDay!, date))
                            ? null
                            : date,
                      ),
                      onClear: () => setState(() => _selectedDay = null),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (visible.isEmpty)
                      const _EmptyState(
                        title: 'Bu seçimde etkinlik yok',
                        message:
                            'Seçtiğin gün veya türde etkinlik bulunamadı. '
                            'Filtreyi değiştirip tekrar dene.',
                      )
                    else if (rest.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'Diğer Etkinlikler',
                        count: rest.length,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (var i = 0; i < rest.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.md),
                        _EventCard(event: rest[i])
                            .animate()
                            .fadeIn(
                              delay: (60 * (i + 1)).ms,
                              duration: 300.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .slideY(
                              begin: 0.06,
                              end: 0,
                              delay: (60 * (i + 1)).ms,
                              duration: 300.ms,
                              curve: Curves.easeOutCubic,
                            ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 280,
      child: Center(
        child: CircularProgressIndicator(color: AppColors.actionRed),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero bilgi kartı
// ---------------------------------------------------------------------------

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.total});

  final int total;

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
            color: _violet.withValues(alpha: 0.10),
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
              color: _violet.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Symbols.calendar_event_line,
              size: 23,
              color: _violet,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: _violet,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Niğde · ${_fullDateLabel(_dateBase)}',
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
                  'Etkinlik Takvimi',
                  style: AppTypography.titleL.copyWith(
                    color: AppColors.inkStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Konser · festival · tiyatro · spor',
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
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: _violet.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _violet.withValues(alpha: 0.20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$total',
                  style: AppTypography.titleM.copyWith(
                    color: _violet,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'etkinlik',
                  style: AppTypography.eyebrow.copyWith(
                    color: _violet,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Öne çıkan (en yakın) etkinlik — büyük afiş kart
// ---------------------------------------------------------------------------

class _FeaturedEvent extends StatelessWidget {
  const _FeaturedEvent({required this.event});

  final EtkinlikEvent event;

  @override
  Widget build(BuildContext context) {
    final color = event.color;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, 0.16)!,
              color,
              Color.lerp(color, Colors.black, 0.34)!,
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -38,
              top: -44,
              child: _SoftCircle(size: 150, opacity: 0.10),
            ),
            Positioned(
              left: -30,
              bottom: -50,
              child: _SoftCircle(size: 120, opacity: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _PosterBadge(
                        icon: event.icon,
                        label: event.category.longLabel,
                      ),
                      const Spacer(),
                      _CountdownChipLight(date: event.date),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Symbols.sparkling_fill,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'EN YAKIN ETKİNLİK',
                        style: AppTypography.eyebrow.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleL.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  if (event.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      event.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _PosterInfoLine(
                    icon: Symbols.map_pin_line,
                    text: event.venue,
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _PosterInfoLine(
                          icon: Symbols.time_fill,
                          text:
                              '${event.weekday}, ${event.day} ${_trMonthFull[event.date.month - 1]} · ${event.time}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      _PosterPricePill(event: event),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _FeaturedButton(
                          icon: Symbols.navigation_fill,
                          label: 'Yol Tarifi',
                          filled: true,
                          accent: color,
                          // Aksiyon (harita) ileride bağlanacak.
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _FeaturedButton(
                          icon: Symbols.calendar_event_line,
                          label: 'Hatırlat',
                          filled: false,
                          accent: color,
                          // Aksiyon (takvim/hatırlatma) ileride bağlanacak.
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterBadge extends StatelessWidget {
  const _PosterBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.eyebrow.copyWith(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownChipLight extends StatelessWidget {
  const _CountdownChipLight({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final color = _countdownColor(date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            _countdownLabel(date),
            style: AppTypography.eyebrow.copyWith(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterInfoLine extends StatelessWidget {
  const _PosterInfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PosterPricePill extends StatelessWidget {
  const _PosterPricePill({required this.event});

  final EtkinlikEvent event;

  @override
  Widget build(BuildContext context) {
    if (event.free) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.check, size: 13, color: _freeGreen),
            const SizedBox(width: 5),
            Text(
              'Ücretsiz',
              style: AppTypography.eyebrow.copyWith(
                color: _freeGreen,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.coins_fill,
            size: 13,
            color: Colors.white.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 5),
          Text(
            event.priceText,
            style: AppTypography.eyebrow.copyWith(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedButton extends StatelessWidget {
  const _FeaturedButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? accent : Colors.white;
    return Material(
      color: filled ? Colors.white : Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.55)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: AppTypography.titleS.copyWith(
                    color: fg,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
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

// ---------------------------------------------------------------------------
// Kategori seçici — şık modern dropdown; dokununca alt sayfada (bottom sheet) tür seçilir
// ---------------------------------------------------------------------------

/// Tek satırlık şık seçici düğme: seçili türü (ikon + ad + sayı) gösterir,
/// dokununca altta yumuşak köşeli bir sayfa açılıp tüm türler listelenir.
class _CategorySelect extends StatelessWidget {
  const _CategorySelect({
    required this.events,
    required this.selected,
    required this.onSelect,
  });

  final List<EtkinlikEvent> events;
  final EtkinlikCategory? selected;
  final ValueChanged<EtkinlikCategory?> onSelect;

  int _count(EtkinlikCategory category) =>
      events.where((e) => e.category == category).length;

  Future<void> _openPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      builder: (sheetContext) => _CategoryPickerSheet(
        events: events,
        selected: selected,
        onPick: (category) {
          Navigator.of(sheetContext).pop();
          onSelect(category);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAll = selected == null;
    final color = isAll ? _tabDark : selected!.color;
    final icon = isAll ? Symbols.apps_fill : selected!.icon;
    final label = isAll ? 'Tüm Etkinlikler' : selected!.longLabel;
    final count = isAll ? events.length : _count(selected!);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openPicker(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 14,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ETKİNLİK TÜRÜ',
                      style: AppTypography.eyebrow.copyWith(
                        color: AppColors.support,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleM.copyWith(
                        color: AppColors.inkStrong,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.eyebrow.copyWith(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Symbols.keyboard_arrow_down,
                  size: 20,
                  color: AppColors.iconStrong,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tür seçimi için açılan alt sayfa (modern bottom sheet).
class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.events,
    required this.selected,
    required this.onPick,
  });

  final List<EtkinlikEvent> events;
  final EtkinlikCategory? selected;
  final ValueChanged<EtkinlikCategory?> onPick;

  int _count(EtkinlikCategory category) =>
      events.where((e) => e.category == category).length;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    final categories = EtkinlikCategory.values
        .where((c) => _count(c) > 0)
        .toList(growable: false);
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: _violet,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Etkinlik Türü Seç',
                  style: AppTypography.titleL.copyWith(
                    color: AppColors.inkStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
              shrinkWrap: true,
              children: [
                _CategoryOption(
                  icon: Symbols.apps_fill,
                  label: 'Tüm Etkinlikler',
                  count: events.length,
                  color: _tabDark,
                  selected: selected == null,
                  onTap: () => onPick(null),
                ),
                for (final category in categories) ...[
                  const SizedBox(height: 8),
                  _CategoryOption(
                    icon: category.icon,
                    label: category.longLabel,
                    count: _count(category),
                    color: category.color,
                    selected: selected == category,
                    onTap: () => onPick(category),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Alt sayfadaki tek tür satırı: renkli ikon + ad + sayı; seçili olan tikli.
class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.07) : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.40) : AppColors.line,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleM.copyWith(
                    color: AppColors.inkStrong,
                    fontSize: 15.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: AppTypography.eyebrow.copyWith(
                  color: AppColors.support,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              if (selected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Symbols.check,
                    size: 14,
                    color: Colors.white,
                  ),
                )
              else
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line, width: 1.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarih şeridi — yatay gün seçici (etkinlik olan günlerde nokta)
// ---------------------------------------------------------------------------

class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.events,
    required this.selected,
    required this.onSelect,
    required this.onClear,
  });

  final List<EtkinlikEvent> events;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onClear;

  bool _hasEvents(DateTime day) => events.any((e) => _sameDay(e.date, day));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Symbols.calendar_event_line, size: 15, color: _violet),
            const SizedBox(width: 7),
            Text(
              'Gün Seç',
              style: AppTypography.eyebrow.copyWith(
                color: AppColors.inkStrong,
                fontSize: 12.5,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (selected != null)
              GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _violet.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.close, size: 12, color: _violet),
                      const SizedBox(width: 4),
                      Text(
                        'Tüm günler',
                        style: AppTypography.eyebrow.copyWith(
                          color: _violet,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                'İleri 14 gün',
                style: AppTypography.meta.copyWith(
                  color: AppColors.support,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 66,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _dateRange.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final date = _dateRange[i];
              return _DayCard(
                date: date,
                selected: selected != null && _sameDay(date, selected!),
                isToday: _sameDay(date, _dateBase),
                hasEvents: _hasEvents(date),
                onTap: () => onSelect(date),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.hasEvents,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final bool hasEvents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    final Color dotColor;
    if (selected) {
      dotColor = (hasEvents || isToday) ? Colors.white : Colors.transparent;
    } else if (isToday) {
      dotColor = AppColors.actionRed;
    } else if (hasEvents) {
      dotColor = _violet;
    } else {
      dotColor = Colors.transparent;
    }

    return Material(
      color: selected ? _tabDark : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? _tabDark : AppColors.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _weekdayShort(date),
                style: AppTypography.eyebrow.copyWith(
                  color: selected ? Colors.white70 : AppColors.support,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${date.day}',
                style: AppTypography.titleM.copyWith(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bölüm başlığı
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: _violet,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          title,
          style: AppTypography.titleL.copyWith(
            color: AppColors.inkStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceInk,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$count',
            style: AppTypography.eyebrow.copyWith(
              color: AppColors.inkSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Etkinlik kartı
// ---------------------------------------------------------------------------

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final EtkinlikEvent event;

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
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          // Detay/harita ileride bağlanacak.
          onTap: () {},
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: event.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _EventBody(event: event)),
                        const SizedBox(width: AppSpacing.md),
                        _EventThumb(event: event),
                      ],
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

/// Kartın sağındaki kare görsel. Görsel varsa gerçek (disk-cache'li) foto,
/// yoksa kategori renginde markalı ikon poster — Duyurular kartıyla aynı dil.
class _EventThumb extends StatelessWidget {
  const _EventThumb({required this.event});

  final EtkinlikEvent event;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: event.hasImage
              ? CachedImage(
                  url: event.imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 220,
                  errorWidget: _EventPoster(event: event),
                )
              : _EventPoster(event: event),
        ),
      ),
    );
  }
}

class _EventPoster extends StatelessWidget {
  const _EventPoster({required this.event});

  final EtkinlikEvent event;

  @override
  Widget build(BuildContext context) {
    final color = event.color;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, Colors.white, 0.16)!,
                color,
                Color.lerp(color, Colors.black, 0.30)!,
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: -w * 0.20,
                top: -w * 0.20,
                child: _SoftCircle(size: w * 0.62, opacity: 0.12),
              ),
              Positioned(
                left: -w * 0.18,
                bottom: -w * 0.24,
                child: _SoftCircle(size: w * 0.5, opacity: 0.08),
              ),
              Center(
                child: Icon(
                  event.icon,
                  size: w * 0.42,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EventBody extends StatelessWidget {
  const _EventBody({required this.event});

  final EtkinlikEvent event;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(child: _CategoryBadge(event: event)),
            const SizedBox(width: AppSpacing.sm),
            _CountdownPill(date: event.date),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          event.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleM.copyWith(
            color: AppColors.inkStrong,
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        _MetaLine(icon: Symbols.map_pin_line, text: event.venue),
        const SizedBox(height: 5),
        _MetaLine(
          icon: Symbols.calendar_event_line,
          text:
              '${event.day} ${_trMonthFull[event.date.month - 1]} ${event.weekdayShort} · ${event.time}',
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: _PricePill(event: event),
        ),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.event});

  final EtkinlikEvent event;

  @override
  Widget build(BuildContext context) {
    final color = event.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(event.icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              event.category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.eyebrow.copyWith(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownPill extends StatelessWidget {
  const _CountdownPill({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final color = _countdownColor(date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            _countdownLabel(date),
            style: AppTypography.eyebrow.copyWith(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.event});

  final EtkinlikEvent event;

  @override
  Widget build(BuildContext context) {
    final isFree = event.free;
    final color = isFree ? _freeGreen : AppColors.warmHorizon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFree ? Symbols.check : Symbols.coins_fill,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            event.priceText,
            style: AppTypography.eyebrow.copyWith(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1.5),
          child: Icon(icon, size: 13, color: AppColors.support),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              color: AppColors.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Boş durum
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: 40,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _violet.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Symbols.calendar_event_line,
              size: 30,
              color: _violet,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleM.copyWith(
              color: AppColors.inkStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarih yardımcıları
// ---------------------------------------------------------------------------

const _trWeekdayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _trMonthFull = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

final _nowDate = DateTime.now();
final _dateBase = DateTime(_nowDate.year, _nowDate.month, _nowDate.day);
final _dateRange = List<DateTime>.generate(
  14,
  (i) => _dateBase.add(Duration(days: i)),
);

String _weekdayShort(DateTime date) => _trWeekdayShort[date.weekday - 1];
String _fullDateLabel(DateTime date) =>
    '${date.day} ${_trMonthFull[date.month - 1]} ${date.year}';
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int _dayDiff(DateTime date) =>
    DateTime(date.year, date.month, date.day).difference(_dateBase).inDays;

String _countdownLabel(DateTime date) {
  final diff = _dayDiff(date);
  if (diff <= 0) return 'BUGÜN';
  if (diff == 1) return 'YARIN';
  return '$diff GÜN SONRA';
}

Color _countdownColor(DateTime date) {
  final diff = _dayDiff(date);
  if (diff <= 0) return AppColors.actionRed;
  if (diff == 1) return AppColors.warmHorizon;
  return AppColors.deepOcean;
}
