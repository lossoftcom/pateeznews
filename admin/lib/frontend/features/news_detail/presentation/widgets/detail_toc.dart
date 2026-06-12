import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';

const double _tocCornerRadius = 4;

class DetailTocBlock extends StatefulWidget {
  const DetailTocBlock({
    super.key,
    required this.data,
    required this.title,
    required this.description,
  });

  final NewsTocData data;
  final String title;
  final String description;

  @override
  State<DetailTocBlock> createState() => _DetailTocBlockState();
}

class _DetailTocBlockState extends State<DetailTocBlock> {
  final Map<String, GlobalKey> _sectionKeys = {};
  String? _activeItemId;

  @override
  void didUpdateWidget(covariant DetailTocBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _sectionKeys.clear();
      _activeItemId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.data.items
        .where((item) => item.isValid)
        .toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();
    _syncSectionKeys(items);
    final hierarchy = _TocHierarchy(items);
    final title = _firstNonEmpty(widget.title, widget.data.title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TocHeader(itemCount: items.length, activeItemId: _activeItemId),
        if (title.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTypography.mobileNewsCardTitle.copyWith(
              color: AppColors.inkStrong,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 1.08,
              letterSpacing: 0,
            ),
          ),
        ],
        if (widget.description.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.description.trim(),
            style: AppTypography.mobileNewsCardSummary.copyWith(
              color: AppColors.inkSoft.withValues(alpha: 0.86),
              fontSize: 14,
              height: 1.46,
              letterSpacing: 0,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _TocLinkPanel(
          data: widget.data,
          items: items,
          hierarchy: hierarchy,
          activeItemId: _activeItemId,
          onTap: _scrollToItem,
        ),
        const SizedBox(height: 18),
        _TocSectionLabel(count: items.length),
        const SizedBox(height: 10),
        for (var index = 0; index < items.length; index += 1) ...[
          KeyedSubtree(
            key: _sectionKeyFor(items[index], index),
            child: _TocContentSection(
              data: widget.data,
              item: items[index],
              index: index,
              level: hierarchy.levelFor(items[index]),
              marker: _markerFor(
                widget.data.styleForLevel(hierarchy.levelFor(items[index])),
                items[index],
                index,
              ),
              active: _activeItemId == _tocItemKey(items[index], index),
            ),
          ),
          if (index != items.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }

  void _syncSectionKeys(List<NewsTocItem> items) {
    final activeKeys = <String>{};
    for (var index = 0; index < items.length; index += 1) {
      activeKeys.add(_tocItemKey(items[index], index));
    }
    _sectionKeys.removeWhere((key, _) => !activeKeys.contains(key));
  }

  GlobalKey _sectionKeyFor(NewsTocItem item, int index) {
    return _sectionKeys.putIfAbsent(_tocItemKey(item, index), GlobalKey.new);
  }

  void _scrollToItem(NewsTocItem item, int index) {
    final itemKey = _tocItemKey(item, index);
    setState(() => _activeItemId = itemKey);
    unawaited(_scrollToKey(_sectionKeyFor(item, index)));
  }

  Future<void> _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return Future<void>.value();
    return Scrollable.ensureVisible(
      context,
      alignment: 0.14,
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
    );
  }
}

class _TocHeader extends StatelessWidget {
  const _TocHeader({required this.itemCount, required this.activeItemId});

  final int itemCount;
  final String? activeItemId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.actionRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(_tocCornerRadius),
            border: Border.all(
              color: AppColors.actionRed.withValues(alpha: 0.12),
            ),
          ),
          child: const Icon(
            Symbols.format_list_numbered,
            size: 18,
            color: AppColors.actionRed,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'İçindekiler',
                style: AppTypography.meta.copyWith(
                  color: AppColors.inkStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$itemCount bölüm · hızlı geçiş',
                style: AppTypography.meta.copyWith(
                  color: AppColors.support,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        _TocTinyPill(text: activeItemId == null ? 'Oku' : 'Konumlandı'),
      ],
    );
  }
}

class _TocLinkPanel extends StatelessWidget {
  const _TocLinkPanel({
    required this.data,
    required this.items,
    required this.hierarchy,
    required this.activeItemId,
    required this.onTap,
  });

  final NewsTocData data;
  final List<NewsTocItem> items;
  final _TocHierarchy hierarchy;
  final String? activeItemId;
  final void Function(NewsTocItem item, int index) onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(_tocCornerRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index += 1) ...[
            _TocLinkRow(
              item: items[index],
              index: index,
              level: hierarchy.levelFor(items[index]),
              marker: _markerFor(
                data.styleForLevel(hierarchy.levelFor(items[index])),
                items[index],
                index,
              ),
              styleName: data.styleForLevel(hierarchy.levelFor(items[index])),
              active: activeItemId == _tocItemKey(items[index], index),
              onTap: () => onTap(items[index], index),
            ),
            if (index != items.length - 1)
              Divider(height: 1, thickness: 1, color: AppColors.softLine),
          ],
        ],
      ),
    );
  }
}

class _TocLinkRow extends StatelessWidget {
  const _TocLinkRow({
    required this.item,
    required this.index,
    required this.level,
    required this.marker,
    required this.styleName,
    required this.active,
    required this.onTap,
  });

  final NewsTocItem item;
  final int index;
  final int level;
  final String marker;
  final String styleName;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim().isNotEmpty
        ? item.title.trim()
        : 'Bölüm ${index + 1}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_tocCornerRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(10 + (level - 1) * 13, 10, 10, 10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.actionRed.withValues(alpha: 0.055)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(_tocCornerRadius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TocMarker(marker: marker, styleName: styleName, active: active),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleM.copyWith(
                    color: active ? AppColors.actionRed : AppColors.inkStrong,
                    fontSize: level == 1 ? 13.8 : 12.8,
                    fontWeight: level == 1 ? FontWeight.w900 : FontWeight.w800,
                    height: 1.18,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Symbols.arrow_forward_rounded,
                size: 15,
                color: active ? AppColors.actionRed : AppColors.placeholder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TocMarker extends StatelessWidget {
  const _TocMarker({
    required this.marker,
    required this.styleName,
    required this.active,
  });

  final String marker;
  final String styleName;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (styleName == 'none') {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 4,
        height: active ? 24 : 17,
        decoration: BoxDecoration(
          color: active ? AppColors.actionRed : AppColors.warmHorizon,
          borderRadius: BorderRadius.circular(_tocCornerRadius),
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minWidth: 25),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? AppColors.actionRed
            : AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(_tocCornerRadius),
        border: Border.all(
          color: active
              ? AppColors.actionRed
              : AppColors.line.withValues(alpha: 0.9),
        ),
      ),
      child: Text(
        marker,
        style: AppTypography.meta.copyWith(
          color: active ? AppColors.surface : AppColors.inkSoft,
          fontSize: 10.2,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _TocSectionLabel extends StatelessWidget {
  const _TocSectionLabel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Symbols.menu_book_rounded,
          size: 16,
          color: AppColors.actionRed,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Bölümler',
            style: AppTypography.titleM.copyWith(
              color: AppColors.inkStrong,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: 0,
            ),
          ),
        ),
        Text(
          '$count madde',
          style: AppTypography.meta.copyWith(
            color: AppColors.support,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _TocContentSection extends StatelessWidget {
  const _TocContentSection({
    required this.data,
    required this.item,
    required this.index,
    required this.level,
    required this.marker,
    required this.active,
  });

  final NewsTocData data;
  final NewsTocItem item;
  final int index;
  final int level;
  final String marker;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim();
    final prefix = data.showStyleInTextForLevel(level) && marker.isNotEmpty
        ? '$marker '
        : '';
    final sectionTitle = title.isNotEmpty
        ? '$prefix$title'
        : '${prefix}Bölüm ${index + 1}'.trim();
    final paragraphs = _paragraphs(item.content);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: active
            ? AppColors.surfaceSoft.withValues(alpha: 0.9)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(_tocCornerRadius),
        border: Border.all(color: active ? AppColors.line : AppColors.softLine),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.actionRed.withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : const [],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: active ? AppColors.actionRed : AppColors.warmHorizon,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(_tocCornerRadius),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 13, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionOrdinal(index: index, level: level),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sectionTitle,
                        style: AppTypography.titleL.copyWith(
                          color: AppColors.inkStrong,
                          fontSize: level == 1 ? 20 : 17.5,
                          fontWeight: FontWeight.w900,
                          height: 1.16,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.imageUrl.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _TocSectionImage(item: item),
                ],
                if (paragraphs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (var i = 0; i < paragraphs.length; i += 1) ...[
                    Text(
                      paragraphs[i],
                      style: AppTypography.mobileDetailBody.copyWith(
                        color: AppColors.ink.withValues(alpha: 0.94),
                        fontSize: 15.1,
                        height: 1.58,
                        letterSpacing: 0,
                      ),
                    ),
                    if (i != paragraphs.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TocSectionImage extends StatelessWidget {
  const _TocSectionImage({required this.item});

  final NewsTocItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_tocCornerRadius),
          child: ColoredBox(
            color: AppColors.surfaceSoft,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedImage(
                url: item.imageUrl,
                fit: BoxFit.contain,
                memCacheWidth: 900,
              ),
            ),
          ),
        ),
        if (item.imageDescription.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            item.imageDescription.trim(),
            style: AppTypography.meta.copyWith(
              color: AppColors.support.withValues(alpha: 0.76),
              fontSize: 10.8,
              fontStyle: FontStyle.italic,
              height: 1.25,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionOrdinal extends StatelessWidget {
  const _SectionOrdinal({required this.index, required this.level});

  final int index;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: level == 1 ? AppColors.deepOcean : AppColors.surfaceInk,
        borderRadius: BorderRadius.circular(_tocCornerRadius),
        border: Border.all(
          color: level == 1 ? AppColors.deepOcean : AppColors.line,
        ),
      ),
      child: Text(
        (index + 1).toString(),
        style: AppTypography.meta.copyWith(
          color: level == 1 ? AppColors.surface : AppColors.inkSoft,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _TocTinyPill extends StatelessWidget {
  const _TocTinyPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey<String>(text),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.warmHorizon.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(_tocCornerRadius),
        ),
        child: Text(
          text,
          style: AppTypography.meta.copyWith(
            color: AppColors.warmHorizon,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _TocHierarchy {
  _TocHierarchy(this.items);

  final List<NewsTocItem> items;

  int levelFor(NewsTocItem item) {
    if (item.parentId.trim().isEmpty) return 1;
    final parent = _parentFor(item.parentId);
    if (parent == null || parent.parentId.trim().isEmpty) return 2;
    return 3;
  }

  NewsTocItem? _parentFor(String parentId) {
    final clean = parentId.trim();
    if (clean.isEmpty) return null;
    for (final item in items) {
      if (item.id.trim() == clean) return item;
    }
    final numeric = int.tryParse(clean);
    if (numeric != null) {
      for (var index = 0; index < items.length; index += 1) {
        final item = items[index];
        if (item.orderNumber == numeric || index + 1 == numeric) return item;
      }
    }
    return null;
  }
}

String _firstNonEmpty(String first, String second) {
  final cleanFirst = first.trim();
  if (cleanFirst.isNotEmpty) return cleanFirst;
  return second.trim();
}

String _tocItemKey(NewsTocItem item, int index) {
  final id = item.id.trim();
  return id.isNotEmpty ? id : 'toc-item-${index + 1}';
}

String _markerFor(String style, NewsTocItem item, int index) {
  final order = item.orderNumber > 0 ? item.orderNumber : index + 1;
  return switch (style) {
    'decimal' => order.toString(),
    'decimal-leading-zero' => order.toString().padLeft(2, '0'),
    'circle' => '○',
    'disc' => '•',
    'square' => '■',
    'lower-alpha' => _alphaMarker(order, uppercase: false),
    'upper-alpha' => _alphaMarker(order, uppercase: true),
    'lower-roman' => _romanMarker(order).toLowerCase(),
    'upper-roman' => _romanMarker(order),
    _ => '',
  };
}

String _alphaMarker(int value, {required bool uppercase}) {
  var number = value < 1 ? 1 : value;
  final buffer = StringBuffer();
  while (number > 0) {
    number -= 1;
    buffer.writeCharCode(97 + (number % 26));
    number ~/= 26;
  }
  final result = buffer.toString().split('').reversed.join();
  return uppercase ? result.toUpperCase() : result;
}

String _romanMarker(int value) {
  var number = value.clamp(1, 3999);
  final pairs = <(int, String)>[
    (1000, 'M'),
    (900, 'CM'),
    (500, 'D'),
    (400, 'CD'),
    (100, 'C'),
    (90, 'XC'),
    (50, 'L'),
    (40, 'XL'),
    (10, 'X'),
    (9, 'IX'),
    (5, 'V'),
    (4, 'IV'),
    (1, 'I'),
  ];
  final buffer = StringBuffer();
  for (final pair in pairs) {
    while (number >= pair.$1) {
      buffer.write(pair.$2);
      number -= pair.$1;
    }
  }
  return buffer.toString();
}

List<String> _paragraphs(String value) {
  final text = value.trim();
  if (text.isEmpty) return const [];
  return text
      .split(RegExp(r'\n{2,}'))
      .map((part) => part.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}
