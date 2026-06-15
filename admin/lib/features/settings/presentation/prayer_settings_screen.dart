import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_module_settings_repository.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminModuleSettingsRepository(),
  });

  final AdminSession session;
  final AdminModuleSettingsRepository repository;

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  var _tab = _PrayerSettingsTab.cities;
  var _settings = PrayerSettingsData.empty('tr');
  PrayerPreviewData? _preview;
  String? _error;
  String? _previewError;
  var _loading = true;
  var _saving = false;
  var _refreshing = false;

  late final TextEditingController _diyanetBaseController;
  late final TextEditingController _locationNameController;
  late final TextEditingController _locationCountryController;
  late final TextEditingController _stateIdController;
  late final TextEditingController _cityIdController;
  late final TextEditingController _timezoneController;
  late final TextEditingController _refreshLeadController;
  late final TextEditingController _cacheDaysController;
  late final TextEditingController _ayahStartController;
  late final TextEditingController _quranBaseController;
  late final TextEditingController _quranTokenController;

  @override
  void initState() {
    super.initState();
    _diyanetBaseController = TextEditingController();
    _locationNameController = TextEditingController();
    _locationCountryController = TextEditingController();
    _stateIdController = TextEditingController();
    _cityIdController = TextEditingController();
    _timezoneController = TextEditingController();
    _refreshLeadController = TextEditingController();
    _cacheDaysController = TextEditingController();
    _ayahStartController = TextEditingController();
    _quranBaseController = TextEditingController();
    _quranTokenController = TextEditingController();
    unawaited(_load());
  }

  @override
  void dispose() {
    _diyanetBaseController.dispose();
    _locationNameController.dispose();
    _locationCountryController.dispose();
    _stateIdController.dispose();
    _cityIdController.dispose();
    _timezoneController.dispose();
    _refreshLeadController.dispose();
    _cacheDaysController.dispose();
    _ayahStartController.dispose();
    _quranBaseController.dispose();
    _quranTokenController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _previewError = null;
    });
    try {
      final settings = await widget.repository.fetchPrayerSettings('tr');
      PrayerPreviewData? preview;
      String? previewError;
      try {
        preview = await widget.repository.fetchPrayerPreview();
      } catch (error) {
        previewError = error.toString();
      }
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _preview = preview;
        _previewError = previewError;
        _applyControllers(settings);
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.savePrayerSettings(
        session: widget.session,
        settings: _settingsFromForm(),
      );
      PrayerPreviewData? preview;
      String? previewError;
      try {
        preview = await widget.repository.fetchPrayerPreview(
          forceRefresh: true,
        );
      } catch (error) {
        previewError = error.toString();
      }
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _preview = preview ?? _preview;
        _previewError = previewError;
        _applyControllers(saved);
        _saving = false;
      });
      _showMessage('Namaz vakitleri ayarları kaydedildi');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Namaz vakitleri ayarları kaydedilemedi: $error');
    }
  }

  Future<void> _refreshPreview() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _previewError = null;
    });
    try {
      final preview = await widget.repository.fetchPrayerPreview(
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _previewError = error.toString();
        _refreshing = false;
      });
    }
  }

  void _applyControllers(PrayerSettingsData settings) {
    _diyanetBaseController.text = settings.diyanetBaseUrl;
    _locationNameController.text = settings.locationName;
    _locationCountryController.text = settings.locationCountry;
    _stateIdController.text = settings.locationStateId.toString();
    _cityIdController.text = settings.locationCityId.toString();
    _timezoneController.text = settings.timezone;
    _refreshLeadController.text = settings.refreshLeadDays.toString();
    _cacheDaysController.text = settings.cacheDays.toString();
    _ayahStartController.text = settings.ayahStartDate;
    _quranBaseController.text = settings.quranApiBaseUrl;
    _quranTokenController.text = settings.quranApiToken;
  }

  PrayerSettingsData _settingsFromForm() {
    return _settings.copyWith(
      diyanetBaseUrl: _diyanetBaseController.text.trim(),
      locationName: _locationNameController.text.trim(),
      locationCountry: _locationCountryController.text.trim(),
      locationStateId: int.tryParse(_stateIdController.text.trim()) ?? 561,
      locationCityId: int.tryParse(_cityIdController.text.trim()) ?? 9766,
      timezone: _timezoneController.text.trim(),
      refreshLeadDays: int.tryParse(_refreshLeadController.text.trim()) ?? 3,
      cacheDays: int.tryParse(_cacheDaysController.text.trim()) ?? 370,
      ayahStartDate: _ayahStartController.text.trim(),
      quranApiBaseUrl: _quranBaseController.text.trim(),
      quranApiToken: _quranTokenController.text.trim(),
    );
  }

  void _showMessage(String message) {
    AdminToast.show(context, message: message, tone: _toastToneFor(message));
  }

  AdminToastTone _toastToneFor(String message) {
    final lower = message.toLowerCase();
    return lower.contains('hata') ||
            lower.contains('edilemedi') ||
            lower.contains('kaydedilemedi')
        ? AdminToastTone.error
        : AdminToastTone.success;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PrayerHeader(),
            const SizedBox(height: 24),
            _PrayerTabs(
              selected: _tab,
              onSelected: (tab) => setState(() => _tab = tab),
            ),
            const SizedBox(height: 22),
            if (_loading)
              const _PrayerLoadingBox()
            else if (_error != null)
              _PrayerErrorBox(message: _error!, onRetry: _load)
            else
              _PrayerCard(
                title: _tab.title,
                icon: _tab.icon,
                trailing: _tab == _PrayerSettingsTab.preview
                    ? _PrimaryActionButton(
                        label: _refreshing ? 'Yenileniyor' : 'Veriyi Yenile',
                        icon: Symbols.send_rounded,
                        onPressed: _refreshing ? null : _refreshPreview,
                      )
                    : null,
                child: _tab == _PrayerSettingsTab.cities
                    ? _PrayerSettingsForm(
                        settings: _settings,
                        saving: _saving,
                        diyanetBaseController: _diyanetBaseController,
                        locationNameController: _locationNameController,
                        locationCountryController: _locationCountryController,
                        stateIdController: _stateIdController,
                        cityIdController: _cityIdController,
                        timezoneController: _timezoneController,
                        refreshLeadController: _refreshLeadController,
                        cacheDaysController: _cacheDaysController,
                        ayahStartController: _ayahStartController,
                        quranBaseController: _quranBaseController,
                        quranTokenController: _quranTokenController,
                        onChanged: (settings) =>
                            setState(() => _settings = settings),
                        onSave: _save,
                      )
                    : _PrayerPreview(
                        preview: _preview,
                        error: _previewError,
                        refreshing: _refreshing,
                        onRefresh: _refreshPreview,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrayerHeader extends StatelessWidget {
  const _PrayerHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Namaz Vakitleri Ayarları',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Mobildeki namaz vakitleri ve günün ayetini Diyanet kaynaklarıyla cache korumalı yönetin.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _PrayerTabs extends StatelessWidget {
  const _PrayerTabs({required this.selected, required this.onSelected});

  final _PrayerSettingsTab selected;
  final ValueChanged<_PrayerSettingsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tab in _PrayerSettingsTab.values)
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
        child: Text(label),
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: Row(
              children: [
                SymbolIcon(icon, color: AppColors.actionRed, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Padding(padding: const EdgeInsets.all(24), child: child),
        ],
      ),
    );
  }
}

class _PrayerSettingsForm extends StatelessWidget {
  const _PrayerSettingsForm({
    required this.settings,
    required this.saving,
    required this.diyanetBaseController,
    required this.locationNameController,
    required this.locationCountryController,
    required this.stateIdController,
    required this.cityIdController,
    required this.timezoneController,
    required this.refreshLeadController,
    required this.cacheDaysController,
    required this.ayahStartController,
    required this.quranBaseController,
    required this.quranTokenController,
    required this.onChanged,
    required this.onSave,
  });

  final PrayerSettingsData settings;
  final bool saving;
  final TextEditingController diyanetBaseController;
  final TextEditingController locationNameController;
  final TextEditingController locationCountryController;
  final TextEditingController stateIdController;
  final TextEditingController cityIdController;
  final TextEditingController timezoneController;
  final TextEditingController refreshLeadController;
  final TextEditingController cacheDaysController;
  final TextEditingController ayahStartController;
  final TextEditingController quranBaseController;
  final TextEditingController quranTokenController;
  final ValueChanged<PrayerSettingsData> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SwitchTile(
          title: 'Namaz Vakitleri Aktif',
          subtitle:
              'Mobilde uygulamalar menüsündeki namaz vakitleri sayfasını canlı veriyle besler.',
          value: settings.enabled,
          onChanged: (value) => onChanged(settings.copyWith(enabled: value)),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            final sourceFields = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Field(
                  label: 'Diyanet kaynak URL',
                  controller: diyanetBaseController,
                ),
                const SizedBox(height: 14),
                _TwoColumn(
                  left: _Field(
                    label: 'Şehir adı',
                    controller: locationNameController,
                  ),
                  right: _Field(
                    label: 'Ülke',
                    controller: locationCountryController,
                  ),
                ),
                const SizedBox(height: 14),
                _ThreeColumn(
                  first: _Field(
                    label: 'Diyanet il ID',
                    controller: stateIdController,
                  ),
                  second: _Field(
                    label: 'Diyanet şehir ID',
                    controller: cityIdController,
                  ),
                  third: _Field(
                    label: 'Zaman dilimi',
                    controller: timezoneController,
                  ),
                ),
              ],
            );
            final cityCard = _PrayerLocationCard(settings: settings);

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [sourceFields, const SizedBox(height: 14), cityCard],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: sourceFields),
                const SizedBox(width: 14),
                Expanded(child: cityCard),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _SectionLabel('Cache ve Otomatik Yenileme'),
        const SizedBox(height: 12),
        _TwoColumn(
          left: _Field(
            label: 'Ay bitmeden yenileme günü',
            controller: refreshLeadController,
          ),
          right: _Field(label: 'Cache günü', controller: cacheDaysController),
        ),
        const SizedBox(height: 18),
        _SwitchTile(
          title: 'Günün Ayeti Aktif',
          subtitle:
              'Her gün sıradaki ayeti Arapça ve Türkçe meal olarak getirir.',
          value: settings.ayahEnabled,
          onChanged: (value) =>
              onChanged(settings.copyWith(ayahEnabled: value)),
        ),
        const SizedBox(height: 12),
        _TwoColumn(
          left: _Field(
            label: 'İlk ayet başlangıç tarihi',
            controller: ayahStartController,
          ),
          right: _Field(
            label: 'Kur’an API base URL',
            controller: quranBaseController,
          ),
        ),
        const SizedBox(height: 12),
        _Field(
          label: 'Diyanet Kur’an API token',
          controller: quranTokenController,
          obscure: true,
        ),
        const SizedBox(height: 24),
        _PrayerSaveRow(saving: saving, onSave: onSave),
      ],
    );
  }
}

class _PrayerLocationCard extends StatelessWidget {
  const _PrayerLocationCard({required this.settings});

  final PrayerSettingsData settings;

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
          Text(
            '${settings.locationCountry} / ${settings.locationName}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _SoftBadge(label: 'Diyanet şehir ID ${settings.locationCityId}'),
              const _SoftBadge(label: 'Public kaynak'),
              _StatusBadge(active: settings.enabled),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const _SoftBadge(label: 'Varsayılan'),
              const Spacer(),
              Text(
                settings.enabled ? 'Aktif' : 'Pasif',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrayerPreview extends StatelessWidget {
  const _PrayerPreview({
    required this.preview,
    required this.error,
    required this.refreshing,
    required this.onRefresh,
  });

  final PrayerPreviewData? preview;
  final String? error;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (error != null && preview == null) {
      return _PrayerErrorBox(message: error!, onRetry: onRefresh);
    }
    final today = preview?.today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          _InlineWarning(message: error!),
          const SizedBox(height: 16),
        ],
        _PreviewHeader(preview: preview),
        const SizedBox(height: 18),
        if (today == null || today.times.isEmpty)
          _InlineWarning(message: 'Canlı vakit listesi henüz alınamadı.')
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final time in today.times)
                _PrayerTimeChip(label: time.name, value: time.time),
            ],
          ),
        const SizedBox(height: 18),
        _AyahPreview(ayah: preview?.dailyAyah),
      ],
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.preview});

  final PrayerPreviewData? preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF12A18C).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: const Icon(
              Symbols.moon_clear_fill,
              color: Color(0xFF12A18C),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview?.location ?? 'Niğde',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  preview?.serviceDateLabel ?? 'Diyanet Namaz Vakitleri',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            preview?.cache.stale == true ? 'Stale cache' : 'Canlı',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: preview?.cache.stale == true
                  ? AppColors.warmHorizon
                  : const Color(0xFF12A18C),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerTimeChip extends StatelessWidget {
  const _PrayerTimeChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AyahPreview extends StatelessWidget {
  const _AyahPreview({required this.ayah});

  final PrayerPreviewAyah? ayah;

  @override
  Widget build(BuildContext context) {
    final hasAyah =
        ayah != null &&
        (ayah!.arabicText.isNotEmpty || ayah!.translation.isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12A18C).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(
          color: const Color(0xFF12A18C).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Günün Ayeti',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasAyah
                ? '${ayah!.surahName} ${ayah!.verseNumber} · ${ayah!.translation}'
                : 'Diyanet Kur’an API tokenı tanımlandığında canlı ayet burada görünür.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w800,
        ),
        filled: true,
        fillColor: AppColors.surface,
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
          borderSide: const BorderSide(color: AppColors.actionRed, width: 1.3),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
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
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
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
          _CompactCheckSwitch(value: value, onChanged: onChanged),
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

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        label,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF2ECC71).withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        active ? 'Aktif' : 'Pasif',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: active ? const Color(0xFF168A45) : AppColors.inkSoft,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(children: [left, const SizedBox(height: 12), right]);
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _ThreeColumn extends StatelessWidget {
  const _ThreeColumn({
    required this.first,
    required this.second,
    required this.third,
  });

  final Widget first;
  final Widget second;
  final Widget third;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 920) {
          return Column(
            children: [
              first,
              const SizedBox(height: 12),
              second,
              const SizedBox(height: 12),
              third,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
            const SizedBox(width: 16),
            Expanded(child: third),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w900,
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
  final VoidCallback? onPressed;

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
              disabledBackgroundColor: AppColors.line,
              disabledForegroundColor: AppColors.inkSoft,
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
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _PrayerSaveRow extends StatelessWidget {
  const _PrayerSaveRow({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 38,
        child: TextButton(
          onPressed: saving ? null : onSave,
          style:
              TextButton.styleFrom(
                backgroundColor: AppColors.actionRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.line,
                disabledForegroundColor: AppColors.inkSoft,
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
              const SymbolIcon(Symbols.check, color: Colors.white, size: 17),
              const SizedBox(width: 8),
              Text(saving ? 'Kaydediliyor' : 'Değişiklikleri Kaydet'),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.22)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PrayerLoadingBox extends StatelessWidget {
  const _PrayerLoadingBox();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 180,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.actionRed,
        ),
      ),
    );
  }
}

class _PrayerErrorBox extends StatelessWidget {
  const _PrayerErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
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
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

enum _PrayerSettingsTab {
  cities('Şehir Yönetimi', Symbols.language),
  preview('Canlı Önizleme', Symbols.visibility);

  const _PrayerSettingsTab(this.title, this.icon);
  final String title;
  final IconData icon;
}
