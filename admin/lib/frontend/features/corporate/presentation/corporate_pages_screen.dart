import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../category/presentation/widgets/category_app_bar.dart';
import '../../shell/data/app_shell_repository.dart';

class CorporatePagesScreen extends StatefulWidget {
  const CorporatePagesScreen({
    super.key,
    required this.pages,
    this.rootLabel = '',
    this.onSearch,
  });

  final List<AppShellPage> pages;
  final String rootLabel;
  final VoidCallback? onSearch;

  @override
  State<CorporatePagesScreen> createState() => _CorporatePagesScreenState();
}

class _CorporatePagesScreenState extends State<CorporatePagesScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollY = ValueNotifier<double>(0);

  var _selectedIndex = 0;

  AppShellPage? get _selectedPage {
    if (widget.pages.isEmpty) return null;
    final safeIndex = _selectedIndex.clamp(0, widget.pages.length - 1);
    return widget.pages[safeIndex];
  }

  void _selectPage(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrollY.value = _scrollController.offset;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollY.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPage;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _scrollY,
              builder: (context, offset, _) => CategoryAppBar(
                title: selected?.title ?? 'Hakkımızda',
                scrollOffset: offset,
                onBack: () => Navigator.of(context).maybePop(),
                onSearch: widget.onSearch,
              ),
            ),
            Expanded(
              child: selected == null
                  ? const _EmptyCorporatePages()
                  : CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: _CorporateIntro(
                            rootLabel: widget.rootLabel,
                            selected: selected,
                            pageCount: widget.pages.length,
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _CorporateTabsHeader(
                            pages: widget.pages,
                            selectedIndex: _selectedIndex,
                            onSelected: _selectPage,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _CorporatePageBody(page: selected),
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

class _CorporateIntro extends StatelessWidget {
  const _CorporateIntro({
    required this.rootLabel,
    required this.selected,
    required this.pageCount,
  });

  final String rootLabel;
  final AppShellPage selected;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final scope = rootLabel.trim().isEmpty ? 'Pateez.com' : rootLabel.trim();
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.softLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.lg,
          AppSpacing.pageHorizontal,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Symbols.article,
                  size: 14,
                  color: AppColors.actionRed,
                ),
                const SizedBox(width: 7),
                Text(
                  'KURUMSAL',
                  style: AppTypography.eyebrow.copyWith(
                    color: AppColors.support,
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 30,
                  margin: const EdgeInsets.only(top: 4, right: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.actionRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(
                    selected.title,
                    style: AppTypography.mobileDetailTitle.copyWith(
                      letterSpacing: -0.2,
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ),
            if (selected.metaDescription.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm + 2),
              Text(
                selected.metaDescription,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(
                  color: AppColors.inkSoft,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _CorporateMetaRow(scope: scope, pageCount: pageCount),
          ],
        ),
      ),
    );
  }
}

class _CorporateMetaRow extends StatelessWidget {
  const _CorporateMetaRow({required this.scope, required this.pageCount});

  final String scope;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: AppTypography.meta.copyWith(
        color: AppColors.support,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      child: Row(
        children: [
          const Icon(
            Symbols.location_on_rounded,
            size: 14,
            color: AppColors.support,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              scope,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.meta.copyWith(
                color: AppColors.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const _MetaDot(),
          const SizedBox(width: 10),
          const Icon(Symbols.article, size: 14, color: AppColors.support),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$pageCount sayfa',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2.5,
      height: 2.5,
      decoration: const BoxDecoration(
        color: AppColors.support,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CorporateTabsHeader extends SliverPersistentHeaderDelegate {
  const _CorporateTabsHeader({
    required this.pages,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AppShellPage> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  double get minExtent => 58;

  @override
  double get maxExtent => 58;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.softLine)),
        boxShadow: overlapsContent
            ? const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        itemBuilder: (context, index) {
          final page = pages[index];
          return _PageTab(
            label: page.title,
            selected: index == selectedIndex,
            onTap: () => onSelected(index),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: pages.length,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CorporateTabsHeader oldDelegate) {
    return oldDelegate.pages != pages ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _PageTab extends StatelessWidget {
  const _PageTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.deepOcean : AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 38,
          constraints: const BoxConstraints(minWidth: 74, maxWidth: 178),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? AppColors.deepOcean : AppColors.line,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.navLabel.copyWith(
              color: selected ? Colors.white : AppColors.inkSoft,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CorporatePageBody extends StatelessWidget {
  const _CorporatePageBody({required this.page});

  final AppShellPage page;

  @override
  Widget build(BuildContext context) {
    final blocks = _contentBlocks(page.contentPlain);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottomInset + 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final block in blocks)
                block.heading
                    ? _ContentHeading(block.text)
                    : _ContentParagraph(block.text),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentHeading extends StatelessWidget {
  const _ContentHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        text,
        style: AppTypography.titleS.copyWith(
          color: AppColors.inkStrong,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

class _ContentParagraph extends StatelessWidget {
  const _ContentParagraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final contactLine = text.contains(':') && text.length < 96;
    return Padding(
      padding: EdgeInsets.only(bottom: contactLine ? 7 : 12),
      child: Text(
        text,
        style:
            (contactLine ? AppTypography.bodySmall : AppTypography.articleBody)
                .copyWith(
                  color: contactLine ? AppColors.inkSoft : AppColors.ink,
                  fontWeight: contactLine ? FontWeight.w600 : FontWeight.w400,
                  height: contactLine ? 1.38 : 1.58,
                ),
      ),
    );
  }
}

class _EmptyCorporatePages extends StatelessWidget {
  const _EmptyCorporatePages();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Sayfa bulunamadı.',
          textAlign: TextAlign.center,
          style: AppTypography.titleS.copyWith(color: AppColors.support),
        ),
      ),
    );
  }
}

class _ContentBlock {
  const _ContentBlock({required this.text, required this.heading});

  final String text;
  final bool heading;
}

List<_ContentBlock> _contentBlocks(String text) {
  final blocks = <_ContentBlock>[];
  var previousWasBlank = true;

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      previousWasBlank = true;
      continue;
    }
    blocks.add(
      _ContentBlock(
        text: line,
        heading: previousWasBlank && _looksLikeHeading(line),
      ),
    );
    previousWasBlank = false;
  }
  return blocks;
}

bool _looksLikeHeading(String value) {
  if (value.length > 54) return false;
  if (value.contains(':')) return false;
  if (value.endsWith('.') || value.endsWith(',') || value.endsWith(';')) {
    return false;
  }
  return true;
}
