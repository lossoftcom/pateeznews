import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/back_circle_button.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../account/data/frontend_auth_repository.dart';
import '../../ads/presentation/frontend_ad_slot.dart';
import '../../apps/data/app_item.dart';
import '../../home/data/home_repository.dart';
import '../../news_detail/presentation/news_detail_screen.dart';
import '../../shell/data/app_shell_repository.dart';
import '../data/search_repository.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.repository = const SearchRepository(),
    this.initialQuery = '',
    this.showBackButton = false,
    this.autoFocus = true,
    this.onBack,
    this.shellSettings = const AppShellSettings.empty(),
    this.navigationItems = const [],
    this.contentSettings = const HomeContentSettings.defaults(),
    this.homeFeedItems = const [],
    this.authState,
    this.onAuthRequired,
    this.onAuthorTap,
    this.onOpenApp,
  });

  final SearchRepository repository;
  final String initialQuery;
  final bool showBackButton;
  final bool autoFocus;
  final VoidCallback? onBack;
  final AppShellSettings shellSettings;
  final List<AppShellNavigationItem> navigationItems;
  final HomeContentSettings contentSettings;
  final List<NewsArticle> homeFeedItems;
  final FrontendAuthState? authState;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final ValueChanged<AppItem>? onOpenApp;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery.trim(),
  );
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  var _data = const SearchData.empty();
  var _loading = false;
  var _searched = false;
  var _activeQuery = '';
  var _requestSerial = 0;

  static const _debounceDelay = Duration(milliseconds: 260);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activateSearchField();
    });
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextQuery = widget.initialQuery.trim();
    if (nextQuery != oldWidget.initialQuery.trim() &&
        nextQuery != _controller.text.trim()) {
      _controller.text = nextQuery;
      _controller.selection = TextSelection.collapsed(offset: nextQuery.length);
    }
    if (!oldWidget.autoFocus && widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _activateSearchField();
      });
    } else if (oldWidget.autoFocus && !widget.autoFocus) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    _debounce?.cancel();
    if (query.length < 2) {
      _requestSerial++;
      if (_data.posts.isNotEmpty || _data.profiles.isNotEmpty || _loading) {
        setState(() {
          _data = const SearchData.empty();
          _loading = false;
          _searched = false;
          _activeQuery = query;
        });
      } else {
        _activeQuery = query;
      }
      return;
    }
    _debounce = Timer(_debounceDelay, () => _searchNow(query));
  }

  void _activateSearchField() {
    if (!mounted || !widget.autoFocus) return;
    _focusNode.requestFocus();
    final query = _controller.text.trim();
    if (query.length >= 2 && query != _activeQuery) _searchNow(query);
  }

  Future<void> _searchNow(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return;
    final serial = ++_requestSerial;
    setState(() {
      _loading = true;
      _searched = true;
      _activeQuery = cleanQuery;
    });
    final token = widget.authState?.session.accessToken.trim() ?? '';
    final result = await widget.repository.search(
      query: cleanQuery,
      token: token.isEmpty ? null : token,
    );
    if (!mounted || serial != _requestSerial) return;
    setState(() {
      _data = result;
      _loading = false;
    });
  }

  void _submit() {
    final query = _controller.text.trim();
    _debounce?.cancel();
    if (query.length >= 2) {
      _searchNow(query);
    }
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _openArticle(int index) {
    _openArticleFromList(_data.posts, index);
  }

  void _openArticleFromList(List<NewsArticle> articles, int index) {
    if (index < 0 || index >= articles.length) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => NewsDetailScreen(
          articles: articles,
          initialIndex: index,
          shellSettings: widget.shellSettings,
          navigationItems: widget.navigationItems,
          contentSettings: widget.contentSettings,
          videoFeedArticles: _dateSortedVideoFeed(widget.homeFeedItems),
          authState: widget.authState,
          onAuthRequired: widget.onAuthRequired,
          onAuthorTap: widget.onAuthorTap,
        ),
        transitionsBuilder: (context, animation, secondary, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _openProfile(SearchProfile profile) {
    final handler = widget.onAuthorTap;
    if (handler == null) return;
    handler(
      NewsAuthor(
        id: profile.id,
        name: profile.displayName,
        avatarUrl: profile.avatarUrl,
        handle: profile.handle,
        isVerified: true,
        isOfficial: _isOfficialRole(profile.role),
      ),
    );
  }

  List<NewsArticle> _dateSortedVideoFeed(List<NewsArticle> items) {
    final videos = items
        .where((item) => item.videoFeedUrls.isNotEmpty)
        .toList(growable: false);
    return List<NewsArticle>.of(videos)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  List<AppItem> get _appResults {
    final query = _controller.text.trim();
    if (query.isEmpty) return AppItems.all;
    return AppItems.all
        .where(
          (item) =>
              _matches(item.label, query) ||
              _matches(item.tagline, query) ||
              _matches(item.description, query) ||
              _matches(item.id, query),
        )
        .toList(growable: false);
  }

  List<NewsArticle> get _localVideoResults {
    final query = _controller.text.trim();
    if (query.length < 2) return const [];
    final results = widget.homeFeedItems
        .where(
          (article) =>
              article.videoFeedUrls.isNotEmpty &&
              (_matches(article.title, query) ||
                  _matches(article.summary, query) ||
                  _matches(article.category, query)),
        )
        .toList(growable: false);
    results.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return results.take(4).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            _SearchHeader(
              controller: _controller,
              focusNode: _focusNode,
              loading: _loading,
              showBackButton: widget.showBackButton,
              onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
              onClear: _clear,
              onSubmitted: (_) => _submit(),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final query = _controller.text.trim();
    final apps = _appResults;
    final localVideos = _localVideoResults;
    final hasRemoteResults =
        _data.posts.isNotEmpty || _data.profiles.isNotEmpty;
    final hasAnyResult =
        apps.isNotEmpty || localVideos.isNotEmpty || hasRemoteResults;

    if (query.isEmpty) {
      return _SearchIdleState(apps: apps, onAppTap: widget.onOpenApp);
    }

    if (query.length < 2) {
      return const _CompactState(
        icon: Symbols.search_ai_line,
        title: 'Arama hazır',
        message: 'Sonuçlar için en az iki karakter yaz.',
      );
    }

    if (_loading && !_searched) {
      return const _SearchLoadingList();
    }

    if (!_loading && _searched && !hasAnyResult) {
      return _CompactState(
        icon: Symbols.search_ai_line,
        title: 'Sonuç bulunamadı',
        message: '"$_activeQuery" için eşleşme yok.',
      );
    }

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        if (_loading) const SliverToBoxAdapter(child: _LinearSearchProgress()),
        if (apps.isNotEmpty)
          SliverToBoxAdapter(
            child: _AppResultsSection(apps: apps, onAppTap: widget.onOpenApp),
          ),
        if (localVideos.isNotEmpty)
          SliverToBoxAdapter(
            child: _VideoShortcutSection(
              videos: localVideos,
              onTap: (index) => _openArticleFromList(localVideos, index),
            ),
          ),
        if (_data.posts.isNotEmpty)
          SliverToBoxAdapter(
            child: _SectionTitle(title: 'Haberler', count: _data.posts.length),
          ),
        if (_data.posts.isNotEmpty)
          SliverList.builder(
            itemCount: _data.posts.length,
            itemBuilder: (context, index) {
              final tile = _PostResultTile(
                article: _data.posts[index],
                onTap: () => _openArticle(index),
              );
              if ((index + 1) % 5 != 0) return tile;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tile,
                  const FrontendAdSlot(
                    slotKey: 'mobile_search_results_inline',
                    margin: EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageHorizontal,
                    ),
                  ),
                ],
              );
            },
          ),
        if (_data.profiles.isNotEmpty)
          SliverToBoxAdapter(
            child: _SectionTitle(
              title: 'Yayıncılar',
              count: _data.profiles.length,
            ),
          ),
        if (_data.profiles.isNotEmpty)
          SliverList.builder(
            itemCount: _data.profiles.length,
            itemBuilder: (context, index) => _ProfileResultTile(
              profile: _data.profiles[index],
              onTap: () => _openProfile(_data.profiles[index]),
              enabled: widget.onAuthorTap != null,
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.showBackButton,
    required this.onBack,
    required this.onClear,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final bool showBackButton;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.viewPaddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        topPadding + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.softLine, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    Symbols.search_ai_line,
                    color: loading ? AppColors.actionRed : AppColors.iconMuted,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.search,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: onSubmitted,
                      cursorColor: AppColors.actionRed,
                      style: AppTypography.body.copyWith(
                        color: AppColors.inkStrong,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Haber, video, yazar veya uygulama ara',
                        hintStyle: AppTypography.body.copyWith(
                          color: AppColors.placeholder,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      if (value.text.isEmpty) return const SizedBox(width: 10);
                      return _HeaderIconButton(
                        icon: Symbols.close_rounded,
                        semantics: 'Aramayı temizle',
                        onTap: onClear,
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ),
            ),
          ),
          if (showBackButton) ...[
            const SizedBox(width: AppSpacing.sm),
            BackCircleButton(onTap: onBack),
          ],
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.semantics,
    required this.onTap,
  });

  final IconData icon;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 22, color: AppColors.iconStrong),
          ),
        ),
      ),
    );
  }
}

class _SearchIdleState extends StatelessWidget {
  const _SearchIdleState({required this.apps, required this.onAppTap});

  final List<AppItem> apps;
  final ValueChanged<AppItem>? onAppTap;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        const SliverToBoxAdapter(
          child: _CompactState(
            icon: Symbols.search_ai_line,
            title: 'Arama',
            message: 'Gündem, yazar, kategori, video ve uygulamalar.',
          ),
        ),
        if (apps.isNotEmpty)
          SliverToBoxAdapter(
            child: _AppResultsSection(apps: apps, onAppTap: onAppTap),
          ),
      ],
    );
  }
}

class _AppResultsSection extends StatelessWidget {
  const _AppResultsSection({required this.apps, required this.onAppTap});

  final List<AppItem> apps;
  final ValueChanged<AppItem>? onAppTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SectionTitle.inline(title: 'Uygulamalar', count: apps.length),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final app in apps)
                _AppChip(
                  item: app,
                  onTap: onAppTap == null ? null : () => onAppTap!(app),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppChip extends StatelessWidget {
  const _AppChip({required this.item, required this.onTap});

  final AppItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.value),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: Container(
          width: 162,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                  border: Border.all(
                    color: item.accent.withValues(alpha: 0.18),
                  ),
                ),
                child: item.glyph(20, item.accent),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleS.copyWith(
                  color: AppColors.inkStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.tagline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.meta.copyWith(color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoShortcutSection extends StatelessWidget {
  const _VideoShortcutSection({required this.videos, required this.onTap});

  final List<NewsArticle> videos;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle.inline(title: 'Videolar', count: videos.length),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < videos.length; index++)
            _PostResultTile(
              article: videos[index],
              compact: true,
              onTap: () => onTap(index),
            ),
        ],
      ),
    );
  }
}

class _PostResultTile extends StatelessWidget {
  const _PostResultTile({
    required this.article,
    required this.onTap,
    this.compact = false,
  });

  final NewsArticle article;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 0 : AppSpacing.pageHorizontal,
        AppSpacing.xs,
        compact ? 0 : AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.value),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                _ResultImage(article: article),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.category.isEmpty ? 'Haber' : article.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.eyebrow.copyWith(
                          color: AppColors.actionRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleS.copyWith(
                          color: AppColors.inkStrong,
                          fontWeight: FontWeight.w800,
                          height: 1.18,
                        ),
                      ),
                      if (article.summary.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          article.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.meta.copyWith(
                            color: AppColors.inkSoft,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _timeLabel(article.publishedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.meta,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Symbols.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.iconMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 220.ms, curve: Curves.easeOutCubic);
  }
}

class _ResultImage extends StatelessWidget {
  const _ResultImage({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final imageUrl = article.imageUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.value),
      child: SizedBox(
        width: 76,
        height: 76,
        child: imageUrl.isEmpty
            ? Container(
                color: AppColors.surfaceSoft,
                child: const Icon(
                  Symbols.article,
                  size: 24,
                  color: AppColors.iconMuted,
                ),
              )
            : CachedImage(
                url: imageUrl,
                memCacheWidth: 220,
                placeholderColor: AppColors.surfaceSoft,
                errorWidget: Container(
                  color: AppColors.surfaceSoft,
                  child: const Icon(
                    Symbols.article,
                    size: 24,
                    color: AppColors.iconMuted,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ProfileResultTile extends StatelessWidget {
  const _ProfileResultTile({
    required this.profile,
    required this.onTap,
    required this.enabled,
  });

  final SearchProfile profile;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xs,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.value),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                _ProfileAvatar(profile: profile),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleS.copyWith(
                          color: AppColors.inkStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [
                          if (profile.handle.isNotEmpty) profile.handle,
                          if (profile.expertise.isNotEmpty) profile.expertise,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.meta.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(
                    Symbols.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.iconMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});

  final SearchProfile profile;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarUrl.trim();
    return ClipOval(
      child: SizedBox(
        width: 48,
        height: 48,
        child: avatarUrl.isEmpty
            ? Container(
                alignment: Alignment.center,
                color: AppColors.surfaceSoft,
                child: Text(
                  _initials(profile.displayName),
                  style: AppTypography.titleS.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : CachedImage(
                url: avatarUrl,
                memCacheWidth: 120,
                placeholderColor: AppColors.surfaceSoft,
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count})
    : compact = false;

  const _SectionTitle.inline({required this.title, required this.count})
    : compact = true;

  final String title;
  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Text(
          title,
          style: AppTypography.titleM.copyWith(
            color: AppColors.inkStrong,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$count',
          style: AppTypography.meta.copyWith(
            color: AppColors.support,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    if (compact) return child;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
        AppSpacing.pageHorizontal,
        AppSpacing.xs,
      ),
      child: child,
    );
  }
}

class _CompactState extends StatelessWidget {
  const _CompactState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.huge,
          AppSpacing.pageHorizontal,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(color: AppColors.line),
              ),
              child: Icon(icon, size: 28, color: AppColors.actionRed),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleM.copyWith(
                color: AppColors.inkStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LinearSearchProgress extends StatelessWidget {
  const _LinearSearchProgress();

  @override
  Widget build(BuildContext context) {
    return const LinearProgressIndicator(
      minHeight: 2,
      color: AppColors.actionRed,
      backgroundColor: AppColors.softLine,
    );
  }
}

class _SearchLoadingList extends StatelessWidget {
  const _SearchLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
        AppSpacing.pageHorizontal,
        AppSpacing.xxl,
      ),
      itemCount: 5,
      itemBuilder: (context, index) => const _SkeletonTile(),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(width: 76, height: 76, color: AppColors.surfaceSoft),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(height: 10, width: 72, color: AppColors.surfaceSoft),
                const SizedBox(height: AppSpacing.sm),
                Container(height: 12, color: AppColors.surfaceSoft),
                const SizedBox(height: AppSpacing.xs),
                FractionallySizedBox(
                  widthFactor: 0.72,
                  child: Container(height: 12, color: AppColors.surfaceSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _matches(String value, String query) {
  final haystack = value.toLowerCase();
  final needle = query.toLowerCase();
  return haystack.contains(needle);
}

bool _isOfficialRole(String role) {
  final value = role.trim().toLowerCase();
  return value == 'admin' || value == 'super_admin' || value == 'editor';
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  final chars = words.take(2).map((word) => word.substring(0, 1)).join();
  return chars.isEmpty ? 'P' : chars.toUpperCase();
}

String _timeLabel(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);
  if (difference.inMinutes < 1) return 'Şimdi';
  if (difference.inHours < 1) return '${difference.inMinutes} dk önce';
  if (difference.inDays < 1) return '${difference.inHours} sa önce';
  if (difference.inDays < 7) return '${difference.inDays} gün önce';
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}
