import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/admin_image_url.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
import '../../../news/data/admin_news_repository.dart';
import '../../../news/presentation/news_models.dart';
import '../../../news/presentation/widgets/news_link_opener.dart';

/// News source picker: opens a searchable modal for selecting a published news article.
/// When a news article is selected, fetches full detail (summary, keywords, etc.) via a
/// secondary query and calls [onNewsSelected] with all data.
class SocialNewsSourcePicker extends StatefulWidget {
  const SocialNewsSourcePicker({
    super.key,
    required this.newsRepository,
    required this.selectedLink,
    required this.manualLink,
    required this.onNewsSelected,
    required this.onManualLinkChanged,
  });

  final AdminNewsRepository newsRepository;
  final String selectedLink;
  final String manualLink;
  final void Function({
    required String title,
    required String imageUrl,
    required String link,
    required String summary,
    required String keywords,
    required String category,
    required String type,
  })
  onNewsSelected;
  final ValueChanged<String> onManualLinkChanged;

  @override
  State<SocialNewsSourcePicker> createState() => _SocialNewsSourcePickerState();
}

class _SocialNewsSourcePickerState extends State<SocialNewsSourcePicker> {
  final _manualLinkController = TextEditingController();
  List<_SocialNewsOption> _newsList = [];
  var _loading = true;
  var _selectingNews = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncManualLinkText();
    unawaited(_loadNews());
  }

  @override
  void didUpdateWidget(covariant SocialNewsSourcePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manualLink != widget.manualLink ||
        oldWidget.selectedLink != widget.selectedLink) {
      _syncManualLinkText();
    }
  }

  @override
  void dispose() {
    _manualLinkController.dispose();
    super.dispose();
  }

  void _syncManualLinkText() {
    final next = widget.manualLink.trim().isNotEmpty
        ? widget.manualLink.trim()
        : _normalizedPostLink(widget.selectedLink);
    if (_manualLinkController.text == next) return;
    _manualLinkController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _loadNews({String search = ''}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _fetchNews(search: search);
      if (!mounted) return;
      setState(() {
        _newsList = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<_SocialNewsOption>> _fetchNews({required String search}) async {
    final result = await widget.newsRepository.fetchPosts(
      search: search,
      language: 'Tümü',
      category: 'Tümü',
      type: 'Tümü',
      status: 'published',
      publisher: 'Tümü',
      trash: false,
      videoOnly: false,
      page: 1,
      pageSize: 50,
      sortKey: 'date',
      sortAscending: false,
    );
    return result.posts.map(_SocialNewsOption.fromPost).toList();
  }

  Future<void> _openNewsPicker() async {
    final selected = await showDialog<_SocialNewsOption>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (context) => _SocialNewsPickerDialog(
        newsRepository: widget.newsRepository,
        initialNews: _newsList,
      ),
    );
    if (selected == null || !mounted) return;
    await _fetchPostDetail(selected);
  }

  /// Fetch extended post details (summary, keywords) by post id.
  Future<void> _fetchPostDetail(_SocialNewsOption news) async {
    setState(() {
      _selectingNews = true;
      _error = null;
    });

    final fallbackLink = news.publicUrl;
    final postId = news.id;
    if (postId.isEmpty) {
      widget.onNewsSelected(
        title: news.displayTitle,
        imageUrl: _resolvedNewsImageUrl(news.rawImageUrl, width: 1080),
        link: fallbackLink,
        summary: '',
        keywords: '',
        category: news.category,
        type: news.type,
      );
      if (mounted) setState(() => _selectingNews = false);
      return;
    }

    try {
      // Build the API URL the same way SupabaseAdminNewsRepository does.
      const apiBase = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
      Uri uri;
      if (apiBase.isNotEmpty) {
        uri = Uri.parse(apiBase).resolve('/api/admin/query');
      } else if (!kIsWeb) {
        final host = defaultTargetPlatform == TargetPlatform.android
            ? 'https://pateez.com'
            : 'https://pateez.com';
        uri = Uri.parse(host).resolve('/api/admin/query');
      } else {
        uri = Uri.base.resolve('/api/admin/query');
      }

      final response = await adminHttpClient
          .post(
            uri,
            headers: await adminJsonHeaders(),
            body: jsonEncode({
              'table': 'posts',
              'method': 'select',
              'select':
                  'summary,keywords,thumbnail_url,title,slug,category,type',
              'filters': [
                {
                  'type': 'comparison',
                  'op': 'eq',
                  'column': 'id',
                  'value': int.tryParse(postId) ?? postId,
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 8));

      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] is List) {
        final rows = (decoded['data'] as List).whereType<Map>().toList();
        if (rows.isNotEmpty) {
          final row = rows.first;
          if (!mounted) return;
          final slugOrId = (row['slug'] ?? news.slugOrId).toString();
          final rawImageUrl = (row['thumbnail_url'] ?? news.rawImageUrl)
              .toString();
          final previewImageUrl = _resolvedNewsImageUrl(
            rawImageUrl,
            width: 1080,
          );
          final tileImageUrl = _resolvedNewsImageUrl(rawImageUrl, width: 360);
          widget.onNewsSelected(
            title: (row['title'] ?? news.displayTitle).toString(),
            imageUrl: previewImageUrl,
            link: _publicPostUrl(slugOrId),
            summary: (row['summary'] ?? '').toString(),
            keywords: (row['keywords'] ?? '').toString(),
            category: (row['category'] ?? news.category).toString(),
            type: (row['type'] ?? news.type).toString(),
          );
          setState(() {
            _selectingNews = false;
            _upsertNews(
              news.copyWith(
                title: (row['title'] ?? news.displayTitle).toString(),
                slug: slugOrId,
                imageUrl: tileImageUrl,
                rawImageUrl: rawImageUrl,
                category: (row['category'] ?? news.category).toString(),
                type: (row['type'] ?? news.type).toString(),
              ),
            );
          });
          return;
        }
      }
    } catch (_) {
      // Fallback to basic data.
    }

    if (!mounted) return;
    widget.onNewsSelected(
      title: news.displayTitle,
      imageUrl: _resolvedNewsImageUrl(news.rawImageUrl, width: 1080),
      link: fallbackLink,
      summary: '',
      keywords: '',
      category: news.category,
      type: news.type,
    );
    setState(() {
      _selectingNews = false;
      _upsertNews(news);
    });
  }

  void _upsertNews(_SocialNewsOption news) {
    final index = _newsList.indexWhere((item) => item.id == news.id);
    if (index == -1) {
      _newsList = [news, ..._newsList];
    } else {
      _newsList = [
        for (final item in _newsList)
          if (item.id == news.id) news else item,
      ];
    }
  }

  _SocialNewsOption? get _selectedNews {
    final link = _normalizedPostLink(widget.selectedLink);
    if (link.isEmpty) return null;
    for (final item in _newsList) {
      if (_sameNewsLink(item.publicUrl, link) ||
          item.slug == widget.selectedLink) {
        return item;
      }
    }
    return null;
  }

  void _openCurrentLink() {
    final link = _normalizedPostLink(_manualLinkController.text);
    if (link.isEmpty) return;
    unawaited(openNewsLink(link));
  }

  @override
  Widget build(BuildContext context) {
    final selectedNews = _selectedNews;
    final currentLink = _normalizedPostLink(_manualLinkController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(
                context.t('social.publish.newsSource'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepOcean,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              if (!_loading)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _loadNews(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Symbols.refresh_rounded,
                          size: 14,
                          color: AppColors.iconMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.t('social.publish.refreshNews'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.iconMuted,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (_loading)
          _PickerShell(
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_error != null)
          _PickerShell(
            tone: _PickerShellTone.error,
            child: Text(
              context.t('social.publish.newsError'),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.actionRed,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          )
        else
          _SelectedNewsButton(
            news: selectedNews,
            selecting: _selectingNews,
            onTap: _openNewsPicker,
          ),

        const SizedBox(height: 14),
        Text(
          context.t('social.publish.manualLink'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.deepOcean,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: TextField(
            controller: _manualLinkController,
            onChanged: (value) {
              setState(() {});
              widget.onManualLinkChanged(value);
            },
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.deepOcean,
              letterSpacing: 0,
            ),
            decoration: InputDecoration(
              hintText: context.t('social.publish.manualLinkHint'),
              hintStyle: const TextStyle(
                color: AppColors.placeholder,
                fontSize: 13,
                letterSpacing: 0,
              ),
              prefixIcon: const Icon(
                Symbols.link_rounded,
                size: 18,
                color: AppColors.iconMuted,
              ),
              suffixIcon: IconButton(
                tooltip: context.t('social.publish.newsPickerOpen'),
                onPressed: currentLink.isEmpty ? null : _openCurrentLink,
                icon: const Icon(Symbols.open_in_new, size: 17),
                color: currentLink.isEmpty
                    ? AppColors.placeholder
                    : AppColors.deepOcean,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value * 2),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value * 2),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value * 2),
                borderSide: const BorderSide(color: AppColors.deepOcean),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialNewsPickerDialog extends StatefulWidget {
  const _SocialNewsPickerDialog({
    required this.newsRepository,
    required this.initialNews,
  });

  final AdminNewsRepository newsRepository;
  final List<_SocialNewsOption> initialNews;

  @override
  State<_SocialNewsPickerDialog> createState() =>
      _SocialNewsPickerDialogState();
}

class _SocialNewsPickerDialogState extends State<_SocialNewsPickerDialog> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<_SocialNewsOption> _items = [];
  var _loading = true;
  String? _error;
  int _requestSerial = 0;
  var _lastSearchText = '';

  @override
  void initState() {
    super.initState();
    _items = widget.initialNews;
    _loading = _items.isEmpty;
    _searchController.addListener(_scheduleSearch);
    if (_items.isEmpty) unawaited(_loadNews());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    final nextSearchText = _searchController.text;
    if (nextSearchText == _lastSearchText) return;
    _lastSearchText = nextSearchText;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_loadNews(search: nextSearchText));
    });
  }

  Future<void> _loadNews({String search = ''}) async {
    final serial = ++_requestSerial;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.newsRepository.fetchPosts(
        search: search,
        language: 'Tümü',
        category: 'Tümü',
        type: 'Tümü',
        status: 'published',
        publisher: 'Tümü',
        trash: false,
        videoOnly: false,
        page: 1,
        pageSize: 50,
        sortKey: 'date',
        sortAscending: false,
      );
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _items = result.posts.map(_SocialNewsOption.fromPost).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxHeight = size.height > 96 ? size.height - 48 : size.height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 880, maxHeight: maxHeight),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.actionRed.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.value),
                      ),
                      child: const Icon(
                        Symbols.article_outlined,
                        color: AppColors.actionRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('social.publish.newsPickerTitle'),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppColors.deepOcean,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.t('social.publish.newsPickerSubtitle'),
                            style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      mouseCursor: SystemMouseCursors.click,
                      icon: const Icon(
                        Symbols.close,
                        size: 18,
                        color: AppColors.deepOcean,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.deepOcean,
                    letterSpacing: 0,
                  ),
                  decoration: InputDecoration(
                    hintText: context.t('social.publish.newsPickerSearchHint'),
                    hintStyle: const TextStyle(
                      color: AppColors.placeholder,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                    prefixIcon: const Icon(
                      Symbols.search_rounded,
                      color: AppColors.iconMuted,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.value),
                      ),
                      borderSide: BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.value),
                      ),
                      borderSide: BorderSide(color: AppColors.deepOcean),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    child: _buildBody(context),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '${_items.length} ${context.t('social.publish.newsPickerResultCount')}',
                      style: const TextStyle(
                        color: AppColors.support,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style:
                          TextButton.styleFrom(
                            foregroundColor: AppColors.deepOcean,
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
                      child: Text(context.t('social.publish.cancel')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Text(
            context.t('social.publish.newsError'),
            style: const TextStyle(
              color: AppColors.actionRed,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Text(
            context.t('social.publish.newsPickerEmpty'),
            style: const TextStyle(
              color: AppColors.support,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _NewsPickerTile(
          news: _items[index],
          onSelect: () => Navigator.of(context).pop(_items[index]),
        );
      },
    );
  }
}

class _SelectedNewsButton extends StatelessWidget {
  const _SelectedNewsButton({
    required this.news,
    required this.selecting,
    required this.onTap,
  });

  final _SocialNewsOption? news;
  final bool selecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasNews = news != null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: selecting ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value * 2),
            border: Border.all(
              color: hasNews
                  ? AppColors.deepOcean.withValues(alpha: 0.16)
                  : AppColors.line,
            ),
          ),
          child: Row(
            children: [
              _NewsThumb(url: news?.imageUrl ?? '', width: 54, height: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hasNews
                          ? news!.displayTitle
                          : context.t('social.publish.newsSourceHint'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: hasNews
                            ? AppColors.deepOcean
                            : AppColors.placeholder,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    if (hasNews) ...[
                      const SizedBox(height: 4),
                      Text(
                        news!.publicUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.support,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (selecting)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Symbols.keyboard_arrow_down_rounded,
                  color: AppColors.iconMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsPickerTile extends StatelessWidget {
  const _NewsPickerTile({required this.news, required this.onSelect});

  final _SocialNewsOption news;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          child: InkWell(
            onTap: onSelect,
            borderRadius: BorderRadius.circular(AppRadius.value),
            mouseCursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: compact ? _buildCompact(context) : _buildWide(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWide(BuildContext context) {
    return Row(
      children: [
        _NewsThumb(url: news.imageUrl, width: 96, height: 70),
        const SizedBox(width: 12),
        Expanded(child: _NewsTileInfo(news: news)),
        const SizedBox(width: 12),
        _OpenNewsButton(url: news.publicUrl),
        const SizedBox(width: 4),
        _SelectNewsButton(onSelect: onSelect),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NewsThumb(url: news.imageUrl, width: 78, height: 58),
            const SizedBox(width: 10),
            Expanded(child: _NewsTileInfo(news: news)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _OpenNewsButton(url: news.publicUrl),
            const SizedBox(width: 6),
            _SelectNewsButton(onSelect: onSelect),
          ],
        ),
      ],
    );
  }
}

class _NewsTileInfo extends StatelessWidget {
  const _NewsTileInfo({required this.news});

  final _SocialNewsOption news;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          news.displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.25,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _NewsMetaPill(
              icon: Symbols.category_outlined,
              label: news.category.isEmpty ? '-' : news.category,
            ),
            _NewsMetaPill(
              icon: Symbols.article_outlined,
              label: news.type.isEmpty ? 'standard' : news.type,
            ),
            if (news.dateLabel.isNotEmpty)
              _NewsMetaPill(
                icon: Symbols.calendar_today_outlined,
                label: news.dateLabel,
              ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          news.publicUrl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.support,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _OpenNewsButton extends StatelessWidget {
  const _OpenNewsButton({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.t('social.publish.newsPickerOpen'),
      onPressed: () => unawaited(openNewsLink(url)),
      icon: const Icon(Symbols.open_in_new, size: 18),
      color: AppColors.iconMuted,
    );
  }
}

class _SelectNewsButton extends StatelessWidget {
  const _SelectNewsButton({required this.onSelect});

  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onSelect,
      icon: const Icon(Symbols.check_circle_rounded, size: 16),
      label: Text(context.t('social.publish.newsPickerSelect')),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.deepOcean,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 34),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _NewsThumb extends StatelessWidget {
  const _NewsThumb({
    required this.url,
    required this.width,
    required this.height,
  });

  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.value),
      child: SizedBox(
        width: width,
        height: height,
        child: url.trim().isEmpty
            ? const _NewsThumbFallback()
            : AdminCachedImage(
                url: url,
                width: width,
                height: height,
                fit: BoxFit.contain,
                memCacheWidth: 240,
                errorWidget: const _NewsThumbFallback(),
              ),
      ),
    );
  }
}

class _NewsThumbFallback extends StatelessWidget {
  const _NewsThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Symbols.image_not_supported_outlined,
        color: AppColors.iconMuted,
        size: 20,
      ),
    );
  }
}

class _NewsMetaPill extends StatelessWidget {
  const _NewsMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.deepOcean.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.iconMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PickerShellTone { normal, error }

class _PickerShell extends StatelessWidget {
  const _PickerShell({
    required this.child,
    this.tone = _PickerShellTone.normal,
  });

  final Widget child;
  final _PickerShellTone tone;

  @override
  Widget build(BuildContext context) {
    final error = tone == _PickerShellTone.error;
    return Container(
      width: double.infinity,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: error
            ? AppColors.actionRed.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value * 2),
        border: Border.all(
          color: error
              ? AppColors.actionRed.withValues(alpha: 0.2)
              : AppColors.line,
        ),
      ),
      child: child,
    );
  }
}

class _SocialNewsOption {
  const _SocialNewsOption({
    required this.id,
    required this.title,
    required this.slug,
    required this.imageUrl,
    required this.rawImageUrl,
    required this.category,
    required this.type,
    required this.dateLabel,
  });

  factory _SocialNewsOption.fromPost(AdminNewsPost post) {
    return _SocialNewsOption(
      id: post.id,
      title: post.title,
      slug: post.slug,
      imageUrl: _resolvedNewsImageUrl(post.thumbnailUrl, width: 360),
      rawImageUrl: post.thumbnailUrl,
      category: post.displayCategory,
      type: post.displayType,
      dateLabel: post.createdDate == '-' ? '' : post.createdDate,
    );
  }

  final String id;
  final String title;
  final String slug;
  final String imageUrl;
  final String rawImageUrl;
  final String category;
  final String type;
  final String dateLabel;

  String get displayTitle => title.trim().isEmpty ? slugOrId : title.trim();

  String get slugOrId => slug.trim().isEmpty ? id.trim() : slug.trim();

  String get publicUrl => _publicPostUrl(slugOrId);

  _SocialNewsOption copyWith({
    String? title,
    String? slug,
    String? imageUrl,
    String? rawImageUrl,
    String? category,
    String? type,
  }) {
    return _SocialNewsOption(
      id: id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      imageUrl: imageUrl ?? this.imageUrl,
      rawImageUrl: rawImageUrl ?? this.rawImageUrl,
      category: category ?? this.category,
      type: type ?? this.type,
      dateLabel: dateLabel,
    );
  }
}

String _publicPostUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) return trimmed;
  return Uri.https(
    'pateeznews.com',
    '/haber/${Uri.encodeComponent(trimmed)}',
  ).toString();
}

String _normalizedPostLink(String value) => _publicPostUrl(value);

String _resolvedNewsImageUrl(String value, {required int width}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return adminImageUrl(trimmed, width: width, quality: 90);
}

bool _sameNewsLink(String left, String right) {
  return left.trim().replaceAll(RegExp(r'/+$'), '') ==
      right.trim().replaceAll(RegExp(r'/+$'), '');
}
