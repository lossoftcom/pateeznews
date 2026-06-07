import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../data/admin_module_settings_repository.dart';

class DeathNoticeSettingsScreen extends StatefulWidget {
  const DeathNoticeSettingsScreen({
    super.key,
    this.repository = const SupabaseAdminModuleSettingsRepository(),
  });

  final AdminModuleSettingsRepository repository;

  @override
  State<DeathNoticeSettingsScreen> createState() =>
      _DeathNoticeSettingsScreenState();
}

class _DeathNoticeSettingsScreenState extends State<DeathNoticeSettingsScreen> {
  var _selectedTab = _DeathNoticeSettingsTab.locations;
  var _serviceEnabled = true;
  var _cacheEnabled = true;
  var _dateGuardEnabled = true;
  var _selectedPreviewLocationIndex = 0;
  var _selectedPreviewDistrict = 'Hıdırlık';
  var _locations = List<_DeathNoticeLocation>.of(_defaultDeathNoticeLocations);
  DeathNoticePreviewData? _preview;
  var _loadingPreview = true;
  var _refreshingPreview = false;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreview());
  }

  _DeathNoticeLocation get _defaultLocation => _locations.firstWhere(
    (location) => location.isDefault,
    orElse: () => _locations.first,
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
      final preview = await widget.repository.fetchDeathNoticePreview(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      final location = _locationFromPreview(preview);
      setState(() {
        _preview = preview;
        _locations = [location];
        _selectedPreviewLocationIndex = 0;
        _selectedPreviewDistrict = location.districts.first;
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

  Future<void> _openLocationDialog({
    _DeathNoticeLocation? location,
    int? index,
  }) async {
    final result = await _showDeathNoticeLocationDialog(
      context,
      location: location,
    );
    if (!mounted || result == null) return;

    setState(() {
      final normalized = result.isDefault
          ? result.copyWith(isDefault: true)
          : result;
      if (index == null) {
        _locations.add(normalized);
      } else {
        _locations[index] = normalized;
      }
      if (normalized.isDefault) {
        _applyDefault(index ?? _locations.length - 1);
      }
      _ensureDefaultLocation();
      _selectedPreviewLocationIndex = _locations.indexWhere(
        (location) => location.isDefault,
      );
      _selectedPreviewDistrict = _defaultLocation.districts.first;
    });
  }

  void _deleteLocation(int index) {
    if (_locations.length == 1) return;
    setState(() {
      _locations.removeAt(index);
      _ensureDefaultLocation();
      if (_selectedPreviewLocationIndex >= _locations.length) {
        _selectedPreviewLocationIndex = _locations.length - 1;
      }
      _selectedPreviewDistrict = _defaultLocation.districts.first;
    });
  }

  void _setDefaultLocation(int index) {
    setState(() {
      _applyDefault(index);
      _selectedPreviewLocationIndex = index;
      _selectedPreviewDistrict = _locations[index].districts.first;
    });
  }

  void _toggleLocationActive(int index, bool value) {
    setState(() {
      _locations[index] = _locations[index].copyWith(active: value);
    });
  }

  void _applyDefault(int index) {
    for (var i = 0; i < _locations.length; i++) {
      _locations[i] = _locations[i].copyWith(isDefault: i == index);
    }
  }

  void _ensureDefaultLocation() {
    if (_locations.isEmpty) {
      _locations.addAll(_defaultDeathNoticeLocations);
    }
    if (!_locations.any((location) => location.isDefault)) {
      _locations[0] = _locations[0].copyWith(isDefault: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            28,
            horizontalPadding,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DeathNoticePageHeader(),
              const SizedBox(height: 22),
              _DeathNoticeTabs(
                selected: _selectedTab,
                onSelected: (tab) => setState(() => _selectedTab = tab),
              ),
              const SizedBox(height: 22),
              _DeathNoticeSettingsCard(
                title: _selectedTab.title,
                icon: _selectedTab.icon,
                trailing: _selectedTab == _DeathNoticeSettingsTab.locations
                    ? _PrimaryActionButton(
                        label: 'Konum Ekle',
                        icon: Symbols.add,
                        onPressed: () => _openLocationDialog(),
                      )
                    : _selectedTab == _DeathNoticeSettingsTab.preview
                    ? _PrimaryActionButton(
                        label: 'Veriyi Yenile',
                        icon: Symbols.schedule_send,
                        onPressed: () => _loadPreview(forceRefresh: true),
                      )
                    : null,
                child: switch (_selectedTab) {
                  _DeathNoticeSettingsTab.locations =>
                    _DeathNoticeLocationSettings(
                      locations: _locations,
                      serviceEnabled: _serviceEnabled,
                      cacheEnabled: _cacheEnabled,
                      dateGuardEnabled: _dateGuardEnabled,
                      onServiceChanged: (value) =>
                          setState(() => _serviceEnabled = value),
                      onCacheChanged: (value) =>
                          setState(() => _cacheEnabled = value),
                      onDateGuardChanged: (value) =>
                          setState(() => _dateGuardEnabled = value),
                      onEdit: (index) => _openLocationDialog(
                        location: _locations[index],
                        index: index,
                      ),
                      onDelete: _deleteLocation,
                      onSetDefault: _setDefaultLocation,
                      onActiveChanged: _toggleLocationActive,
                    ),
                  _DeathNoticeSettingsTab.preview => _DeathNoticePreview(
                    locations: _locations,
                    preview: _preview,
                    loading: _loadingPreview,
                    refreshing: _refreshingPreview,
                    error: _previewError,
                    selectedLocationIndex: _selectedPreviewLocationIndex,
                    selectedDistrict: _selectedPreviewDistrict,
                    onLocationSelected: (index) => setState(() {
                      _selectedPreviewLocationIndex = index;
                      _selectedPreviewDistrict =
                          _locations[index].districts.first;
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

Future<_DeathNoticeLocation?> _showDeathNoticeLocationDialog(
  BuildContext context, {
  _DeathNoticeLocation? location,
}) {
  return showDialog<_DeathNoticeLocation>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (context) =>
        _DeathNoticeDialogFrame(child: _LocationDialog(location: location)),
  );
}

class _DeathNoticePageHeader extends StatelessWidget {
  const _DeathNoticePageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('Death Notice Settings'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.t(
            'Manage the frontend death notices card by city, district and source.',
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

class _DeathNoticeTabs extends StatelessWidget {
  const _DeathNoticeTabs({required this.selected, required this.onSelected});

  final _DeathNoticeSettingsTab selected;
  final ValueChanged<_DeathNoticeSettingsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tab in _DeathNoticeSettingsTab.values)
          _SettingsTabButton(
            label: tab.title,
            selected: selected == tab,
            onTap: () => onSelected(tab),
          ),
      ],
    );
  }
}

class _SettingsTabButton extends StatelessWidget {
  const _SettingsTabButton({
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
      height: 38,
      child: TextButton(
        onPressed: onTap,
        style:
            TextButton.styleFrom(
              backgroundColor: selected ? AppColors.actionRed : Colors.white,
              foregroundColor: selected ? Colors.white : AppColors.deepOcean,
              side: BorderSide(
                color: selected
                    ? AppColors.actionRed
                    : AppColors.line.withValues(alpha: 0.88),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
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

class _DeathNoticeSettingsCard extends StatelessWidget {
  const _DeathNoticeSettingsCard({
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

class _DeathNoticeGeneralSettings extends StatelessWidget {
  const _DeathNoticeGeneralSettings({
    required this.serviceEnabled,
    required this.onServiceChanged,
  });

  final bool serviceEnabled;
  final ValueChanged<bool> onServiceChanged;

  @override
  Widget build(BuildContext context) {
    return _StatusBox(
      title: 'Ölüm İlanları Aktif',
      description: 'Ön yüzde ölüm ilanları kartını göster.',
      enabled: serviceEnabled,
      onChanged: onServiceChanged,
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
    required this.dateGuardEnabled,
    required this.onCacheChanged,
    required this.onDateGuardChanged,
  });

  final bool cacheEnabled;
  final bool dateGuardEnabled;
  final ValueChanged<bool> onCacheChanged;
  final ValueChanged<bool> onDateGuardChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TextInputField(
          label: 'Veri Kaynağı',
          initialValue: 'nigde.bel.tr/vefat-edenler',
        ),
        const SizedBox(height: 14),
        const _SelectInputField(
          label: 'Cache Süresi',
          value: '30 dakika',
          options: ['15 dakika', '30 dakika', '60 dakika', '120 dakika'],
        ),
        const SizedBox(height: 14),
        _InlineToggle(
          title: 'Open cache • 30 dk',
          description: 'Aynı şehir/ilçe ilanlarını gereksiz yenilemeden korur.',
          value: cacheEnabled,
          onChanged: onCacheChanged,
        ),
        const SizedBox(height: 10),
        _InlineToggle(
          title: 'Gün Tarihi Koruması',
          description:
              'Sadece bugünün ilanlarını gösterir; tarih değişince eski cache kullanılmaz.',
          value: dateGuardEnabled,
          onChanged: onDateGuardChanged,
        ),
      ],
    );
  }
}

class _DeathNoticeLocationSettings extends StatelessWidget {
  const _DeathNoticeLocationSettings({
    required this.locations,
    required this.serviceEnabled,
    required this.cacheEnabled,
    required this.dateGuardEnabled,
    required this.onServiceChanged,
    required this.onCacheChanged,
    required this.onDateGuardChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
    required this.onActiveChanged,
  });

  final List<_DeathNoticeLocation> locations;
  final bool serviceEnabled;
  final bool cacheEnabled;
  final bool dateGuardEnabled;
  final ValueChanged<bool> onServiceChanged;
  final ValueChanged<bool> onCacheChanged;
  final ValueChanged<bool> onDateGuardChanged;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onSetDefault;
  final void Function(int index, bool value) onActiveChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeathNoticeGeneralSettings(
          serviceEnabled: serviceEnabled,
          onServiceChanged: onServiceChanged,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            final source = _SourceSettings(
              cacheEnabled: cacheEnabled,
              dateGuardEnabled: dateGuardEnabled,
              onCacheChanged: onCacheChanged,
              onDateGuardChanged: onDateGuardChanged,
            );
            final locationCards = _LocationCardList(
              locations: locations,
              onEdit: onEdit,
              onDelete: onDelete,
              onSetDefault: onSetDefault,
              onActiveChanged: onActiveChanged,
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [source, const SizedBox(height: 14), locationCards],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: source),
                const SizedBox(width: 14),
                Expanded(child: locationCards),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const _SaveRow(),
      ],
    );
  }
}

class _LocationCardList extends StatelessWidget {
  const _LocationCardList({
    required this.locations,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
    required this.onActiveChanged,
  });

  final List<_DeathNoticeLocation> locations;
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
            for (var i = 0; i < locations.length; i++)
              SizedBox(
                width: constraints.maxWidth,
                child: _LocationCard(
                  location: locations[i],
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

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
    required this.onActiveChanged,
  });

  final _DeathNoticeLocation location;
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
                      '${location.country} / ${location.city}',
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
                        if (location.isDefault)
                          const _SoftBadge(label: 'Varsayılan konum'),
                        _StatusBadge(active: location.active),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _IconActionButton(
                tooltip: 'Konumu düzenle',
                icon: Symbols.edit_square,
                color: AppColors.deepOcean,
                onTap: onEdit,
              ),
              const SizedBox(width: 6),
              _IconActionButton(
                tooltip: 'Konumu sil',
                icon: Symbols.delete,
                color: AppColors.actionRed,
                onTap: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _FieldLabel('İlçeler'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final district in location.districts)
                _SoftBadge(label: district),
            ],
          ),
          const SizedBox(height: 12),
          _SoftSourceBox(source: location.source),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!location.isDefault)
                _OutlineActionButton(
                  label: 'Varsayılan yap',
                  onPressed: onSetDefault,
                )
              else
                const _SoftBadge(label: 'Varsayılan'),
              const Spacer(),
              Text(
                context.t(location.active ? 'Aktif' : 'Pasif'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 8),
              _CompactCheckSwitch(
                value: location.active,
                onChanged: onActiveChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoftSourceBox extends StatelessWidget {
  const _SoftSourceBox({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Text(
        source,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.actionRed,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _DeathNoticePreview extends StatelessWidget {
  const _DeathNoticePreview({
    required this.locations,
    required this.preview,
    required this.loading,
    required this.refreshing,
    required this.error,
    required this.selectedLocationIndex,
    required this.selectedDistrict,
    required this.onLocationSelected,
    required this.onDistrictSelected,
    required this.onRefresh,
  });

  final List<_DeathNoticeLocation> locations;
  final DeathNoticePreviewData? preview;
  final bool loading;
  final bool refreshing;
  final String? error;
  final int selectedLocationIndex;
  final String selectedDistrict;
  final ValueChanged<int> onLocationSelected;
  final ValueChanged<String> onDistrictSelected;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final safeIndex =
        selectedLocationIndex >= 0 && selectedLocationIndex < locations.length
        ? selectedLocationIndex
        : 0;
    final location = locations[safeIndex];
    final notices = [
      for (final notice in preview?.notices ?? const <DeathNoticeItem>[])
        if (selectedDistrict.isEmpty ||
            notice.burialPlace.contains(selectedDistrict.toUpperCase()))
          _PreviewDeathNotice.fromLive(notice),
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
                      values: {'name': location.city},
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
                      'settings.deathPreviewMeta',
                      values: {
                        'date': preview?.serviceDateLabel ?? '-',
                        'count': (preview?.total ?? notices.length).toString(),
                        'source': preview?.cache.source ?? location.source,
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
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < locations.length; i++)
              _DistrictButton(
                label: locations[i].city,
                selected: safeIndex == i,
                onTap: () => onLocationSelected(i),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final district in location.districts)
              _DistrictButton(
                label: district,
                selected: selectedDistrict == district,
                onTap: () => onDistrictSelected(district),
              ),
          ],
        ),
        const SizedBox(height: 18),
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
                if (notices.isEmpty)
                  SizedBox(
                    width: constraints.maxWidth,
                    child: const _PreviewEmptyBox(
                      title: 'Kayıt bulunamadı',
                      description: 'Seçili ilçe için canlı ilan kaydı yok.',
                    ),
                  )
                else
                  for (final notice in notices)
                    SizedBox(
                      width: itemWidth,
                      child: _PreviewDeathNoticeCard(notice: notice),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PreviewDeathNoticeCard extends StatelessWidget {
  const _PreviewDeathNoticeCard({required this.notice});

  final _PreviewDeathNotice notice;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  notice.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                notice.date,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notice.route,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.actionRed,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            notice.description,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.45,
            ),
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

class _LocationDialog extends StatefulWidget {
  const _LocationDialog({this.location});

  final _DeathNoticeLocation? location;

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
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
    final location = widget.location;
    _countryController = TextEditingController(
      text: location?.country ?? 'Türkiye',
    );
    _cityController = TextEditingController(text: location?.city ?? 'Niğde');
    _sourceController = TextEditingController(
      text: location?.source ?? 'nigde.bel.tr/vefat-edenler',
    );
    _districtController = TextEditingController();
    _districts = List<String>.of(
      location?.districts ?? const ['Hıdırlık', 'Merkez'],
    );
    _active = location?.active ?? true;
    _isDefault = location?.isDefault ?? false;
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
        _knownDeathNoticeDistricts(_cityController.text),
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
        ? 'nigde.bel.tr/vefat-edenler'
        : _sourceController.text.trim();

    Navigator.of(context).pop(
      _DeathNoticeLocation(
        country: country,
        city: city,
        source: source,
        districts: _districts.isEmpty
            ? const ['Hıdırlık']
            : List.of(_districts),
        isDefault: _isDefault,
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.location != null;
    final knownDistricts = _knownDeathNoticeDistricts(_cityController.text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogHeader(title: editing ? 'Konum Düzenle' : 'Konum Ekle'),
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
            hintText: 'Belediye, resmi servis veya API kaynağı',
          ),
          const SizedBox(height: 20),
          _AddableChipSection(
            title: 'İlçeler',
            helper: 'İstenen ilçeleri seçin veya yeni ilçe ekleyin.',
            addController: _districtController,
            addHint: 'İlçe ekle',
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
                title: 'Konum Aktif',
                description: 'Bu şehir/ilçe grubu ön yüzde kullanılabilir.',
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              );
              final defaultToggle = _InlineToggle(
                title: 'Varsayılan Konum',
                description: 'Ön yüzde ilk açılacak ilan konumu olarak seç.',
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

            return Row(
              children: [
                SizedBox(width: 230, child: field),
                const SizedBox(width: 8),
                button,
                if (knownValues.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(child: knownChips),
                ],
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
        child: Text(context.t(label)),
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

class _DeathNoticeDialogFrame extends StatelessWidget {
  const _DeathNoticeDialogFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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

List<String> _knownDeathNoticeDistricts(String city) {
  final normalized = city.trim().toLowerCase();
  if (normalized == 'istanbul') {
    return const ['Kadıköy', 'Üsküdar', 'Şişli', 'Bakırköy', 'Beşiktaş'];
  }
  if (normalized == 'konya') {
    return const ['Meram', 'Selçuklu', 'Karatay', 'Akşehir', 'Ereğli'];
  }
  if (normalized == 'berlin') {
    return const ['Mitte', 'Kreuzberg', 'Neukölln', 'Charlottenburg'];
  }
  return const ['Hıdırlık', 'Merkez', 'Bor', 'Altunhisar', 'Ulukışla'];
}

const _defaultDeathNoticeLocations = [
  _DeathNoticeLocation(
    country: 'Türkiye',
    city: 'Niğde',
    source: 'nigde.bel.tr/vefat-edenler',
    districts: ['Hıdırlık', 'Merkez', 'Bor', 'Altunhisar', 'Ulukışla'],
    isDefault: true,
    active: true,
  ),
];

class _DeathNoticeLocation {
  const _DeathNoticeLocation({
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

  _DeathNoticeLocation copyWith({
    String? country,
    String? city,
    String? source,
    List<String>? districts,
    bool? isDefault,
    bool? active,
  }) {
    return _DeathNoticeLocation(
      country: country ?? this.country,
      city: city ?? this.city,
      source: source ?? this.source,
      districts: districts ?? this.districts,
      isDefault: isDefault ?? this.isDefault,
      active: active ?? this.active,
    );
  }
}

class _PreviewDeathNotice {
  const _PreviewDeathNotice({
    required this.name,
    required this.date,
    required this.route,
    required this.description,
  });

  factory _PreviewDeathNotice.fromLive(DeathNoticeItem item) {
    final route = [
      if (item.prayerTime.trim().isNotEmpty) item.prayerTime,
      if (item.burialPlace.trim().isNotEmpty) item.burialPlace,
    ].join(' - ');
    return _PreviewDeathNotice(
      name: item.name,
      date: item.deathDateLabel,
      route: route,
      description: item.description,
    );
  }

  final String name;
  final String date;
  final String route;
  final String description;
}

_DeathNoticeLocation _locationFromPreview(DeathNoticePreviewData preview) {
  final districts = <String>{};
  for (final notice in preview.notices) {
    final place = notice.burialPlace.trim();
    if (place.isNotEmpty) districts.add(_titleCaseTurkish(place));
  }
  return _DeathNoticeLocation(
    country: 'Türkiye',
    city: preview.city,
    source: preview.sourceUrl.replaceFirst('https://', ''),
    districts: districts.isEmpty ? const ['Hıdırlık'] : districts.toList(),
    isDefault: true,
    active: true,
  );
}

String _titleCaseTurkish(String value) {
  if (value.toUpperCase() == 'HIDIRLIK') return 'Hıdırlık';
  final lower = value.toLowerCase();
  if (lower.isEmpty) return value;
  return lower[0].toUpperCase() + lower.substring(1);
}

enum _DeathNoticeSettingsTab {
  locations('Şehir Yönetimi', Symbols.language),
  preview('Canlı Önizleme', Symbols.visibility);

  const _DeathNoticeSettingsTab(this.title, this.icon);

  final String title;
  final IconData icon;
}
