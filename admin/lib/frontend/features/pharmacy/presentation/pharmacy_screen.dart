import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/data_unavailable_state.dart';
import '../../../shared/widgets/feature_app_bar.dart';
import '../data/pharmacy_repository.dart';

const Color _pharmacyRed = Color(0xFFEA4335);
const Color _routeGreen = Color(0xFF2C873A);
const Color _tabDark = Color(0xFF2C3E50);
const Color _mutedSea = Color(0xFF95A5A6);
const Color _softRed = Color(0xFFFFF1F0);

/// Niğde için nöbetçi eczane sayfası: splash'te alınan canlı listeyi gösterir;
/// yalnızca aşağı çekme hareketi force refresh çalıştırır.
class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({
    super.key,
    this.initialData = const DutyPharmacyData.empty(),
    this.repository = const PharmacyRepository(),
    this.onSearch,
  });

  final DutyPharmacyData initialData;
  final PharmacyRepository repository;
  final VoidCallback? onSearch;

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  late DutyPharmacyData _data;
  var _refreshing = false;
  var _selectedDistrict = 'MERKEZ';

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _selectedDistrict = _preferredDistrict(_districtsFor(_data));
  }

  @override
  void didUpdateWidget(covariant PharmacyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_refreshing ||
        _data.hasPharmacies ||
        !widget.initialData.hasPharmacies) {
      return;
    }
    _data = widget.initialData;
    _selectedDistrict = _preferredDistrict(_districtsFor(_data));
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final data = await widget.repository.fetch(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _data = data;
      _selectedDistrict = _preferredDistrict(_districtsFor(data));
      _refreshing = false;
    });
  }

  Future<void> _openCall(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Aksiyon başarısız olsa da sayfa akışı bozulmamalı.
    }
  }

  Future<void> _openRoute(DutyPharmacyItem pharmacy) async {
    final confirmed = await _confirmOpenMaps(pharmacy.name);
    if (!mounted || confirmed != true) return;
    final uri = _routeUriFor(pharmacy, _data.city);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Harita uygulaması bulunamazsa sayfa kullanılmaya devam eder.
      }
    }
  }

  Future<bool?> _confirmOpenMaps(String pharmacyName) {
    final title = '$pharmacyName için harita açılsın mı?';
    const message = 'Yol tarifi harita uygulamasında açılacak.';
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: const Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Aç'),
            ),
          ],
        ),
      );
    }
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aç'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final pharmacies = _data.pharmacies;
    final districts = _districtsFor(_data);
    final activeDistrict = _resolveDistrict(districts, _selectedDistrict);
    final visiblePharmacies = activeDistrict.isEmpty
        ? pharmacies
        : pharmacies
              .where((pharmacy) => pharmacy.district == activeDistrict)
              .toList();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            FeatureAppBar(title: 'Nöbetçi Eczane', onSearch: widget.onSearch),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.actionRed,
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
                    if (pharmacies.isEmpty)
                      const DataUnavailableState()
                    else ...[
                      _InfoBanner(data: _data)
                          .animate()
                          .fadeIn(duration: 340.ms, curve: Curves.easeOutCubic)
                          .slideY(
                            begin: 0.06,
                            end: 0,
                            duration: 340.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      if (districts.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        _DistrictTabs(
                          districts: districts,
                          activeDistrict: activeDistrict,
                          countFor: (district) => pharmacies
                              .where(
                                (pharmacy) => pharmacy.district == district,
                              )
                              .length,
                          onSelected: (district) =>
                              setState(() => _selectedDistrict = district),
                        ).animate().fadeIn(
                          delay: 70.ms,
                          duration: 280.ms,
                          curve: Curves.easeOutCubic,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      for (var i = 0; i < visiblePharmacies.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.md),
                        _PharmacyCard(
                              pharmacy: visiblePharmacies[i],
                              onCall: visiblePharmacies[i].callUrl.isEmpty
                                  ? null
                                  : () =>
                                        _openCall(visiblePharmacies[i].callUrl),
                              onRoute: visiblePharmacies[i].routeUrl.isEmpty
                                  ? null
                                  : () => _openRoute(visiblePharmacies[i]),
                            )
                            .animate()
                            .fadeIn(
                              delay: (80 * (i + 1)).ms,
                              duration: 320.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .slideY(
                              begin: 0.08,
                              end: 0,
                              delay: (80 * (i + 1)).ms,
                              duration: 320.ms,
                              curve: Curves.easeOutCubic,
                            ),
                      ],
                    ],
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

List<String> _districtsFor(DutyPharmacyData data) {
  final districts = data.districts.isNotEmpty
      ? data.districts
      : data.pharmacies.map((pharmacy) => pharmacy.district).toList();
  return {
    for (final district in districts)
      if (district.trim().isNotEmpty) district.trim(),
  }.toList();
}

String _preferredDistrict(List<String> districts) {
  if (districts.isEmpty) return '';
  return districts.contains('MERKEZ') ? 'MERKEZ' : districts.first;
}

String _resolveDistrict(List<String> districts, String selectedDistrict) {
  if (districts.isEmpty) return '';
  if (districts.contains(selectedDistrict)) return selectedDistrict;
  return _preferredDistrict(districts);
}

String _districtLabel(String district) {
  const knownDistricts = {
    'MERKEZ': 'Merkez',
    'ALTUNHİSAR': 'Altunhisar',
    'BOR': 'Bor',
    'ÇAMARDI': 'Çamardı',
    'ÇİFTLİK': 'Çiftlik',
    'ULUKIŞLA': 'Ulukışla',
  };
  return knownDistricts[district.toUpperCase()] ?? district;
}

/// Türkçe-duyarlı "Sadece Baş Harf" biçimi. Veri çoğunlukla BÜYÜK HARF geldiği
/// için her kelimenin ilk harfi büyük, kalanı küçük yapılır. 'İ' düzgün
/// küçültülür (birleşik nokta sorunu olmadan) ve 'i' ile başlayan kelimeler
/// 'İ' ile başlatılır.
String _titleCaseTr(String input) {
  final words = input.split(' ');
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    if (word.isEmpty) continue;
    final lower = word.replaceAll('İ', 'i').toLowerCase();
    final first = lower[0] == 'i' ? 'İ' : lower[0].toUpperCase();
    words[i] = first + lower.substring(1);
  }
  return words.join(' ');
}

Uri _routeUriFor(DutyPharmacyItem pharmacy, String city) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    return Uri.https('maps.apple.com', '/', {
      'daddr': _routeDestination(pharmacy, city),
      'dirflg': 'd',
    });
  }
  final routeUri = Uri.tryParse(pharmacy.routeUrl);
  if (routeUri != null && routeUri.hasScheme) return routeUri;
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': _routeDestination(pharmacy, city),
  });
}

String _routeDestination(DutyPharmacyItem pharmacy, String city) {
  final destination = _googleMapsDestination(pharmacy.directionUrl);
  if (destination.isNotEmpty) return destination;
  return [
    pharmacy.name,
    pharmacy.address,
    city,
  ].where((part) => part.trim().isNotEmpty).join(' ');
}

String _googleMapsDestination(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return '';
  return uri.queryParameters['destination']?.trim() ?? '';
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.data});

  final DutyPharmacyData data;

  @override
  Widget build(BuildContext context) {
    final dateLabel = data.serviceDateLabel.isEmpty
        ? 'Bugün'
        : data.serviceDateLabel;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _pharmacyRed.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: _pharmacyRed.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/nobetci_eczane.webp',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const Icon(
                Symbols.capsule_fill,
                color: _pharmacyRed,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 13),
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
                        color: _pharmacyRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Nöbetçi Eczane',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.eyebrow.copyWith(
                          color: AppColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${data.city} · $dateLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: _mutedSea,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: _softRed,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _pharmacyRed.withValues(alpha: 0.18)),
            ),
            child: Text(
              '${data.updateIntervalMinutes} dk',
              style: AppTypography.eyebrow.copyWith(
                color: _pharmacyRed,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DistrictTabs extends StatelessWidget {
  const _DistrictTabs({
    required this.districts,
    required this.activeDistrict,
    required this.countFor,
    required this.onSelected,
  });

  final List<String> districts;
  final String activeDistrict;
  final int Function(String district) countFor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 3;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final district in districts)
              _DistrictTab(
                width: itemWidth,
                district: district,
                count: countFor(district),
                selected: district == activeDistrict,
                onTap: () => onSelected(district),
              ),
          ],
        );
      },
    );
  }
}

class _DistrictTab extends StatelessWidget {
  const _DistrictTab({
    required this.width,
    required this.district,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String district;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : _mutedSea;
    return SizedBox(
      width: width,
      child: Material(
        color: selected ? _tabDark : AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 31,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: selected ? _tabDark : AppColors.line),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _tabDark.withValues(alpha: 0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _districtLabel(district),
                    style: AppTypography.eyebrow.copyWith(
                      color: fg,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      count.toString(),
                      style: AppTypography.eyebrow.copyWith(
                        color: selected ? Colors.white70 : _mutedSea,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PharmacyCard extends StatelessWidget {
  const _PharmacyCard({
    required this.pharmacy,
    required this.onCall,
    required this.onRoute,
  });

  final DutyPharmacyItem pharmacy;
  final VoidCallback? onCall;
  final VoidCallback? onRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleCaseTr(pharmacy.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleM.copyWith(
                        color: AppColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: _pharmacyRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _districtLabel(pharmacy.district),
                          style: AppTypography.eyebrow.copyWith(
                            color: _pharmacyRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _PharmacyMark(),
            ],
          ),
          if (pharmacy.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            _NotePill(text: _titleCaseTr(pharmacy.note)),
          ],
          const SizedBox(height: 12),
          Text(
            pharmacy.address.isEmpty
                ? 'Adres bilgisi bekleniyor'
                : _titleCaseTr(pharmacy.address),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: _mutedSea,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Symbols.phone_fill,
                  label: 'Ara',
                  variant: _ActionButtonVariant.phone,
                  onTap: onCall,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _ActionButton(
                  icon: Symbols.navigation_fill,
                  label: 'Yol Tarifi',
                  variant: _ActionButtonVariant.route,
                  onTap: onRoute,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PharmacyMark extends StatelessWidget {
  const _PharmacyMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _softRed,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _pharmacyRed.withValues(alpha: 0.18)),
      ),
      child: const Icon(Symbols.capsule_fill, color: _pharmacyRed, size: 17),
    );
  }
}

class _NotePill extends StatelessWidget {
  const _NotePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: _softRed,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _pharmacyRed.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.eyebrow.copyWith(
          color: _pharmacyRed,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          height: 1.35,
        ),
      ),
    );
  }
}

enum _ActionButtonVariant { phone, route }

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.variant,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final _ActionButtonVariant variant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isRoute = variant == _ActionButtonVariant.route;
    final fg = isRoute ? Colors.white : _tabDark;
    final bg = isRoute ? _routeGreen : AppColors.surfaceSoft;
    final border = isRoute ? _routeGreen : AppColors.line;
    return Opacity(
      opacity: onTap == null ? 0.48 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 37,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: border),
              boxShadow: isRoute
                  ? [
                      BoxShadow(
                        color: _routeGreen.withValues(alpha: 0.24),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleS.copyWith(
                      color: fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
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
