import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';
import 'package:pateeznews_admin/features/automatic_news/data/admin_automatic_news_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_ai_settings_repository.dart';
import 'package:pateeznews_admin/features/news/presentation/widgets/news_link_opener.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:quill_native_bridge/quill_native_bridge.dart';
import 'package:share_plus/share_plus.dart' hide XFile;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/data/admin_image_url.dart';
import '../../../shared/widgets/admin_cached_image.dart';
import '../../../shared/widgets/admin_mobile_list.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/admin_toast.dart';
import '../../../shared/widgets/admin_table_chrome.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';

class AutomaticNewsAiDraftSeed {
  const AutomaticNewsAiDraftSeed({
    required this.topic,
    required this.sourceUrl,
    required this.imageUrl,
    required this.imageAlt,
  });

  final String topic;
  final String sourceUrl;
  final String imageUrl;
  final String imageAlt;
}

class AutomaticNewsScreen extends StatefulWidget {
  const AutomaticNewsScreen({
    super.key,
    this.repository = const SupabaseAdminAutomaticNewsRepository(),
    this.onEditDraft,
  });

  final AdminAutomaticNewsRepository repository;
  final ValueChanged<AutomaticNewsAiDraftSeed>? onEditDraft;

  @override
  State<AutomaticNewsScreen> createState() => _AutomaticNewsScreenState();
}

class _AutomaticNewsScreenState extends State<AutomaticNewsScreen> {
  static const _all = 'Tümü';

  final _searchController = TextEditingController();
  final _selectedDraftIds = <int>{};

  var _drafts = const <_AutomaticNewsDraft>[];
  var _sources = const <AutomaticNewsSource>[];
  var _totalCount = 0;
  var _loading = true;
  var _errorMessage = '';
  var _platformFilter = _all;
  var _categoryFilter = _all;
  var _statusFilter = _all;
  var _languageFilter = _all;
  var _page = 1;
  var _pageSize = 25;
  var _searchQuery = '';
  var _sortState = const TableSortState(key: 'date', ascending: false);
  var _imageRequestHeaders = const <String, String>{};
  String? _downloadingImageDraftId;
  Timer? _searchDebounce;
  Timer? _fallbackPollTimer;
  var _itemsRequestId = 0;
  var _automationEnabled = false;
  var _automationLoading = true;
  var _automationSaving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
    _fallbackPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _loading || !_automationEnabled) return;
      unawaited(_loadItems());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _fallbackPollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<_AutomaticNewsDraft> get _pagedDrafts => _drafts;

  int get _pageCount {
    final total = _totalCount;
    if (total == 0) return 1;
    return ((total - 1) ~/ _pageSize) + 1;
  }

  Future<void> _loadInitial() async {
    await _loadImageRequestHeaders();
    await Future.wait([
      _loadAutomationSettings(),
      _loadSources(),
      _loadItems(showLoading: true),
    ]);
  }

  Future<void> _loadImageRequestHeaders() async {
    if (!kIsWeb) return;
    final headers = await adminAuthHeaders();
    final authorization = headers['Authorization']?.trim() ?? '';
    if (!mounted || authorization.isEmpty) return;
    setState(() {
      _imageRequestHeaders = {'Authorization': authorization};
    });
  }

  Future<void> _loadSources() async {
    try {
      final sources = await widget.repository.fetchSources();
      if (!mounted) return;
      setState(() {
        _sources = sources;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    }
  }

  Future<void> _loadAutomationSettings() async {
    try {
      final settings = await widget.repository.fetchAutomationSettings();
      if (!mounted) return;
      setState(() {
        _automationEnabled = settings.enabled;
        _automationLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _automationLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _toggleAutomation(bool value) async {
    if (_automationLoading ||
        _automationSaving ||
        value == _automationEnabled) {
      return;
    }
    setState(() {
      _automationSaving = true;
      _errorMessage = '';
    });
    try {
      final settings = await widget.repository.setAutomationEnabled(value);
      if (!mounted) return;
      setState(() {
        _automationEnabled = settings.enabled;
        _automationSaving = false;
      });
      if (settings.enabled) {
        unawaited(_loadItems(showLoading: true));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _automationSaving = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _loadItems({bool showLoading = false}) async {
    final requestId = ++_itemsRequestId;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _errorMessage = '';
      });
    }
    try {
      final result = await widget.repository.fetchItems(
        search: _searchQuery,
        platform: _platformFilter,
        category: _categoryFilter,
        status: _statusFilter,
        language: _languageFilter,
        page: _page,
        pageSize: _pageSize,
        sortKey: _sortState.key,
        sortAscending: _sortState.ascending,
      );
      if (!mounted || requestId != _itemsRequestId) return;
      setState(() {
        _drafts = [
          for (final item in result.items) _AutomaticNewsDraft.fromItem(item),
        ];
        _totalCount = result.totalCount;
        _loading = false;
        _errorMessage = '';
        _selectedDraftIds.clear();
      });
    } catch (error) {
      if (!mounted || requestId != _itemsRequestId) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _resetPageAndSelection() {
    _page = 1;
    _selectedDraftIds.clear();
  }

  void _changeSearch(String value) {
    setState(() {
      _searchQuery = value;
      _resetPageAndSelection();
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_loadItems());
    });
  }

  void _changeFilter({
    String? platform,
    String? category,
    String? status,
    String? language,
  }) {
    setState(() {
      if (platform != null) _platformFilter = platform;
      if (category != null) _categoryFilter = category;
      if (status != null) _statusFilter = status;
      if (language != null) _languageFilter = language;
      _resetPageAndSelection();
    });
    unawaited(_loadItems());
  }

  void _clearFilters() {
    if (_platformFilter == _all &&
        _categoryFilter == _all &&
        _statusFilter == _all &&
        _languageFilter == _all) {
      return;
    }
    setState(() {
      _platformFilter = _all;
      _categoryFilter = _all;
      _statusFilter = _all;
      _languageFilter = _all;
      _resetPageAndSelection();
    });
    unawaited(_loadItems());
  }

  void _changePageSize(int? value) {
    if (value == null || value == _pageSize) return;
    setState(() {
      _pageSize = value;
      _resetPageAndSelection();
    });
    unawaited(_loadItems(showLoading: true));
  }

  void _changePage(int page) {
    if (page == _page || page < 1 || page > _pageCount) return;
    setState(() {
      _page = page;
      _selectedDraftIds.clear();
    });
    unawaited(_loadItems(showLoading: true));
  }

  void _changeSort(String sortKey) {
    setState(() {
      _sortState = _sortState.toggled(sortKey);
      _selectedDraftIds.clear();
    });
    unawaited(_loadItems(showLoading: true));
  }

  void _toggleDraft(int id) {
    setState(() {
      if (!_selectedDraftIds.remove(id)) {
        _selectedDraftIds.add(id);
      }
    });
  }

  void _toggleVisibleDrafts() {
    final rows = _pagedDrafts;
    final visibleIds = rows.map((draft) => draft.id).toSet();
    setState(() {
      if (visibleIds.isNotEmpty && _selectedDraftIds.containsAll(visibleIds)) {
        _selectedDraftIds.removeAll(visibleIds);
      } else {
        _selectedDraftIds.addAll(visibleIds);
      }
    });
  }

  Future<void> _deleteDrafts(List<_AutomaticNewsDraft> drafts) async {
    if (drafts.isEmpty) return;
    final count = drafts.length;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: count == 1 ? 'Haber silinsin mi?' : 'Seçili haberler silinsin mi?',
      message: count == 1
          ? 'Bu otomatik haber silinecek.'
          : '$count otomatik haber silinecek.',
      confirmLabel: 'Sil',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = '';
    });
    try {
      await widget.repository.deleteItems(
        drafts.map((draft) => draft.recordId).toList(growable: false),
      );
      if (!mounted) return;
      _selectedDraftIds.removeAll(drafts.map((draft) => draft.id));
      if (drafts.length >= _pagedDrafts.length && _page > 1) {
        _page -= 1;
      }
      await _loadItems();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _deleteSelectedDrafts() async {
    final selected = _pagedDrafts
        .where((draft) => _selectedDraftIds.contains(draft.id))
        .toList(growable: false);
    await _deleteDrafts(selected);
  }

  Future<void> _deleteDraft(_AutomaticNewsDraft draft) async {
    await _deleteDrafts([draft]);
  }

  void _editDraft(_AutomaticNewsDraft draft) {
    widget.onEditDraft?.call(draft.toAiDraftSeed());
  }

  Future<void> _downloadDraftImage(_AutomaticNewsDraft draft) async {
    if (draft.imageUrl.isEmpty || _downloadingImageDraftId != null) return;
    setState(() => _downloadingImageDraftId = draft.recordId);
    try {
      final file = await widget.repository.downloadImage(draft.recordId);
      if (!mounted) return;
      await _saveDownloadedImage(file);
    } catch (error) {
      if (!mounted) return;
      AdminToast.show(
        context,
        message: error.toString(),
        tone: AdminToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _downloadingImageDraftId = null);
    }
  }

  Future<void> _saveDownloadedImage(AutomaticNewsImageFile file) async {
    if (_shouldSaveDownloadedImageToGallery) {
      final savedToGallery = await _saveDownloadedImageToGallery(file);
      if (savedToGallery) return;
    }
    final extension = _fileExtension(file.fileName);
    try {
      final location = await getSaveLocation(
        suggestedName: file.fileName,
        acceptedTypeGroups: [
          XTypeGroup(
            label: 'Görsel',
            extensions: [if (extension.isNotEmpty) extension],
            mimeTypes: [file.mimeType],
          ),
        ],
      );
      if (location == null) return;
      await XFile.fromData(
        file.bytes,
        mimeType: file.mimeType,
        name: file.fileName,
      ).saveTo(location.path);
      if (!mounted) return;
      AdminToast.show(
        context,
        message: 'Görsel kaydedildi',
        tone: AdminToastTone.success,
      );
    } on UnimplementedError {
      await _shareDownloadedImage(file);
    } on UnsupportedError {
      await _shareDownloadedImage(file);
    }
  }

  bool get _shouldSaveDownloadedImageToGallery {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<bool> _saveDownloadedImageToGallery(
    AutomaticNewsImageFile file,
  ) async {
    final bridge = QuillNativeBridge();
    try {
      final supported = await bridge.isSupported(
        QuillNativeBridgeFeature.saveImageToGallery,
      );
      if (!supported) return false;
      final extension = _fileExtension(file.fileName).isNotEmpty
          ? _fileExtension(file.fileName)
          : _fileExtensionForMimeType(file.mimeType);
      await bridge.saveImageToGallery(
        file.bytes,
        options: GalleryImageSaveOptions(
          name: _fileNameWithoutExtension(file.fileName),
          fileExtension: extension.isEmpty ? 'jpg' : extension,
          albumName: null,
        ),
      );
      if (!mounted) return true;
      AdminToast.show(
        context,
        message: 'Görsel galeriye kaydedildi',
        tone: AdminToastTone.success,
      );
      return true;
    } on UnimplementedError {
      return false;
    } on UnsupportedError {
      return false;
    }
  }

  Future<void> _shareDownloadedImage(AutomaticNewsImageFile file) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            file.bytes,
            mimeType: file.mimeType,
            name: file.fileName,
          ),
        ],
        fileNameOverrides: [file.fileName],
        title: file.fileName,
        sharePositionOrigin: origin,
      ),
    );
    if (!mounted || result.status != ShareResultStatus.success) return;
    AdminToast.show(
      context,
      message: 'Görsel paylaşım menüsüne gönderildi',
      tone: AdminToastTone.success,
    );
  }

  Future<void> _openSourceDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AutomaticNewsSourceDialog(
        initialSources: _sources,
        onSaveSources: (urls) async {
          final saved = await widget.repository.saveSources(urls);
          await _loadSources();
          return saved;
        },
        onTestSources: () async {
          final result = await widget.repository.testSources();
          final sources = await widget.repository.fetchSources();
          if (mounted) {
            setState(() {
              _sources = sources;
            });
          }
          await _loadItems();
          return _AutomaticNewsSourceTestPayload(
            result: result,
            sources: sources,
          );
        },
        onScanSources: () async {
          final result = await widget.repository.refreshNow();
          final sources = await widget.repository.fetchSources();
          if (mounted) {
            setState(() {
              _sources = sources;
            });
          }
          await _loadItems(showLoading: true);
          return _AutomaticNewsSourceTestPayload(
            result: result,
            sources: sources,
          );
        },
        onToggleSource: (source, value) async {
          final updated = await widget.repository.setSourceActive(
            id: source.id,
            isActive: value,
          );
          await _loadSources();
          return updated;
        },
      ),
    );
    unawaited(_loadSources());
  }

  void _showDraftPreview(_AutomaticNewsDraft draft) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xB20D1B24),
      builder: (context) => _AutomaticNewsPreviewDialog(
        draft: draft,
        repository: widget.repository,
        imageRequestHeaders: _imageRequestHeaders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final mobile = constraints.maxWidth < 800;
        final compact = constraints.maxWidth < 900;

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AutomaticNewsTitle(),
            SizedBox(height: mobile ? 14 : 20),
            if (_errorMessage.isNotEmpty) ...[
              _AutomaticNewsErrorBanner(message: _errorMessage),
              const SizedBox(height: 14),
            ],
            Expanded(
              child: _AutomaticNewsTableCard(
                drafts: _pagedDrafts,
                totalCount: _totalCount,
                page: _page,
                pageCount: _pageCount,
                pageSize: _pageSize,
                loading: _loading,
                refreshing: _loading,
                automationEnabled: _automationEnabled,
                automationBusy: _automationLoading || _automationSaving,
                searchController: _searchController,
                searchQuery: _searchQuery,
                selectedDraftIds: _selectedDraftIds,
                imageRequestHeaders: _imageRequestHeaders,
                platformFilter: _platformFilter,
                categoryFilter: _categoryFilter,
                statusFilter: _statusFilter,
                languageFilter: _languageFilter,
                sortState: _sortState,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onPlatformChanged: (value) => _changeFilter(platform: value),
                onCategoryChanged: (value) => _changeFilter(category: value),
                onStatusChanged: (value) => _changeFilter(status: value),
                onLanguageChanged: (value) => _changeFilter(language: value),
                onClearFilters: _clearFilters,
                onPageChanged: _changePage,
                onSort: _changeSort,
                onToggleDraft: _toggleDraft,
                onToggleVisibleDrafts: _toggleVisibleDrafts,
                onDeleteSelected: () => unawaited(_deleteSelectedDrafts()),
                onAutomationChanged: (value) =>
                    unawaited(_toggleAutomation(value)),
                onRefresh: () => unawaited(_loadItems(showLoading: true)),
                onOpenSources: _openSourceDialog,
                onViewDraft: _showDraftPreview,
                onEditDraft: _editDraft,
                onDownloadDraftImage: (draft) =>
                    unawaited(_downloadDraftImage(draft)),
                onDeleteDraft: (draft) => unawaited(_deleteDraft(draft)),
              ),
            ),
          ],
        );

        if (mobile) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              18,
              horizontalPadding,
              0,
            ),
            child: content,
          );
        }

        if (compact) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              28,
              horizontalPadding,
              28,
            ),
            child: SizedBox(height: 980, child: content),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            28,
            horizontalPadding,
            28,
          ),
          child: content,
        );
      },
    );
  }
}

class _AutomaticNewsTitle extends StatelessWidget {
  const _AutomaticNewsTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Otomatik Haber',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _AutomaticNewsErrorBanner extends StatelessWidget {
  const _AutomaticNewsErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const SymbolIcon(
            Symbols.error_outline,
            color: AppColors.actionRed,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

class _CompactSwitch extends StatelessWidget {
  const _CompactSwitch({required this.value, required this.onChanged});

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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepOcean.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _AutomaticNewsTableCard extends StatelessWidget {
  const _AutomaticNewsTableCard({
    required this.drafts,
    required this.totalCount,
    required this.page,
    required this.pageCount,
    required this.pageSize,
    required this.loading,
    required this.refreshing,
    required this.automationEnabled,
    required this.automationBusy,
    required this.searchController,
    required this.searchQuery,
    required this.selectedDraftIds,
    required this.imageRequestHeaders,
    required this.platformFilter,
    required this.categoryFilter,
    required this.statusFilter,
    required this.languageFilter,
    required this.sortState,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onPlatformChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onLanguageChanged,
    required this.onClearFilters,
    required this.onPageChanged,
    required this.onSort,
    required this.onToggleDraft,
    required this.onToggleVisibleDrafts,
    required this.onDeleteSelected,
    required this.onAutomationChanged,
    required this.onRefresh,
    required this.onOpenSources,
    required this.onViewDraft,
    required this.onEditDraft,
    required this.onDownloadDraftImage,
    required this.onDeleteDraft,
  });

  final List<_AutomaticNewsDraft> drafts;
  final int totalCount;
  final int page;
  final int pageCount;
  final int pageSize;
  final bool loading;
  final bool refreshing;
  final bool automationEnabled;
  final bool automationBusy;
  final TextEditingController searchController;
  final String searchQuery;
  final Set<int> selectedDraftIds;
  final Map<String, String> imageRequestHeaders;
  final String platformFilter;
  final String categoryFilter;
  final String statusFilter;
  final String languageFilter;
  final TableSortState sortState;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onLanguageChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onSort;
  final ValueChanged<int> onToggleDraft;
  final VoidCallback onToggleVisibleDrafts;
  final VoidCallback onDeleteSelected;
  final ValueChanged<bool> onAutomationChanged;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSources;
  final ValueChanged<_AutomaticNewsDraft> onViewDraft;
  final ValueChanged<_AutomaticNewsDraft> onEditDraft;
  final ValueChanged<_AutomaticNewsDraft> onDownloadDraftImage;
  final ValueChanged<_AutomaticNewsDraft> onDeleteDraft;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 800;
        if (mobile) {
          return _AutomaticNewsMobileView(
            drafts: drafts,
            totalCount: totalCount,
            page: page,
            pageCount: pageCount,
            pageSize: pageSize,
            loading: loading,
            refreshing: refreshing,
            automationEnabled: automationEnabled,
            automationBusy: automationBusy,
            searchController: searchController,
            selectedDraftIds: selectedDraftIds,
            platformFilter: platformFilter,
            categoryFilter: categoryFilter,
            statusFilter: statusFilter,
            languageFilter: languageFilter,
            onPageSizeChanged: onPageSizeChanged,
            onSearchChanged: onSearchChanged,
            onPlatformChanged: onPlatformChanged,
            onCategoryChanged: onCategoryChanged,
            onStatusChanged: onStatusChanged,
            onLanguageChanged: onLanguageChanged,
            onClearFilters: onClearFilters,
            onPageChanged: onPageChanged,
            onToggleDraft: onToggleDraft,
            onDeleteSelected: onDeleteSelected,
            onAutomationChanged: onAutomationChanged,
            onRefresh: onRefresh,
            onOpenSources: onOpenSources,
            onViewDraft: onViewDraft,
            onEditDraft: onEditDraft,
            onDownloadDraftImage: onDownloadDraftImage,
            onDeleteDraft: onDeleteDraft,
          );
        }

        final compact = constraints.maxWidth < 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AutomaticNewsFilters(
              platformFilter: platformFilter,
              categoryFilter: categoryFilter,
              statusFilter: statusFilter,
              languageFilter: languageFilter,
              onPlatformChanged: onPlatformChanged,
              onCategoryChanged: onCategoryChanged,
              onStatusChanged: onStatusChanged,
              onLanguageChanged: onLanguageChanged,
            ),
            const SizedBox(height: 28),
            _AutomaticNewsToolbar(
              compact: compact,
              pageSize: pageSize,
              searchController: searchController,
              searchQuery: searchQuery,
              selectedCount: selectedDraftIds.length,
              refreshing: refreshing,
              automationEnabled: automationEnabled,
              automationBusy: automationBusy,
              onPageSizeChanged: onPageSizeChanged,
              onSearchChanged: onSearchChanged,
              onDeleteSelected: onDeleteSelected,
              onAutomationChanged: onAutomationChanged,
              onRefresh: onRefresh,
              onOpenSources: onOpenSources,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _AutomaticNewsDataTable(
                drafts: drafts,
                loading: loading,
                selectedDraftIds: selectedDraftIds,
                imageRequestHeaders: imageRequestHeaders,
                sortState: sortState,
                onSort: onSort,
                onToggleDraft: onToggleDraft,
                onToggleVisibleDrafts: onToggleVisibleDrafts,
                onViewDraft: onViewDraft,
                onEditDraft: onEditDraft,
                onDownloadDraftImage: onDownloadDraftImage,
                onDeleteDraft: onDeleteDraft,
              ),
            ),
            const SizedBox(height: 16),
            _AutomaticNewsFooter(
              page: page,
              pageSize: pageSize,
              totalCount: totalCount,
              pageCount: pageCount,
              onPageChanged: onPageChanged,
            ),
          ],
        );
      },
    );
  }
}

class _AutomaticNewsMobileView extends StatefulWidget {
  const _AutomaticNewsMobileView({
    required this.drafts,
    required this.totalCount,
    required this.page,
    required this.pageCount,
    required this.pageSize,
    required this.loading,
    required this.refreshing,
    required this.automationEnabled,
    required this.automationBusy,
    required this.searchController,
    required this.selectedDraftIds,
    required this.platformFilter,
    required this.categoryFilter,
    required this.statusFilter,
    required this.languageFilter,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onPlatformChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onLanguageChanged,
    required this.onClearFilters,
    required this.onPageChanged,
    required this.onToggleDraft,
    required this.onDeleteSelected,
    required this.onAutomationChanged,
    required this.onRefresh,
    required this.onOpenSources,
    required this.onViewDraft,
    required this.onEditDraft,
    required this.onDownloadDraftImage,
    required this.onDeleteDraft,
  });

  final List<_AutomaticNewsDraft> drafts;
  final int totalCount;
  final int page;
  final int pageCount;
  final int pageSize;
  final bool loading;
  final bool refreshing;
  final bool automationEnabled;
  final bool automationBusy;
  final TextEditingController searchController;
  final Set<int> selectedDraftIds;
  final String platformFilter;
  final String categoryFilter;
  final String statusFilter;
  final String languageFilter;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onLanguageChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onToggleDraft;
  final VoidCallback onDeleteSelected;
  final ValueChanged<bool> onAutomationChanged;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSources;
  final ValueChanged<_AutomaticNewsDraft> onViewDraft;
  final ValueChanged<_AutomaticNewsDraft> onEditDraft;
  final ValueChanged<_AutomaticNewsDraft> onDownloadDraftImage;
  final ValueChanged<_AutomaticNewsDraft> onDeleteDraft;

  @override
  State<_AutomaticNewsMobileView> createState() =>
      _AutomaticNewsMobileViewState();
}

class _AutomaticNewsMobileViewState extends State<_AutomaticNewsMobileView> {
  var _filtersExpanded = false;

  int get _activeFilterCount {
    var count = 0;
    if (widget.platformFilter != _AutomaticNewsScreenState._all) count++;
    if (widget.categoryFilter != _AutomaticNewsScreenState._all) count++;
    if (widget.statusFilter != _AutomaticNewsScreenState._all) count++;
    if (widget.languageFilter != _AutomaticNewsScreenState._all) count++;
    return count;
  }

  void _toggleFilters() {
    setState(() => _filtersExpanded = !_filtersExpanded);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final safePageCount = widget.pageCount < 1 ? 1 : widget.pageCount;
    final safePage = widget.page.clamp(1, safePageCount).toInt();
    final start = widget.totalCount == 0
        ? 0
        : ((safePage - 1) * widget.pageSize) + 1;
    final end = widget.totalCount == 0
        ? 0
        : (safePage * widget.pageSize).clamp(0, widget.totalCount).toInt();
    final rangeText = '$start - $end / ${widget.totalCount} kayıt gösteriliyor';
    final hasSelection = widget.selectedDraftIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AutomaticNewsMobileFilterPanel(
          searchController: widget.searchController,
          hintText: 'Ara...',
          onSearchChanged: widget.onSearchChanged,
          isExpanded: _filtersExpanded,
          onToggleExpanded: _toggleFilters,
          activeFilterCount: _activeFilterCount,
          recordCount: widget.totalCount,
          pageSize: widget.pageSize,
          platformFilter: widget.platformFilter,
          categoryFilter: widget.categoryFilter,
          statusFilter: widget.statusFilter,
          languageFilter: widget.languageFilter,
          onPageSizeChanged: widget.onPageSizeChanged,
          onPlatformChanged: widget.onPlatformChanged,
          onCategoryChanged: widget.onCategoryChanged,
          onStatusChanged: widget.onStatusChanged,
          onLanguageChanged: widget.onLanguageChanged,
          onClearFilters: _activeFilterCount == 0
              ? null
              : widget.onClearFilters,
        ),
        const SizedBox(height: 8),
        hasSelection
            ? AdminMobileSelectionBar(
                selectedCount: widget.selectedDraftIds.length,
                label:
                    '${widget.selectedDraftIds.length} otomatik haber seçildi',
                onClear: () {
                  for (final id in widget.selectedDraftIds.toList()) {
                    widget.onToggleDraft(id);
                  }
                },
                onDelete: widget.onDeleteSelected,
              )
            : _AutomaticNewsMobileActionRow(
                refreshing: widget.refreshing,
                automationEnabled: widget.automationEnabled,
                automationBusy: widget.automationBusy,
                onAutomationChanged: widget.onAutomationChanged,
                onRefresh: widget.onRefresh,
                onOpenSources: widget.onOpenSources,
              ),
        const SizedBox(height: 14),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: AdminMobileListView(
                  loading: widget.loading,
                  itemCount: widget.drafts.length,
                  emptyLabel: 'Çekilmiş haber bulunamadı',
                  itemBuilder: (context, index) {
                    final draft = widget.drafts[index];
                    return _AutomaticNewsMobileCard(
                      draft: draft,
                      selected: widget.selectedDraftIds.contains(draft.id),
                      onToggle: () => widget.onToggleDraft(draft.id),
                      onView: () => widget.onViewDraft(draft),
                      onEdit: () => widget.onEditDraft(draft),
                      onDownload: () => widget.onDownloadDraftImage(draft),
                      onDelete: () => widget.onDeleteDraft(draft),
                    );
                  },
                ),
              ),
              if (widget.loading && widget.drafts.isNotEmpty)
                const Positioned.fill(
                  child: _AutomaticNewsMobileLoadingOverlay(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _AutomaticNewsMobileBottomPager(
          page: safePage,
          lastPage: safePageCount,
          rangeText: rangeText,
          loading: widget.loading,
          onPageChanged: widget.onPageChanged,
        ),
      ],
    );
  }
}

class _AutomaticNewsMobileFilterPanel extends StatelessWidget {
  const _AutomaticNewsMobileFilterPanel({
    required this.searchController,
    required this.hintText,
    required this.onSearchChanged,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.activeFilterCount,
    required this.recordCount,
    required this.pageSize,
    required this.platformFilter,
    required this.categoryFilter,
    required this.statusFilter,
    required this.languageFilter,
    required this.onPageSizeChanged,
    required this.onPlatformChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onLanguageChanged,
    required this.onClearFilters,
  });

  static const _borderColor = Color(0xFFE6EAF0);
  static const _muted = Color(0xFF9AA3AA);
  static const _navy = Color(0xFF2F4053);

  final TextEditingController searchController;
  final String hintText;
  final ValueChanged<String> onSearchChanged;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final int activeFilterCount;
  final int recordCount;
  final int pageSize;
  final String platformFilter;
  final String categoryFilter;
  final String statusFilter;
  final String languageFilter;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onLanguageChanged;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 9),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const SymbolIcon(
                          Symbols.search,
                          color: _muted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextField(
                                controller: searchController,
                                onChanged: onSearchChanged,
                                textAlignVertical: TextAlignVertical.center,
                                cursorColor: _navy,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: _navy,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: hintText,
                                  hintStyle: const TextStyle(
                                    color: _muted,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                              Container(
                                height: 1,
                                color: const Color(0xFFB9BEC4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onToggleExpanded,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isExpanded ? 'Gizle' : 'Göster',
                                style: const TextStyle(
                                  color: _navy,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              RotatedBox(
                                quarterTurns: isExpanded ? 2 : 0,
                                child: const SymbolIcon(
                                  Symbols.keyboard_arrow_down,
                                  color: _navy,
                                  size: 17,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$recordCount kayıt',
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeFilterCount == 0
                                ? 'Filtre yok'
                                : '$activeFilterCount filtre',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: _borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      _AutomaticNewsMobilePageSizeDropdown(
                        value: pageSize,
                        onChanged: onPageSizeChanged,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AutomaticNewsMobileFilterDropdown(
                          icon: Symbols.public_outlined,
                          label: 'Platform',
                          value: platformFilter,
                          items: _automaticNewsMobileFilterItems(_platforms),
                          onChanged: onPlatformChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _AutomaticNewsMobileFilterDropdown(
                          icon: Symbols.folder_open,
                          label: 'Kategori',
                          value: categoryFilter,
                          items: _automaticNewsMobileFilterItems(_categories),
                          onChanged: onCategoryChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AutomaticNewsMobileFilterDropdown(
                          icon: Symbols.visibility,
                          label: 'Durum',
                          value: statusFilter,
                          items: _automaticNewsMobileFilterItems(_statuses),
                          onChanged: onStatusChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _AutomaticNewsMobileFilterDropdown(
                    icon: Symbols.language,
                    label: 'Dil',
                    value: languageFilter,
                    items: _automaticNewsMobileFilterItems(_languages),
                    onChanged: onLanguageChanged,
                  ),
                  if (onClearFilters != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onClearFilters,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.actionRed,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text(
                          'Temizle',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

List<DropdownMenuItem<String>> _automaticNewsMobileFilterItems(
  List<String> values,
) {
  return [
    const DropdownMenuItem(value: 'Tümü', child: Text('Tümü')),
    for (final value in values)
      DropdownMenuItem(value: value, child: Text(value)),
  ];
}

class _AutomaticNewsMobilePageSizeDropdown extends StatelessWidget {
  const _AutomaticNewsMobilePageSizeDropdown({
    required this.value,
    required this.onChanged,
  });

  static const _values = ['25', '50', '100'];

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = _values.contains(value.toString())
        ? value.toString()
        : '25';
    return Container(
      width: 66,
      height: 42,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(10),
          icon: const SymbolIcon(
            Symbols.keyboard_arrow_down,
            color: Color(0xFF6F7780),
            size: 16,
          ),
          style: const TextStyle(
            color: Color(0xFF2F4053),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            DropdownMenuItem(value: '25', child: Text('25')),
            DropdownMenuItem(value: '50', child: Text('50')),
            DropdownMenuItem(value: '100', child: Text('100')),
          ],
          onChanged: (value) => onChanged(int.tryParse(value ?? '')),
        ),
      ),
    );
  }
}

class _AutomaticNewsMobileFilterDropdown extends StatelessWidget {
  const _AutomaticNewsMobileFilterDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.any((item) => item.value == value)
        ? value
        : (items.isEmpty ? null : items.first.value);

    return Container(
      height: 42,
      padding: const EdgeInsets.only(left: 10, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Row(
        children: [
          SymbolIcon(icon, color: const Color(0xFF7C858D), size: 17),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7076),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeValue,
                isDense: true,
                isExpanded: true,
                alignment: Alignment.centerRight,
                borderRadius: BorderRadius.circular(10),
                dropdownColor: Colors.white,
                icon: const SymbolIcon(
                  Symbols.keyboard_arrow_down,
                  color: Color(0xFFB0B8BE),
                  size: 16,
                ),
                style: const TextStyle(
                  color: Color(0xFF2F4053),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomaticNewsMobileActionRow extends StatelessWidget {
  const _AutomaticNewsMobileActionRow({
    required this.refreshing,
    required this.automationEnabled,
    required this.automationBusy,
    required this.onAutomationChanged,
    required this.onRefresh,
    required this.onOpenSources,
  });

  static const _red = Color(0xFFF44336);

  final bool refreshing;
  final bool automationEnabled;
  final bool automationBusy;
  final ValueChanged<bool> onAutomationChanged;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSources;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _AutomaticNewsAutomationSwitch(
            value: automationEnabled,
            busy: automationBusy,
            onChanged: onAutomationChanged,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _AutomaticNewsMobileActionButton(
                icon: Symbols.refresh_line,
                label: refreshing ? 'Yenileniyor...' : 'Listeyi Yenile',
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2F4053),
                borderColor: const Color(0xFFE6EAF0),
                onPressed: refreshing ? null : onRefresh,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AutomaticNewsMobileActionButton(
                icon: Symbols.add,
                label: 'Adres Ekle',
                backgroundColor: _red,
                foregroundColor: Colors.white,
                onPressed: onOpenSources,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AutomaticNewsAutomationSwitch extends StatelessWidget {
  const _AutomaticNewsAutomationSwitch({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value ? 'Otomasyon açık' : 'Otomasyon kapalı';
    return Opacity(
      opacity: busy ? 0.62 : 1,
      child: MouseRegion(
        cursor: busy ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: busy ? null : () => onChanged(!value),
          child: Container(
            height: AdminTableChrome.toolbarHeight,
            padding: const EdgeInsets.only(left: 12, right: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 10),
                IgnorePointer(
                  ignoring: busy,
                  child: _CompactSwitch(value: value, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AutomaticNewsMobileActionButton extends StatelessWidget {
  const _AutomaticNewsMobileActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor,
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.55),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: borderColor ?? backgroundColor),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(
              icon,
              color: onPressed == null
                  ? foregroundColor.withValues(alpha: 0.55)
                  : foregroundColor,
              size: 17,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutomaticNewsMobileCard extends StatelessWidget {
  const _AutomaticNewsMobileCard({
    required this.draft,
    required this.selected,
    required this.onToggle,
    required this.onView,
    required this.onEdit,
    required this.onDownload,
    required this.onDelete,
  });

  final _AutomaticNewsDraft draft;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AdminMobileCard(
      selected: selected,
      onTap: onView,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: AdminMobileCheckbox(
                  value: selected,
                  onChanged: (_) => onToggle(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2F4053),
                        fontWeight: FontWeight.w700,
                        fontSize: 14.2,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${draft.id} • ${_readableText(draft.sourceName)} • ${draft.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7A7F85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Transform.scale(
                scale: 0.88,
                alignment: Alignment.topRight,
                child: AdminMobileMenuButton(
                  tooltip: 'İşlemler',
                  actions: [
                    AdminMobileMenuAction(
                      icon: Symbols.visibility,
                      label: 'Haberi Görüntüle',
                      onTap: onView,
                    ),
                    AdminMobileMenuAction(
                      icon: Symbols.edit_square,
                      label: 'Haberi düzenle',
                      onTap: onEdit,
                    ),
                    if (draft.imageUrl.isNotEmpty)
                      AdminMobileMenuAction(
                        icon: Symbols.download,
                        label: 'Resmi indir',
                        onTap: onDownload,
                      ),
                    AdminMobileMenuAction(
                      icon: Symbols.delete,
                      label: 'Sil',
                      danger: true,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _AutomaticNewsMobileStatusBadge(value: draft.status),
              _AutomaticNewsMobileMetricChip(
                icon: _platformIcon(draft.platform),
                label: draft.platform,
              ),
              _AutomaticNewsMobileMetricChip(
                icon: Symbols.language,
                label: draft.language,
              ),
              _AutomaticNewsMobileMetricChip(
                icon: Symbols.verified,
                label: '%${draft.quality} kalite',
              ),
              if (draft.hasDuplicateWarning)
                _AutomaticNewsMobileMetricChip(
                  icon: Symbols.warning,
                  label: 'Olası tekrar',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutomaticNewsMobileStatusBadge extends StatelessWidget {
  const _AutomaticNewsMobileStatusBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final ready = value == 'Hazır';
    final review = value == 'İncele';
    final color = ready
        ? const Color(0xFF12825F)
        : review
        ? AppColors.warmHorizon
        : AppColors.inkSoft;
    final background = ready
        ? const Color(0xFFEAF7F1)
        : review
        ? const Color(0xFFFFF6E7)
        : AppColors.surface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _AutomaticNewsMobileMetricChip extends StatelessWidget {
  const _AutomaticNewsMobileMetricChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SymbolIcon(icon, color: const Color(0xFF9AA3AA), size: 13),
        const SizedBox(width: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF7A7F85),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _AutomaticNewsMobileLoadingOverlay extends StatelessWidget {
  const _AutomaticNewsMobileLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white70,
      child: Center(
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.actionRed,
            ),
          ),
        ),
      ),
    );
  }
}

class _AutomaticNewsMobileBottomPager extends StatelessWidget {
  const _AutomaticNewsMobileBottomPager({
    required this.page,
    required this.lastPage,
    required this.rangeText,
    required this.loading,
    required this.onPageChanged,
  });

  final int page;
  final int lastPage;
  final String rangeText;
  final bool loading;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final hasPrevious = page > 1 && !loading;
    final hasNext = page < lastPage && !loading;
    return Transform.translate(
      offset: const Offset(0, 14),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            _AutomaticNewsMobileBottomPagerArrow(
              icon: Symbols.chevron_left_rounded,
              enabled: hasPrevious,
              onPressed: () => onPageChanged(page - 1),
            ),
            Expanded(
              child: Text(
                rangeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB8BDC3),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
            _AutomaticNewsMobileBottomPagerArrow(
              icon: Symbols.chevron_right,
              enabled: hasNext,
              onPressed: () => onPageChanged(page + 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutomaticNewsMobileBottomPagerArrow extends StatelessWidget {
  const _AutomaticNewsMobileBottomPagerArrow({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Icon(
      icon,
      color: enabled ? AppColors.deepOcean : const Color(0xFFC5CAD0),
      size: 18,
    );
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: child,
      constraints: const BoxConstraints.tightFor(width: 30, height: 28),
      padding: EdgeInsets.zero,
      splashRadius: 16,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AutomaticNewsFilters extends StatelessWidget {
  const _AutomaticNewsFilters({
    required this.platformFilter,
    required this.categoryFilter,
    required this.statusFilter,
    required this.languageFilter,
    required this.onPlatformChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onLanguageChanged,
  });

  final String platformFilter;
  final String categoryFilter;
  final String statusFilter;
  final String languageFilter;
  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1040;
        final filters = [
          _FilterSelect(
            label: 'Platform',
            value: platformFilter,
            items: _filterItems(_platforms),
            onChanged: onPlatformChanged,
          ),
          _FilterSelect(
            label: 'Kategori',
            value: categoryFilter,
            items: _filterItems(_categories),
            onChanged: onCategoryChanged,
          ),
          _FilterSelect(
            label: 'Durum',
            value: statusFilter,
            items: _filterItems(_statuses),
            onChanged: onStatusChanged,
          ),
          _FilterSelect(
            label: 'Dil',
            value: languageFilter,
            items: _filterItems(_languages),
            onChanged: onLanguageChanged,
          ),
        ];

        if (compact) {
          return Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              for (final filter in filters)
                SizedBox(
                  width: constraints.maxWidth < 560
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 16) / 2,
                  child: filter,
                ),
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < filters.length; index++) ...[
              Expanded(child: filters[index]),
              if (index != filters.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }

  List<DropdownMenuItem<String>> _filterItems(List<String> values) {
    return [
      const DropdownMenuItem(value: 'Tümü', child: Text('Tümü')),
      for (final value in values)
        DropdownMenuItem(value: value, child: Text(value)),
    ];
  }
}

class _FilterSelect extends StatelessWidget {
  const _FilterSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.any((item) => item.value == value)
        ? value
        : (items.isEmpty ? null : items.first.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ControlLabel(label),
        const SizedBox(height: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: AdminTableChrome.toolbarHeight,
            padding: const EdgeInsets.only(left: 12, right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: safeValue,
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
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AutomaticNewsToolbar extends StatelessWidget {
  const _AutomaticNewsToolbar({
    required this.compact,
    required this.pageSize,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCount,
    required this.refreshing,
    required this.automationEnabled,
    required this.automationBusy,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onDeleteSelected,
    required this.onAutomationChanged,
    required this.onRefresh,
    required this.onOpenSources,
  });

  final bool compact;
  final int pageSize;
  final TextEditingController searchController;
  final String searchQuery;
  final int selectedCount;
  final bool refreshing;
  final bool automationEnabled;
  final bool automationBusy;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onDeleteSelected;
  final ValueChanged<bool> onAutomationChanged;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSources;

  @override
  Widget build(BuildContext context) {
    final pageSizeSelect = AdminTablePageSizeSelect(
      value: pageSize,
      onChanged: onPageSizeChanged,
    );
    final deleteButton = selectedCount == 0
        ? null
        : AdminTablePrimaryActionButton(
            icon: Symbols.delete,
            label: 'Seçili $selectedCount haberi sil',
            onPressed: onDeleteSelected,
          );
    final search = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: compact ? double.infinity : 260,
        maxWidth: compact ? double.infinity : 280,
      ),
      child: AdminTableSearchField(
        controller: searchController,
        hintText: 'Search...',
        query: searchQuery,
        showClearButton: true,
        onChanged: onSearchChanged,
      ),
    );
    final refreshButton = AdminTableSecondaryActionButton(
      icon: Symbols.refresh_line,
      label: refreshing ? 'Yenileniyor...' : 'Listeyi Yenile',
      onPressed: refreshing ? () {} : onRefresh,
    );
    final automationSwitch = _AutomaticNewsAutomationSwitch(
      value: automationEnabled,
      busy: automationBusy,
      onChanged: onAutomationChanged,
    );
    final addressButton = AdminTablePrimaryActionButton(
      icon: Symbols.add,
      label: 'Adres Ekle',
      onPressed: onOpenSources,
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: pageSizeSelect),
          if (deleteButton != null) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: deleteButton),
          ],
          const SizedBox(height: 14),
          search,
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [automationSwitch, refreshButton, addressButton],
          ),
        ],
      );
    }

    return Row(
      children: [
        pageSizeSelect,
        if (deleteButton != null) ...[const SizedBox(width: 12), deleteButton],
        const Spacer(),
        search,
        const SizedBox(width: 14),
        automationSwitch,
        const SizedBox(width: 10),
        refreshButton,
        const SizedBox(width: 10),
        addressButton,
      ],
    );
  }
}

class _AutomaticNewsDataTable extends StatelessWidget {
  const _AutomaticNewsDataTable({
    required this.drafts,
    required this.loading,
    required this.selectedDraftIds,
    required this.imageRequestHeaders,
    required this.sortState,
    required this.onSort,
    required this.onToggleDraft,
    required this.onToggleVisibleDrafts,
    required this.onViewDraft,
    required this.onEditDraft,
    required this.onDownloadDraftImage,
    required this.onDeleteDraft,
  });

  final List<_AutomaticNewsDraft> drafts;
  final bool loading;
  final Set<int> selectedDraftIds;
  final Map<String, String> imageRequestHeaders;
  final TableSortState sortState;
  final ValueChanged<String> onSort;
  final ValueChanged<int> onToggleDraft;
  final VoidCallback onToggleVisibleDrafts;
  final ValueChanged<_AutomaticNewsDraft> onViewDraft;
  final ValueChanged<_AutomaticNewsDraft> onEditDraft;
  final ValueChanged<_AutomaticNewsDraft> onDownloadDraftImage;
  final ValueChanged<_AutomaticNewsDraft> onDeleteDraft;

  static const double _selectWidth = 42;
  static const double _idWidth = 62;
  static const double _postMinWidth = 330;
  static const double _sourceWidth = 150;
  static const double _statusWidth = 118;
  static const double _languageWidth = 84;
  static const double _originWidth = 210;
  static const double _qualityWidth = 94;
  static const double _dateWidth = 150;
  static const double _menuWidth = 70;
  static const double _horizontalPadding = 32;
  static const double _tableBorderWidth = 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fixedWidth =
            _horizontalPadding +
            _tableBorderWidth +
            _selectWidth +
            _idWidth +
            _sourceWidth +
            _statusWidth +
            _languageWidth +
            _originWidth +
            _qualityWidth +
            _dateWidth +
            _menuWidth;
        final requiredMinWidth = fixedWidth + _postMinWidth;
        final tableWidth = constraints.maxWidth < requiredMinWidth
            ? requiredMinWidth
            : constraints.maxWidth;
        final postWidth = (tableWidth - fixedWidth) < _postMinWidth
            ? _postMinWidth
            : tableWidth - fixedWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(
                  color: AppColors.line.withValues(alpha: 0.72),
                ),
              ),
              child: Column(
                children: [
                  _AutomaticNewsHeader(
                    selectedCount: selectedDraftIds.length,
                    totalCount: drafts.length,
                    postWidth: postWidth,
                    sortState: sortState,
                    onToggleVisibleDrafts: onToggleVisibleDrafts,
                    onSort: onSort,
                  ),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.actionRed,
                              ),
                            ),
                          )
                        : drafts.isEmpty
                        ? const _AutomaticNewsEmpty()
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final draft in drafts)
                                  _AutomaticNewsRow(
                                    draft: draft,
                                    imageRequestHeaders: imageRequestHeaders,
                                    postWidth: postWidth,
                                    selected: selectedDraftIds.contains(
                                      draft.id,
                                    ),
                                    onToggle: () => onToggleDraft(draft.id),
                                    onView: () => onViewDraft(draft),
                                    onEdit: () => onEditDraft(draft),
                                    onDownload: () =>
                                        onDownloadDraftImage(draft),
                                    onDelete: () => onDeleteDraft(draft),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AutomaticNewsHeader extends StatelessWidget {
  const _AutomaticNewsHeader({
    required this.selectedCount,
    required this.totalCount,
    required this.postWidth,
    required this.sortState,
    required this.onToggleVisibleDrafts,
    required this.onSort,
  });

  final int selectedCount;
  final int totalCount;
  final double postWidth;
  final TableSortState sortState;
  final VoidCallback onToggleVisibleDrafts;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _AutomaticNewsDataTable._selectWidth,
            child: _AutoNewsCheckbox(
              value: selectedCount == 0 || totalCount == 0
                  ? false
                  : selectedCount == totalCount
                  ? true
                  : null,
              tristate: true,
              onChanged: (_) => onToggleVisibleDrafts(),
            ),
          ),
          _SortableColumnHeader(
            width: _AutomaticNewsDataTable._idWidth,
            label: 'ID',
            sortKey: 'id',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: postWidth,
            label: 'Haber',
            sortKey: 'post',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: _AutomaticNewsDataTable._sourceWidth,
            label: 'Kaynak',
            sortKey: 'source',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: _AutomaticNewsDataTable._statusWidth,
            label: 'Durum',
            sortKey: 'status',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: _AutomaticNewsDataTable._languageWidth,
            label: 'Dil',
            sortKey: 'language',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: _AutomaticNewsDataTable._originWidth,
            label: 'Alındığı Yer',
            sortKey: 'origin',
            sortState: sortState,
            onSort: onSort,
          ),
          const SizedBox(
            width: _AutomaticNewsDataTable._qualityWidth,
            child: _HeaderText('Kalite', centered: true),
          ),
          _SortableColumnHeader(
            width: _AutomaticNewsDataTable._dateWidth,
            label: 'Tarih',
            sortKey: 'date',
            sortState: sortState,
            onSort: onSort,
          ),
          const SizedBox(
            width: _AutomaticNewsDataTable._menuWidth,
            child: _HeaderText('İşlem', centered: true),
          ),
        ],
      ),
    );
  }
}

class _SortableColumnHeader extends StatelessWidget {
  const _SortableColumnHeader({
    required this.width,
    required this.label,
    required this.sortKey,
    required this.sortState,
    required this.onSort,
    this.centered = false,
  });

  final double width;
  final String label;
  final String sortKey;
  final TableSortState sortState;
  final ValueChanged<String> onSort;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final selected = sortState.key == sortKey;
    final icon = SymbolIcon(
      Symbols.keyboard_arrow_down,
      color: selected ? AppColors.deepOcean : AppColors.support,
      size: 14,
    );

    return SizedBox(
      width: width,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSort(sortKey),
          child: Align(
            alignment: centered ? Alignment.center : Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppColors.deepOcean : AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                selected && sortState.ascending
                    ? RotatedBox(quarterTurns: 2, child: icon)
                    : icon,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AutomaticNewsRow extends StatelessWidget {
  const _AutomaticNewsRow({
    required this.draft,
    required this.imageRequestHeaders,
    required this.postWidth,
    required this.selected,
    required this.onToggle,
    required this.onView,
    required this.onEdit,
    required this.onDownload,
    required this.onDelete,
  });

  final _AutomaticNewsDraft draft;
  final Map<String, String> imageRequestHeaders;
  final double postWidth;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selected ? AppColors.surface : Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _AutomaticNewsDataTable._selectWidth,
            child: _AutoNewsCheckbox(
              value: selected,
              onChanged: (_) => onToggle(),
            ),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._idWidth,
            child: _RowTapTarget(
              onTap: onToggle,
              child: Text(
                draft.id.toString(),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          SizedBox(
            width: postWidth,
            child: _DraftIdentity(
              draft: draft,
              imageRequestHeaders: imageRequestHeaders,
            ),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._sourceWidth,
            child: _SourceCell(draft: draft),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._statusWidth,
            child: Center(child: _StatusBadge(value: draft.status)),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._languageWidth,
            child: Center(child: _LanguageBadge(value: draft.language)),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._originWidth,
            child: _OriginCell(draft: draft),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._qualityWidth,
            child: Center(child: _QualityBadge(value: draft.quality)),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._dateWidth,
            child: _DateCell(dateTime: draft.capturedAt),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._menuWidth,
            child: Align(
              alignment: Alignment.center,
              child: _AutomaticNewsRowMenu(
                onView: onView,
                onEdit: onEdit,
                onDownload: onDownload,
                canDownload: draft.imageUrl.isNotEmpty,
                onDelete: onDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftIdentity extends StatelessWidget {
  const _DraftIdentity({
    required this.draft,
    required this.imageRequestHeaders,
  });

  final _AutomaticNewsDraft draft;
  final Map<String, String> imageRequestHeaders;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DraftPreview(draft: draft, imageRequestHeaders: imageRequestHeaders),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                draft.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: 0,
                ),
              ),
              if (draft.hasDuplicateWarning) ...[
                const SizedBox(height: 6),
                _DuplicateWarningChip(draft: draft, compact: true),
              ],
              const SizedBox(height: 7),
              Row(
                children: [
                  _MiniTag(draft.category),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      draft.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DraftPreview extends StatelessWidget {
  const _DraftPreview({required this.draft, required this.imageRequestHeaders});

  final _AutomaticNewsDraft draft;
  final Map<String, String> imageRequestHeaders;

  @override
  Widget build(BuildContext context) {
    final color = _platformColor(draft.platform);
    final mediaUrl = _automaticNewsImageDisplayUrl(
      draft,
      width: 140,
      imageRequestHeaders: imageRequestHeaders,
    );
    final hasVideo = draft.videoUrl.isNotEmpty;

    return Container(
      width: 54,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: mediaUrl.isEmpty
          ? _DraftPreviewFallback(platform: draft.platform, hasVideo: hasVideo)
          : Stack(
              fit: StackFit.expand,
              children: [
                AdminCachedImage(
                  url: mediaUrl,
                  httpHeaders: _automaticNewsImageHttpHeaders(
                    imageRequestHeaders,
                  ),
                  fit: BoxFit.cover,
                  memCacheWidth: 140,
                  fadeIn: false,
                  errorWidget: _DraftPreviewFallback(
                    platform: draft.platform,
                    hasVideo: hasVideo,
                  ),
                ),
                if (hasVideo)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.all(4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.deepOcean.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const SymbolIcon(
                        Symbols.videocam_outlined,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DraftPreviewFallback extends StatelessWidget {
  const _DraftPreviewFallback({required this.platform, required this.hasVideo});

  final String platform;
  final bool hasVideo;

  @override
  Widget build(BuildContext context) {
    final color = _platformColor(platform);
    final icon = hasVideo ? Symbols.videocam_outlined : _platformIcon(platform);
    return Center(child: SymbolIcon(icon, color: color, size: 22));
  }
}

String _automaticNewsImageDisplayUrl(
  _AutomaticNewsDraft draft, {
  required int width,
  required Map<String, String> imageRequestHeaders,
}) {
  final imageUrl = draft.imageUrl.trim();
  if (imageUrl.isEmpty) return '';
  if (kIsWeb &&
      imageRequestHeaders.isNotEmpty &&
      draft.recordId.trim().isNotEmpty) {
    return Uri.base
        .resolve('/api/admin/automatic-news/image')
        .replace(
          queryParameters: {
            'id': draft.recordId,
            'disposition': 'inline',
            'w': '$width',
          },
        )
        .toString();
  }
  return adminImageUrl(imageUrl, width: width);
}

bool _automaticNewsPreviewImageUsesProxy(
  _AutomaticNewsDraft draft,
  Map<String, String> imageRequestHeaders,
) {
  return kIsWeb &&
      imageRequestHeaders.isNotEmpty &&
      draft.recordId.trim().isNotEmpty;
}

String _automaticNewsPreviewImageDisplayUrl(
  _AutomaticNewsDraft draft,
  String imageUrl, {
  required int imageIndex,
  required int width,
  required bool mediaLoaded,
  required Map<String, String> imageRequestHeaders,
}) {
  if (_automaticNewsPreviewImageUsesProxy(draft, imageRequestHeaders)) {
    final path = mediaLoaded
        ? '/api/admin/automatic-news/media'
        : '/api/admin/automatic-news/image';
    final query = mediaLoaded
        ? {'id': draft.recordId, 'image': '$imageIndex', 'w': '$width'}
        : {'id': draft.recordId, 'disposition': 'inline', 'w': '$width'};
    return Uri.base.resolve(path).replace(queryParameters: query).toString();
  }
  return adminImageUrl(imageUrl, width: width);
}

Map<String, String>? _automaticNewsImageHttpHeaders(
  Map<String, String> imageRequestHeaders,
) {
  return kIsWeb && imageRequestHeaders.isNotEmpty ? imageRequestHeaders : null;
}

IconData _platformIcon(String platform) {
  return switch (platform) {
    'Instagram' => Symbols.instagram_fill,
    'Facebook' => Symbols.facebook_fill,
    'X' => Symbols.twitter_x_fill,
    'RSS' => Symbols.rss_feed_outlined,
    _ => Symbols.link,
  };
}

Color _platformColor(String platform) {
  return switch (platform) {
    'Instagram' => const Color(0xFFE4405F),
    'Facebook' => const Color(0xFF1877F2),
    'X' => AppColors.deepOcean,
    'RSS' => AppColors.warmHorizon,
    _ => AppColors.iconMuted,
  };
}

String _compactUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '-';
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty) return raw;
  final path = uri.path.isEmpty ? '' : uri.path;
  return '${uri.host}$path';
}

String _readableText(String value, {String fallback = '-'}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String _previewSourceName(_AutomaticNewsDraft draft) {
  final raw = draft.sourceName.trim().isNotEmpty
      ? draft.sourceName.trim()
      : draft.sourceUrl.trim();
  if (raw.isEmpty) return '-';
  if (raw.startsWith('@')) return raw;

  final parsed = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
  var name = parsed?.host.isNotEmpty == true ? parsed!.host : raw;
  name = name
      .replaceFirst(RegExp(r'^www\.', caseSensitive: false), '')
      .replaceFirst(
        RegExp(r'\.(com|net|org|info|haber|tv)(\.tr)?$', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'[-_.]+'), ' ')
      .trim();
  name = name.replaceAll(RegExp('nigde', caseSensitive: false), 'niğde');
  name = name.replaceAllMapped(
    RegExp(r'([A-Za-zÇĞİÖŞÜçğıöşü])haber\b', caseSensitive: false),
    (match) => '${match.group(1)} haber',
  );

  return name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(_sourceNameWord)
      .join(' ');
}

String _sourceNameWord(String value) {
  final lower = value.toLowerCase();
  if (lower == 'niğde') return 'Niğde';
  if (lower == 'dmc') return 'Dmc';
  return '${value.characters.first.toUpperCase()}'
      '${value.characters.skip(1).toString().toLowerCase()}';
}

void _openPreviewLink(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;
  unawaited(openNewsLink(trimmed));
}

Future<void> _copyPreviewText(
  BuildContext context,
  String value, {
  String message = 'Metin kopyalandı',
}) async {
  final text = _readableText(value, fallback: '').trim();
  if (text.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  AdminToast.show(context, message: message, tone: AdminToastTone.success);
}

String _fileExtension(String fileName) {
  final normalized = fileName.trim();
  final index = normalized.lastIndexOf('.');
  if (index < 0 || index == normalized.length - 1) return '';
  final extension = normalized.substring(index + 1).toLowerCase();
  return RegExp(r'^[a-z0-9]{2,5}$').hasMatch(extension) ? extension : '';
}

String _fileNameWithoutExtension(String fileName) {
  final normalized = fileName.trim();
  if (normalized.isEmpty) return 'otomatik-haber-gorseli';
  final index = normalized.lastIndexOf('.');
  if (index <= 0) return normalized;
  return normalized.substring(0, index).trim().isEmpty
      ? 'otomatik-haber-gorseli'
      : normalized.substring(0, index).trim();
}

String _fileExtensionForMimeType(String mimeType) {
  final normalized = mimeType.split(';').first.trim().toLowerCase();
  return switch (normalized) {
    'image/jpeg' || 'image/jpg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    'image/avif' => 'avif',
    _ => '',
  };
}

class _AutomaticNewsRowMenu extends StatefulWidget {
  const _AutomaticNewsRowMenu({
    required this.onView,
    required this.onEdit,
    required this.onDownload,
    required this.canDownload,
    required this.onDelete,
  });

  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDownload;
  final bool canDownload;
  final VoidCallback onDelete;

  @override
  State<_AutomaticNewsRowMenu> createState() => _AutomaticNewsRowMenuState();
}

class _AutomaticNewsRowMenuState extends State<_AutomaticNewsRowMenu> {
  final _layerLink = LayerLink();
  OverlayEntry? _menuEntry;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _openMenu() {
    if (_menuEntry != null) return;
    _menuEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeMenu,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: _AutomaticNewsMenuCard(
                onView: () => _runAndClose(widget.onView),
                onEdit: () => _runAndClose(widget.onEdit),
                onDownload: () => _runAndClose(widget.onDownload),
                canDownload: widget.canDownload,
                onDelete: () => _runAndClose(widget.onDelete),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_menuEntry!);
  }

  void _runAndClose(VoidCallback action) {
    _closeMenu();
    action();
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _toggleMenu() {
    if (_menuEntry == null) {
      _openMenu();
    } else {
      _closeMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: 'İşlemler',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleMenu,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                '...',
                style: TextStyle(
                  color: AppColors.support.withValues(alpha: 0.92),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutomaticNewsMenuCard extends StatelessWidget {
  const _AutomaticNewsMenuCard({
    required this.onView,
    required this.onEdit,
    required this.onDownload,
    required this.canDownload,
    required this.onDelete,
  });

  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDownload;
  final bool canDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AutomaticNewsMenuItem(
              icon: Symbols.visibility,
              label: 'Haberi Görüntüle',
              onTap: onView,
            ),
            _AutomaticNewsMenuItem(
              icon: Symbols.edit_square,
              label: 'Haberi düzenle',
              onTap: onEdit,
            ),
            if (canDownload)
              _AutomaticNewsMenuItem(
                icon: Symbols.download,
                label: 'Resmi indir',
                onTap: onDownload,
              ),
            _AutomaticNewsMenuItem(
              icon: Symbols.delete,
              label: 'Sil',
              onTap: onDelete,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _AutomaticNewsMenuItem extends StatelessWidget {
  const _AutomaticNewsMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.actionRed : AppColors.deepOcean;
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(AppRadius.value),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            SymbolIcon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
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

class _SourceCell extends StatelessWidget {
  const _SourceCell({required this.draft});

  final _AutomaticNewsDraft draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          draft.platform,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          draft.sourceName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _OriginCell extends StatelessWidget {
  const _OriginCell({required this.draft});

  final _AutomaticNewsDraft draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          draft.origin,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          draft.sourceUrl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final ready = value == 'Hazır';
    final review = value == 'İncele';
    final color = ready
        ? const Color(0xFF12825F)
        : review
        ? AppColors.warmHorizon
        : AppColors.inkSoft;
    final background = ready
        ? const Color(0xFFEAF7F1)
        : review
        ? const Color(0xFFFFF6E7)
        : AppColors.surface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: color.withValues(alpha: 0.08)),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _DuplicateWarningChip extends StatelessWidget {
  const _DuplicateWarningChip({required this.draft, this.compact = false});

  final _AutomaticNewsDraft draft;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final source = _readableText(
      draft.duplicateMatchSource,
      fallback: draft.duplicateMatchTable == 'post'
          ? 'Pateez haberleri'
          : 'Otomatik haberler',
    );
    final label = compact
        ? 'Olası tekrar: $source'
        : 'Olası tekrar %${draft.duplicateScore}: $source';
    return Container(
      constraints: compact ? const BoxConstraints(maxWidth: 260) : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E7),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: AppColors.warmHorizon.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SymbolIcon(
            Symbols.warning,
            color: AppColors.warmHorizon,
            size: 14,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.warmHorizon,
                fontSize: 11.5,
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

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.softLine,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final color = value >= 90
        ? const Color(0xFF12825F)
        : value >= 80
        ? AppColors.warmHorizon
        : AppColors.inkSoft;
    return Text(
      '%$value',
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({required this.dateTime});

  final DateTime dateTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDate(dateTime),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatTime(dateTime),
          style: const TextStyle(
            color: AppColors.placeholder,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inkSoft,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.label, {this.centered = false});

  final String label;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AutoNewsCheckbox extends StatelessWidget {
  const _AutoNewsCheckbox({
    required this.value,
    required this.onChanged,
    this.tristate = false,
  });

  final bool? value;
  final ValueChanged<bool?> onChanged;
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      tristate: tristate,
      onChanged: onChanged,
      checkColor: Colors.white,
      activeColor: AppColors.deepOcean,
      side: BorderSide(color: AppColors.line.withValues(alpha: 0.92)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value / 2),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _RowTapTarget extends StatelessWidget {
  const _RowTapTarget({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ),
    );
  }
}

class _AutomaticNewsEmpty extends StatelessWidget {
  const _AutomaticNewsEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Çekilmiş haber bulunamadı',
        style: TextStyle(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AutomaticNewsPreviewDialog extends StatefulWidget {
  const _AutomaticNewsPreviewDialog({
    required this.draft,
    required this.repository,
    required this.imageRequestHeaders,
  });

  final _AutomaticNewsDraft draft;
  final AdminAutomaticNewsRepository repository;
  final Map<String, String> imageRequestHeaders;

  @override
  State<_AutomaticNewsPreviewDialog> createState() =>
      _AutomaticNewsPreviewDialogState();
}

class _AutomaticNewsPreviewDialogState
    extends State<_AutomaticNewsPreviewDialog> {
  late final Future<AutomaticNewsMediaResult> _mediaFuture;

  @override
  void initState() {
    super.initState();
    _mediaFuture = widget.repository.fetchMedia(widget.draft.recordId);
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth < 1040
              ? constraints.maxWidth
              : 1040.0;
          final maxHeight = constraints.maxHeight < 760
              ? constraints.maxHeight
              : 760.0;
          final compact = maxWidth < 780;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.value),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepOcean.withValues(alpha: 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _AutomaticNewsPreviewHeader(
                      draft: draft,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    Flexible(
                      child: FutureBuilder<AutomaticNewsMediaResult>(
                        future: _mediaFuture,
                        builder: (context, snapshot) {
                          final mediaImages = _previewMediaImages(
                            draft,
                            snapshot.data,
                          );
                          final mediaVideos = _previewMediaVideos(
                            draft,
                            snapshot.data,
                          );
                          final mediaUrls = _previewMediaUrls(
                            draft,
                            snapshot.data,
                          );
                          final mediaLoading =
                              snapshot.connectionState != ConnectionState.done;
                          final mediaLoaded = snapshot.hasData;

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: compact
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _AutomaticNewsPreviewMedia(
                                        draft: draft,
                                        mediaImages: mediaImages,
                                        mediaVideos: mediaVideos,
                                        mediaUrls: mediaUrls,
                                        mediaLoading: mediaLoading,
                                        mediaLoaded: mediaLoaded,
                                        imageRequestHeaders:
                                            widget.imageRequestHeaders,
                                        compact: true,
                                      ),
                                      const SizedBox(height: 20),
                                      _AutomaticNewsPreviewDetails(
                                        draft: draft,
                                      ),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: _AutomaticNewsPreviewMedia(
                                          draft: draft,
                                          mediaImages: mediaImages,
                                          mediaVideos: mediaVideos,
                                          mediaUrls: mediaUrls,
                                          mediaLoading: mediaLoading,
                                          mediaLoaded: mediaLoaded,
                                          imageRequestHeaders:
                                              widget.imageRequestHeaders,
                                          compact: false,
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        flex: 4,
                                        child: _AutomaticNewsPreviewDetails(
                                          draft: draft,
                                        ),
                                      ),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

List<String> _previewMediaImages(
  _AutomaticNewsDraft draft,
  AutomaticNewsMediaResult? media,
) {
  final images = <String>[];
  void add(String value) {
    final url = value.trim();
    if (url.isEmpty) return;
    final key = url.replaceFirst(RegExp(r'[?#].*$'), '');
    final exists = images.any(
      (item) => item.replaceFirst(RegExp(r'[?#].*$'), '') == key,
    );
    if (!exists) images.add(url);
  }

  for (final image in media?.images ?? const <String>[]) {
    add(image);
  }
  add(draft.imageUrl);
  return images;
}

List<String> _previewMediaVideos(
  _AutomaticNewsDraft draft,
  AutomaticNewsMediaResult? media,
) {
  final videos = <String>[];
  void add(String value) {
    final url = value.trim();
    if (url.isEmpty) return;
    final key = url.replaceFirst(RegExp(r'[?#].*$'), '');
    final exists = videos.any(
      (item) => item.replaceFirst(RegExp(r'[?#].*$'), '') == key,
    );
    if (!exists) videos.add(url);
  }

  add(draft.videoUrl);
  for (final video in draft.videoUrls) {
    add(video);
  }
  for (final video in media?.videos ?? const <String>[]) {
    add(video);
  }
  return videos;
}

List<String> _previewMediaUrls(
  _AutomaticNewsDraft draft,
  AutomaticNewsMediaResult? media,
) {
  final urls = <String>[];
  void add(String value) {
    final url = value.trim();
    if (url.isEmpty) return;
    final key = url.replaceFirst(RegExp(r'[?#].*$'), '');
    final exists = urls.any(
      (item) => item.replaceFirst(RegExp(r'[?#].*$'), '') == key,
    );
    if (!exists) urls.add(url);
  }

  for (final url in draft.allMediaUrls) {
    add(url);
  }
  for (final url in media?.mediaUrls ?? const <String>[]) {
    add(url);
  }
  for (final url in media?.images ?? const <String>[]) {
    add(url);
  }
  for (final url in media?.videos ?? const <String>[]) {
    add(url);
  }
  return urls;
}

class _AutomaticNewsPreviewHeader extends StatelessWidget {
  const _AutomaticNewsPreviewHeader({
    required this.draft,
    required this.onClose,
  });

  final _AutomaticNewsDraft draft;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = _platformColor(draft.platform);
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: SymbolIcon(_platformIcon(draft.platform), color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Haberi Görüntüle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${draft.platform} · ${draft.sourceName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kapat',
            onPressed: onClose,
            icon: const SymbolIcon(
              Symbols.close,
              color: AppColors.iconMuted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomaticNewsPreviewMedia extends StatefulWidget {
  const _AutomaticNewsPreviewMedia({
    required this.draft,
    required this.mediaImages,
    required this.mediaVideos,
    required this.mediaUrls,
    required this.mediaLoading,
    required this.mediaLoaded,
    required this.imageRequestHeaders,
    required this.compact,
  });

  final _AutomaticNewsDraft draft;
  final List<String> mediaImages;
  final List<String> mediaVideos;
  final List<String> mediaUrls;
  final bool mediaLoading;
  final bool mediaLoaded;
  final Map<String, String> imageRequestHeaders;
  final bool compact;

  @override
  State<_AutomaticNewsPreviewMedia> createState() =>
      _AutomaticNewsPreviewMediaState();
}

class _AutomaticNewsPreviewMediaState
    extends State<_AutomaticNewsPreviewMedia> {
  late final PageController _controller;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void didUpdateWidget(covariant _AutomaticNewsPreviewMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lastIndex = widget.mediaImages.isEmpty
        ? 0
        : widget.mediaImages.length - 1;
    if (_index > lastIndex) {
      _index = lastIndex;
      if (_controller.hasClients) {
        _controller.jumpToPage(_index);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int delta) {
    final count = widget.mediaImages.length;
    if (count < 2) return;
    final next = (_index + delta).clamp(0, count - 1).toInt();
    if (next == _index) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.mediaImages;
    final hasImage = images.isNotEmpty;
    final videoUrls = widget.mediaVideos;
    final hasVideo = videoUrls.isNotEmpty;
    final selectedUrl = hasImage ? images[_index] : '';
    final mediaUrl = selectedUrl.isNotEmpty
        ? selectedUrl
        : widget.draft.mediaUrl;
    final extraMediaUrls = widget.mediaUrls
        .where(
          (url) =>
              url.trim().isNotEmpty &&
              url != selectedUrl &&
              !videoUrls.contains(url),
        )
        .take(8)
        .toList(growable: false);
    final hasMultipleImages = images.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: widget.compact ? 280 : 420,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.82)),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _controller,
                      itemCount: images.length,
                      onPageChanged: (value) => setState(() => _index = value),
                      itemBuilder: (context, index) {
                        final imageUrl = images[index];
                        final useProxy = _automaticNewsPreviewImageUsesProxy(
                          widget.draft,
                          widget.imageRequestHeaders,
                        );
                        return AdminCachedImage(
                          url: _automaticNewsPreviewImageDisplayUrl(
                            widget.draft,
                            imageUrl,
                            imageIndex: index,
                            width: widget.compact ? 720 : 920,
                            mediaLoaded: widget.mediaLoaded,
                            imageRequestHeaders: widget.imageRequestHeaders,
                          ),
                          httpHeaders: useProxy
                              ? _automaticNewsImageHttpHeaders(
                                  widget.imageRequestHeaders,
                                )
                              : null,
                          fit: BoxFit.cover,
                          memCacheWidth: widget.compact ? 720 : 920,
                          errorWidget: _AutomaticNewsMediaFallback(
                            hasVideo: hasVideo,
                          ),
                        );
                      },
                    ),
                    if (widget.mediaLoading)
                      const Align(
                        alignment: Alignment.bottomCenter,
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          color: AppColors.actionRed,
                        ),
                      ),
                    if (hasMultipleImages)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _PreviewImageCounter(
                          current: _index + 1,
                          total: images.length,
                        ),
                      ),
                    if (hasMultipleImages)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _PreviewSliderArrow(
                          icon: Symbols.chevron_left_rounded,
                          tooltip: 'Önceki görsel',
                          onPressed: _index == 0 ? null : () => _goTo(-1),
                        ),
                      ),
                    if (hasMultipleImages)
                      Align(
                        alignment: Alignment.centerRight,
                        child: _PreviewSliderArrow(
                          icon: Symbols.chevron_right,
                          tooltip: 'Sonraki görsel',
                          onPressed: _index == images.length - 1
                              ? null
                              : () => _goTo(1),
                        ),
                      ),
                    if (hasVideo)
                      const Align(
                        alignment: Alignment.center,
                        child: _VideoOverlayBadge(),
                      ),
                  ],
                )
              : _AutomaticNewsMediaFallback(hasVideo: hasVideo),
        ),
        if (hasMultipleImages) ...[
          const SizedBox(height: 10),
          _PreviewImageThumbStrip(
            images: images,
            selectedIndex: _index,
            draft: widget.draft,
            mediaLoaded: widget.mediaLoaded,
            imageRequestHeaders: widget.imageRequestHeaders,
            onSelected: (index) {
              _controller.animateToPage(
                index,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
              );
            },
          ),
        ],
        if (widget.draft.sourceName.trim().isNotEmpty ||
            widget.draft.sourceUrl.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _PreviewSourceBlock(draft: widget.draft),
        ],
        if (mediaUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          _PreviewInfoBlock(
            label: hasMultipleImages
                ? 'Seçili Görsel Linki'
                : hasVideo
                ? 'Medya / Video Linki'
                : 'Medya Linki',
            value: mediaUrl,
            compactValue: _compactUrl(mediaUrl),
            linkUrl: mediaUrl,
          ),
        ],
        for (var index = 0; index < videoUrls.length; index++) ...[
          const SizedBox(height: 10),
          _PreviewInfoBlock(
            label: videoUrls.length == 1
                ? 'Video Linki'
                : 'Video Linki ${index + 1}',
            value: videoUrls[index],
            compactValue: _compactUrl(videoUrls[index]),
            linkUrl: videoUrls[index],
          ),
        ],
        for (var index = 0; index < extraMediaUrls.length; index++) ...[
          const SizedBox(height: 10),
          _PreviewInfoBlock(
            label: extraMediaUrls.length == 1
                ? 'Ek Medya Linki'
                : 'Ek Medya Linki ${index + 1}',
            value: extraMediaUrls[index],
            compactValue: _compactUrl(extraMediaUrls[index]),
            linkUrl: extraMediaUrls[index],
          ),
        ],
        const SizedBox(height: 10),
        _AutomaticNewsPreviewTiming(draft: widget.draft),
      ],
    );
  }
}

class _PreviewImageCounter extends StatelessWidget {
  const _PreviewImageCounter({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.deepOcean.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: Colors.white.withValues(alpha: 0.46)),
      ),
      child: Text(
        '$current / $total',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PreviewSliderArrow extends StatelessWidget {
  const _PreviewSliderArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.deepOcean.withValues(alpha: 0.82),
            disabledBackgroundColor: AppColors.deepOcean.withValues(
              alpha: 0.34,
            ),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.58),
            fixedSize: const Size(38, 38),
          ),
          icon: SymbolIcon(icon, size: 20),
        ),
      ),
    );
  }
}

class _PreviewImageThumbStrip extends StatelessWidget {
  const _PreviewImageThumbStrip({
    required this.images,
    required this.selectedIndex,
    required this.draft,
    required this.mediaLoaded,
    required this.imageRequestHeaders,
    required this.onSelected,
  });

  final List<String> images;
  final int selectedIndex;
  final _AutomaticNewsDraft draft;
  final bool mediaLoaded;
  final Map<String, String> imageRequestHeaders;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final useProxy = _automaticNewsPreviewImageUsesProxy(
      draft,
      imageRequestHeaders,
    );
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return Tooltip(
            message: 'Görsel ${index + 1}',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.value),
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 76,
                height: 58,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: selected ? AppColors.deepOcean : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.value),
                  border: Border.all(
                    color: selected
                        ? AppColors.deepOcean
                        : AppColors.line.withValues(alpha: 0.76),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.value - 2),
                  child: AdminCachedImage(
                    url: _automaticNewsPreviewImageDisplayUrl(
                      draft,
                      images[index],
                      imageIndex: index,
                      width: 180,
                      mediaLoaded: mediaLoaded,
                      imageRequestHeaders: imageRequestHeaders,
                    ),
                    httpHeaders: useProxy
                        ? _automaticNewsImageHttpHeaders(imageRequestHeaders)
                        : null,
                    fit: BoxFit.cover,
                    memCacheWidth: 180,
                    fadeIn: false,
                    errorWidget: const ColoredBox(
                      color: AppColors.surface,
                      child: Center(
                        child: SymbolIcon(
                          Symbols.image_outlined,
                          color: AppColors.iconMuted,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PreviewSourceBlock extends StatelessWidget {
  const _PreviewSourceBlock({required this.draft});

  final _AutomaticNewsDraft draft;

  @override
  Widget build(BuildContext context) {
    final sourceUrl = draft.sourceUrl.trim();
    final sourceName = _previewSourceName(draft);
    final color = _platformColor(draft.platform);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alındığı Yer',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: SymbolIcon(
                  _platformIcon(draft.platform),
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  sourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          if (sourceUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PreviewLinkValue(
              value: _compactUrl(sourceUrl),
              url: sourceUrl,
              weight: FontWeight.w700,
            ),
          ],
        ],
      ),
    );
  }
}

class _AutomaticNewsMediaFallback extends StatelessWidget {
  const _AutomaticNewsMediaFallback({required this.hasVideo});

  final bool hasVideo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SymbolIcon(
            hasVideo ? Symbols.videocam_outlined : Symbols.image_outlined,
            color: AppColors.iconMuted,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            hasVideo ? 'Video bağlantısı alındı' : 'Medya görseli bulunamadı',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoOverlayBadge extends StatelessWidget {
  const _VideoOverlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.deepOcean.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: const SymbolIcon(
        Symbols.videocam_outlined,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

class _AutomaticNewsPreviewDetails extends StatelessWidget {
  const _AutomaticNewsPreviewDetails({required this.draft});

  final _AutomaticNewsDraft draft;

  @override
  Widget build(BuildContext context) {
    final content = draft.contentText.trim().isNotEmpty
        ? draft.contentText
        : draft.summary;
    final copyText = _automaticNewsPreviewCopyText(draft, content);
    final promptText = _automaticNewsPromptCopyText(draft, content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                draft.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _PreviewCopyButton(
              onPressed: () => unawaited(_copyPreviewText(context, copyText)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PreviewBadge(draft.category),
            _PreviewBadge(draft.status, success: draft.status == 'Hazır'),
            _PreviewBadge('${draft.language} dil'),
            _PreviewBadge('%${draft.quality} içerik kalitesi'),
            if (draft.hasDuplicateWarning)
              _PreviewBadge(
                'Olası tekrar %${draft.duplicateScore}',
                success: false,
              ),
          ],
        ),
        const SizedBox(height: 12),
        _AutomaticNewsPromptMenu(promptText: promptText),
        if (draft.hasDuplicateWarning) ...[
          const SizedBox(height: 18),
          _PreviewSection(
            title: 'Olası Tekrar Uyarısı',
            body: _duplicateWarningDetails(draft),
            copyValue: copyText,
          ),
        ],
        const SizedBox(height: 18),
        _PreviewSection(
          title: 'Kısa Özet',
          body: draft.summary,
          copyValue: copyText,
        ),
        const SizedBox(height: 16),
        _PreviewSection(title: 'Tam Metin', body: content, copyValue: copyText),
      ],
    );
  }
}

String _duplicateWarningDetails(_AutomaticNewsDraft draft) {
  final lines = <String>[
    'Eşleşme skoru: %${draft.duplicateScore}',
    'Kaynak: ${_readableText(draft.duplicateMatchSource, fallback: draft.duplicateMatchTable == 'post' ? 'Pateez haberleri' : 'Otomatik haberler')}',
    'Sebep: ${_readableText(draft.duplicateReason, fallback: 'Başlık/metin/olay benzerliği')}',
  ];
  if (draft.duplicateMatchTitle.trim().isNotEmpty) {
    lines.add('Eşleşen başlık: ${draft.duplicateMatchTitle.trim()}');
  }
  if (draft.duplicateMatchUrl.trim().isNotEmpty) {
    lines.add('Eşleşen link: ${draft.duplicateMatchUrl.trim()}');
  }
  return lines.join('\n');
}

String _automaticNewsPreviewCopyText(
  _AutomaticNewsDraft draft,
  String content,
) {
  final lines = <String>[
    'Başlık',
    _readableText(draft.title, fallback: ''),
    '',
    'Kaynak',
    _previewSourceName(draft),
    '',
    'Haber Linki',
    _readableText(draft.sourceUrl, fallback: ''),
    '',
    'Medya Linkleri',
    _readableText(draft.allMediaUrls.join('\n'), fallback: ''),
    '',
    'Kategori',
    _readableText(draft.category, fallback: ''),
    '',
    'Durum',
    _readableText(draft.status, fallback: ''),
    '',
    'Dil',
    _readableText(draft.language, fallback: ''),
    '',
    'İçerik Kalitesi',
    '%${draft.quality}',
    '',
    if (draft.hasDuplicateWarning) ...[
      'Olası Tekrar Uyarısı',
      _duplicateWarningDetails(draft),
      '',
    ],
    'Gönderi Tarihi',
    draft.publishedAt == null
        ? 'Kaynakta tarih yok'
        : _formatDateTime(draft.publishedAt!),
    '',
    'Çekim Tarihi',
    _formatDateTime(draft.capturedAt),
    '',
    'Kısa Özet',
    _readableText(draft.summary, fallback: ''),
    '',
    'Tam Metin',
    _readableText(content, fallback: ''),
  ];
  return lines
      .map((line) => line.trimRight())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String _automaticNewsPromptCopyText(_AutomaticNewsDraft draft, String content) {
  final sourceText = _automaticNewsPreviewCopyText(draft, content);
  return [
    adminLocalNewsAiDefaultSystemPrompt.trim(),
    '',
    'Ham Haber Metni:',
    sourceText,
  ].join('\n').trim();
}

class _AutomaticNewsPreviewTiming extends StatelessWidget {
  const _AutomaticNewsPreviewTiming({required this.draft});

  final _AutomaticNewsDraft draft;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;
        final itemWidth = narrow
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: itemWidth,
              child: _PreviewInfoBlock(
                label: 'Gönderi Tarihi',
                value: draft.publishedAt == null
                    ? 'Kaynakta tarih yok'
                    : _formatDateTime(draft.publishedAt!),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _PreviewInfoBlock(
                label: 'Çekim Tarihi',
                value: _formatDateTime(draft.capturedAt),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge(this.label, {this.success = false});

  final String label;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? const Color(0xFF12825F) : AppColors.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFEAF7F1) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.title,
    required this.body,
    required this.copyValue,
  });

  final String title;
  final String body;
  final String copyValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SelectableText(
          _readableText(body),
          onTap: () => unawaited(_copyPreviewText(context, copyValue)),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w600,
            height: 1.45,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _PreviewCopyButton extends StatelessWidget {
  const _PreviewCopyButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Metni kopyala',
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 30),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AppColors.deepOcean,
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            side: BorderSide(color: AppColors.line.withValues(alpha: 0.72)),
          ),
        ),
        icon: const Icon(Icons.content_copy_rounded, size: 14),
        label: const Text(
          'Kopyala',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

enum _AutomaticNewsPromptAction { view, copy }

class _AutomaticNewsPromptMenu extends StatelessWidget {
  const _AutomaticNewsPromptMenu({required this.promptText});

  final String promptText;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AutomaticNewsPromptAction>(
      tooltip: 'Prompt seçenekleri',
      offset: const Offset(0, 8),
      color: Colors.white,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
        side: BorderSide(color: AppColors.line.withValues(alpha: 0.82)),
      ),
      onSelected: (action) {
        if (action == _AutomaticNewsPromptAction.view) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            _showAutomaticNewsPromptPreview(context, promptText);
          });
        } else {
          unawaited(
            _copyPreviewText(context, promptText, message: 'Prompt kopyalandı'),
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AutomaticNewsPromptAction>(
          enabled: false,
          height: 38,
          child: SizedBox(
            width: 260,
            child: Text(
              adminLocalNewsAiDefaultPromptTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w800,
                height: 1.24,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<_AutomaticNewsPromptAction>(
          value: _AutomaticNewsPromptAction.view,
          height: 42,
          child: _PromptMenuActionRow(
            icon: Icons.visibility_outlined,
            label: 'Görüntüle',
          ),
        ),
        PopupMenuItem<_AutomaticNewsPromptAction>(
          value: _AutomaticNewsPromptAction.copy,
          height: 42,
          child: _PromptMenuActionRow(
            icon: Icons.content_copy_rounded,
            label: 'Kopyala',
          ),
        ),
      ],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.84)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.deepOcean.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.value / 1.4),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppColors.deepOcean,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prompt Kopyala',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    adminLocalNewsAiDefaultPromptTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.iconMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptMenuActionRow extends StatelessWidget {
  const _PromptMenuActionRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.deepOcean),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

void _showAutomaticNewsPromptPreview(BuildContext context, String promptText) {
  showDialog<void>(
    context: context,
    barrierColor: const Color(0xB20D1B24),
    builder: (context) => _AutomaticNewsPromptPreviewDialog(
      title: adminLocalNewsAiDefaultPromptTitle,
      promptText: promptText,
    ),
  );
}

class _AutomaticNewsPromptPreviewDialog extends StatelessWidget {
  const _AutomaticNewsPromptPreviewDialog({
    required this.title,
    required this.promptText,
  });

  final String title;
  final String promptText;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.deepOcean.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.value),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: AppColors.deepOcean,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.deepOcean,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const SymbolIcon(
                        Symbols.close,
                        color: AppColors.iconMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.line.withValues(alpha: 0.74)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(AppRadius.value),
                      border: Border.all(
                        color: AppColors.line.withValues(alpha: 0.76),
                      ),
                    ),
                    child: Text(
                      promptText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.line.withValues(alpha: 0.74)),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label: const Text('Kapat'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => unawaited(
                        _copyPreviewText(
                          context,
                          promptText,
                          message: 'Prompt kopyalandı',
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.deepOcean,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.value),
                        ),
                      ),
                      icon: const Icon(Icons.content_copy_rounded, size: 17),
                      label: const Text('Kopyala'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewLinkValue extends StatelessWidget {
  const _PreviewLinkValue({
    required this.value,
    required this.url,
    this.weight = FontWeight.w800,
  });

  final String value;
  final String url;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: url,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.value / 2),
          onTap: () => _openPreviewLink(url),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _readableText(value),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.actionRed,
                      fontWeight: weight,
                      height: 1.28,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.actionRed.withValues(
                        alpha: 0.72,
                      ),
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: SymbolIcon(
                    Symbols.open_in_new,
                    color: AppColors.actionRed,
                    size: 14,
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

class _PreviewInfoBlock extends StatelessWidget {
  const _PreviewInfoBlock({
    required this.label,
    required this.value,
    this.compactValue,
    this.linkUrl,
  });

  final String label;
  final String value;
  final String? compactValue;
  final String? linkUrl;

  @override
  Widget build(BuildContext context) {
    final displayValue = _readableText(compactValue ?? value);
    final targetUrl = linkUrl?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          if (targetUrl.isEmpty)
            SelectableText(
              displayValue,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            )
          else
            _PreviewLinkValue(value: displayValue, url: targetUrl),
        ],
      ),
    );
  }
}

class _AutomaticNewsFooter extends StatelessWidget {
  const _AutomaticNewsFooter({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.pageCount,
    required this.onPageChanged,
  });

  final int page;
  final int pageSize;
  final int totalCount;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final safePageCount = pageCount < 1 ? 1 : pageCount;
    final safePage = page.clamp(1, safePageCount).toInt();
    final start = totalCount == 0 ? 0 : ((safePage - 1) * pageSize) + 1;
    final end = totalCount == 0
        ? 0
        : (safePage * pageSize).clamp(0, totalCount).toInt();

    final summary = Text(
      '$start - $end / $totalCount kayıt gösteriliyor',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );

    final pagination = AdminTablePagination(
      page: safePage,
      pageCount: safePageCount,
      onPageChanged: onPageChanged,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: pagination),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: summary),
            const SizedBox(width: 16),
            pagination,
          ],
        );
      },
    );
  }
}

class _AutomaticNewsSourceDialog extends StatefulWidget {
  const _AutomaticNewsSourceDialog({
    required this.initialSources,
    required this.onSaveSources,
    required this.onTestSources,
    required this.onScanSources,
    required this.onToggleSource,
  });

  final List<AutomaticNewsSource> initialSources;
  final Future<List<AutomaticNewsSource>> Function(List<String> urls)
  onSaveSources;
  final Future<_AutomaticNewsSourceTestPayload> Function() onTestSources;
  final Future<_AutomaticNewsSourceTestPayload> Function() onScanSources;
  final Future<AutomaticNewsSource?> Function(
    AutomaticNewsSource source,
    bool value,
  )
  onToggleSource;

  @override
  State<_AutomaticNewsSourceDialog> createState() =>
      _AutomaticNewsSourceDialogState();
}

class _AutomaticNewsSourceDialogState
    extends State<_AutomaticNewsSourceDialog> {
  final _addressController = TextEditingController();

  late List<AutomaticNewsSource> _sources;
  var _saving = false;
  var _testing = false;
  var _scanning = false;
  var _busySourceId = '';
  var _error = '';
  AutomaticNewsRefreshResult? _testResult;
  var _latestBySourceId = const <String, AutomaticNewsSourcePreview>{};

  @override
  void initState() {
    super.initState();
    _sources = [...widget.initialSources];
    _addressController.text = _sourceAddressText(_sources);
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  List<String> get _addresses {
    return _addressController.text
        .split(RegExp(r'[\s,]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _save() async {
    final addresses = _addresses;
    if (addresses.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final saved = await widget.onSaveSources(addresses);
      if (!mounted) return;
      setState(() {
        _sources = saved.toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        _addressController.text = _sourceAddressText(_sources);
        _testResult = null;
        _latestBySourceId = const {};
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testSources() async {
    if (_testing || _saving || _scanning) return;
    setState(() {
      _testing = true;
      _error = '';
    });
    try {
      final payload = await widget.onTestSources();
      if (!mounted) return;
      setState(() {
        _sources = payload.sources.toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        _addressController.text = _sourceAddressText(_sources);
        _testResult = payload.result;
        _latestBySourceId = {
          for (final preview in payload.result.previews)
            preview.sourceId: preview,
        };
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _scanSources() async {
    if (_testing || _saving || _scanning) return;
    setState(() {
      _scanning = true;
      _error = '';
    });
    try {
      final payload = await widget.onScanSources();
      if (!mounted) return;
      setState(() {
        _sources = payload.sources.toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        _addressController.text = _sourceAddressText(_sources);
        _testResult = payload.result;
        _latestBySourceId = {
          for (final preview in payload.result.previews)
            preview.sourceId: preview,
        };
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _toggle(AutomaticNewsSource source, bool value) async {
    if (_busySourceId.isNotEmpty) return;
    setState(() {
      _busySourceId = source.id;
      _error = '';
    });
    try {
      final updated = await widget.onToggleSource(source, value);
      if (!mounted || updated == null) return;
      setState(() {
        _sources = [
          for (final item in _sources) item.id == updated.id ? updated : item,
        ];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busySourceId = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final inset = viewport.width < 640 ? 16.0 : 24.0;
    final dialogWidth = viewport.width < 1120
        ? viewport.width - (inset * 2)
        : 980.0;
    final dialogHeight = viewport.height < 760
        ? viewport.height - (inset * 2)
        : 700.0;

    return Dialog(
      insetPadding: EdgeInsets.all(inset),
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          children: [
            _SourceDialogHeader(onClose: () => Navigator.of(context).pop()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final left = _SourceAddressEditor(
                      controller: _addressController,
                      error: _error,
                      sourceCount: _sources.length,
                      activeSourceCount: _sources
                          .where((source) => source.isActive)
                          .length,
                      testResult: _testResult,
                    );
                    final right = _SourceListPanel(
                      sources: _sources,
                      busySourceId: _busySourceId,
                      latestBySourceId: _latestBySourceId,
                      onToggle: _toggle,
                    );
                    if (compact) {
                      return ListView(
                        children: [
                          SizedBox(height: 320, child: left),
                          const SizedBox(height: 18),
                          SizedBox(height: 320, child: right),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 6, child: left),
                        const SizedBox(width: 22),
                        Expanded(flex: 4, child: right),
                      ],
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.softLine.withValues(alpha: 0.86),
                  ),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  AdminTableSecondaryActionButton(
                    icon: Symbols.close,
                    label: 'Kapat',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  AdminTableSecondaryActionButton(
                    icon: Symbols.refresh_line,
                    label: _testing ? 'Test Ediliyor...' : 'Kaynakları Test Et',
                    onPressed: _testing || _scanning || _saving
                        ? () {}
                        : _testSources,
                  ),
                  AdminTableSecondaryActionButton(
                    icon: Symbols.bolt_rounded,
                    label: _scanning ? 'Taranıyor...' : 'Kaynakları Şimdi Tara',
                    onPressed: _testing || _scanning || _saving
                        ? () {}
                        : _scanSources,
                  ),
                  AdminTablePrimaryActionButton(
                    icon: Symbols.add,
                    label: _saving ? 'Kaydediliyor...' : 'Adresleri Güncelle',
                    onPressed: _saving ? () {} : _save,
                    backgroundColor: AppColors.deepOcean,
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

class _AutomaticNewsSourceTestPayload {
  const _AutomaticNewsSourceTestPayload({
    required this.result,
    required this.sources,
  });

  final AutomaticNewsRefreshResult result;
  final List<AutomaticNewsSource> sources;
}

String _sourceAddressText(List<AutomaticNewsSource> sources) {
  final sorted = sources.toList()
    ..sort((a, b) {
      final type = a.sourceType.compareTo(b.sourceType);
      if (type != 0) return type;
      return a.displayName.compareTo(b.displayName);
    });
  return sorted
      .where((source) => source.isActive)
      .map((source) => source.url)
      .join('\n');
}

class _SourceDialogHeader extends StatelessWidget {
  const _SourceDialogHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.actionRed.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: const SymbolIcon(
              Symbols.rss_feed_outlined,
              color: AppColors.actionRed,
              size: 18,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Otomatik Haber Kaynakları',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          _SourceDialogBadge('5 dk otomasyon'),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Kapat',
            onPressed: onClose,
            icon: const SymbolIcon(
              Symbols.close,
              color: AppColors.iconMuted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceDialogBadge extends StatelessWidget {
  const _SourceDialogBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F1),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(
          color: const Color(0xFF12825F).withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF12825F),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SourceAddressEditor extends StatelessWidget {
  const _SourceAddressEditor({
    required this.controller,
    required this.error,
    required this.sourceCount,
    required this.activeSourceCount,
    required this.testResult,
  });

  final TextEditingController controller;
  final String error;
  final int sourceCount;
  final int activeSourceCount;
  final AutomaticNewsRefreshResult? testResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _ControlLabel('Adresler')),
            _SourceDialogBadge('$activeSourceCount aktif / $sourceCount adres'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: controller,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            cursorColor: AppColors.support,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              height: 1.45,
              letterSpacing: 0,
            ),
            decoration: InputDecoration(
              hintText:
                  'https://www.instagram.com/haberhesabi/\nhttps://site.com/rss.xml',
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.placeholder,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                borderSide: BorderSide(
                  color: AppColors.line.withValues(alpha: 0.72),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                borderSide: BorderSide(
                  color: AppColors.line.withValues(alpha: 0.72),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                borderSide: BorderSide(
                  color: AppColors.deepOcean.withValues(alpha: 0.42),
                ),
              ),
            ),
          ),
        ),
        if (testResult != null) ...[
          const SizedBox(height: 10),
          _SourceTestResultStrip(result: testResult!),
        ],
        if (error.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            error,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.actionRed,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _SourceTestResultStrip extends StatelessWidget {
  const _SourceTestResultStrip({required this.result});

  final AutomaticNewsRefreshResult result;

  @override
  Widget build(BuildContext context) {
    final hasError = result.errorCount > 0;
    final color = hasError ? AppColors.warmHorizon : const Color(0xFF12825F);
    final background = hasError
        ? const Color(0xFFFFF6E7)
        : const Color(0xFFEAF7F1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          SymbolIcon(
            hasError ? Symbols.warning : Symbols.check_circle,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${result.checkedSources} kaynak kontrol edildi · ${result.candidatesFound} son içerik · ${result.errorCount} hata',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.deepOcean,
                fontSize: 12,
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

class _SourceListPanel extends StatelessWidget {
  const _SourceListPanel({
    required this.sources,
    required this.busySourceId,
    required this.latestBySourceId,
    required this.onToggle,
  });

  final List<AutomaticNewsSource> sources;
  final String busySourceId;
  final Map<String, AutomaticNewsSourcePreview> latestBySourceId;
  final Future<void> Function(AutomaticNewsSource source, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SymbolIcon(
                Symbols.link,
                color: AppColors.iconMuted,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kayıtlı Kaynaklar',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _SourceDialogBadge('${sources.length} adres'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: sources.isEmpty
                ? const Center(
                    child: Text(
                      'Kayıtlı adres yok',
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: sources.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: AppColors.softLine.withValues(alpha: 0.86),
                    ),
                    itemBuilder: (context, index) {
                      final source = sources[index];
                      return _SourceListRow(
                        source: source,
                        latest: latestBySourceId[source.id],
                        busy: busySourceId == source.id,
                        onToggle: (value) => onToggle(source, value),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SourceListRow extends StatelessWidget {
  const _SourceListRow({
    required this.source,
    required this.latest,
    required this.busy,
    required this.onToggle,
  });

  final AutomaticNewsSource source;
  final AutomaticNewsSourcePreview? latest;
  final bool busy;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final platform = switch (source.sourceType) {
      'instagram' => 'Instagram',
      'rss' => 'RSS',
      _ => 'Web',
    };
    final status = source.lastError.isNotEmpty
        ? source.lastError
        : latest != null
        ? 'Son içerik · ${latest!.title}'
        : source.lastSuccessAt == null
        ? 'Hazır'
        : '${_formatDate(source.lastSuccessAt!)} ${_formatTime(source.lastSuccessAt!)}';
    final statusColor = source.lastError.isNotEmpty
        ? AppColors.actionRed
        : AppColors.inkSoft;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _SourcePlatformPreview(platform: platform),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  source.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.actionRed,
                  ),
                )
              : _CompactSwitch(value: source.isActive, onChanged: onToggle),
        ],
      ),
    );
  }
}

class _SourcePlatformPreview extends StatelessWidget {
  const _SourcePlatformPreview({required this.platform});

  final String platform;

  @override
  Widget build(BuildContext context) {
    final color = _platformColor(platform);
    return Container(
      width: 54,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: SymbolIcon(_platformIcon(platform), color: color, size: 22),
    );
  }
}

class _AutomaticNewsDraft {
  const _AutomaticNewsDraft({
    required this.recordId,
    required this.id,
    required this.title,
    required this.summary,
    required this.contentText,
    required this.platform,
    required this.sourceName,
    required this.sourceUrl,
    required this.imageUrl,
    required this.videoUrl,
    required this.mediaUrls,
    required this.dateConfidence,
    required this.duplicateState,
    required this.duplicateScore,
    required this.duplicateMatchTable,
    required this.duplicateMatchId,
    required this.duplicateMatchSource,
    required this.duplicateMatchTitle,
    required this.duplicateMatchUrl,
    required this.duplicateReason,
    required this.origin,
    required this.category,
    required this.status,
    required this.language,
    required this.quality,
    required this.publishedAt,
    required this.capturedAt,
  });

  factory _AutomaticNewsDraft.fromItem(AutomaticNewsItem item) {
    final platform = switch (item.sourceType) {
      'instagram' => 'Instagram',
      'rss' => 'RSS',
      'website' => 'Web',
      _ => 'Web',
    };
    final sourceUrl = item.canonicalUrl.trim().isNotEmpty
        ? item.canonicalUrl.trim()
        : item.sourceUrl.trim();
    return _AutomaticNewsDraft(
      recordId: item.id,
      id: item.displayId,
      title: item.title,
      summary: item.summary.isEmpty ? item.contentText : item.summary,
      contentText: item.contentText,
      platform: platform,
      sourceName: item.sourceName,
      sourceUrl: sourceUrl,
      imageUrl: item.imageUrl.trim(),
      videoUrl: item.videoUrl.trim(),
      mediaUrls: item.mediaUrls,
      dateConfidence: item.dateConfidence,
      duplicateState: item.duplicateState,
      duplicateScore: item.duplicateScore,
      duplicateMatchTable: item.duplicateMatchTable,
      duplicateMatchId: item.duplicateMatchId,
      duplicateMatchSource: item.duplicateMatchSource,
      duplicateMatchTitle: item.duplicateMatchTitle,
      duplicateMatchUrl: item.duplicateMatchUrl,
      duplicateReason: item.duplicateReason,
      origin: item.originLabel.isEmpty ? 'Kaynak adresi' : item.originLabel,
      category: item.category,
      status: item.status,
      language: item.languageCode.toLowerCase() == 'tr'
          ? 'Tr'
          : item.languageCode,
      quality: item.qualityScore,
      publishedAt: item.publishedAt,
      capturedAt: item.capturedAt,
    );
  }

  final String recordId;
  final int id;
  final String title;
  final String summary;
  final String contentText;
  final String platform;
  final String sourceName;
  final String sourceUrl;
  final String imageUrl;
  final String videoUrl;
  final List<String> mediaUrls;
  final String dateConfidence;
  final String duplicateState;
  final int duplicateScore;
  final String duplicateMatchTable;
  final String duplicateMatchId;
  final String duplicateMatchSource;
  final String duplicateMatchTitle;
  final String duplicateMatchUrl;
  final String duplicateReason;
  final String origin;
  final String category;
  final String status;
  final String language;
  final int quality;
  final DateTime? publishedAt;
  final DateTime capturedAt;

  bool get hasDuplicateWarning => duplicateState == 'possible';

  List<String> get allMediaUrls {
    final urls = <String>[];
    void add(String value) {
      final url = value.trim();
      if (url.isEmpty) return;
      final key = url.replaceFirst(RegExp(r'[?#].*$'), '');
      if (!urls.any(
        (item) => item.replaceFirst(RegExp(r'[?#].*$'), '') == key,
      )) {
        urls.add(url);
      }
    }

    add(imageUrl);
    add(videoUrl);
    for (final url in mediaUrls) {
      add(url);
    }
    return urls;
  }

  List<String> get videoUrls {
    return allMediaUrls
        .where(
          (url) =>
              url == videoUrl ||
              RegExp(
                r'\.(m3u8|mp4|mov|m4v|webm)(\?|$)',
                caseSensitive: false,
              ).hasMatch(url) ||
              RegExp(
                r'(video|reel|player|stream|instagram\.com/(p|reel))',
                caseSensitive: false,
              ).hasMatch(url),
        )
        .toList(growable: false);
  }

  String get mediaUrl => allMediaUrls.isEmpty ? '' : allMediaUrls.first;

  AutomaticNewsAiDraftSeed toAiDraftSeed() {
    final source = sourceUrl.trim();
    final body = contentText.trim().isNotEmpty ? contentText : summary;
    final keywords = _automaticNewsSeedKeywords(this);
    final lines = <String>[
      _seedField('Haber başlığı', title),
      _seedField('Kısa özet', summary),
      _seedField('SEO başlık', title),
      _seedField('URL uzantısı', _slugifyAutomaticNewsTitle(title)),
      _seedField('Meta açıklama', summary),
      if (keywords.isNotEmpty) _seedField('Odak anahtar kelimeler', keywords),
      'Haber içerik blokları:',
      '---',
      _seedField('Blok tipi', 'text'),
      _seedField('Blok metni', _plainTextToHtml(body)),
      if (source.isNotEmpty) _seedField('Blok kaynağı', source),
      if (imageUrl.trim().isNotEmpty) ...[
        '---',
        _seedField('Blok tipi', 'image'),
        _seedField('Medya URL', imageUrl.trim()),
        _seedField('Alt metin', title),
      ],
    ].where((line) => line.trim().isNotEmpty).toList(growable: false);
    return AutomaticNewsAiDraftSeed(
      topic: lines.join('\n'),
      sourceUrl: source,
      imageUrl: imageUrl.trim(),
      imageAlt: title,
    );
  }
}

String _seedField(String label, String value) {
  final text = value.trim();
  return text.isEmpty ? '' : '$label: $text';
}

String _plainTextToHtml(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  return text
      .split(RegExp(r'\n{2,}'))
      .map(
        (paragraph) =>
            '<p>${_escapeHtml(paragraph).replaceAll('\n', '<br>')}</p>',
      )
      .join('');
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _slugifyAutomaticNewsTitle(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized;
}

String _automaticNewsSeedKeywords(_AutomaticNewsDraft draft) {
  final values = <String>[
    draft.category,
    _compactUrl(draft.sourceUrl).split('/').first,
    ...draft.title.split(RegExp(r'\s+')).where((word) => word.length > 3),
  ];
  final seen = <String>{};
  final keywords = <String>[];
  for (final value in values) {
    final keyword = value
        .replaceAll(RegExp(r'''[,.!?;:()"'\u2019\u201c\u201d]+'''), '')
        .trim();
    if (keyword.isEmpty || !seen.add(keyword.toLowerCase())) {
      continue;
    }
    keywords.add(keyword);
    if (keywords.length >= 10) break;
  }
  return keywords.join(', ');
}

const _platforms = ['Instagram', 'Web', 'RSS'];
const _categories = [
  'Niğde',
  'Gündem',
  'Yaşam',
  'Ekonomi',
  'Spor',
  'Eğitim',
  'Sağlık',
];
const _statuses = ['Hazır', 'İncele', 'Kaynak Bekliyor'];
const _languages = ['Tr', 'En'];

String _formatDate(DateTime value) {
  return '${value.day} ${_monthName(value.month)} ${value.year}';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDateTime(DateTime value) =>
    '${_formatDate(value)} ${_formatTime(value)}';

String _monthName(int value) {
  return switch (value) {
    1 => 'Ocak',
    2 => 'Şubat',
    3 => 'Mart',
    4 => 'Nisan',
    5 => 'Mayıs',
    6 => 'Haziran',
    7 => 'Temmuz',
    8 => 'Ağustos',
    9 => 'Eylül',
    10 => 'Ekim',
    11 => 'Kasım',
    12 => 'Aralık',
    _ => '',
  };
}
