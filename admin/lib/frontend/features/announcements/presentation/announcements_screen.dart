import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/platform/debug_platform_view_hot_restart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/mock/home_mock_data.dart' show NewsArticle, NewsAuthor;
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/data_unavailable_state.dart';
import '../../../shared/widgets/feature_app_bar.dart';
import '../data/announcement_content.dart';
import '../data/announcements_repository.dart';
import '../../news_detail/presentation/news_detail_screen.dart';

const Color _tabDark = AppColors.deepOcean;
const _announcementNewsAuthor = NewsAuthor(
  name: 'Pateeznews',
  avatarUrl: '',
  isOfficial: true,
);

/// Resmî duyurular: valilik/belediye bilgilendirmeleri, elektrik kesintileri ve
/// yol durumu tek ekranda. Kategoriye göre filtrelenir; her kartın sağında küçük
/// görsel/afiş bulunur, dokununca tam ekran büyür (parmakla yakınlaştırılabilir).
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({
    super.key,
    this.items,
    this.initialData,
    this.repository = const AnnouncementsRepository(),
    this.onSearch,
  });

  final List<AnnouncementItem>? items;
  final AnnouncementData? initialData;
  final AnnouncementsRepository repository;
  final VoidCallback? onSearch;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  AnnouncementCategory? _filter; // null = Tümü
  DateTime _selectedDate = _dateBase;
  late AnnouncementData _data;
  var _refreshing = false;

  List<AnnouncementItem> get _items => widget.items ?? _data.announcements;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData ?? const AnnouncementData.empty();
  }

  @override
  void didUpdateWidget(covariant AnnouncementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData != oldWidget.initialData &&
        widget.initialData != null) {
      _data = widget.initialData!;
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || widget.items != null) return;
    setState(() => _refreshing = true);
    final data = await widget.repository.fetch();
    if (!mounted) return;
    setState(() {
      _data = data;
      _refreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final all = _items;
    final categoryVisible = _filter == null
        ? all
        : all.where((a) => a.category == _filter).toList(growable: false);
    final visible = categoryVisible;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            FeatureAppBar(title: 'Duyurular', onSearch: widget.onSearch),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.actionRed,
                backgroundColor: AppColors.surface,
                displacement: 32,
                onRefresh: _refresh,
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.lg,
                    AppSpacing.pageHorizontal,
                    AppSpacing.xxxl + bottomInset,
                  ),
                  children: [
                    if (all.isEmpty)
                      const DataUnavailableState()
                    else ...[
                      _HeroBanner(
                            totalCount: all.length,
                            allSelected: _filter == null,
                            onAllTap: () => setState(() => _filter = null),
                          )
                          .animate()
                          .fadeIn(duration: 340.ms, curve: Curves.easeOutCubic)
                          .slideY(
                            begin: 0.05,
                            end: 0,
                            duration: 340.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      const SizedBox(height: AppSpacing.lg),
                      _CategoryChips(
                        items: all,
                        selected: _filter,
                        onSelect: (category) =>
                            setState(() => _filter = category),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _DateStrip(
                        selected: _selectedDate,
                        onSelect: (date) =>
                            setState(() => _selectedDate = date),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (var i = 0; i < visible.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.md),
                        _AnnouncementCard(
                              item: visible[i],
                              heroTag: 'announcement-${visible[i].title}',
                              onTap: () => _openAnnouncement(visible[i]),
                              onSourceTap: () =>
                                  _openAnnouncementSource(visible[i]),
                            )
                            .animate()
                            .fadeIn(
                              delay: (60 * (i + 1)).ms,
                              duration: 300.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .slideY(
                              begin: 0.05,
                              end: 0,
                              delay: (60 * (i + 1)).ms,
                              duration: 300.ms,
                              curve: Curves.easeOutCubic,
                            ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAnnouncement(AnnouncementItem item) async {
    if (item.hasLinkedPost) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => NewsDetailScreen(
            articles: [_newsArticleFromAnnouncement(item)],
            initialIndex: 0,
          ),
        ),
      );
      return;
    }

    await _openAnnouncementSource(item);
  }

  Future<void> _openAnnouncementSource(AnnouncementItem item) async {
    final uri = Uri.tryParse(item.sourceUrl.trim());
    if (uri == null || !uri.hasScheme) return;
    if (_isSocialUrl(uri)) {
      try {
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        if (opened) return;
      } catch (_) {
        // Sosyal uygulama yoksa duyuru bağlantısı uygulama içi tarayıcıya düşer.
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _AnnouncementBrowserScreen(
          uri: uri,
          title: item.source.trim().isEmpty ? 'Duyuru' : item.source,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero bilgi kartı
// ---------------------------------------------------------------------------

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.totalCount,
    required this.allSelected,
    required this.onAllTap,
  });

  final int totalCount;
  final bool allSelected;
  final VoidCallback onAllTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.deepOcean.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Symbols.notifications,
              size: 23,
              color: AppColors.deepOcean,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.actionRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Niğde · ${_fullDateLabel(_dateBase)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.meta.copyWith(
                          color: AppColors.support,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Duyuru Merkezi',
                  style: AppTypography.titleL.copyWith(
                    color: AppColors.inkStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Valilik · belediye · kurum',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.inkSoft,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterChip(
            label: 'Tümü',
            count: totalCount,
            color: AppColors.deepOcean,
            selected: allSelected,
            onTap: onAllTap,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filtre çipleri (Tümü + kategoriler, sayaçlı)
// ---------------------------------------------------------------------------

/// Üç kategori çipi — eşit genişlikte, tam responsive (yan yana sığar, hepsi
/// görünür). Seçili çipe tekrar dokunmak "Tümü"ne (filtre yok) döner.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<AnnouncementItem> items;
  final AnnouncementCategory? selected;
  final ValueChanged<AnnouncementCategory?> onSelect;

  int _count(AnnouncementCategory category) =>
      items.where((a) => a.category == category).length;

  @override
  Widget build(BuildContext context) {
    final categories = AnnouncementCategory.values;
    return Row(
      children: [
        for (var i = 0; i < categories.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _FilterChip(
              label: categories[i].label,
              count: _count(categories[i]),
              color: categories[i].color,
              selected: selected == categories[i],
              onTap: () =>
                  onSelect(selected == categories[i] ? null : categories[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    return Material(
      color: selected ? _tabDark : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? _tabDark : AppColors.line),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: AppTypography.eyebrow.copyWith(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: AppTypography.eyebrow.copyWith(
                    color: selected ? Colors.white70 : AppColors.support,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
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

// ---------------------------------------------------------------------------
// Duyuru kartı
// ---------------------------------------------------------------------------

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.item,
    required this.heroTag,
    required this.onTap,
    required this.onSourceTap,
  });

  final AnnouncementItem item;
  final String heroTag;
  final VoidCallback onTap;
  final VoidCallback onSourceTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: item.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _CardBody(
                            item: item,
                            onSourceTap: onSourceTap,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _Thumb(item: item, heroTag: heroTag),
                      ],
                    ),
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

class _CardBody extends StatelessWidget {
  const _CardBody({required this.item, required this.onSourceTap});

  final AnnouncementItem item;
  final VoidCallback onSourceTap;

  @override
  Widget build(BuildContext context) {
    final detailText = _announcementDetailText(item);
    final dateInfo = _announcementDateInfo(item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(child: _SourceBadge(item: item)),
            const SizedBox(width: AppSpacing.sm),
            Text(
              item.timeLabel,
              style: AppTypography.meta.copyWith(
                color: AppColors.support,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          item.title,
          style: AppTypography.titleM.copyWith(
            color: AppColors.inkStrong,
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        if (detailText.isNotEmpty)
          Text(
            detailText,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.inkSoft,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        if (dateInfo.isNotEmpty) ...[
          const SizedBox(height: 9),
          _InfoLine(icon: Symbols.calendar_event_line, text: dateInfo),
        ],
        if (item.sourceUrl.trim().isNotEmpty) ...[
          const SizedBox(height: 9),
          _SourceLink(item: item, onTap: onSourceTap),
        ],
        const SizedBox(height: 10),
        _MetaRow(item: item),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1.5),
          child: Icon(icon, size: 13, color: AppColors.support),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              color: AppColors.inkSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.item, required this.onTap});

  final AnnouncementItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Row(
            children: [
              Icon(Symbols.open_in_new, size: 13, color: item.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Başvuru / detay linki',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: item.color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _hostLabel(item.sourceUrl),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.support,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.item});

  final AnnouncementItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 13, color: item.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              item.source,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.eyebrow.copyWith(
                color: item.color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.item});

  final AnnouncementItem item;

  @override
  Widget build(BuildContext context) {
    final placeLabel = _placeLabelFor(item.place);
    final chips = <Widget>[
      if (item.scheduleLabel.isNotEmpty)
        _MetaChip(icon: Symbols.time_fill, label: item.scheduleLabel),
      if (item.statusLabel.isNotEmpty)
        _StatusPill(label: item.statusLabel, color: _statusColor(item)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips.isNotEmpty) ...[
          Wrap(spacing: 6, runSpacing: 6, children: chips),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1.5),
              child: Icon(Symbols.map_pin_line, size: 13, color: item.color),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Kapsam: $placeLabel',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.meta.copyWith(
                  color: AppColors.inkSoft,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceInk,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.inkSoft),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.eyebrow.copyWith(
              color: AppColors.ink,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.eyebrow.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(AnnouncementItem item) {
  switch (item.statusLabel.toLowerCase()) {
    case 'kapalı':
    case 'arıza':
      return AppColors.actionRed;
    case 'açık':
      return const Color(0xFF2F8F67);
    case 'planlı':
    case 'çalışma':
    case 'uyarı':
      return const Color(0xFFE59A22);
    default:
      return item.color;
  }
}

NewsArticle _newsArticleFromAnnouncement(AnnouncementItem item) {
  final post = item.linkedPost;
  final publishedAt = DateTime.tryParse(post.publishedAt)?.toLocal();
  return NewsArticle(
    id: post.id,
    author: _announcementNewsAuthor,
    region: 'Niğde',
    category: post.category.trim().isEmpty
        ? item.category.label
        : post.category,
    title: post.title.trim().isEmpty ? item.title : post.title,
    summary: post.summary.trim().isEmpty ? item.summary : post.summary,
    imageUrl: post.imageUrl.trim().isEmpty ? item.imageUrl : post.imageUrl,
    publishedAt: publishedAt ?? DateTime.now(),
    readMinutes: 2,
    likes: 0,
    dislikes: 0,
    comments: 0,
    shares: 0,
  );
}

bool _isSocialUrl(Uri uri) {
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  return host == 'instagram.com' ||
      host.endsWith('.instagram.com') ||
      host == 'facebook.com' ||
      host.endsWith('.facebook.com') ||
      host == 'fb.watch';
}

String _announcementDetailText(AnnouncementItem item) {
  final title = _compactAnnouncementText(item.title);
  final summary = _cleanAnnouncementDisplayText(item.summary, item);
  var body = _cleanAnnouncementDisplayText(item.body, item);
  if (title.isNotEmpty && body.toLowerCase().startsWith(title.toLowerCase())) {
    body = body.substring(title.length).trim();
  }
  if (summary.isEmpty) return body;
  if (body.isEmpty) return summary;
  final lowerBody = body.toLowerCase();
  final lowerSummary = summary.toLowerCase();
  if (lowerBody.contains(lowerSummary) || lowerSummary.contains(lowerBody)) {
    return body.length >= summary.length ? body : summary;
  }
  return '$summary\n\n$body';
}

String _cleanAnnouncementDisplayText(String value, AnnouncementItem item) {
  var text = _compactAnnouncementText(value);
  if (text.isEmpty) return '';

  final titleIndex = _indexOfLoose(text, item.title);
  if (titleIndex > 0) {
    final afterTitle = titleIndex + _compactAnnouncementText(item.title).length;
    if (afterTitle < text.length) {
      text = text.substring(afterTitle).trim();
    }
  } else {
    final contentIndex = _firstAnnouncementContentIndex(text);
    if (contentIndex > 0 &&
        _looksLikePageChrome(text.substring(0, contentIndex))) {
      text = text.substring(contentIndex).trim();
    }
  }

  final contentIndex = _firstAnnouncementContentIndex(text);
  if (contentIndex > 0 &&
      _looksLikePageChrome(text.substring(0, contentIndex))) {
    text = text.substring(contentIndex).trim();
  }

  if (_looksLikePageChrome(text) && contentIndex < 0) return '';
  return text;
}

String _compactAnnouncementText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

int _indexOfLoose(String text, String phrase) {
  final cleanPhrase = _compactAnnouncementText(phrase);
  if (cleanPhrase.isEmpty) return -1;
  final exact = text.indexOf(cleanPhrase);
  if (exact >= 0) return exact;
  return text.toLowerCase().indexOf(cleanPhrase.toLowerCase());
}

int _firstAnnouncementContentIndex(String text) {
  final patterns = [
    RegExp(r'başvurular[ıi]n', caseSensitive: false, unicode: true),
    RegExp(r'başlama\s+tarihi', caseSensitive: false, unicode: true),
    RegExp(r'sona\s+erme\s+tarihi', caseSensitive: false, unicode: true),
    RegExp(r'son\s+başvuru', caseSensitive: false, unicode: true),
    RegExp(r'başvuru\s+yapmak', caseSensitive: false, unicode: true),
    RegExp(r'detayl[ıi]\s+bilgi', caseSensitive: false, unicode: true),
  ];
  var first = -1;
  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    if (first < 0 || match.start < first) first = match.start;
  }
  return first;
}

bool _looksLikePageChrome(String value) {
  final text = _foldTurkish(value);
  final signals = [
    'gorme engelli',
    'ana sayfa',
    'kurumsal',
    'il muduru',
    'sube mudurlukleri',
    'alt yapi',
    'arazi degerlendirme',
    'bakanligi',
  ];
  final count = signals.where(text.contains).length;
  return count >= 2 || (text.startsWith('t.c.') && count >= 1);
}

String _foldTurkish(String value) {
  return value
      .toLowerCase()
      .replaceAll('i̇', 'i')
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

String _announcementDateInfo(AnnouncementItem item) {
  final parts = <String>[];
  final published = _dateLabelFromIso(item.publishedAt);
  if (published.isNotEmpty) {
    parts.add('Yayın: $published');
  } else if (item.timeLabel.trim().isNotEmpty) {
    parts.add('Yayın: ${item.timeLabel.trim()}');
  }
  final starts = _dateLabelFromIso(item.startsAt);
  if (starts.isNotEmpty) parts.add('Başlangıç: $starts');
  final ends = _dateLabelFromIso(item.endsAt);
  if (ends.isNotEmpty) parts.add('Bitiş: $ends');
  return parts.join(' · ');
}

String _dateLabelFromIso(String value) {
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) return '';
  final local = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  final date = '${two(local.day)}.${two(local.month)}.${local.year}';
  final hasTime = local.hour != 0 || local.minute != 0;
  return hasTime ? '$date ${two(local.hour)}:${two(local.minute)}' : date;
}

String _hostLabel(String value) {
  final uri = Uri.tryParse(value.trim());
  final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  if (host == null || host.isEmpty) return 'Kaynak';
  return host;
}

String _placeLabelFor(String value) {
  final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.isEmpty) return 'Niğde geneli';
  final normalized = clean
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
  const districtTokens = [
    'merkez',
    'altunhisar',
    'bor',
    'camardi',
    'ciftlik',
    'ulukisla',
  ];
  final districtCount = districtTokens
      .where((district) => normalized.contains(district))
      .length;
  if (districtCount >= 3) return 'Niğde geneli';
  return clean;
}

// ---------------------------------------------------------------------------
// Sağdaki küçük görsel (afiş) + tam ekran büyütme
// ---------------------------------------------------------------------------

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, required this.heroTag});

  final AnnouncementItem item;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openAnnouncementViewer(context, item, heroTag),
      child: SizedBox(
        width: 78,
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: heroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _AnnouncementVisual(item: item),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(
                    Symbols.image_outlined,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Görsel varsa gerçek (disk-cache'li) foto; yoksa kategori renginde markalı afiş.
class _AnnouncementVisual extends StatelessWidget {
  const _AnnouncementVisual({required this.item, this.large = false});

  final AnnouncementItem item;
  final bool large;

  @override
  Widget build(BuildContext context) {
    if (item.hasImage) {
      return CachedImage(
        url: item.imageUrl,
        fit: large ? BoxFit.contain : BoxFit.cover,
        errorWidget: _PosterPlaceholder(item: item),
      );
    }
    return _PosterPlaceholder(item: item);
  }
}

/// API'den görsel gelene kadar kullanılan, kuruma/duyuruya özel markalı "afiş".
/// Boyuta göre uyarlanır: küçükken sade ikon, büyükken başlık + kaynak.
class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder({required this.item});

  final AnnouncementItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.color;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final big = w > 180;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, Colors.white, 0.14)!,
                color,
                Color.lerp(color, Colors.black, 0.30)!,
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: -w * 0.20,
                top: -w * 0.20,
                child: _SoftCircle(size: w * 0.62, opacity: 0.08),
              ),
              Positioned(
                left: -w * 0.18,
                bottom: -w * 0.24,
                child: _SoftCircle(size: w * 0.5, opacity: 0.06),
              ),
              if (big)
                _PosterContent(item: item)
              else
                Center(
                  child: Icon(
                    item.icon,
                    size: w * 0.42,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PosterContent extends StatelessWidget {
  const _PosterContent({required this.item});

  final AnnouncementItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 19, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item.category.longLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.eyebrow.copyWith(
                    color: Colors.white,
                    fontSize: 12.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleL.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _AnnouncementBrowserScreen extends StatefulWidget {
  const _AnnouncementBrowserScreen({required this.uri, required this.title});

  final Uri uri;
  final String title;

  @override
  State<_AnnouncementBrowserScreen> createState() =>
      _AnnouncementBrowserScreenState();
}

class _AnnouncementBrowserScreenState
    extends State<_AnnouncementBrowserScreen> {
  WebViewController? _controller;
  var _progress = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_configureController());
  }

  Future<void> _configureController() async {
    await prepareDebugDarwinPlatformViewsForHotRestart();
    if (!mounted) return;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
        ),
      )
      ..loadRequest(widget.uri);
    if (mounted) setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(12, topInset + 8, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.line.withValues(alpha: 0.8),
                  ),
                ),
              ),
              child: Row(
                children: [
                  _BrowserCloseButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleS.copyWith(
                            color: AppColors.inkStrong,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          widget.uri.host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.meta.copyWith(
                            color: AppColors.support,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_progress < 100)
              LinearProgressIndicator(
                value: _progress <= 0 ? null : _progress / 100,
                minHeight: 2,
                color: AppColors.actionRed,
                backgroundColor: AppColors.surfaceInk,
              ),
            Expanded(
              child: _controller == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.actionRed,
                      ),
                    )
                  : WebViewWidget(controller: _controller!),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowserCloseButton extends StatelessWidget {
  const _BrowserCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceInk,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            Symbols.close_rounded,
            size: 19,
            color: AppColors.deepOcean,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tam ekran görsel görüntüleyici (Hero + InteractiveViewer / pinch-zoom)
// ---------------------------------------------------------------------------

void _openAnnouncementViewer(
  BuildContext context,
  AnnouncementItem item,
  String heroTag,
) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) =>
          _AnnouncementViewer(item: item, heroTag: heroTag),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    ),
  );
}

class _AnnouncementViewer extends StatelessWidget {
  const _AnnouncementViewer({required this.item, required this.heroTag});

  final AnnouncementItem item;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.darkOverlay,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.93)),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  top: topInset + 64,
                  bottom: bottomInset + 132,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 440,
                        maxHeight: 560,
                      ),
                      child: AspectRatio(
                        aspectRatio: 4 / 5,
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Hero(
                            tag: heroTag,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _AnnouncementVisual(
                                item: item,
                                large: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: topInset + 10,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  _ViewerCircleButton(
                    icon: Symbols.close_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.category.longLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleS.copyWith(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          item.source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.meta.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: bottomInset + 26,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.scheduleLabel.isNotEmpty ||
                      item.statusLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          if (item.scheduleLabel.isNotEmpty)
                            _MetaChip(
                              icon: Symbols.time_fill,
                              label: item.scheduleLabel,
                            ),
                          if (item.statusLabel.isNotEmpty)
                            _StatusPill(
                              label: item.statusLabel,
                              color: _statusColor(item),
                            ),
                        ],
                      ),
                    ),
                  Text(
                    item.title,
                    style: AppTypography.titleL.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.summary,
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Symbols.map_pin_line,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.meta.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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

class _ViewerCircleButton extends StatelessWidget {
  const _ViewerCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 19, color: Colors.white),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarih seçici — şık yatay gün şeridi (tek tarih seçimi)
// ---------------------------------------------------------------------------

const _trWeekdayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _trMonthNames = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

final _nowDate = DateTime.now();
final _dateBase = DateTime(_nowDate.year, _nowDate.month, _nowDate.day);
final _dateRange = List<DateTime>.generate(
  14,
  (i) => _dateBase.add(Duration(days: i)),
);

String _weekdayShort(DateTime date) => _trWeekdayShort[date.weekday - 1];
String _fullDateLabel(DateTime date) =>
    '${date.day} ${_trMonthNames[date.month - 1]} ${date.year}';
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Symbols.calendar_event_line,
              size: 15,
              color: AppColors.deepOcean,
            ),
            const SizedBox(width: 7),
            Text(
              'Tarih',
              style: AppTypography.eyebrow.copyWith(
                color: AppColors.inkStrong,
                fontSize: 12.5,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              _fullDateLabel(selected),
              style: AppTypography.meta.copyWith(
                color: AppColors.inkSoft,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _dateRange.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final date = _dateRange[i];
              return _DayCard(
                date: date,
                selected: _sameDay(date, selected),
                isToday: _sameDay(date, _dateBase),
                onTap: () => onSelect(date),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    return Material(
      color: selected ? _tabDark : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? _tabDark : AppColors.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _weekdayShort(date),
                style: AppTypography.eyebrow.copyWith(
                  color: selected ? Colors.white70 : AppColors.support,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${date.day}',
                style: AppTypography.titleM.copyWith(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday
                      ? (selected ? Colors.white : AppColors.actionRed)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
