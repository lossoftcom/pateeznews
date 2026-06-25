import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../data/admin_module_settings_repository.dart';
import 'settings_mobile_chrome.dart';

class PharmacySettingsScreen extends StatefulWidget {
  const PharmacySettingsScreen({
    super.key,
    this.repository = const SupabaseAdminModuleSettingsRepository(),
  });

  final AdminModuleSettingsRepository repository;

  @override
  State<PharmacySettingsScreen> createState() => _PharmacySettingsScreenState();
}

class _PharmacySettingsScreenState extends State<PharmacySettingsScreen> {
  var _selectedTab = _PharmacySettingsTab.regions;
  var _serviceEnabled = true;
  var _cacheEnabled = true;
  var _nightProtectionEnabled = true;
  var _selectedPreviewRegionIndex = 0;
  var _selectedPreviewDistrict = 'Merkez';
  var _regions = List<_PharmacyRegion>.of(_defaultPharmacyRegions);
  DutyPharmacyPreviewData? _preview;
  var _loadingPreview = true;
  var _refreshingPreview = false;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreview());
  }

  _PharmacyRegion get _defaultRegion => _regions.firstWhere(
    (region) => region.isDefault,
    orElse: () => _regions.first,
  );

  Future<void> _loadPreview({bool forceRefresh = false}) async {
    setState(() {
      if (forceRefresh) {
        _refreshingPreview = true;
      } else {
        _loadingPreview = true;
      }
      _previewError = null;
    });
    try {
      final preview = await widget.repository.fetchDutyPharmacyPreview(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      final region = _regionFromPreview(preview);
      setState(() {
        _preview = preview;
        _regions = [region];
        _selectedPreviewRegionIndex = 0;
        _selectedPreviewDistrict = region.districts.first;
        _loadingPreview = false;
        _refreshingPreview = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _previewError = error.toString();
        _loadingPreview = false;
        _refreshingPreview = false;
      });
    }
  }

  Future<void> _openRegionDialog({_PharmacyRegion? region, int? index}) async {
    final result = await _showPharmacyRegionDialog(context, region: region);
    if (!mounted || result == null) return;

    setState(() {
      final normalized = result.isDefault
          ? _withoutOtherDefaults(result)
          : result;
      if (index == null) {
        _regions.add(normalized);
      } else {
        _regions[index] = normalized;
      }
      if (normalized.isDefault) {
        _applyDefault(index ?? _regions.length - 1);
      }
      _ensureDefaultRegion();
      _selectedPreviewRegionIndex = _regions.indexWhere(
        (region) => region.isDefault,
      );
      _selectedPreviewDistrict = _defaultRegion.districts.first;
    });
  }

  void _deleteRegion(int index) {
    setState(() {
      _regions.removeAt(index);
      _ensureDefaultRegion();
      if (_selectedPreviewRegionIndex >= _regions.length) {
        _selectedPreviewRegionIndex = _regions.length - 1;
      }
      _selectedPreviewDistrict = _defaultRegion.districts.first;
    });
  }

  void _setDefaultRegion(int index) {
    setState(() {
      _applyDefault(index);
      _selectedPreviewRegionIndex = index;
      _selectedPreviewDistrict = _regions[index].districts.first;
    });
  }

  void _toggleRegionActive(int index, bool value) {
    setState(() {
      _regions[index] = _regions[index].copyWith(active: value);
    });
  }

  _PharmacyRegion _withoutOtherDefaults(_PharmacyRegion region) {
    return region.copyWith(isDefault: true);
  }

  void _applyDefault(int index) {
    for (var i = 0; i < _regions.length; i++) {
      _regions[i] = _regions[i].copyWith(isDefault: i == index);
    }
  }

  void _ensureDefaultRegion() {
    if (_regions.isEmpty) {
      _regions.addAll(_defaultPharmacyRegions);
    }
    if (!_regions.any((region) => region.isDefault)) {
      _regions[0] = _regions[0].copyWith(isDefault: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: settingsPagePadding(constraints.maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PharmacyPageHeader(),
              const SizedBox(height: 22),
              _PharmacyTabs(
                selected: _selectedTab,
                onSelected: (tab) => setState(() => _selectedTab = tab),
              ),
              const SizedBox(height: 22),
              _PharmacySettingsCard(
                title: _selectedTab.title,
                icon: _selectedTab.icon,
                trailing: _selectedTab == _PharmacySettingsTab.regions
                    ? _PrimaryActionButton(
                        label: 'Bölge Ekle',
                        icon: Symbols.add,
                        onPressed: () => _openRegionDialog(),
                      )
                    : _selectedTab == _PharmacySettingsTab.preview
                    ? _PrimaryActionButton(
                        label: 'Veriyi Yenile',
                        icon: Symbols.schedule_send,
                        onPressed: () => _loadPreview(forceRefresh: true),
                      )
                    : null,
                child: switch (_selectedTab) {
                  _PharmacySettingsTab.regions => _PharmacyRegionSettings(
                    regions: _regions,
                    serviceEnabled: _serviceEnabled,
                    cacheEnabled: _cacheEnabled,
                    nightProtectionEnabled: _nightProtectionEnabled,
                    onServiceChanged: (value) =>
                        setState(() => _serviceEnabled = value),
                    onCacheChanged: (value) =>
                        setState(() => _cacheEnabled = value),
                    onNightProtectionChanged: (value) =>
                        setState(() => _nightProtectionEnabled = value),
                    onEdit: (index) => _openRegionDialog(
                      region: _regions[index],
                      index: index,
                    ),
                    onDelete: _deleteRegion,
                    onSetDefault: _setDefaultRegion,
                    onActiveChanged: _toggleRegionActive,
                  ),
                  _PharmacySettingsTab.preview => _PharmacyPreview(
                    regions: _regions,
                    preview: _preview,
                    loading: _loadingPreview,
                    refreshing: _refreshingPreview,
                    error: _previewError,
                    selectedRegionIndex: _selectedPreviewRegionIndex,
                    selectedDistrict: _selectedPreviewDistrict,
                    onRegionSelected: (index) => setState(() {
                      _selectedPreviewRegionIndex = index;
                      _selectedPreviewDistrict =
                          _regions[index].districts.first;
                    }),
                    onDistrictSelected: (district) =>
                        setState(() => _selectedPreviewDistrict = district),
                    onRefresh: () => _loadPreview(forceRefresh: true),
                  ),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<_PharmacyRegion?> _showPharmacyRegionDialog(
  BuildContext context, {
  _PharmacyRegion? region,
}) {
  return showSettingsSideDialog<_PharmacyRegion>(
    context,
    barrierLabel: 'PharmacyRegionDialog',
    builder: (mobile) => _PharmacyDialogFrame(
      mobileDrawer: mobile,
      child: _PharmacyRegionDialog(region: region),
    ),
  );
}

class _PharmacyPageHeader extends StatelessWidget {
  const _PharmacyPageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('Duty Pharmacy Settings'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.t(
            'Manage the frontend duty pharmacy card by country, city, district and neighborhood.',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _PharmacyTabs extends StatelessWidget {
  const _PharmacyTabs({required this.selected, required this.onSelected});

  final _PharmacySettingsTab selected;
  final ValueChanged<_PharmacySettingsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SettingsResponsiveTabs<_PharmacySettingsTab>(
      selected: selected,
      onSelected: onSelected,
      items: [
        for (final tab in _PharmacySettingsTab.values)
          SettingsTabItem(value: tab, label: tab.title),
      ],
    );
  }
}

class _PharmacySettingsCard extends StatelessWidget {
  const _PharmacySettingsCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Row(
              children: [
                SymbolIcon(icon, color: AppColors.actionRed, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.t(title),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 16), trailing!],
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.line.withValues(alpha: 0.9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({
    required this.title,
    required this.description,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
            ),
            child: const SymbolIcon(
              Symbols.check,
              color: AppColors.actionRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(title),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.t(description),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _CompactCheckSwitch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SourceSettings extends StatelessWidget {
  const _SourceSettings({
    required this.cacheEnabled,
    required this.nightProtectionEnabled,
    required this.onCacheChanged,
    required this.onNightProtectionChanged,
  });

  final bool cacheEnabled;
  final bool nightProtectionEnabled;
  final ValueChanged<bool> onCacheChanged;
  final ValueChanged<bool> onNightProtectionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TextInputField(
          label: 'Veri Kaynağı',
          initialValue: 'neo.org.tr/nobetci-eczaneler',
        ),
        const SizedBox(height: 14),
        const _SelectInputField(
          label: 'Cache Süresi',
          value: '60 dakika',
          options: ['5 dakika', '15 dakika', '30 dakika', '60 dakika'],
        ),
        const SizedBox(height: 14),
        _InlineToggle(
          title: 'Open cache • 60 dk',
          description:
              'Aynı şehir/ilçe sorgularını gereksiz yenilemeden korur.',
          value: cacheEnabled,
          onChanged: onCacheChanged,
        ),
        const SizedBox(height: 10),
        _InlineToggle(
          title: 'Gece 00:00 Koruması',
          description:
              'Gece yarısından sonra eski nöbet listesinin görünmesini engeller.',
          value: nightProtectionEnabled,
          onChanged: onNightProtectionChanged,
        ),
      ],
    );
  }
}

class _PharmacyRegionSettings extends StatelessWidget {
  const _PharmacyRegionSettings({
    required this.regions,
    required this.serviceEnabled,
    required this.cacheEnabled,
    required this.nightProtectionEnabled,
    required this.onServiceChanged,
    required this.onCacheChanged,
    required this.onNightProtectionChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
    required this.onActiveChanged,
  });

  final List<_PharmacyRegion> regions;
  final bool serviceEnabled;
  final bool cacheEnabled;
  final bool nightProtectionEnabled;
  final ValueChanged<bool> onServiceChanged;
  final ValueChanged<bool> onCacheChanged;
  final ValueChanged<bool> onNightProtectionChanged;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onSetDefault;
  final void Function(int index, bool value) onActiveChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusBox(
          title: 'Nöbetçi Eczane Aktif',
          description: 'Ön yüzde nöbetçi eczane kartını göster.',
          enabled: serviceEnabled,
          onChanged: onServiceChanged,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            final source = _SourceSettings(
              cacheEnabled: cacheEnabled,
              nightProtectionEnabled: nightProtectionEnabled,
              onCacheChanged: onCacheChanged,
              onNightProtectionChanged: onNightProtectionChanged,
            );
            final regionCards = _RegionCardList(
              regions: regions,
              onEdit: onEdit,
              onDelete: onDelete,
              onSetDefault: onSetDefault,
              onActiveChanged: onActiveChanged,
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [source, const SizedBox(height: 14), regionCards],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: source),
                const SizedBox(width: 14),
                Expanded(child: regionCards),
              ],
            );
          },
        ),
        const _FormDivider(),
        const _SaveRow(),
      ],
    );
  }
}

class _RegionCardList extends StatelessWidget {
  const _RegionCardList({
    required this.regions,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
    required this.onActiveChanged,
  });

  final List<_PharmacyRegion> regions;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onSetDefault;
  final void Function(int index, bool value) onActiveChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < regions.length; i++)
              SizedBox(
                width: constraints.maxWidth,
                child: _RegionCard(
                  region: regions[i],
                  onEdit: () => onEdit(i),
                  onDelete: () => onDelete(i),
                  onSetDefault: () => onSetDefault(i),
                  onActiveChanged: (value) => onActiveChanged(i, value),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({
    required this.region,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
    required this.onActiveChanged,
  });

  final _PharmacyRegion region;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${region.country} / ${region.city}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (region.isDefault)
                          const _SoftBadge(label: 'Varsayılan konum'),
                        _StatusBadge(active: region.active),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _IconActionButton(
                tooltip: 'Bölgeyi düzenle',
                icon: Symbols.edit_square,
                color: AppColors.deepOcean,
                onTap: onEdit,
              ),
              const SizedBox(width: 6),
              _IconActionButton(
                tooltip: 'Bölgeyi sil',
                icon: Symbols.delete,
                color: AppColors.actionRed,
                onTap: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _FieldLabel('İlçeler / Bölgeler'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final district in region.districts)
                _SoftBadge(label: district),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!region.isDefault)
                _OutlineActionButton(
                  label: 'Varsayılan yap',
                  onPressed: onSetDefault,
                )
              else
                const _SoftBadge(label: 'Varsayılan'),
              const Spacer(),
              Text(
                context.t(region.active ? 'Aktif' : 'Pasif'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 8),
              _CompactCheckSwitch(
                value: region.active,
                onChanged: onActiveChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PharmacyPreview extends StatelessWidget {
  const _PharmacyPreview({
    required this.regions,
    required this.preview,
    required this.loading,
    required this.refreshing,
    required this.error,
    required this.selectedRegionIndex,
    required this.selectedDistrict,
    required this.onRegionSelected,
    required this.onDistrictSelected,
    required this.onRefresh,
  });

  final List<_PharmacyRegion> regions;
  final DutyPharmacyPreviewData? preview;
  final bool loading;
  final bool refreshing;
  final String? error;
  final int selectedRegionIndex;
  final String selectedDistrict;
  final ValueChanged<int> onRegionSelected;
  final ValueChanged<String> onDistrictSelected;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final safeIndex =
        selectedRegionIndex >= 0 && selectedRegionIndex < regions.length
        ? selectedRegionIndex
        : 0;
    final region = regions[safeIndex];
    final pharmacies = [
      for (final pharmacy in preview?.pharmacies ?? const <DutyPharmacyItem>[])
        if (pharmacy.district == selectedDistrict)
          _PreviewPharmacy.fromLive(pharmacy),
    ];

    if (loading) {
      return const SizedBox(
        height: 280,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.deepOcean,
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return _PreviewErrorBox(message: error!, onRetry: onRefresh);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(
                      'settings.livePreviewTitle',
                      values: {'name': region.city},
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t(
                      'settings.pharmacyPreviewMeta',
                      values: {
                        'date': preview?.serviceDateLabel ?? '-',
                        'count': (preview?.total ?? pharmacies.length)
                            .toString(),
                        'source': preview?.cache.source ?? region.source,
                      },
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            _SoftBadge(
              label: refreshing
                  ? 'yenileniyor'
                  : preview?.cache.source ?? 'database',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < regions.length; i++)
              _DistrictButton(
                label: regions[i].city,
                selected: safeIndex == i,
                onTap: () => onRegionSelected(i),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final district in region.districts)
              _DistrictButton(
                label: district,
                selected: selectedDistrict == district,
                onTap: () => onDistrictSelected(district),
              ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final itemWidth = compact
                ? constraints.maxWidth
                : (constraints.maxWidth - 14) / 2;

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                if (pharmacies.isEmpty)
                  SizedBox(
                    width: constraints.maxWidth,
                    child: const _PreviewEmptyBox(
                      title: 'Kayıt bulunamadı',
                      description: 'Seçili ilçe için canlı eczane kaydı yok.',
                    ),
                  )
                else
                  for (final pharmacy in pharmacies)
                    SizedBox(
                      width: itemWidth,
                      child: _PreviewPharmacyCard(pharmacy: pharmacy),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PreviewPharmacyCard extends StatelessWidget {
  const _PreviewPharmacyCard({required this.pharmacy});

  final _PreviewPharmacy pharmacy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pharmacy.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SymbolIcon(
                Symbols.schedule,
                color: AppColors.actionRed,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pharmacy.district,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.warmHorizon,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          if (pharmacy.note != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.actionRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(
                  color: AppColors.actionRed.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                pharmacy.note!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.actionRed,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            pharmacy.address,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PreviewSmallButton(
                label: pharmacy.phone,
                icon: Symbols.verified,
              ),
              _PreviewSmallButton(
                label: 'Yol Tarifi',
                icon: Symbols.open_in_new,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewErrorBox extends StatelessWidget {
  const _PreviewErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          _OutlineActionButton(label: 'Tekrar dene', onPressed: onRetry),
        ],
      ),
    );
  }
}

class _PreviewEmptyBox extends StatelessWidget {
  const _PreviewEmptyBox({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Text(
            context.t(title),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(description),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PharmacyRegionDialog extends StatefulWidget {
  const _PharmacyRegionDialog({this.region});

  final _PharmacyRegion? region;

  @override
  State<_PharmacyRegionDialog> createState() => _PharmacyRegionDialogState();
}

class _PharmacyRegionDialogState extends State<_PharmacyRegionDialog> {
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  late final TextEditingController _sourceController;
  late final TextEditingController _districtController;
  late List<String> _districts;
  late bool _active;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final region = widget.region;
    _countryController = TextEditingController(
      text: region?.country ?? 'Türkiye',
    );
    _cityController = TextEditingController(text: region?.city ?? 'Niğde');
    _sourceController = TextEditingController(
      text: region?.source ?? 'Eczacı Odası / resmi kaynak',
    );
    _districtController = TextEditingController();
    _districts = List<String>.of(region?.districts ?? const ['Merkez']);
    _active = region?.active ?? true;
    _isDefault = region?.isDefault ?? false;
  }

  @override
  void dispose() {
    _countryController.dispose();
    _cityController.dispose();
    _sourceController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  void _addDistrict(String value) {
    final district = value.trim();
    if (district.isEmpty || _districts.contains(district)) return;
    setState(() => _districts.add(district));
    _districtController.clear();
  }

  void _toggleDistrict(String district) {
    setState(() {
      if (_districts.contains(district)) {
        if (_districts.length > 1) {
          _districts.remove(district);
        }
      } else {
        _districts.add(district);
      }
    });
  }

  void _selectAllKnownDistricts() {
    setState(() {
      _districts = _mergeUnique(
        _districts,
        _knownDistricts(_cityController.text),
      );
    });
  }

  void _save() {
    final country = _countryController.text.trim().isEmpty
        ? 'Türkiye'
        : _countryController.text.trim();
    final city = _cityController.text.trim().isEmpty
        ? 'Niğde'
        : _cityController.text.trim();
    final source = _sourceController.text.trim().isEmpty
        ? 'Eczacı Odası / resmi kaynak'
        : _sourceController.text.trim();

    Navigator.of(context).pop(
      _PharmacyRegion(
        country: country,
        city: city,
        source: source,
        districts: _districts.isEmpty ? const ['Merkez'] : List.of(_districts),
        isDefault: _isDefault,
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.region != null;
    final knownDistricts = _knownDistricts(_cityController.text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogHeader(title: editing ? 'Bölge Düzenle' : 'Bölge Ekle'),
          const SizedBox(height: 24),
          _ResponsiveFieldRow(
            children: [
              _TextInputField(
                controller: _countryController,
                label: 'Ülke',
                hintText: 'Türkiye, Almanya, İngiltere...',
              ),
              _TextInputField(
                controller: _cityController,
                label: 'Şehir',
                hintText: 'Niğde, İstanbul, Berlin...',
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TextInputField(
            controller: _sourceController,
            label: 'Kaynak',
            hintText: 'Eczacı odası, resmi servis veya API kaynağı',
          ),
          const SizedBox(height: 20),
          _AddableChipSection(
            title: 'İlçeler / Bölgeler',
            helper: 'İstenen ilçeleri seçin veya yeni ilçe ekleyin.',
            addController: _districtController,
            addHint: 'İlçe / bölge ekle',
            values: _districts,
            knownValues: knownDistricts,
            onAdd: _addDistrict,
            onToggleKnown: _toggleDistrict,
            onRemove: (value) => setState(() {
              if (_districts.length > 1) {
                _districts.remove(value);
              }
            }),
            onSelectAll: _selectAllKnownDistricts,
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final active = _InlineToggle(
                title: 'Bölge Aktif',
                description: 'Bu ülke/şehir ön yüzde kullanılabilir.',
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              );
              final defaultToggle = _InlineToggle(
                title: 'Varsayılan Bölge',
                description: 'Ön yüzde ilk açılacak konum olarak seç.',
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [active, const SizedBox(height: 10), defaultToggle],
                );
              }

              return Row(
                children: [
                  Expanded(child: active),
                  const SizedBox(width: 10),
                  Expanded(child: defaultToggle),
                ],
              );
            },
          ),
          const _FormDivider(),
          _DialogFooter(onSave: _save),
        ],
      ),
    );
  }
}

class _AddableChipSection extends StatelessWidget {
  const _AddableChipSection({
    required this.title,
    required this.helper,
    required this.addController,
    required this.addHint,
    required this.values,
    required this.knownValues,
    required this.onAdd,
    required this.onToggleKnown,
    required this.onRemove,
    this.onSelectAll,
  });

  final String title;
  final String helper;
  final TextEditingController addController;
  final String addHint;
  final List<String> values;
  final List<String> knownValues;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onToggleKnown;
  final ValueChanged<String> onRemove;
  final VoidCallback? onSelectAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _FieldLabel(title)),
            if (onSelectAll != null)
              _TextActionButton(label: 'Tümünü seç', onPressed: onSelectAll!),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.t(helper),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final field = _AddTextField(
              controller: addController,
              hint: addHint,
            );
            final button = _OutlineActionButton(
              label: 'Ekle',
              onPressed: () => onAdd(addController.text),
            );
            final knownChips = Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in knownValues)
                  _SelectableChip(
                    label: value,
                    selected: values.contains(value),
                    onTap: () => onToggleKnown(value),
                  ),
              ],
            );

            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  field,
                  const SizedBox(height: 8),
                  button,
                  if (knownValues.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    knownChips,
                  ],
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(width: 230, child: field),
                    const SizedBox(width: 8),
                    button,
                    if (knownValues.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(child: knownChips),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final value in values)
              _RemovableChip(label: value, onRemove: () => onRemove(value)),
          ],
        ),
      ],
    );
  }
}

class _CompactCheckSwitch extends StatelessWidget {
  const _CompactCheckSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 42,
          height: 24,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? AppColors.actionRed : AppColors.softLine,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value
                  ? AppColors.actionRed
                  : AppColors.line.withValues(alpha: 0.9),
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: value
                  ? const SymbolIcon(
                      Symbols.check,
                      color: AppColors.actionRed,
                      size: 12,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineToggle extends StatelessWidget {
  const _InlineToggle({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(title),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.t(description),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CompactCheckSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 8),
            Text(context.t(label)),
          ],
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: onPressed,
        style:
            OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepOcean,
              side: const BorderSide(color: AppColors.line),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Text(context.t(label)),
      ),
    );
  }
}

class _TextActionButton extends StatelessWidget {
  const _TextActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style:
          TextButton.styleFrom(
            foregroundColor: AppColors.actionRed,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ).copyWith(
            mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
          ),
      child: Text(context.t(label)),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.t(tooltip),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
            ),
            child: SymbolIcon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}

class _DistrictButton extends StatelessWidget {
  const _DistrictButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextButton(
        onPressed: onTap,
        style:
            TextButton.styleFrom(
              backgroundColor: selected ? AppColors.deepOcean : Colors.white,
              foregroundColor: selected ? Colors.white : AppColors.deepOcean,
              side: BorderSide(
                color: selected
                    ? AppColors.deepOcean
                    : AppColors.line.withValues(alpha: 0.9),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Text(label),
      ),
    );
  }
}

class _PreviewSmallButton extends StatelessWidget {
  const _PreviewSmallButton({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: () {},
        style:
            OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepOcean,
              side: const BorderSide(color: AppColors.line),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(icon, color: AppColors.deepOcean, size: 15),
            const SizedBox(width: 8),
            Text(context.t(label)),
          ],
        ),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? AppColors.actionRed.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected ? AppColors.actionRed : AppColors.line,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? AppColors.actionRed : AppColors.deepOcean,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 4),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: SymbolIcon(
                  Symbols.close,
                  color: AppColors.iconMuted,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Text(
        context.t(label),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFEAF7EF)
            : AppColors.actionRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        context.t(active ? 'Aktif' : 'Pasif'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: active ? const Color(0xFF0A7A3B) : AppColors.actionRed,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AddTextField extends StatelessWidget {
  const _AddTextField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextFormField(
        controller: controller,
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        decoration: _inputDecoration(context, hintText: hint).copyWith(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
        ),
      ),
    );
  }
}

class _TextInputField extends StatelessWidget {
  const _TextInputField({
    required this.label,
    this.controller,
    this.initialValue,
    this.hintText,
    this.onChanged,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: TextFormField(
            controller: controller,
            initialValue: controller == null ? initialValue : null,
            onChanged: onChanged,
            mouseCursor: SystemMouseCursors.text,
            cursorColor: AppColors.support,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            decoration: _inputDecoration(context, hintText: hintText),
          ),
        ),
      ],
    );
  }
}

class _SelectInputField extends StatelessWidget {
  const _SelectInputField({
    required this.label,
    required this.value,
    required this.options,
  });

  final String label;
  final String value;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        Container(
          height: 42,
          padding: const EdgeInsets.only(left: 12, right: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              borderRadius: BorderRadius.circular(AppRadius.value),
              dropdownColor: Colors.white,
              focusColor: Colors.transparent,
              mouseCursor: SystemMouseCursors.click,
              dropdownMenuItemMouseCursor: SystemMouseCursors.click,
              icon: const SymbolIcon(
                Symbols.keyboard_arrow_down,
                color: AppColors.iconMuted,
                size: 18,
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option,
                    child: Text(context.t(option)),
                  ),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ],
    );
  }
}

class _ResponsiveFieldRow extends StatelessWidget {
  const _ResponsiveFieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                children[i],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 18),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t(label),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _FormDivider extends StatelessWidget {
  const _FormDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 46,
      thickness: 1,
      color: AppColors.line.withValues(alpha: 0.9),
    );
  }
}

class _SaveRow extends StatelessWidget {
  const _SaveRow();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 38,
        child: TextButton(
          onPressed: () {},
          style:
              TextButton.styleFrom(
                backgroundColor: AppColors.actionRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ).copyWith(
                mouseCursor: const WidgetStatePropertyAll(
                  SystemMouseCursors.click,
                ),
              ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SymbolIcon(Symbols.check, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(context.t('Save Changes')),
            ],
          ),
        ),
      ),
    );
  }
}

class _PharmacyDialogFrame extends StatelessWidget {
  const _PharmacyDialogFrame({required this.child, required this.mobileDrawer});

  final Widget child;
  final bool mobileDrawer;

  @override
  Widget build(BuildContext context) {
    if (mobileDrawer) {
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(child: child),
      );
    }

    final height = MediaQuery.sizeOf(context).height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: height - 48),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          clipBehavior: Clip.antiAlias,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            context.t(title),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: SymbolIcon(
                Symbols.close,
                color: AppColors.inkSoft,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style:
                TextButton.styleFrom(
                  foregroundColor: AppColors.deepOcean,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ).copyWith(
                  mouseCursor: const WidgetStatePropertyAll(
                    SystemMouseCursors.click,
                  ),
                ),
            child: Text(context.t('Cancel')),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 114,
            height: 36,
            child: TextButton(
              onPressed: onSave,
              style:
                  TextButton.styleFrom(
                    backgroundColor: AppColors.deepOcean,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ).copyWith(
                    mouseCursor: const WidgetStatePropertyAll(
                      SystemMouseCursors.click,
                    ),
                  ),
              child: Text(context.t('Save')),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(BuildContext context, {String? hintText}) {
  return InputDecoration(
    hintText: hintText == null ? null : context.t(hintText),
    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.placeholder,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    filled: false,
    fillColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: AppColors.support),
    ),
  );
}

List<String> _mergeUnique(List<String> current, List<String> incoming) {
  final values = <String>[...current];
  for (final item in incoming) {
    if (!values.contains(item)) {
      values.add(item);
    }
  }
  return values;
}

List<String> _knownDistricts(String city) {
  final normalized = city.trim().toLowerCase();
  if (normalized == 'istanbul') {
    return const [
      'Adalar',
      'Ataşehir',
      'Bakırköy',
      'Beşiktaş',
      'Kadıköy',
      'Şişli',
      'Üsküdar',
    ];
  }
  if (normalized == 'konya') {
    return const ['Meram', 'Selçuklu', 'Karatay', 'Akşehir', 'Ereğli'];
  }
  if (normalized == 'berlin') {
    return const ['Mitte', 'Kreuzberg', 'Neukölln', 'Charlottenburg'];
  }
  return const [
    'Merkez',
    'Altunhisar',
    'Bor',
    'Çamardı',
    'Çiftlik',
    'Ulukışla',
  ];
}

const _defaultPharmacyRegions = [
  _PharmacyRegion(
    country: 'Türkiye',
    city: 'Niğde',
    source: 'Niğde Eczacı Odası / neo.org.tr',
    districts: [
      'Merkez',
      'Altunhisar',
      'Bor',
      'Çamardı',
      'Çiftlik',
      'Ulukışla',
    ],
    isDefault: true,
    active: true,
  ),
  _PharmacyRegion(
    country: 'Türkiye',
    city: 'İstanbul',
    source: 'İstanbul Eczacı Odası',
    districts: ['Kadıköy', 'Üsküdar', 'Şişli', 'Bakırköy', 'Beşiktaş'],
    isDefault: false,
    active: true,
  ),
  _PharmacyRegion(
    country: 'Almanya',
    city: 'Berlin',
    source: 'Apothekennotdienst',
    districts: ['Mitte', 'Kreuzberg', 'Neukölln'],
    isDefault: false,
    active: false,
  ),
];

class _PharmacyRegion {
  const _PharmacyRegion({
    required this.country,
    required this.city,
    required this.source,
    required this.districts,
    required this.isDefault,
    required this.active,
  });

  final String country;
  final String city;
  final String source;
  final List<String> districts;
  final bool isDefault;
  final bool active;

  _PharmacyRegion copyWith({
    String? country,
    String? city,
    String? source,
    List<String>? districts,
    bool? isDefault,
    bool? active,
  }) {
    return _PharmacyRegion(
      country: country ?? this.country,
      city: city ?? this.city,
      source: source ?? this.source,
      districts: districts ?? this.districts,
      isDefault: isDefault ?? this.isDefault,
      active: active ?? this.active,
    );
  }
}

class _PreviewPharmacy {
  const _PreviewPharmacy({
    required this.name,
    required this.district,
    required this.address,
    required this.phone,
    this.note,
  });

  factory _PreviewPharmacy.fromLive(DutyPharmacyItem item) {
    return _PreviewPharmacy(
      name: item.name,
      district: item.district,
      address: item.address,
      phone: item.phone,
      note: item.note.trim().isEmpty ? null : item.note,
    );
  }

  final String name;
  final String district;
  final String address;
  final String phone;
  final String? note;
}

_PharmacyRegion _regionFromPreview(DutyPharmacyPreviewData preview) {
  final districts = preview.districts.isEmpty
      ? const ['MERKEZ']
      : preview.districts;
  return _PharmacyRegion(
    country: 'Türkiye',
    city: preview.city,
    source: preview.sourceUrl.replaceFirst('https://www.', ''),
    districts: districts,
    isDefault: true,
    active: true,
  );
}

enum _PharmacySettingsTab {
  regions('Şehir Yönetimi', Symbols.language),
  preview('Canlı Önizleme', Symbols.visibility);

  const _PharmacySettingsTab(this.title, this.icon);

  final String title;
  final IconData icon;
}
