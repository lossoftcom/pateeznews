import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/admin_cached_image.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../../news/data/admin_news_repository.dart';
import '../../news/presentation/news_models.dart';
import '../data/admin_module_settings_repository.dart';

const _announcementDistrictLabels = {
  'merkez': 'Merkez',
  'altunhisar': 'Altunhisar',
  'bor': 'Bor',
  'camardi': 'Çamardı',
  'ciftlik': 'Çiftlik',
  'ulukisla': 'Ulukışla',
};

class AnnouncementsSettingsScreen extends StatefulWidget {
  const AnnouncementsSettingsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminModuleSettingsRepository(),
    this.newsRepository = const SupabaseAdminNewsRepository(),
  });

  final AdminSession session;
  final AdminModuleSettingsRepository repository;
  final AdminNewsRepository newsRepository;

  @override
  State<AnnouncementsSettingsScreen> createState() =>
      _AnnouncementsSettingsScreenState();
}

class _AnnouncementsSettingsScreenState
    extends State<AnnouncementsSettingsScreen> {
  var _tab = _AnnouncementsTab.sources;
  var _loading = true;
  var _saving = false;
  var _refreshing = false;
  String? _error;
  List<AnnouncementSourceData> _sources = const [];
  List<AnnouncementRunData> _runs = const [];
  AnnouncementPreviewData _preview = const AnnouncementPreviewData.empty();
  AnnouncementRefreshResult? _lastRefresh;
  final Set<String> _selectedAnnouncementIds = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sourcesFuture = widget.repository.fetchAnnouncementSources();
      final runsFuture = widget.repository.fetchAnnouncementRuns();
      final previewFuture = widget.repository
          .fetchAnnouncementPreview()
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => const AnnouncementPreviewData.empty(),
          )
          .catchError((_) => const AnnouncementPreviewData.empty());
      final sources = await sourcesFuture;
      final runs = await runsFuture;
      final preview = await previewFuture;
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _preview = preview;
        _runs = runs;
        _loading = false;
        _selectedAnnouncementIds.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _lastRefresh = null;
    });
    try {
      final result = await widget.repository.refreshAnnouncements(
        session: widget.session,
      );
      final sources = await widget.repository.fetchAnnouncementSources();
      final preview = await widget.repository.fetchAnnouncementPreview();
      final runs = await widget.repository.fetchAnnouncementRuns();
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _sources = sources;
        _runs = runs;
        _lastRefresh = result;
        _refreshing = false;
        _selectedAnnouncementIds.clear();
      });
      _showMessage('Duyuru taraması tamamlandı');
    } catch (error) {
      if (!mounted) return;
      setState(() => _refreshing = false);
      _showMessage('Duyurular yenilenemedi: $error');
    }
  }

  Future<void> _openSourceDialog([AnnouncementSourceData? source]) async {
    final result = await showDialog<AnnouncementSourceData>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (context) => _SourceDialog(source: source),
    );
    if (!mounted || result == null) return;

    setState(() => _saving = true);
    try {
      await widget.repository.saveAnnouncementSource(
        session: widget.session,
        source: result,
      );
      final sources = await widget.repository.fetchAnnouncementSources();
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _saving = false;
      });
      _showMessage('Duyuru kaynağı kaydedildi');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Duyuru kaynağı kaydedilemedi: $error');
    }
  }

  Future<void> _deleteSource(AnnouncementSourceData source) async {
    if (source.id.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.repository.deleteAnnouncementSource(
        session: widget.session,
        id: source.id,
      );
      final sources = await widget.repository.fetchAnnouncementSources();
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _saving = false;
      });
      _showMessage('Duyuru kaynağı silindi');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Duyuru kaynağı silinemedi: $error');
    }
  }

  Future<void> _openAnnouncementDialog(AnnouncementPreviewItem item) async {
    final result = await showDialog<AnnouncementPreviewItem>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (context) => _AnnouncementDialog(
        item: item,
        newsRepository: widget.newsRepository,
      ),
    );
    if (!mounted || result == null) return;

    setState(() => _saving = true);
    try {
      final saved = await widget.repository.saveAnnouncement(
        session: widget.session,
        announcement: result,
      );
      final items = [
        for (final existing in _preview.announcements)
          if (existing.id == saved.id) saved else existing,
      ];
      if (!mounted) return;
      setState(() {
        _preview = _preview.copyWith(announcements: items);
        _selectedAnnouncementIds.remove(item.id);
        _saving = false;
      });
      _showMessage('Duyuru güncellendi');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Duyuru güncellenemedi: $error');
    }
  }

  Future<void> _setAnnouncementActive(
    AnnouncementPreviewItem item,
    bool isActive,
  ) async {
    if (item.id.isEmpty) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.setAnnouncementActive(
        session: widget.session,
        id: item.id,
        isActive: isActive,
      );
      final items = [
        for (final existing in _preview.announcements)
          if (existing.id == saved.id) saved else existing,
      ];
      if (!mounted) return;
      setState(() {
        _preview = _preview.copyWith(announcements: items);
        _saving = false;
      });
      _showMessage(
        isActive ? 'Duyuru yayına alındı' : 'Duyuru yayından kaldırıldı',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Duyuru durumu güncellenemedi: $error');
    }
  }

  Future<void> _deleteAnnouncement(AnnouncementPreviewItem item) async {
    if (item.id.isEmpty) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: 'Duyuruyu sil',
      message:
          '"${item.title}" duyurusu kalıcı olarak silinecek. Devam edilsin mi?',
      confirmLabel: 'Sil',
      danger: true,
    );
    if (!mounted || confirmed != true) return;
    setState(() => _saving = true);
    try {
      await widget.repository.deleteAnnouncement(
        session: widget.session,
        id: item.id,
      );
      final items = _preview.announcements
          .where((existing) => existing.id != item.id)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _preview = _preview.copyWith(announcements: items);
        _selectedAnnouncementIds.remove(item.id);
        _saving = false;
      });
      _showMessage('Duyuru silindi');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Duyuru silinemedi: $error');
    }
  }

  void _toggleAnnouncementSelection(String id, bool selected) {
    if (id.isEmpty) return;
    setState(() {
      if (selected) {
        _selectedAnnouncementIds.add(id);
      } else {
        _selectedAnnouncementIds.remove(id);
      }
    });
  }

  Future<void> _deleteSelectedAnnouncements() async {
    if (_selectedAnnouncementIds.isEmpty) return;
    final selectedIds = _selectedAnnouncementIds.toList(growable: false);
    final confirmed = await showAppConfirmationDialog(
      context,
      title: 'Seçili duyuruları sil',
      message:
          'Seçilen ${selectedIds.length} duyuru kalıcı olarak silinecek. Devam edilsin mi?',
      confirmLabel: 'Sil',
      danger: true,
    );
    if (!mounted || !confirmed) return;
    setState(() => _saving = true);
    try {
      await widget.repository.deleteAnnouncements(
        session: widget.session,
        ids: selectedIds,
      );
      final announcements = await widget.repository.fetchAnnouncementPreview();
      if (!mounted) return;
      setState(() {
        _preview = _preview.copyWith(
          announcements: announcements.announcements,
        );
        _selectedAnnouncementIds.clear();
        _saving = false;
      });
      _showMessage('Seçilen duyurular silindi');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Seçili duyurular silinemedi: $error');
    }
  }

  Widget _announcementTabTrailing() {
    if (_selectedAnnouncementIds.isEmpty) {
      return _PrimaryButton(
        label: _refreshing ? 'Taranıyor' : 'Veriyi Yenile',
        icon: Symbols.schedule_send,
        enabled: !_refreshing,
        onPressed: _refresh,
      );
    }

    return Wrap(
      spacing: 10,
      children: [
        Text(
          '${_selectedAnnouncementIds.length} öğe seçildi',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        _OutlineButton(
          label: 'Seçimi Kaldır',
          icon: Symbols.close,
          onPressed: () => setState(() => _selectedAnnouncementIds.clear()),
        ),
        _PrimaryButton(
          label: 'Seçilenleri Sil',
          icon: Symbols.delete,
          enabled: !_saving && !_refreshing,
          onPressed: _deleteSelectedAnnouncements,
        ),
      ],
    );
  }

  void _showMessage(String message) {
    AdminToast.show(context, message: message, tone: _toastToneFor(message));
  }

  AdminToastTone _toastToneFor(String message) {
    final lower = message.toLowerCase();
    return lower.contains('hata') ||
            lower.contains('edilemedi') ||
            lower.contains('yenilenemedi') ||
            lower.contains('silinemedi') ||
            lower.contains('güncellenemedi') ||
            lower.contains('kaydedilemedi')
        ? AdminToastTone.error
        : AdminToastTone.success;
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
              const _PageHeader(),
              const SizedBox(height: 22),
              _Tabs(
                selected: _tab,
                onSelected: (tab) => setState(() => _tab = tab),
              ),
              const SizedBox(height: 22),
              if (_loading)
                const _StateBox(label: 'Duyuru ayarları yükleniyor...')
              else if (_error != null)
                _ErrorBox(message: _error!, onRetry: _load)
              else
                _SettingsCard(
                  title: _tab.title,
                  icon: _tab.icon,
                  trailing: switch (_tab) {
                    _AnnouncementsTab.sources => _PrimaryButton(
                      label: 'Kaynak Ekle',
                      icon: Symbols.add,
                      enabled: !_saving,
                      onPressed: () => _openSourceDialog(),
                    ),
                    _AnnouncementsTab.preview => _announcementTabTrailing(),
                    _AnnouncementsTab.runs => _OutlineButton(
                      label: 'Yenile',
                      icon: Symbols.refresh_line,
                      enabled: !_saving && !_refreshing,
                      onPressed: _load,
                    ),
                  },
                  child: switch (_tab) {
                    _AnnouncementsTab.sources => _SourcesPanel(
                      sources: _sources,
                      saving: _saving,
                      onEdit: _openSourceDialog,
                      onDelete: _deleteSource,
                    ),
                    _AnnouncementsTab.preview => _PreviewPanel(
                      preview: _preview,
                      refreshing: _refreshing,
                      lastRefresh: _lastRefresh,
                      onEdit: _openAnnouncementDialog,
                      onSetActive: _setAnnouncementActive,
                      onDelete: _deleteAnnouncement,
                      selectedIds: _selectedAnnouncementIds,
                      onToggleSelection: _toggleAnnouncementSelection,
                    ),
                    _AnnouncementsTab.runs => _RunsPanel(runs: _runs),
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _AnnouncementsTab {
  sources('Kaynak Yönetimi', Symbols.language),
  preview('Canlı Önizleme', Symbols.visibility),
  runs('Çalışma Kayıtları', Symbols.schedule);

  const _AnnouncementsTab(this.title, this.icon);

  final String title;
  final IconData icon;
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duyuru Ayarları',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Niğde kurum, STK, oda, sendika ve açık sosyal sayfa duyurularını yönetin.',
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

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelected});

  final _AnnouncementsTab selected;
  final ValueChanged<_AnnouncementsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tab in _AnnouncementsTab.values)
          SizedBox(
            height: 38,
            child: TextButton(
              onPressed: () => onSelected(tab),
              style: TextButton.styleFrom(
                backgroundColor: selected == tab
                    ? AppColors.actionRed
                    : Colors.white,
                foregroundColor: selected == tab
                    ? Colors.white
                    : AppColors.deepOcean,
                side: BorderSide(
                  color: selected == tab
                      ? AppColors.actionRed
                      : AppColors.line.withValues(alpha: 0.88),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              child: Text(tab.title),
            ),
          ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget trailing;

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
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                trailing,
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

class _SourcesPanel extends StatelessWidget {
  const _SourcesPanel({
    required this.sources,
    required this.saving,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AnnouncementSourceData> sources;
  final bool saving;
  final ValueChanged<AnnouncementSourceData> onEdit;
  final ValueChanged<AnnouncementSourceData> onDelete;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return const _StateBox(label: 'Henüz duyuru kaynağı yok.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoStrip(
          title: 'Tarama kuralı',
          description:
              'Açık web sayfaları, RSS/sitemap ve public sosyal sayfa HTML’i taranır; sosyal medya API kullanılmaz.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final source in sources)
              SizedBox(
                width: 520,
                child: _SourceCard(
                  source: source,
                  saving: saving,
                  onEdit: () => onEdit(source),
                  onDelete: () => onDelete(source),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.saving,
    required this.onEdit,
    required this.onDelete,
  });

  final AnnouncementSourceData source;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                      source.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SoftBadge(label: source.sourceType),
                        _SoftBadge(label: source.categoryHint),
                        _SoftBadge(
                          label:
                              _announcementDistrictLabels[source.district] ??
                              'Merkez',
                        ),
                        _StatusBadge(active: source.isActive),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _IconButton(
                tooltip: 'Kaynağı düzenle',
                icon: Symbols.edit_square,
                color: AppColors.deepOcean,
                onTap: saving ? null : onEdit,
              ),
              const SizedBox(width: 6),
              _IconButton(
                tooltip: 'Kaynağı sil',
                icon: Symbols.delete,
                color: AppColors.actionRed,
                onTap: saving ? null : onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _UrlLine(label: 'Liste', value: source.listUrl),
          if (source.websiteUrl.isNotEmpty) ...[
            const SizedBox(height: 6),
            _UrlLine(label: 'Site', value: source.websiteUrl),
          ],
          if (source.socialUrl.isNotEmpty) ...[
            const SizedBox(height: 6),
            _UrlLine(label: 'Sosyal', value: source.socialUrl),
          ],
          if (source.facebookUrl.isNotEmpty) ...[
            const SizedBox(height: 6),
            _UrlLine(label: 'Facebook', value: source.facebookUrl),
          ],
          if (source.instagramUrl.isNotEmpty) ...[
            const SizedBox(height: 6),
            _UrlLine(label: 'Instagram', value: source.instagramUrl),
          ],
          const SizedBox(height: 12),
          Text(
            'Her ${source.crawlIntervalMinutes} dk · ${source.lastSuccessAt.isEmpty ? 'Henüz başarılı tarama yok' : source.lastSuccessAt}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          if (source.lastError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              source.lastError,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.actionRed,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatefulWidget {
  const _PreviewPanel({
    required this.preview,
    required this.refreshing,
    required this.lastRefresh,
    required this.onEdit,
    required this.onSetActive,
    required this.onDelete,
    required this.selectedIds,
    required this.onToggleSelection,
  });

  final AnnouncementPreviewData preview;
  final bool refreshing;
  final AnnouncementRefreshResult? lastRefresh;
  final ValueChanged<AnnouncementPreviewItem> onEdit;
  final void Function(AnnouncementPreviewItem item, bool isActive) onSetActive;
  final ValueChanged<AnnouncementPreviewItem> onDelete;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onToggleSelection;

  @override
  State<_PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<_PreviewPanel> {
  var _district = 'all';
  final _search = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filteredAnnouncements();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricPill(
              label: 'Toplam',
              value: widget.preview.total.toString(),
            ),
            _MetricPill(
              label: 'Resmî',
              value: widget.preview.officialCount.toString(),
            ),
            _MetricPill(
              label: 'Elektrik',
              value: widget.preview.powerCount.toString(),
            ),
            _MetricPill(
              label: 'Yol',
              value: widget.preview.roadCount.toString(),
            ),
            _MetricPill(
              label: 'Kaynak',
              value: widget.preview.activeSources.toString(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _AnnouncementFilters(
          controller: _search,
          fromDate: _fromDate,
          toDate: _toDate,
          onChanged: () => setState(() {}),
          onPickFrom: () => _pickDate(isStart: true),
          onPickTo: () => _pickDate(isStart: false),
          onClearDates: () => setState(() {
            _fromDate = null;
            _toDate = null;
          }),
        ),
        const SizedBox(height: 12),
        _AdminDistrictTabs(
          selected: _district,
          countFor: (district) => district == 'all'
              ? widget.preview.announcements
                    .where((item) => item.isActive)
                    .length
              : widget.preview.announcements
                    .where((item) => item.district == district && item.isActive)
                    .length,
          onSelected: (district) => setState(() => _district = district),
        ),
        if (widget.lastRefresh != null) ...[
          const SizedBox(height: 14),
          _InfoStrip(
            title: 'Son manuel tarama',
            description:
                '${widget.lastRefresh!.sourcesChecked} kaynak · ${widget.lastRefresh!.candidatesFound} aday · ${widget.lastRefresh!.insertedCount} yeni · ${widget.lastRefresh!.updatedCount} güncel',
          ),
        ],
        const SizedBox(height: 16),
        if (widget.refreshing)
          const _StateBox(label: 'Kaynaklar taranıyor...')
        else if (widget.preview.announcements.isEmpty)
          const _StateBox(label: 'Henüz canlı duyuru yok.')
        else if (visible.isEmpty)
          const _StateBox(label: 'Filtreye uygun duyuru yok.')
        else
          Column(
            children: [
              for (final item in visible.take(120))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PreviewAnnouncement(
                    item: item,
                    isSelected: widget.selectedIds.contains(item.id),
                    onEdit: widget.onEdit,
                    onSetActive: widget.onSetActive,
                    onDelete: widget.onDelete,
                    onToggleSelection: widget.onToggleSelection,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  List<AnnouncementPreviewItem> _filteredAnnouncements() {
    final query = _search.text.trim().toLowerCase();
    final from = _fromDate == null
        ? null
        : DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final to = _toDate == null
        ? null
        : DateTime(_toDate!.year, _toDate!.month, _toDate!.day + 1);
    return widget.preview.announcements
        .where((item) {
          if (_district != 'all' && item.district != _district) return false;
          if (query.isNotEmpty) {
            final haystack =
                '${item.source} ${item.title} ${item.summary} ${item.body} ${item.place} ${item.sourceUrl}'
                    .toLowerCase();
            if (!haystack.contains(query)) return false;
          }
          final date = _announcementDate(item);
          if (from != null && date != null && date.isBefore(from)) return false;
          if (to != null && date != null && !date.isBefore(to)) return false;
          return true;
        })
        .toList(growable: false);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? _fromDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_fromDate != null && _fromDate!.isAfter(picked)) _fromDate = picked;
      }
    });
  }
}

class _AnnouncementFilters extends StatelessWidget {
  const _AnnouncementFilters({
    required this.controller,
    required this.fromDate,
    required this.toDate,
    required this.onChanged,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearDates,
  });

  final TextEditingController controller;
  final DateTime? fromDate;
  final DateTime? toDate;
  final VoidCallback onChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearDates;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: 'Duyuru ara...',
              prefixIcon: const Icon(Symbols.search, size: 18),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged();
                      },
                      icon: const SymbolIcon(Symbols.close, size: 18),
                    ),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                borderSide: BorderSide(color: AppColors.line),
              ),
            ),
          ),
        ),
        _DateFilterButton(
          label: fromDate == null ? 'Başlangıç tarihi' : _shortDate(fromDate!),
          onTap: onPickFrom,
        ),
        _DateFilterButton(
          label: toDate == null ? 'Bitiş tarihi' : _shortDate(toDate!),
          onTap: onPickTo,
        ),
        if (fromDate != null || toDate != null)
          _OutlineButton(
            label: 'Tarihleri Temizle',
            icon: Symbols.close,
            onPressed: onClearDates,
          ),
      ],
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Symbols.calendar_today_outlined, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deepOcean,
        side: BorderSide(color: AppColors.line.withValues(alpha: 0.9)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _AdminDistrictTabs extends StatelessWidget {
  const _AdminDistrictTabs({
    required this.selected,
    required this.countFor,
    required this.onSelected,
  });

  final String selected;
  final int Function(String district) countFor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const tabs = {'all': 'Tümü', ..._announcementDistrictLabels};
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in tabs.entries)
          SizedBox(
            height: 36,
            child: TextButton(
              onPressed: () => onSelected(entry.key),
              style: TextButton.styleFrom(
                backgroundColor: selected == entry.key
                    ? AppColors.deepOcean
                    : AppColors.surface,
                foregroundColor: selected == entry.key
                    ? Colors.white
                    : AppColors.deepOcean,
                side: BorderSide(
                  color: selected == entry.key
                      ? AppColors.deepOcean
                      : AppColors.line.withValues(alpha: 0.88),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              child: Text('${entry.value} ${countFor(entry.key)}'),
            ),
          ),
      ],
    );
  }
}

class _PreviewAnnouncement extends StatelessWidget {
  const _PreviewAnnouncement({
    required this.item,
    required this.isSelected,
    required this.onEdit,
    required this.onSetActive,
    required this.onDelete,
    required this.onToggleSelection,
  });

  final AnnouncementPreviewItem item;
  final bool isSelected;
  final ValueChanged<AnnouncementPreviewItem> onEdit;
  final void Function(AnnouncementPreviewItem item, bool isActive) onSetActive;
  final ValueChanged<AnnouncementPreviewItem> onDelete;
  final void Function(String id, bool selected) onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.category) {
      'power' => const Color(0xFFE59A22),
      'road' => const Color(0xFF2F8F67),
      _ => const Color(0xFF2F6F9F),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (value) => onToggleSelection(item.id, value == true),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 12),
          _AnnouncementThumb(item: item),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _SoftBadge(label: item.source),
                    _SoftBadge(
                      label:
                          _announcementDistrictLabels[item.district] ??
                          'Merkez',
                    ),
                    if (item.statusLabel.isNotEmpty)
                      _SoftBadge(label: item.statusLabel),
                    if (item.scheduleLabel.isNotEmpty)
                      _SoftBadge(label: item.scheduleLabel),
                    _SoftBadge(
                      label: item.isActive ? 'Yayında' : 'Yayında değil',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                if (item.summary.trim().isNotEmpty)
                  Text(
                    item.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${item.place} · ${item.timeLabel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    if (item.sourceUrl.isNotEmpty)
                      InkWell(
                        onTap: () => _openExternalUrl(item.sourceUrl),
                        mouseCursor: SystemMouseCursors.click,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SymbolIcon(
                              Symbols.open_in_new,
                              size: 14,
                              color: AppColors.actionRed,
                            ),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: Text(
                                item.sourceUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.actionRed,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (item.linkedPostTitle.trim().isNotEmpty) ...[
                  Row(
                    children: [
                      const SymbolIcon(
                        Symbols.newspaper,
                        size: 14,
                        color: AppColors.deepOcean,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Bağlı haber: ${item.linkedPostTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.deepOcean,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Yayın: ${_dateLabel(item.publishedAt)} · Başlangıç: ${_dateLabel(item.startsAt)} · Bitiş: ${_dateLabel(item.endsAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _IconButton(
                tooltip: 'Düzenle',
                icon: Symbols.edit_square,
                color: AppColors.deepOcean,
                onTap: () => onEdit(item),
              ),
              _IconButton(
                tooltip: item.isActive ? 'Yayından kaldır' : 'Yayına al',
                icon: item.isActive ? Symbols.visibility_off : Symbols.check,
                color: item.isActive
                    ? AppColors.warmHorizon
                    : const Color(0xFF2F8F67),
                onTap: () => onSetActive(item, !item.isActive),
              ),
              _IconButton(
                tooltip: 'Sil',
                icon: Symbols.delete,
                color: AppColors.actionRed,
                onTap: () => onDelete(item),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnnouncementThumb extends StatelessWidget {
  const _AnnouncementThumb({required this.item});

  final AnnouncementPreviewItem item;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.value),
      child: Container(
        width: 118,
        height: 88,
        color: AppColors.surface,
        child: item.imageUrl.isEmpty
            ? const Center(
                child: SymbolIcon(
                  Symbols.visibility,
                  size: 24,
                  color: AppColors.inkSoft,
                ),
              )
            : AdminCachedImage(
                url: item.imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 360,
                errorWidget: const Center(
                  child: SymbolIcon(
                    Symbols.visibility,
                    size: 24,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
      ),
    );
  }
}

DateTime? _announcementDate(AnnouncementPreviewItem item) {
  for (final value in [item.startsAt, item.publishedAt, item.endsAt]) {
    final date = DateTime.tryParse(value);
    if (date != null) return date.toLocal();
  }
  return null;
}

String _shortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String _dateLabel(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return '-';
  return _shortDate(date.toLocal());
}

Future<void> _openExternalUrl(String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog({required this.item, required this.newsRepository});

  final AnnouncementPreviewItem item;
  final AdminNewsRepository newsRepository;

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _body;
  late final TextEditingController _place;
  late final TextEditingController _statusLabel;
  late final TextEditingController _scheduleLabel;
  late final TextEditingController _imageUrl;
  late final TextEditingController _sourceUrl;
  late final TextEditingController _canonicalUrl;
  late final TextEditingController _publishedAt;
  late final TextEditingController _startsAt;
  late final TextEditingController _endsAt;
  late String _category;
  late String _district;
  late bool _active;
  late String _linkedPostId;
  late String _linkedPostTitle;
  late String _linkedPostSlug;
  late String _linkedPostThumbnailUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item.title);
    _summary = TextEditingController(text: item.summary);
    _body = TextEditingController(text: item.body);
    _place = TextEditingController(text: item.place);
    _statusLabel = TextEditingController(text: item.statusLabel);
    _scheduleLabel = TextEditingController(text: item.scheduleLabel);
    _imageUrl = TextEditingController(text: item.imageUrl);
    _sourceUrl = TextEditingController(text: item.sourceUrl);
    _canonicalUrl = TextEditingController(text: item.canonicalUrl);
    _publishedAt = TextEditingController(text: item.publishedAt);
    _startsAt = TextEditingController(text: item.startsAt);
    _endsAt = TextEditingController(text: item.endsAt);
    _category = item.category;
    _district = item.district;
    _active = item.isActive;
    _linkedPostId = item.linkedPostId;
    _linkedPostTitle = item.linkedPostTitle;
    _linkedPostSlug = item.linkedPostSlug;
    _linkedPostThumbnailUrl = item.linkedPostThumbnailUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _body.dispose();
    _place.dispose();
    _statusLabel.dispose();
    _scheduleLabel.dispose();
    _imageUrl.dispose();
    _sourceUrl.dispose();
    _canonicalUrl.dispose();
    _publishedAt.dispose();
    _startsAt.dispose();
    _endsAt.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Başlık boş bırakılamaz.');
      return;
    }
    Navigator.of(context).pop(
      widget.item.copyWith(
        category: _category,
        district: _district,
        title: title,
        summary: _summary.text.trim(),
        body: _body.text.trim(),
        place: _place.text.trim().isEmpty ? 'Niğde geneli' : _place.text.trim(),
        statusLabel: _statusLabel.text.trim(),
        scheduleLabel: _scheduleLabel.text.trim(),
        imageUrl: _imageUrl.text.trim(),
        sourceUrl: _sourceUrl.text.trim(),
        canonicalUrl: _canonicalUrl.text.trim(),
        linkedPostId: _linkedPostId,
        linkedPostTitle: _linkedPostTitle,
        linkedPostSlug: _linkedPostSlug,
        linkedPostThumbnailUrl: _linkedPostThumbnailUrl,
        publishedAt: _publishedAt.text.trim(),
        startsAt: _startsAt.text.trim(),
        endsAt: _endsAt.text.trim(),
        isActive: _active,
      ),
    );
  }

  Future<void> _selectLinkedPost() async {
    final post = await showDialog<AdminNewsPost>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (context) => _AnnouncementNewsPickerDialog(
        repository: widget.newsRepository,
        selectedPostId: _linkedPostId,
      ),
    );
    if (!mounted || post == null) return;
    setState(() {
      _linkedPostId = post.id;
      _linkedPostTitle = post.displayTitle;
      _linkedPostSlug = post.slug;
      _linkedPostThumbnailUrl = post.thumbnailUrl;
    });
  }

  void _clearLinkedPost() {
    setState(() {
      _linkedPostId = '';
      _linkedPostTitle = '';
      _linkedPostSlug = '';
      _linkedPostThumbnailUrl = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Duyuruyu Düzenle',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.item.source} · ${widget.item.sourceKey}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 18),
              if (_error != null) ...[
                _InfoStrip(title: 'Eksik bilgi', description: _error!),
                const SizedBox(height: 12),
              ],
              _TextField(label: 'Başlık', controller: _title),
              const SizedBox(height: 12),
              _TextField(label: 'Özet', controller: _summary, maxLines: 3),
              const SizedBox(height: 12),
              _TextField(label: 'Detay metni', controller: _body, maxLines: 5),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _DropdownField(
                    label: 'Kategori',
                    value: _category,
                    values: const ['official', 'power', 'road'],
                    onChanged: (value) => setState(() => _category = value),
                  ),
                  _DropdownField(
                    label: 'İlçe',
                    value: _district,
                    values: const [
                      'merkez',
                      'altunhisar',
                      'bor',
                      'camardi',
                      'ciftlik',
                      'ulukisla',
                    ],
                    onChanged: (value) => setState(() => _district = value),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TextField(label: 'Yer', controller: _place),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextField(
                      label: 'Durum etiketi',
                      controller: _statusLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextField(
                      label: 'Zaman etiketi',
                      controller: _scheduleLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TextField(label: 'Görsel URL', controller: _imageUrl),
              const SizedBox(height: 12),
              _TextField(label: 'Alındığı adres', controller: _sourceUrl),
              const SizedBox(height: 12),
              _TextField(label: 'Kalıcı adres', controller: _canonicalUrl),
              const SizedBox(height: 12),
              _LinkedPostField(
                title: _linkedPostTitle,
                slug: _linkedPostSlug,
                thumbnailUrl: _linkedPostThumbnailUrl,
                onSelect: _selectLinkedPost,
                onClear: _clearLinkedPost,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TextField(
                      label: 'Yayın tarihi',
                      controller: _publishedAt,
                      hint: '2026-06-06T12:00:00.000Z',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextField(
                      label: 'Başlangıç',
                      controller: _startsAt,
                      hint: 'Boş bırakılabilir',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextField(
                      label: 'Bitiş',
                      controller: _endsAt,
                      hint: 'Boş bırakılabilir',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                title: const Text('Yayında'),
                subtitle: const Text(
                  'Kapalıysa mobil duyuru listesinde görünmez.',
                ),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.actionRed,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _OutlineButton(
                    label: 'Vazgeç',
                    icon: Symbols.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  _PrimaryButton(
                    label: 'Kaydet',
                    icon: Symbols.save,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedPostField extends StatelessWidget {
  const _LinkedPostField({
    required this.title,
    required this.slug,
    required this.thumbnailUrl,
    required this.onSelect,
    required this.onClear,
  });

  final String title;
  final String slug;
  final String thumbnailUrl;
  final VoidCallback onSelect;
  final VoidCallback onClear;

  bool get _hasPost => title.trim().isNotEmpty || slug.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.value),
            child: Container(
              width: 72,
              height: 54,
              color: Colors.white,
              child: thumbnailUrl.trim().isEmpty
                  ? const Center(
                      child: SymbolIcon(
                        Symbols.article,
                        color: AppColors.inkSoft,
                        size: 22,
                      ),
                    )
                  : AdminCachedImage(
                      url: thumbnailUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 360,
                      errorWidget: const Center(
                        child: SymbolIcon(
                          Symbols.article,
                          color: AppColors.inkSoft,
                          size: 22,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bağlı haber',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hasPost
                      ? title
                      : 'Mobilde duyuru tıklanınca açılacak haber seçilmedi.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                if (slug.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    slug,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OutlineButton(
                label: _hasPost ? 'Değiştir' : 'Haber Seç',
                icon: Symbols.newspaper,
                onPressed: onSelect,
              ),
              if (_hasPost)
                _OutlineButton(
                  label: 'Kaldır',
                  icon: Symbols.close,
                  onPressed: onClear,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnnouncementNewsPickerDialog extends StatefulWidget {
  const _AnnouncementNewsPickerDialog({
    required this.repository,
    required this.selectedPostId,
  });

  final AdminNewsRepository repository;
  final String selectedPostId;

  @override
  State<_AnnouncementNewsPickerDialog> createState() =>
      _AnnouncementNewsPickerDialogState();
}

class _AnnouncementNewsPickerDialogState
    extends State<_AnnouncementNewsPickerDialog> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _loading = true;
  String? _error;
  var _posts = const <AdminNewsPost>[];
  var _totalCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _scheduleSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.fetchPosts(
        search: _search.text,
        language: 'Tümü',
        category: 'Tümü',
        type: 'Tümü',
        status: 'published',
        publisher: 'Tümü',
        trash: false,
        videoOnly: false,
        page: 1,
        pageSize: 24,
        sortKey: 'date',
        sortAscending: false,
      );
      if (!mounted) return;
      setState(() {
        _posts = result.posts;
        _totalCount = result.totalCount;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _posts = const [];
        _totalCount = 0;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SymbolIcon(
                    Symbols.newspaper,
                    color: AppColors.actionRed,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Duyuruya Haber Bağla',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  _IconButton(
                    tooltip: 'Kapat',
                    icon: Symbols.close,
                    color: AppColors.deepOcean,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                onChanged: _scheduleSearch,
                decoration: InputDecoration(
                  hintText: 'Haber ara...',
                  prefixIcon: const Icon(Symbols.search, size: 18),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            unawaited(_load());
                          },
                          icon: const SymbolIcon(Symbols.close, size: 18),
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.value),
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.value),
                    borderSide: BorderSide(
                      color: AppColors.line.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Yalnızca yayındaki haberler listelenir · $_totalCount kayıt',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const _StateBox(label: 'Haberler yükleniyor...');
    }
    final error = _error;
    if (error != null) {
      return _ErrorBox(message: error, onRetry: _load);
    }
    if (_posts.isEmpty) {
      return const _StateBox(label: 'Yayındaki haber bulunamadı.');
    }
    return ListView.separated(
      itemCount: _posts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final post = _posts[index];
        final selected = post.id == widget.selectedPostId;
        return _NewsPickerRow(
          post: post,
          selected: selected,
          onTap: () => Navigator.of(context).pop(post),
        );
      },
    );
  }
}

class _NewsPickerRow extends StatelessWidget {
  const _NewsPickerRow({
    required this.post,
    required this.selected,
    required this.onTap,
  });

  final AdminNewsPost post;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.deepOcean.withValues(alpha: 0.05)
          : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.value),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected
                  ? AppColors.deepOcean
                  : AppColors.line.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.value),
                child: Container(
                  width: 76,
                  height: 56,
                  color: AppColors.surface,
                  child: post.thumbnailUrl.trim().isEmpty
                      ? const Center(
                          child: SymbolIcon(
                            Symbols.article,
                            color: AppColors.inkSoft,
                            size: 22,
                          ),
                        )
                      : AdminCachedImage(
                          url: post.thumbnailUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 360,
                          errorWidget: const Center(
                            child: SymbolIcon(
                              Symbols.article,
                              color: AppColors.inkSoft,
                              size: 22,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SoftBadge(label: post.displayCategory),
                        _SoftBadge(label: post.createdDate),
                        if (selected) const _SoftBadge(label: 'Seçili'),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      post.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      post.slug,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SymbolIcon(
                selected ? Symbols.check : Symbols.arrow_forward,
                color: selected ? AppColors.actionRed : AppColors.inkSoft,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunsPanel extends StatelessWidget {
  const _RunsPanel({required this.runs});

  final List<AnnouncementRunData> runs;

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) {
      return const _StateBox(label: 'Henüz çalışma kaydı yok.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final run in runs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RunRow(run: run),
          ),
      ],
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run});

  final AnnouncementRunData run;

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
          _StatusDot(status: run.status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${run.runType} · ${run.status}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${run.startedAt} · ${run.candidatesFound} aday · ${run.insertedCount} yeni · ${run.updatedCount} güncel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                if (run.errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    run.errorMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.actionRed,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
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

class _SourceDialog extends StatefulWidget {
  const _SourceDialog({this.source});

  final AnnouncementSourceData? source;

  @override
  State<_SourceDialog> createState() => _SourceDialogState();
}

class _SourceDialogState extends State<_SourceDialog> {
  late final TextEditingController _name;
  late final TextEditingController _sourceKey;
  late final TextEditingController _websiteUrl;
  late final TextEditingController _listUrl;
  late final TextEditingController _socialUrl;
  late final TextEditingController _facebookUrl;
  late final TextEditingController _instagramUrl;
  late final TextEditingController _interval;
  late final TextEditingController _sortOrder;
  var _sourceType = 'institution';
  var _categoryHint = 'official';
  var _district = 'merkez';
  var _crawlStrategy = 'auto';
  var _active = true;

  @override
  void initState() {
    super.initState();
    final source = widget.source ?? const AnnouncementSourceData.empty();
    _name = TextEditingController(text: source.name);
    _sourceKey = TextEditingController(text: source.sourceKey);
    _websiteUrl = TextEditingController(text: source.websiteUrl);
    _listUrl = TextEditingController(text: source.listUrl);
    _socialUrl = TextEditingController(text: source.socialUrl);
    _facebookUrl = TextEditingController(text: source.facebookUrl);
    _instagramUrl = TextEditingController(text: source.instagramUrl);
    _interval = TextEditingController(
      text: source.crawlIntervalMinutes.toString(),
    );
    _sortOrder = TextEditingController(text: source.sortOrder.toString());
    _sourceType = source.sourceType;
    _categoryHint = source.categoryHint;
    _district = source.district;
    _crawlStrategy = source.crawlStrategy;
    _active = source.isActive;
  }

  @override
  void dispose() {
    _name.dispose();
    _sourceKey.dispose();
    _websiteUrl.dispose();
    _listUrl.dispose();
    _socialUrl.dispose();
    _facebookUrl.dispose();
    _instagramUrl.dispose();
    _interval.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final listUrl = _listUrl.text.trim();
    if (name.isEmpty || listUrl.isEmpty) return;
    final source = (widget.source ?? const AnnouncementSourceData.empty())
        .copyWith(
          name: name,
          sourceKey: _sourceKey.text.trim(),
          sourceType: _sourceType,
          categoryHint: _categoryHint,
          district: _district,
          websiteUrl: _websiteUrl.text.trim(),
          listUrl: listUrl,
          socialUrl: _socialUrl.text.trim(),
          facebookUrl: _facebookUrl.text.trim(),
          instagramUrl: _instagramUrl.text.trim(),
          crawlStrategy: _crawlStrategy,
          isActive: _active,
          crawlIntervalMinutes: int.tryParse(_interval.text.trim()) ?? 30,
          sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 500,
        );
    Navigator.of(context).pop(source);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.source == null ? 'Kaynak Ekle' : 'Kaynağı Düzenle',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 18),
              _TextField(label: 'Kaynak adı', controller: _name),
              const SizedBox(height: 12),
              _TextField(
                label: 'Kaynak anahtarı',
                controller: _sourceKey,
                hint: 'Boş bırakılırsa addan üretilir',
              ),
              const SizedBox(height: 12),
              _TextField(label: 'Liste URL', controller: _listUrl),
              const SizedBox(height: 12),
              _TextField(label: 'Web sitesi', controller: _websiteUrl),
              const SizedBox(height: 12),
              _TextField(
                label: 'Açık sosyal sayfa URL',
                controller: _socialUrl,
                hint: 'API değil, public sayfa linki',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TextField(
                      label: 'Facebook URL',
                      controller: _facebookUrl,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextField(
                      label: 'Instagram URL',
                      controller: _instagramUrl,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _DropdownField(
                    label: 'Kaynak tipi',
                    value: _sourceType,
                    values: const [
                      'institution',
                      'municipality',
                      'chamber',
                      'union',
                      'ngo',
                      'education',
                      'health',
                      'sports',
                      'utility',
                      'media',
                      'social',
                      'other',
                    ],
                    onChanged: (value) => setState(() => _sourceType = value),
                  ),
                  _DropdownField(
                    label: 'Kategori',
                    value: _categoryHint,
                    values: const ['official', 'power', 'road'],
                    onChanged: (value) => setState(() => _categoryHint = value),
                  ),
                  _DropdownField(
                    label: 'İlçe',
                    value: _district,
                    values: const [
                      'merkez',
                      'altunhisar',
                      'bor',
                      'camardi',
                      'ciftlik',
                      'ulukisla',
                    ],
                    onChanged: (value) => setState(() => _district = value),
                  ),
                  _DropdownField(
                    label: 'Tarama',
                    value: _crawlStrategy,
                    values: const [
                      'auto',
                      'rss',
                      'sitemap',
                      'html',
                      'social_public',
                      'search',
                    ],
                    onChanged: (value) =>
                        setState(() => _crawlStrategy = value),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TextField(
                      label: 'Tarama aralığı dk',
                      controller: _interval,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextField(
                      label: 'Sıra',
                      controller: _sortOrder,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                title: const Text('Aktif'),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.actionRed,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _OutlineButton(
                    label: 'Vazgeç',
                    icon: Symbols.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  _PrimaryButton(
                    label: 'Kaydet',
                    icon: Symbols.save,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.controller,
    this.hint = '',
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint.isEmpty ? null : hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
          borderSide: BorderSide(color: AppColors.line.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
          borderSide: const BorderSide(color: AppColors.deepOcean),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = values.contains(value) ? value : values.first;
    return SizedBox(
      width: 206,
      child: DropdownButtonFormField<String>(
        initialValue: normalizedValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            borderSide: BorderSide(
              color: AppColors.line.withValues(alpha: 0.9),
            ),
          ),
        ),
        items: [
          for (final item in values)
            DropdownMenuItem(
              value: item,
              child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: SymbolIcon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.actionRed,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: SymbolIcon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deepOcean,
        side: BorderSide(color: AppColors.line.withValues(alpha: 0.9)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
          ),
          child: SymbolIcon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

class _UrlLine extends StatelessWidget {
  const _UrlLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          const SymbolIcon(Symbols.check, color: AppColors.actionRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: description),
                ],
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Text(
        '$label  $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
    return _SoftBadge(label: active ? 'Aktif' : 'Pasif');
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'success' => const Color(0xFF2F8F67),
      'partial' => const Color(0xFFE59A22),
      'error' => AppColors.actionRed,
      _ => AppColors.deepOcean,
    };
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StateBox extends StatelessWidget {
  const _StateBox({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          const SymbolIcon(
            Symbols.warning,
            color: AppColors.actionRed,
            size: 20,
          ),
          const SizedBox(width: 12),
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
          const SizedBox(width: 12),
          _OutlineButton(
            label: 'Tekrar dene',
            icon: Symbols.refresh_line,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
