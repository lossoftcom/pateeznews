import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_module_settings_repository.dart';
import 'settings_mobile_chrome.dart';

class WeatherSettingsScreen extends StatefulWidget {
  const WeatherSettingsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminModuleSettingsRepository(),
  });

  final AdminSession session;
  final AdminModuleSettingsRepository repository;

  @override
  State<WeatherSettingsScreen> createState() => _WeatherSettingsScreenState();
}

class _WeatherSettingsScreenState extends State<WeatherSettingsScreen> {
  var _selectedTab = _WeatherSettingsTab.cities;
  var _settingsLanguageCode = 'tr';
  var _serviceEnabled = true;
  var _selectedPreviewIndex = 0;
  var _cities = List<_WeatherCity>.of(_defaultWeatherCities);
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  _WeatherCity get _defaultCity =>
      _cities.firstWhere((city) => city.isDefault, orElse: () => _cities.first);

  _WeatherCity get _previewCity {
    if (_selectedPreviewIndex >= 0 && _selectedPreviewIndex < _cities.length) {
      return _cities[_selectedPreviewIndex];
    }
    return _defaultCity;
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await widget.repository.fetchWeatherSettings(
        _settingsLanguageCode,
      );
      if (!mounted) return;
      setState(() {
        _settingsLanguageCode = settings.languageCode;
        _serviceEnabled = settings.enabled;
        _cities = [_weatherCityFromSettings(settings)];
        _selectedPreviewIndex = 0;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_saving || _loading) return;
    final latitude = _parseCoordinate(_defaultCity.latitude);
    final longitude = _parseCoordinate(_defaultCity.longitude);
    if (latitude == null || longitude == null) {
      _showMessage('Hava durumu koordinatları geçersiz.');
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await widget.repository.saveWeatherSettings(
        session: widget.session,
        settings: WeatherSettingsData(
          languageCode: _settingsLanguageCode,
          enabled: _serviceEnabled,
          locationName: _defaultCity.city,
          locationCountry: _defaultCity.country,
          latitude: latitude,
          longitude: longitude,
          timezone: _defaultCity.timezone,
          updateIntervalMinutes: 30,
        ),
      );
      if (!mounted) return;
      setState(() {
        _serviceEnabled = saved.enabled;
        _cities = [_weatherCityFromSettings(saved)];
        _selectedPreviewIndex = 0;
        _saving = false;
      });
      _showMessage('Ayarlar başarıyla kaydedildi');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Ayarlar kaydedilirken bir hata oluştu: $error');
    }
  }

  void _showMessage(
    String message, {
    AdminToastTone tone = AdminToastTone.info,
  }) {
    AdminToast.show(context, message: context.t(message), tone: tone);
  }

  Future<void> _openCityDialog({_WeatherCity? city, int? index}) async {
    final result = await _showWeatherCityDialog(context, city: city);
    if (!mounted || result == null) return;

    setState(() {
      final normalized = result.isDefault
          ? result.copyWith(isDefault: true)
          : result;
      if (index == null) {
        _cities.add(normalized);
      } else {
        _cities[index] = normalized;
      }
      if (normalized.isDefault) {
        _applyDefault(index ?? _cities.length - 1);
      }
      _ensureDefaultCity();
      _selectedPreviewIndex = _cities.indexWhere((item) => item.isDefault);
    });
  }

  void _deleteCity(int index) {
    if (_cities.length == 1) return;
    setState(() {
      _cities.removeAt(index);
      _ensureDefaultCity();
      if (_selectedPreviewIndex >= _cities.length) {
        _selectedPreviewIndex = _cities.length - 1;
      }
    });
  }

  void _setDefaultCity(int index) {
    setState(() {
      _applyDefault(index);
      _selectedPreviewIndex = index;
    });
  }

  void _toggleCityActive(int index, bool value) {
    setState(() {
      _cities[index] = _cities[index].copyWith(active: value);
    });
  }

  void _applyDefault(int index) {
    for (var i = 0; i < _cities.length; i++) {
      _cities[i] = _cities[i].copyWith(isDefault: i == index);
    }
  }

  void _ensureDefaultCity() {
    if (_cities.isEmpty) {
      _cities.addAll(_defaultWeatherCities);
    }
    if (!_cities.any((city) => city.isDefault)) {
      _cities[0] = _cities[0].copyWith(isDefault: true);
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
              const _WeatherPageHeader(),
              const SizedBox(height: 22),
              _WeatherTabs(
                selected: _selectedTab,
                onSelected: (tab) => setState(() => _selectedTab = tab),
              ),
              const SizedBox(height: 22),
              if (_loading)
                const _WeatherLoadingBox()
              else if (_error != null)
                _WeatherErrorBox(message: _error!, onRetry: _loadSettings)
              else
                _WeatherSettingsCard(
                  title: _selectedTab.title,
                  icon: _selectedTab.icon,
                  trailing: _selectedTab == _WeatherSettingsTab.cities
                      ? _PrimaryActionButton(
                          label: 'Şehir Ekle',
                          icon: Symbols.add,
                          onPressed: () => _openCityDialog(),
                        )
                      : null,
                  child: switch (_selectedTab) {
                    _WeatherSettingsTab.cities => _WeatherCitySettings(
                      cities: _cities,
                      serviceEnabled: _serviceEnabled,
                      saving: _saving,
                      onServiceChanged: (value) =>
                          setState(() => _serviceEnabled = value),
                      onEdit: (index) =>
                          _openCityDialog(city: _cities[index], index: index),
                      onDelete: _deleteCity,
                      onSetDefault: _setDefaultCity,
                      onActiveChanged: _toggleCityActive,
                      onSave: _saveSettings,
                    ),
                    _WeatherSettingsTab.preview => _WeatherPreview(
                      cities: _cities,
                      selectedIndex: _selectedPreviewIndex,
                      city: _previewCity,
                      saving: _saving,
                      onSelected: (index) =>
                          setState(() => _selectedPreviewIndex = index),
                      onSave: _saveSettings,
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

Future<_WeatherCity?> _showWeatherCityDialog(
  BuildContext context, {
  _WeatherCity? city,
}) {
  return showSettingsSideDialog<_WeatherCity>(
    context,
    barrierLabel: 'WeatherCityDialog',
    builder: (mobile) => _WeatherDialogFrame(
      mobileDrawer: mobile,
      child: _WeatherCityDialog(city: city),
    ),
  );
}

class _WeatherPageHeader extends StatelessWidget {
  const _WeatherPageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('Weather Settings'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.t(
            'Manage the frontend weather card with multiple cities and Open-Meteo coordinates.',
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

class _WeatherTabs extends StatelessWidget {
  const _WeatherTabs({required this.selected, required this.onSelected});

  final _WeatherSettingsTab selected;
  final ValueChanged<_WeatherSettingsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SettingsResponsiveTabs<_WeatherSettingsTab>(
      selected: selected,
      onSelected: onSelected,
      items: [
        for (final tab in _WeatherSettingsTab.values)
          SettingsTabItem(value: tab, label: tab.title),
      ],
    );
  }
}

class _WeatherSettingsCard extends StatelessWidget {
  const _WeatherSettingsCard({
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

class _WeatherLoadingBox extends StatelessWidget {
  const _WeatherLoadingBox();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 240,
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
}

class _WeatherErrorBox extends StatelessWidget {
  const _WeatherErrorBox({required this.message, required this.onRetry});

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

class _WeatherGeneralSettings extends StatelessWidget {
  const _WeatherGeneralSettings({
    required this.serviceEnabled,
    required this.onServiceChanged,
  });

  final bool serviceEnabled;
  final ValueChanged<bool> onServiceChanged;

  @override
  Widget build(BuildContext context) {
    return _StatusBox(
      title: 'Hava Durumu Aktif',
      description: 'Ön yüzdeki hava kartı varsayılan şehirden beslensin.',
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

class _WeatherIntervalSettings extends StatelessWidget {
  const _WeatherIntervalSettings();

  @override
  Widget build(BuildContext context) {
    return const _SelectInputField(
      label: 'Yenileme Aralığı',
      value: '30 dakika',
      options: ['15 dakika', '30 dakika', '60 dakika', '120 dakika'],
    );
  }
}

class _WeatherCitySettings extends StatelessWidget {
  const _WeatherCitySettings({
    required this.cities,
    required this.serviceEnabled,
    required this.saving,
    required this.onServiceChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
    required this.onActiveChanged,
    required this.onSave,
  });

  final List<_WeatherCity> cities;
  final bool serviceEnabled;
  final bool saving;
  final ValueChanged<bool> onServiceChanged;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onSetDefault;
  final void Function(int index, bool value) onActiveChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeatherGeneralSettings(
          serviceEnabled: serviceEnabled,
          onServiceChanged: onServiceChanged,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            const intervalSettings = _WeatherIntervalSettings();
            final cityCards = _WeatherCityCardList(
              cities: cities,
              onEdit: onEdit,
              onDelete: onDelete,
              onSetDefault: onSetDefault,
              onActiveChanged: onActiveChanged,
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  intervalSettings,
                  const SizedBox(height: 14),
                  cityCards,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: intervalSettings),
                const SizedBox(width: 14),
                Expanded(child: cityCards),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _WeatherSaveRow(saving: saving, onSave: onSave),
      ],
    );
  }
}

class _WeatherCityCardList extends StatelessWidget {
  const _WeatherCityCardList({
    required this.cities,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
    required this.onActiveChanged,
  });

  final List<_WeatherCity> cities;
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
            for (var i = 0; i < cities.length; i++)
              SizedBox(
                width: constraints.maxWidth,
                child: _WeatherCityCard(
                  city: cities[i],
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

class _WeatherCityCard extends StatelessWidget {
  const _WeatherCityCard({
    required this.city,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
    required this.onActiveChanged,
  });

  final _WeatherCity city;
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
                      '${city.country} / ${city.city}',
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
                        if (city.isDefault)
                          const _SoftBadge(label: 'Varsayılan şehir'),
                        _StatusBadge(active: city.active),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _IconActionButton(
                tooltip: 'Şehri düzenle',
                icon: Symbols.edit_square,
                color: AppColors.deepOcean,
                onTap: onEdit,
              ),
              const SizedBox(width: 6),
              _IconActionButton(
                tooltip: 'Şehri sil',
                icon: Symbols.delete,
                color: AppColors.actionRed,
                onTap: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!city.isDefault)
                _OutlineActionButton(
                  label: 'Varsayılan yap',
                  onPressed: onSetDefault,
                )
              else
                const _SoftBadge(label: 'Varsayılan'),
              const Spacer(),
              Text(
                context.t(city.active ? 'Aktif' : 'Pasif'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 8),
              _CompactCheckSwitch(
                value: city.active,
                onChanged: onActiveChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherPreview extends StatelessWidget {
  const _WeatherPreview({
    required this.cities,
    required this.selectedIndex,
    required this.city,
    required this.saving,
    required this.onSelected,
    required this.onSave,
  });

  final List<_WeatherCity> cities;
  final int selectedIndex;
  final _WeatherCity city;
  final bool saving;
  final ValueChanged<int> onSelected;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
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
                      values: {'name': city.city},
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
                      'settings.weatherPreviewMeta',
                      values: {
                        'date': context.t('May 21, 2026'),
                        'source': city.source,
                        'timezone': city.timezone,
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
            const _SoftBadge(label: 'Open-Meteo'),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < cities.length; i++)
              _CityButton(
                label: cities[i].city,
                selected: selectedIndex == i,
                onTap: () => onSelected(i),
              ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 780;
            final primary = _PreviewWeatherCard(city: city);
            final details = _ForecastDetails(city: city);

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [primary, const SizedBox(height: 14), details],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: primary),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: details),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _WeatherSaveRow(saving: saving, onSave: onSave),
      ],
    );
  }
}

class _PreviewWeatherCard extends StatelessWidget {
  const _PreviewWeatherCard({required this.city});

  final _WeatherCity city;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Seçili Şehir'),
          const SizedBox(height: 10),
          Text(
            city.city,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            city.country,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final temperature = Text(
                '${city.temperature}°',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              );
              final condition = Text(
                context.t(city.condition),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              );

              if (constraints.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [temperature, const SizedBox(height: 2), condition],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  temperature,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: condition,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ForecastDetails extends StatelessWidget {
  const _ForecastDetails({required this.city});

  final _WeatherCity city;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsiveFieldRow(
          children: [
            _ReadOnlyMetric(label: 'Enlem', value: city.latitude),
            _ReadOnlyMetric(label: 'Boylam', value: city.longitude),
          ],
        ),
        const SizedBox(height: 14),
        _ResponsiveFieldRow(
          children: [
            _ReadOnlyMetric(label: 'Nem', value: city.humidity),
            _ReadOnlyMetric(label: 'Rüzgar', value: city.wind),
            _ReadOnlyMetric(label: 'Hissedilen', value: '${city.feelsLike}°'),
          ],
        ),
        const SizedBox(height: 14),
        const _InlineInfo(
          title: 'Yenileme Aralığı',
          description: 'Open-Meteo isteği 30 dakikada bir yenilenir.',
        ),
      ],
    );
  }
}

class _ReadOnlyMetric extends StatelessWidget {
  const _ReadOnlyMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        Container(
          height: 42,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.title, required this.description});

  final String title;
  final String description;

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
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
            ),
            child: const SymbolIcon(
              Symbols.schedule,
              color: AppColors.actionRed,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
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
        ],
      ),
    );
  }
}

class _WeatherCityDialog extends StatefulWidget {
  const _WeatherCityDialog({this.city});

  final _WeatherCity? city;

  @override
  State<_WeatherCityDialog> createState() => _WeatherCityDialogState();
}

class _WeatherCityDialogState extends State<_WeatherCityDialog> {
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _timezoneController;
  late final TextEditingController _sourceController;
  late bool _active;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final city = widget.city;
    _countryController = TextEditingController(
      text: city?.country ?? 'Türkiye',
    );
    _cityController = TextEditingController(text: city?.city ?? 'Niğde');
    _latitudeController = TextEditingController(
      text: city?.latitude ?? '37,96583',
    );
    _longitudeController = TextEditingController(
      text: city?.longitude ?? '34,67935',
    );
    _timezoneController = TextEditingController(
      text: city?.timezone ?? 'Europe/Istanbul',
    );
    _sourceController = TextEditingController(
      text: city?.source ?? 'Open-Meteo',
    );
    _active = city?.active ?? true;
    _isDefault = city?.isDefault ?? false;
  }

  @override
  void dispose() {
    _countryController.dispose();
    _cityController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _timezoneController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  void _save() {
    final country = _countryController.text.trim().isEmpty
        ? 'Türkiye'
        : _countryController.text.trim();
    final cityName = _cityController.text.trim().isEmpty
        ? 'Niğde'
        : _cityController.text.trim();
    final latitude = _latitudeController.text.trim().isEmpty
        ? '37,96583'
        : _latitudeController.text.trim();
    final longitude = _longitudeController.text.trim().isEmpty
        ? '34,67935'
        : _longitudeController.text.trim();
    final timezone = _timezoneController.text.trim().isEmpty
        ? 'Europe/Istanbul'
        : _timezoneController.text.trim();
    final source = _sourceController.text.trim().isEmpty
        ? 'Open-Meteo'
        : _sourceController.text.trim();

    Navigator.of(context).pop(
      _WeatherCity(
        country: country,
        city: cityName,
        latitude: latitude,
        longitude: longitude,
        timezone: timezone,
        source: source,
        temperature: widget.city?.temperature ?? 22,
        feelsLike: widget.city?.feelsLike ?? 23,
        humidity: widget.city?.humidity ?? '%48',
        wind: widget.city?.wind ?? '11 km/s',
        condition: widget.city?.condition ?? 'Parçalı bulutlu',
        isDefault: _isDefault,
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.city != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogHeader(title: editing ? 'Şehir Düzenle' : 'Şehir Ekle'),
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
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ResponsiveFieldRow(
            children: [
              _TextInputField(
                controller: _latitudeController,
                label: 'Enlem',
                hintText: '37,96583',
              ),
              _TextInputField(
                controller: _longitudeController,
                label: 'Boylam',
                hintText: '34,67935',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ResponsiveFieldRow(
            children: [
              _TextInputField(
                controller: _timezoneController,
                label: 'Saat Dilimi',
                hintText: 'Europe/Istanbul',
              ),
              _TextInputField(
                controller: _sourceController,
                label: 'Kaynak',
                hintText: 'Open-Meteo',
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final active = _InlineToggle(
                title: 'Şehir Aktif',
                description: 'Bu şehir hava durumu kartında kullanılabilir.',
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              );
              final defaultToggle = _InlineToggle(
                title: 'Varsayılan Şehir',
                description: 'Ön yüzde ilk açılacak hava konumu olarak seç.',
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

class _CityButton extends StatelessWidget {
  const _CityButton({
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

class _TextInputField extends StatelessWidget {
  const _TextInputField({required this.label, this.controller, this.hintText});

  final String label;
  final TextEditingController? controller;
  final String? hintText;

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
            mouseCursor: SystemMouseCursors.text,
            cursorColor: AppColors.support,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            decoration: _inputDecoration(
              context,
              hintText: hintText,
              modal: true,
            ),
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
              isExpanded: true,
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

class _WeatherSaveRow extends StatelessWidget {
  const _WeatherSaveRow({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            height: 38,
            child: TextButton(
              onPressed: saving ? null : onSave,
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
                  const SymbolIcon(
                    Symbols.check,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(context.t(saving ? 'Kaydediliyor...' : 'Save Changes')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherDialogFrame extends StatelessWidget {
  const _WeatherDialogFrame({required this.child, required this.mobileDrawer});

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
        constraints: BoxConstraints(maxWidth: 720, maxHeight: height - 48),
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

InputDecoration _inputDecoration(
  BuildContext context, {
  String? hintText,
  IconData? prefixIcon,
  bool modal = false,
}) {
  return InputDecoration(
    hintText: hintText == null ? null : context.t(hintText),
    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.placeholder,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    prefixIcon: prefixIcon == null
        ? null
        : SymbolIcon(prefixIcon, color: AppColors.iconMuted, size: 18),
    prefixIconConstraints: const BoxConstraints(minWidth: 38),
    filled: !modal,
    fillColor: modal ? Colors.transparent : Colors.white,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 12,
      vertical: modal ? 10 : 12,
    ),
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
      borderSide: BorderSide(
        color: modal
            ? AppColors.support
            : AppColors.deepOcean.withValues(alpha: 0.4),
      ),
    ),
  );
}

_WeatherCity _weatherCityFromSettings(WeatherSettingsData settings) {
  return _WeatherCity(
    country: settings.locationCountry.trim().isEmpty
        ? 'Türkiye'
        : settings.locationCountry.trim(),
    city: settings.locationName.trim().isEmpty
        ? 'Niğde'
        : settings.locationName.trim(),
    latitude: _formatCoordinate(settings.latitude),
    longitude: _formatCoordinate(settings.longitude),
    timezone: settings.timezone.trim().isEmpty
        ? 'Europe/Istanbul'
        : settings.timezone.trim(),
    source: 'Open-Meteo',
    temperature: 22,
    feelsLike: 23,
    humidity: '%48',
    wind: '11 km/s',
    condition: 'Parçalı bulutlu',
    isDefault: true,
    active: settings.enabled,
  );
}

String _formatCoordinate(double value) {
  return value.toStringAsFixed(5).replaceAll('.', ',');
}

double? _parseCoordinate(String value) {
  return double.tryParse(value.trim().replaceAll(',', '.'));
}

const _defaultWeatherCities = [
  _WeatherCity(
    country: 'Türkiye',
    city: 'Niğde',
    latitude: '37,96583',
    longitude: '34,67935',
    timezone: 'Europe/Istanbul',
    source: 'Open-Meteo',
    temperature: 22,
    feelsLike: 23,
    humidity: '%48',
    wind: '11 km/s',
    condition: 'Parçalı bulutlu',
    isDefault: true,
    active: true,
  ),
  _WeatherCity(
    country: 'Türkiye',
    city: 'İstanbul',
    latitude: '41,00824',
    longitude: '28,97836',
    timezone: 'Europe/Istanbul',
    source: 'Open-Meteo',
    temperature: 20,
    feelsLike: 21,
    humidity: '%63',
    wind: '18 km/s',
    condition: 'Az bulutlu',
    isDefault: false,
    active: true,
  ),
  _WeatherCity(
    country: 'Almanya',
    city: 'Berlin',
    latitude: '52,52000',
    longitude: '13,40500',
    timezone: 'Europe/Berlin',
    source: 'Open-Meteo',
    temperature: 17,
    feelsLike: 16,
    humidity: '%57',
    wind: '14 km/s',
    condition: 'Açık',
    isDefault: false,
    active: false,
  ),
];

class _WeatherCity {
  const _WeatherCity({
    required this.country,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.source,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.wind,
    required this.condition,
    required this.isDefault,
    required this.active,
  });

  final String country;
  final String city;
  final String latitude;
  final String longitude;
  final String timezone;
  final String source;
  final int temperature;
  final int feelsLike;
  final String humidity;
  final String wind;
  final String condition;
  final bool isDefault;
  final bool active;

  _WeatherCity copyWith({
    String? country,
    String? city,
    String? latitude,
    String? longitude,
    String? timezone,
    String? source,
    int? temperature,
    int? feelsLike,
    String? humidity,
    String? wind,
    String? condition,
    bool? isDefault,
    bool? active,
  }) {
    return _WeatherCity(
      country: country ?? this.country,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timezone: timezone ?? this.timezone,
      source: source ?? this.source,
      temperature: temperature ?? this.temperature,
      feelsLike: feelsLike ?? this.feelsLike,
      humidity: humidity ?? this.humidity,
      wind: wind ?? this.wind,
      condition: condition ?? this.condition,
      isDefault: isDefault ?? this.isDefault,
      active: active ?? this.active,
    );
  }
}

enum _WeatherSettingsTab {
  cities('Şehir Yönetimi', Symbols.language),
  preview('Canlı Önizleme', Symbols.visibility);

  const _WeatherSettingsTab(this.title, this.icon);

  final String title;
  final IconData icon;
}
