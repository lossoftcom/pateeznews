import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/core/localization/admin_language_controller.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../data/admin_module_settings_repository.dart';
import '../../auth/data/admin_auth_models.dart';
import 'settings_mobile_chrome.dart';

class MarketSettingsScreen extends StatefulWidget {
  const MarketSettingsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminModuleSettingsRepository(),
  });

  final AdminSession session;
  final AdminModuleSettingsRepository repository;

  @override
  State<MarketSettingsScreen> createState() => _MarketSettingsScreenState();
}

class _MarketSettingsScreenState extends State<MarketSettingsScreen> {
  var _tab = _MarketSettingsTab.settings;
  var _settings = MarketSettingsData.empty('tr');
  MarketPreviewData? _preview;
  var _loading = true;
  var _saving = false;
  var _refreshing = false;
  String? _error;

  late final TextEditingController _apiKeyController;
  late final TextEditingController _altinApiBaseController;
  late final TextEditingController _genelParaBaseController;
  late final TextEditingController _currencySymbolsController;
  late final TextEditingController _goldSymbolsController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _altinApiBaseController = TextEditingController();
    _genelParaBaseController = TextEditingController();
    _currencySymbolsController = TextEditingController();
    _goldSymbolsController = TextEditingController();
    unawaited(_load());
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _altinApiBaseController.dispose();
    _genelParaBaseController.dispose();
    _currencySymbolsController.dispose();
    _goldSymbolsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await widget.repository.fetchMarketSettings('tr');
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _applyControllers(settings);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
      return;
    }
    // Canlı önizleme, ayar formundan BAĞIMSIZ yüklenir: piyasa servisi yavaş ya
    // da erişilemez olsa bile ayarlar düzenlenebilir/kaydedilebilir kalır.
    // Önizleme başarısız olursa yalnızca önizleme sekmesi boş kalır; orada zaten
    // "tekrar dene" sunan hata kutusu var.
    unawaited(_loadPreview());
  }

  Future<void> _loadPreview({bool forceRefresh = false}) async {
    try {
      final preview = await widget.repository.fetchMarketPreview(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (_) {
      // Önizleme alınamadı (servis yavaş/erişilemez). Ayar ekranı bozulmaz;
      // önizleme sekmesi boş kalır ve kullanıcı "Veriyi Yenile" ile tekrar dener.
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final MarketSettingsData saved;
    try {
      saved = await widget.repository.saveMarketSettings(
        session: widget.session,
        settings: _settingsFromForm(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Piyasa ayarları kaydedilemedi: $error');
      return;
    }
    if (!mounted) return;
    setState(() {
      _settings = saved;
      _applyControllers(saved);
      _saving = false;
    });
    _showMessage('Piyasa ayarları kaydedildi');
    // Kaydetme başarılı; canlı önizlemeyi tazelemeyi dene ama önizleme uzak
    // servise bağlı olduğu için takılırsa kaydetmeyi başarısız gösterme.
    unawaited(_loadPreview(forceRefresh: true));
  }

  Future<void> _refreshPreview() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final preview = await widget.repository.fetchMarketPreview(
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _refreshing = false);
      _showMessage('Canlı veri yenilenemedi: $error');
    }
  }

  void _applyControllers(MarketSettingsData settings) {
    _apiKeyController.text = settings.altinApiKey;
    _altinApiBaseController.text = settings.altinApiBaseUrl;
    _genelParaBaseController.text = settings.genelParaBaseUrl;
    _currencySymbolsController.text = settings.currencySymbols.join(',');
    _goldSymbolsController.text = settings.goldSymbols.join(',');
  }

  MarketSettingsData _settingsFromForm() {
    return _settings.copyWith(
      altinApiKey: _apiKeyController.text.trim(),
      altinApiBaseUrl: _altinApiBaseController.text.trim(),
      genelParaBaseUrl: _genelParaBaseController.text.trim(),
      currencySymbols: _splitSymbols(_currencySymbolsController.text),
      goldSymbols: _splitSymbols(_goldSymbolsController.text),
    );
  }

  void _updateSettings(MarketSettingsData settings) {
    setState(() => _settings = settings);
  }

  void _showMessage(String message) {
    AdminToast.show(context, message: message, tone: _toastToneFor(message));
  }

  AdminToastTone _toastToneFor(String message) {
    final lower = message.toLowerCase();
    return lower.contains('hata') ||
            lower.contains('edilemedi') ||
            lower.contains('yenilenemedi') ||
            lower.contains('kaydedilemedi')
        ? AdminToastTone.error
        : AdminToastTone.success;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: settingsPagePadding(
              constraints.maxWidth,
              desktopBottom: 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _MarketHeader(),
                const SizedBox(height: 24),
                _MarketTabs(
                  selected: _tab,
                  onSelected: (tab) => setState(() => _tab = tab),
                ),
                const SizedBox(height: 22),
                if (_loading)
                  const _MarketLoadingBox()
                else if (_error != null)
                  _MarketErrorBox(message: _error!, onRetry: _load)
                else
                  _MarketCard(
                    title: _tab == _MarketSettingsTab.settings
                        ? 'Piyasa Veri Ayarları'
                        : 'Canlı Önizleme',
                    icon: _tab == _MarketSettingsTab.settings
                        ? Symbols.code
                        : Symbols.visibility,
                    trailing: _tab == _MarketSettingsTab.preview
                        ? _PrimaryActionButton(
                            label: _refreshing
                                ? 'Yenileniyor'
                                : 'Veriyi Yenile',
                            icon: Symbols.send_rounded,
                            onPressed: _refreshing ? null : _refreshPreview,
                          )
                        : null,
                    child: _tab == _MarketSettingsTab.settings
                        ? _MarketSettingsForm(
                            settings: _settings,
                            saving: _saving,
                            apiKeyController: _apiKeyController,
                            altinApiBaseController: _altinApiBaseController,
                            genelParaBaseController: _genelParaBaseController,
                            currencySymbolsController:
                                _currencySymbolsController,
                            goldSymbolsController: _goldSymbolsController,
                            onChanged: _updateSettings,
                            onSave: _save,
                          )
                        : _MarketPreview(
                            preview: _preview,
                            refreshing: _refreshing,
                            onRefresh: _refreshPreview,
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MarketHeader extends StatelessWidget {
  const _MarketHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('Döviz & Altın Ayarları'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ön yüzdeki ve mobildeki piyasa kartlarını AltinAPI veya GenelPara üzerinden cache korumalı yönetin.',
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

class _MarketTabs extends StatelessWidget {
  const _MarketTabs({required this.selected, required this.onSelected});

  final _MarketSettingsTab selected;
  final ValueChanged<_MarketSettingsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SettingsResponsiveTabs<_MarketSettingsTab>(
      selected: selected,
      onSelected: onSelected,
      items: [
        for (final tab in _MarketSettingsTab.values)
          SettingsTabItem(value: tab, label: tab.title),
      ],
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({
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
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Row(
              children: [
                SymbolIcon(icon, color: AppColors.actionRed, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                ...?(trailing == null ? null : [trailing!]),
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

class _MarketSettingsForm extends StatelessWidget {
  const _MarketSettingsForm({
    required this.settings,
    required this.saving,
    required this.apiKeyController,
    required this.altinApiBaseController,
    required this.genelParaBaseController,
    required this.currencySymbolsController,
    required this.goldSymbolsController,
    required this.onChanged,
    required this.onSave,
  });

  final MarketSettingsData settings;
  final bool saving;
  final TextEditingController apiKeyController;
  final TextEditingController altinApiBaseController;
  final TextEditingController genelParaBaseController;
  final TextEditingController currencySymbolsController;
  final TextEditingController goldSymbolsController;
  final ValueChanged<MarketSettingsData> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusBox(
          title: 'Döviz & Altın Aktif',
          description:
              'Mobil uygulama ve canlı önizleme cache korumalı piyasa verisi alsın.',
          enabled: settings.enabled,
          onChanged: (value) => onChanged(settings.copyWith(enabled: value)),
        ),
        const SizedBox(height: 18),
        _ProviderBox(
          provider: settings.provider,
          onChanged: (value) => onChanged(settings.copyWith(provider: value)),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 920;
            final fields = [
              _TextFieldBox(
                label: 'AltinAPI Key',
                controller: apiKeyController,
                obscure: true,
                hint: 'hapi_...',
              ),
              _TextFieldBox(
                label: 'AltinAPI Base URL',
                controller: altinApiBaseController,
              ),
              _TextFieldBox(
                label: 'GenelPara Base URL',
                controller: genelParaBaseController,
              ),
              _SelectBox(
                label: 'Cache / Yenileme Aralığı',
                value: settings.updateIntervalSeconds,
                values: const [15, 30, 60, 180, 300, 600],
                onChanged: (value) =>
                    onChanged(settings.copyWith(updateIntervalSeconds: value)),
              ),
              _TextFieldBox(
                label: 'Döviz Sembolleri',
                controller: currencySymbolsController,
                hint: 'USD,EUR,GBP,CHF',
              ),
              _TextFieldBox(
                label: 'Altın Sembolleri',
                controller: goldSymbolsController,
                hint: 'GRAM,CEYREK,YARIM,TAM,ONS,HAS',
              ),
            ];
            if (compact) {
              return Column(
                children: [
                  for (final field in fields) ...[
                    field,
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final field in fields)
                  SizedBox(
                    width: (constraints.maxWidth - 14) / 2,
                    child: field,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _LimitNotice(provider: settings.provider),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: _PrimaryActionButton(
            label: saving ? 'Kaydediliyor' : 'Değişiklikleri Kaydet',
            icon: Symbols.check,
            onPressed: saving ? null : onSave,
          ),
        ),
      ],
    );
  }
}

class _ProviderBox extends StatelessWidget {
  const _ProviderBox({required this.provider, required this.onChanged});

  final String provider;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Veri Sağlayıcı',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                const [
                      _ProviderChoice(value: 'auto', label: 'Otomatik'),
                      _ProviderChoice(value: 'altinapi', label: 'AltinAPI'),
                      _ProviderChoice(value: 'genelpara', label: 'GenelPara'),
                    ]
                    .map(
                      (choice) => _ChoiceChip(
                        label: choice.label,
                        selected: provider == choice.value,
                        onTap: () => onChanged(choice.value),
                      ),
                    )
                    .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _ProviderChoice {
  const _ProviderChoice({required this.value, required this.label});
  final String value;
  final String label;
}

class _MarketPreview extends StatelessWidget {
  const _MarketPreview({
    required this.preview,
    required this.refreshing,
    required this.onRefresh,
  });

  final MarketPreviewData? preview;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final data = preview;
    if (data == null) {
      return _MarketErrorBox(
        message: 'Canlı piyasa verisi henüz alınmadı.',
        onRetry: onRefresh,
      );
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
                    'Canlı Piyasa Önizleme',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${data.source} · ${data.serviceDateLabel} · ${data.updateIntervalSeconds} sn cache',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            _SoftBadge(
              label: refreshing
                  ? 'yenileniyor'
                  : data.cache.hit
                  ? 'cache'
                  : 'canlı',
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            final width = compact
                ? constraints.maxWidth
                : (constraints.maxWidth - 14) / 2;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: width,
                  child: _RateGroupCard(title: 'Döviz', rates: data.currencies),
                ),
                SizedBox(
                  width: width,
                  child: _RateGroupCard(title: 'Altın', rates: data.gold),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RateGroupCard extends StatelessWidget {
  const _RateGroupCard({required this.title, required this.rates});

  final String title;
  final List<MarketPreviewRate> rates;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          if (rates.isEmpty)
            const _EmptyRateBox()
          else ...[
            const _AdminRateHeader(),
            for (var i = 0; i < rates.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.softLine),
              _RatePreviewRow(rate: rates[i]),
            ],
          ],
        ],
      ),
    );
  }
}

class _AdminRateHeader extends StatelessWidget {
  const _AdminRateHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Expanded(flex: 5, child: SizedBox.shrink()),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Expanded(child: _AdminRateHeaderLabel('Alış')),
                const SizedBox(width: 12),
                Expanded(child: _AdminRateHeaderLabel('Satış')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminRateHeaderLabel extends StatelessWidget {
  const _AdminRateHeaderLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _RatePreviewRow extends StatelessWidget {
  const _RatePreviewRow({required this.rate});

  final MarketPreviewRate rate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rate.symbol,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  rate.name,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    height: 1.12,
                  ),
                ),
                if (rate.symbol.toUpperCase() == 'BTC' &&
                    rate.hasSecondaryAsk) ...[
                  const SizedBox(height: 3),
                  Text(
                    'USD ${rate.secondaryCurrencySymbol}${_formatRate(rate.secondaryAsk!)}',
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Expanded(
                  child: _AdminPriceColumn(
                    value: '${rate.currencySymbol}${_formatRate(rate.bid)}',
                    changePercent: rate.changePercent,
                    isUp: rate.isUp,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AdminPriceColumn(
                    value: '${rate.currencySymbol}${_formatRate(rate.ask)}',
                    changePercent: rate.changePercent,
                    isUp: rate.isUp,
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

class _AdminPriceColumn extends StatelessWidget {
  const _AdminPriceColumn({
    required this.value,
    required this.changePercent,
    required this.isUp,
  });

  final String value;
  final double? changePercent;
  final bool isUp;

  @override
  Widget build(BuildContext context) {
    final color = isUp ? const Color(0xFF1FA971) : AppColors.actionRed;
    final percent = changePercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        if (percent != null) ...[
          const SizedBox(height: 4),
          Text(
            '${isUp ? '+' : ''}${percent.toStringAsFixed(2)}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
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
          const SymbolIcon(Symbols.check, color: AppColors.actionRed, size: 20),
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
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: AppColors.actionRed,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _LimitNotice extends StatelessWidget {
  const _LimitNotice({required this.provider});

  final String provider;

  @override
  Widget build(BuildContext context) {
    final text = provider == 'altinapi'
        ? 'AltinAPI REST limitleri planınıza göre uygulanır; cache süresi dolmadan kaynak tekrar çağrılmaz.'
        : provider == 'auto'
        ? 'Otomatik mod AltinAPI key varsa önce AltinAPI kullanır; hata veya key yoksa GenelPara fallback ile devam eder.'
        : 'GenelPara günlük 1000/IP limitlidir; cache aralığı providerı sıkıştırmayacak şekilde korunur.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const SymbolIcon(
            Symbols.info_outline_rounded,
            color: AppColors.actionRed,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextFieldBox extends StatelessWidget {
  const _TextFieldBox({
    required this.label,
    required this.controller,
    this.hint = '',
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
    );
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: values.contains(value) ? value : 180,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text('$item saniye')),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.value),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.deepOcean : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(
            color: selected ? AppColors.deepOcean : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: selected ? Colors.white : AppColors.inkSoft,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
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
              disabledBackgroundColor: AppColors.actionRed.withValues(
                alpha: 0.45,
              ),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
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
            SymbolIcon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 8),
            Text(label),
          ],
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
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MarketLoadingBox extends StatelessWidget {
  const _MarketLoadingBox();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
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

class _MarketErrorBox extends StatelessWidget {
  const _MarketErrorBox({required this.message, required this.onRetry});

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
          TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

class _EmptyRateBox extends StatelessWidget {
  const _EmptyRateBox();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        'Kayıt bulunamadı',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

List<String> _splitSymbols(String value) {
  final result = value
      .split(',')
      .map((item) => item.trim().toUpperCase())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  return result.isEmpty ? const ['USD', 'EUR', 'GBP', 'CHF'] : result;
}

String _formatRate(double value) {
  final digits = value >= 100 ? 2 : 4;
  final fixed = value.toStringAsFixed(digits);
  final parts = fixed.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return parts.length == 1 ? whole : '$whole,${parts.last}';
}

enum _MarketSettingsTab {
  settings('Veri Ayarları'),
  preview('Canlı Önizleme');

  const _MarketSettingsTab(this.title);
  final String title;
}
