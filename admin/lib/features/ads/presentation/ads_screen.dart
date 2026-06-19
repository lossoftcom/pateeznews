import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/data/media_service.dart';
import '../../../shared/widgets/admin_toast.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../data/admin_ads_repository.dart';
import 'widgets/ad_creative_editor.dart';

const _green = Color(0xFF1D9E75);
const _adsTint = Color(0xFFFDECEB);
const _adsInk = Color(0xFFB8281D);
const _localTint = Color(0xFFFEF3E2);
const _localInk = Color(0xFF9A6207);

class AdsScreen extends StatefulWidget {
  const AdsScreen({
    super.key,
    this.repository = const SupabaseAdminAdsRepository(),
    this.mediaService,
  });

  final AdminAdsRepository repository;
  final MediaService? mediaService;

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  AdSettingsData? _data;
  AdPlatform _platform = AdPlatform.web;
  String? _expandedSlotId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.repository.fetchSettings();
      if (!mounted) return;
      setState(() {
        _data = data;
        _expandedSlotId = data.slotsFor(_platform).firstOrNull?.id;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _data = AdSettingsData.seed();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final data = _data;
    if (data == null || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.saveSettings(data);
      if (!mounted) return;
      setState(() {
        _data = saved;
        _saving = false;
      });
      AdminToast.show(
        context,
        message: 'Reklam ayarları kaydedildi',
        tone: AdminToastTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AdminToast.show(
        context,
        message: error.toString(),
        tone: AdminToastTone.error,
      );
    }
  }

  void _mutate(VoidCallback change) => setState(change);

  Future<void> _addCreative(AdSlot slot) async {
    final creative = await showAdCreativeEditor(
      context,
      slot: slot,
      mediaService: widget.mediaService,
    );
    if (creative == null) return;
    _mutate(() {
      slot.creatives.add(creative);
      _expandedSlotId = slot.id;
    });
  }

  Future<void> _editCreative(AdSlot slot, AdCreative creative) async {
    final updated = await showAdCreativeEditor(
      context,
      slot: slot,
      existing: creative,
      mediaService: widget.mediaService,
    );
    if (updated == null) return;
    _mutate(() {
      final index = slot.creatives.indexWhere((c) => c.id == creative.id);
      if (index >= 0) slot.creatives[index] = updated;
    });
  }

  Future<void> _editSlot(AdSlot slot) async {
    final updated = await _showSlotEditor(existing: slot);
    if (updated == null) return;
    _mutate(() {
      final index = _data!.slots.indexWhere((s) => s.id == slot.id);
      if (index >= 0) _data!.slots[index] = updated;
    });
  }

  Future<void> _addSlot() async {
    final slot = await _showSlotEditor();
    if (slot == null) return;
    _mutate(() {
      _data!.slots.add(slot);
      _platform = slot.platform;
      _expandedSlotId = slot.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth < 640 ? 16.0 : 28.0;
        if (_loading || _data == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.actionRed),
          );
        }
        final data = _data!;
        final slots = data.slotsFor(_platform);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, 26, pad, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(data),
              const SizedBox(height: 24),
              _sectionLabel('Reklam servisleri'),
              const SizedBox(height: 12),
              _services(data),
              const SizedBox(height: 26),
              _slotsHeader(data),
              const SizedBox(height: 14),
              if (slots.isEmpty)
                _emptyState()
              else
                for (final slot in slots)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SlotCard(
                      slot: slot,
                      expanded: _expandedSlotId == slot.id,
                      onToggleExpand: () => setState(
                        () => _expandedSlotId = _expandedSlotId == slot.id
                            ? null
                            : slot.id,
                      ),
                      onToggleActive: (v) => _mutate(() => slot.active = v),
                      onAddCreative: () => _addCreative(slot),
                      onEditSlot: () => _editSlot(slot),
                      onEditCreative: (c) => _editCreative(slot, c),
                      onToggleCreative: (c, v) => _mutate(() => c.active = v),
                      onDeleteCreative: (c) => _mutate(
                        () => slot.creatives.removeWhere((x) => x.id == c.id),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(AdSettingsData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titleBlock(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [_masterPill(data), _saveButton()],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _titleBlock()),
            const SizedBox(width: 12),
            _masterPill(data),
            const SizedBox(width: 10),
            _saveButton(),
          ],
        );
      },
    );
  }

  Widget _titleBlock() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.deepOcean,
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: const SymbolIcon(
            Symbols.campaign_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reklamlar',
                style: TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Reklam alanlarını yönet · sınırsız reklam ekle · gerçek boyutta önizle',
                style: TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _saveButton() {
    return FilledButton(
      onPressed: _saving ? null : _save,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.actionRed,
        disabledBackgroundColor: AppColors.actionRed.withValues(alpha: 0.5),
        minimumSize: const Size(120, 46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
      ),
      child: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SymbolIcon(Symbols.check, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Kaydet',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _masterPill(AdSettingsData data) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Reklamlar',
            style: TextStyle(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 10),
          _PzSwitch(
            value: data.masterEnabled,
            onChanged: (v) => setState(() => data.masterEnabled = v),
          ),
          const SizedBox(width: 8),
          Text(
            data.masterEnabled ? 'Açık' : 'Kapalı',
            style: TextStyle(
              color: data.masterEnabled
                  ? AppColors.actionRed
                  : AppColors.placeholder,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w700,
        fontSize: 11.5,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _services(AdSettingsData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 560;
        final adsense = _ServiceCard(
          icon: Symbols.google_fill,
          iconColor: AppColors.actionRed,
          title: 'Google AdSense',
          connected: data.adsenseConnected,
          statusText: data.adsenseConnected ? 'Bağlı' : 'Bağlı değil',
          body: data.adsenseConnected
              ? 'Yayıncı kimliği · ${data.adsensePublisherId}'
              : 'Bağlanmak için yayıncı kimliğini gir',
          chips: const ['Web', 'Mobil'],
          chipTint: const Color(0xFFEEF2F4),
          chipInk: AppColors.deepOcean,
          onEdit: () => _showAdsenseEditor(data),
        );
        final local = _ServiceCard(
          icon: Symbols.add_photo_alternate_outlined,
          iconColor: AppColors.warmHorizon,
          title: 'Yerel Reklam Servisi',
          connected: data.localEnabled,
          statusText: data.localEnabled ? 'Aktif' : 'Kapalı',
          body: 'Kendi reklamların · görsel, GIF, WebP, SVG, HTML kodu',
          chips: const ['Reklamverenler'],
          chipTint: _localTint,
          chipInk: _localInk,
          onEdit: () => setState(() => data.localEnabled = !data.localEnabled),
          editLabel: data.localEnabled ? 'Kapat' : 'Aç',
        );
        if (twoCol) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: adsense),
                const SizedBox(width: 12),
                Expanded(child: local),
              ],
            ),
          );
        }
        return Column(children: [adsense, const SizedBox(height: 12), local]);
      },
    );
  }

  Widget _slotsHeader(AdSettingsData data) {
    final webCount = data.slotsFor(AdPlatform.web).length;
    final mobileCount = data.slotsFor(AdPlatform.mobile).length;
    final segment = _PlatformSegment(
      platform: _platform,
      webCount: webCount,
      mobileCount: mobileCount,
      onChanged: (p) => setState(() {
        _platform = p;
        _expandedSlotId = data.slotsFor(p).firstOrNull?.id;
      }),
    );
    final addButton = OutlinedButton.icon(
      onPressed: _addSlot,
      icon: const SymbolIcon(Symbols.add, color: AppColors.deepOcean, size: 18),
      label: const Text(
        'Yeni reklam alanı',
        style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deepOcean,
        side: const BorderSide(color: AppColors.line),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Reklam alanları'),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: segment,
              ),
              const SizedBox(height: 12),
              addButton,
            ],
          );
        }
        return Row(
          children: [
            _sectionLabel('Reklam alanları'),
            const SizedBox(width: 14),
            segment,
            const Spacer(),
            addButton,
          ],
        );
      },
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          const SymbolIcon(
            Symbols.campaign_outlined,
            color: AppColors.placeholder,
            size: 30,
          ),
          const SizedBox(height: 10),
          const Text(
            'Bu platformda henüz reklam alanı yok',
            style: TextStyle(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _addSlot,
            style:
                OutlinedButton.styleFrom(
                  foregroundColor: AppColors.deepOcean,
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                ).copyWith(
                  mouseCursor: const WidgetStatePropertyAll(
                    SystemMouseCursors.click,
                  ),
                ),
            child: const Text(
              'Reklam alanı ekle',
              style: TextStyle(letterSpacing: 0),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAdsenseEditor(AdSettingsData data) async {
    final result = await showDialog<_AdsenseSettingsResult>(
      context: context,
      builder: (context) => _AdsenseSettingsDialog(data: data),
    );
    if (result != null) {
      setState(() {
        data.adsensePublisherId = result.publisherId;
        data.adsenseConnected = result.connected;
      });
    }
  }

  Future<AdSlot?> _showSlotEditor({AdSlot? existing}) {
    return showDialog<AdSlot>(
      context: context,
      builder: (context) => _SlotEditorDialog(
        existing: existing,
        initialPlatform: existing?.platform ?? _platform,
      ),
    );
  }
}

class _PzSwitch extends StatelessWidget {
  const _PzSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      child: MouseRegion(
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
      ),
    );
  }
}

class _AdsenseSettingsResult {
  const _AdsenseSettingsResult({
    required this.publisherId,
    required this.connected,
  });

  final String publisherId;
  final bool connected;
}

class _AdsenseSettingsDialog extends StatefulWidget {
  const _AdsenseSettingsDialog({required this.data});

  final AdSettingsData data;

  @override
  State<_AdsenseSettingsDialog> createState() => _AdsenseSettingsDialogState();
}

class _AdsenseSettingsDialogState extends State<_AdsenseSettingsDialog> {
  late final TextEditingController _publisherController;
  late bool _connected;

  @override
  void initState() {
    super.initState();
    _publisherController = TextEditingController(
      text: widget.data.adsensePublisherId,
    )..addListener(_refreshSnippet);
    _connected = widget.data.adsenseConnected;
  }

  @override
  void dispose() {
    _publisherController.removeListener(_refreshSnippet);
    _publisherController.dispose();
    super.dispose();
  }

  void _refreshSnippet() {
    setState(() {});
  }

  String get _publisherId => _publisherController.text.trim();

  String get _adsenseCode {
    final publisherId = _publisherId.isEmpty
        ? 'ca-pub-XXXXXXXXXXXXXXXX'
        : _publisherId;
    return '<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$publisherId" crossorigin="anonymous"></script>';
  }

  void _save() {
    Navigator.of(context).pop(
      _AdsenseSettingsResult(publisherId: _publisherId, connected: _connected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 540, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 18, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SymbolIcon(
                    Symbols.google_fill,
                    color: AppColors.actionRed,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google AdSense',
                          style: TextStyle(
                            color: AppColors.deepOcean,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: 0,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Pateez.com yayıncı ve site kodu ayarları',
                          style: TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 12,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    mouseCursor: SystemMouseCursors.click,
                    visualDensity: VisualDensity.compact,
                    icon: const SymbolIcon(
                      Symbols.close,
                      color: AppColors.inkSoft,
                      size: 18,
                    ),
                    tooltip: 'Kapat',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _publisherController,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Yayıncı kimliği',
                        hintText: 'ca-pub-XXXXXXXXXXXXXXXX',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: 12, right: 8),
                          child: SymbolIcon(
                            Symbols.verified_outlined,
                            color: AppColors.iconMuted,
                            size: 18,
                          ),
                        ),
                        prefixIconConstraints: BoxConstraints(
                          minWidth: 38,
                          minHeight: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.value),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AdSense bağlı',
                                  style: TextStyle(
                                    color: AppColors.deepOcean,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Hesap bağlıysa reklam alanlarında AdSense kreatifleri aktif kalır.',
                                  style: TextStyle(
                                    color: AppColors.inkSoft,
                                    fontSize: 11.5,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _PzSwitch(
                            value: _connected,
                            onChanged: (value) {
                              setState(() => _connected = value);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Site kodu',
                      style: TextStyle(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.softLine,
                        borderRadius: BorderRadius.circular(AppRadius.value),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SymbolIcon(
                            Symbols.code_outlined,
                            color: AppColors.iconMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SelectableText(
                              _adsenseCode,
                              style: const TextStyle(
                                color: AppColors.deepOcean,
                                fontSize: 11,
                                height: 1.35,
                                letterSpacing: 0,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogTextButton(
                    label: 'İptal',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  _DialogPrimaryButton(label: 'Kaydet', onPressed: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.connected,
    required this.statusText,
    required this.body,
    required this.chips,
    required this.chipTint,
    required this.chipInk,
    required this.onEdit,
    this.editLabel = 'Düzenle',
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final bool connected;
  final String statusText;
  final String body;
  final List<String> chips;
  final Color chipTint;
  final Color chipInk;
  final VoidCallback onEdit;
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SymbolIcon(icon, color: iconColor, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _statusBadge(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final chip in chips) ...[
                _chip(chip),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              OutlinedButton(
                onPressed: onEdit,
                style:
                    OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepOcean,
                      side: const BorderSide(color: AppColors.line),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.value),
                      ),
                    ).copyWith(
                      mouseCursor: const WidgetStatePropertyAll(
                        SystemMouseCursors.click,
                      ),
                    ),
                child: Text(
                  editLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: connected ? const Color(0xFFE4F5EE) : AppColors.softLine,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: connected ? _green : AppColors.placeholder,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            statusText,
            style: TextStyle(
              color: connected ? const Color(0xFF0F6E56) : AppColors.inkSoft,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipTint,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: chipInk,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PlatformSegment extends StatelessWidget {
  const _PlatformSegment({
    required this.platform,
    required this.webCount,
    required this.mobileCount,
    required this.onChanged,
  });

  final AdPlatform platform;
  final int webCount;
  final int mobileCount;
  final ValueChanged<AdPlatform> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.softLine,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segButton(
            'Web sitesi',
            Symbols.desktop_mac_outlined,
            webCount,
            platform == AdPlatform.web,
            () => onChanged(AdPlatform.web),
          ),
          const SizedBox(width: 3),
          _segButton(
            'Mobil uygulama',
            Symbols.phone_iphone_outlined,
            mobileCount,
            platform == AdPlatform.mobile,
            () => onChanged(AdPlatform.mobile),
          ),
        ],
      ),
    );
  }

  Widget _segButton(
    String label,
    IconData icon,
    int count,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(AppRadius.value),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(
              icon,
              color: selected ? AppColors.deepOcean : AppColors.inkSoft,
              size: 17,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.deepOcean : AppColors.inkSoft,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFEEF2F4) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? AppColors.deepOcean : AppColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.expanded,
    required this.onToggleExpand,
    required this.onToggleActive,
    required this.onAddCreative,
    required this.onEditSlot,
    required this.onEditCreative,
    required this.onToggleCreative,
    required this.onDeleteCreative,
  });

  final AdSlot slot;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onAddCreative;
  final VoidCallback onEditSlot;
  final ValueChanged<AdCreative> onEditCreative;
  final void Function(AdCreative, bool) onToggleCreative;
  final ValueChanged<AdCreative> onDeleteCreative;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          InkWell(
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(AppRadius.value),
            onTap: onToggleExpand,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.value),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: SymbolIcon(
                      _slotIcon(slot),
                      color: AppColors.deepOcean,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            letterSpacing: 0,
                          ),
                        ),
                        Text(
                          slot.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 11.5,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _sizeBadge(),
                  const SizedBox(width: 10),
                  Text(
                    '${slot.creatives.length} reklam',
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _PzSwitch(value: slot.active, onChanged: onToggleActive),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const SymbolIcon(
                      Symbols.keyboard_arrow_down,
                      color: AppColors.placeholder,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.topCenter,
            child: expanded ? _rotation(context) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _rotation(BuildContext context) {
    final total = slot.creatives.fold<int>(0, (sum, c) => sum + c.weight);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dönüşümdeki reklamlar — ağırlığa göre otomatik gösterilir',
                  style: TextStyle(
                    color: AppColors.placeholder,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onEditSlot,
                icon: const SymbolIcon(
                  Symbols.edit_outlined,
                  color: AppColors.inkSoft,
                  size: 16,
                ),
                label: const Text(
                  'Alanı düzenle',
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (slot.creatives.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: const Text(
                'Henüz reklam yok — aşağıdan ekle',
                style: TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 12.5,
                  letterSpacing: 0,
                ),
              ),
            )
          else
            for (final creative in slot.creatives)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CreativeRow(
                  creative: creative,
                  percent: total > 0
                      ? (creative.weight / total * 100).round()
                      : 0,
                  onEdit: () => onEditCreative(creative),
                  onToggle: (v) => onToggleCreative(creative, v),
                  onDelete: () => onDeleteCreative(creative),
                ),
              ),
          const SizedBox(height: 2),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth < 390
                  ? constraints.maxWidth
                  : 390.0;
              return Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: width,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onAddCreative,
                    icon: const SymbolIcon(
                      Symbols.add,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Bu alana reklam ekle',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.deepOcean,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.value),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sizeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F4),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        slot.sizeLabel,
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0,
        ),
      ),
    );
  }

  IconData _slotIcon(AdSlot slot) {
    if (slot.fullscreen) return Symbols.crop_square_outlined;
    if (slot.platform == AdPlatform.mobile) {
      return Symbols.phone_iphone_outlined;
    }
    if (slot.height >= slot.width && slot.width > 0) {
      return Symbols.view_column_outlined;
    }
    return Symbols.desktop_mac_outlined;
  }
}

class _CreativeRow extends StatelessWidget {
  const _CreativeRow({
    required this.creative,
    required this.percent,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final AdCreative creative;
  final int percent;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _thumb(),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creative.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  '${creative.typeLabel} · ${creative.sizeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _typeBadge(),
          const SizedBox(width: 10),
          Text(
            '%$percent',
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onEdit,
            mouseCursor: SystemMouseCursors.click,
            visualDensity: VisualDensity.compact,
            tooltip: 'Düzenle',
            icon: const SymbolIcon(
              Symbols.edit_outlined,
              color: AppColors.iconMuted,
              size: 17,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            mouseCursor: SystemMouseCursors.click,
            visualDensity: VisualDensity.compact,
            tooltip: 'Sil',
            icon: const SymbolIcon(
              Symbols.delete_outline,
              color: AppColors.iconMuted,
              size: 17,
            ),
          ),
          _PzSwitch(value: creative.active, onChanged: onToggle),
        ],
      ),
    );
  }

  Widget _thumb() {
    if (creative.type == AdCreativeType.adsense) {
      return Container(
        width: 60,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _adsTint,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFFE9A59F)),
        ),
        child: const Text(
          'Google\nAds',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _adsInk,
            fontWeight: FontWeight.w700,
            fontSize: 9,
            height: 1.1,
            letterSpacing: 0,
          ),
        ),
      );
    }
    if (creative.type == AdCreativeType.image &&
        creative.imageUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.network(
          creative.imageUrl,
          width: 60,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initialsThumb(),
        ),
      );
    }
    return _initialsThumb();
  }

  Widget _initialsThumb() {
    final color = creative.accentColor != null
        ? Color(creative.accentColor!)
        : AppColors.support;
    final label = creative.type == AdCreativeType.html ? 'HTML' : 'GÖRSEL';
    return Container(
      width: 60,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 9,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _typeBadge() {
    final isAds = creative.type == AdCreativeType.adsense;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAds ? _adsTint : _localTint,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        isAds ? 'AdSense' : 'Yerel',
        style: TextStyle(
          color: isAds ? _adsInk : _localInk,
          fontWeight: FontWeight.w600,
          fontSize: 10.5,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SlotEditorDialog extends StatefulWidget {
  const _SlotEditorDialog({
    required this.existing,
    required this.initialPlatform,
  });

  final AdSlot? existing;
  final AdPlatform initialPlatform;

  @override
  State<_SlotEditorDialog> createState() => _SlotEditorDialogState();
}

class _SlotEditorDialogState extends State<_SlotEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late AdPlatform _platform;
  late AdSize _size;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _descCtrl = TextEditingController(text: existing?.description ?? '');
    _platform = existing?.platform ?? widget.initialPlatform;
    _size = _matchSize(existing) ?? AdSize.forPlatform(_platform).first;
  }

  AdSize? _matchSize(AdSlot? slot) {
    if (slot == null) return null;
    for (final size in AdSize.forPlatform(slot.platform)) {
      if (slot.responsive && size.responsive) return size;
      if (slot.fullscreen && size.fullscreen) return size;
      if (!slot.responsive &&
          !slot.fullscreen &&
          size.width == slot.width &&
          size.height == slot.height) {
        return size;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AdminToast.show(
        context,
        message: 'Lütfen bir alan adı girin.',
        tone: AdminToastTone.error,
      );
      return;
    }
    final existing = widget.existing;
    final slot = AdSlot(
      id: existing?.id ?? generateAdId('slot'),
      key: existing?.key ?? _slugify(name, _platform),
      name: name,
      description: _descCtrl.text.trim(),
      platform: _platform,
      width: _size.width,
      height: _size.height,
      responsive: _size.responsive,
      fullscreen: _size.fullscreen,
      active: existing?.active ?? true,
      creatives: existing?.creatives ?? <AdCreative>[],
    );
    Navigator.of(context).pop(slot);
  }

  @override
  Widget build(BuildContext context) {
    final sizes = AdSize.forPlatform(_platform);
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      title: Text(
        widget.existing == null
            ? 'Yeni reklam alanı'
            : 'Reklam alanını düzenle',
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w700,
          fontSize: 17,
          letterSpacing: 0,
        ),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 13,
                letterSpacing: 0,
              ),
              decoration: const InputDecoration(
                labelText: 'Alan adı',
                hintText: 'örn. Anasayfa — Üst Banner',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 13,
                letterSpacing: 0,
              ),
              decoration: const InputDecoration(
                labelText: 'Açıklama (opsiyonel)',
                hintText: 'örn. Manşetin üstü',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Platform',
              style: TextStyle(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _platformChip('Web sitesi', AdPlatform.web),
                const SizedBox(width: 8),
                _platformChip('Mobil uygulama', AdPlatform.mobile),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Boyut',
              style: TextStyle(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(color: AppColors.line),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AdSize>(
                  value: sizes.contains(_size) ? _size : sizes.first,
                  isExpanded: true,
                  mouseCursor: SystemMouseCursors.click,
                  dropdownMenuItemMouseCursor: SystemMouseCursors.click,
                  icon: const SymbolIcon(
                    Symbols.keyboard_arrow_down,
                    color: AppColors.iconMuted,
                    size: 18,
                  ),
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 13,
                    letterSpacing: 0,
                  ),
                  items: [
                    for (final size in sizes)
                      DropdownMenuItem(
                        value: size,
                        child: Text(
                          '${size.dimensionLabel} · ${size.label}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _size = value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        _DialogTextButton(
          label: 'İptal',
          onPressed: () => Navigator.of(context).pop(),
        ),
        _DialogPrimaryButton(label: 'Kaydet', onPressed: _submit),
      ],
    );
  }

  Widget _platformChip(String label, AdPlatform platform) {
    final selected = _platform == platform;
    return Expanded(
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(AppRadius.value),
        onTap: () => setState(() {
          _platform = platform;
          _size = AdSize.forPlatform(platform).first;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.deepOcean : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected ? AppColors.deepOcean : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogTextButton extends StatelessWidget {
  const _DialogTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style:
          TextButton.styleFrom(
            foregroundColor: AppColors.deepOcean,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(64, 38),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ).copyWith(
            mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
          ),
      child: Text(label),
    );
  }
}

class _DialogPrimaryButton extends StatelessWidget {
  const _DialogPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.deepOcean,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              minimumSize: const Size(104, 38),
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

String _slugify(String name, AdPlatform platform) {
  final base = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final prefix = platform == AdPlatform.mobile ? 'mobile' : 'web';
  return '${prefix}_${base.isEmpty ? 'slot' : base}';
}
