import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'featured_card.dart';

/// PageView tabanlı featured haber kaydırıcısı.
///
/// Yapı:
///   1. Genişliği tam dolduran ve yüksekliği görsel oranına göre belirlenen
///      PageView (kartlar arası boşluk yoktur).
///   2. Görselin altına taşan `AppColors.surfaceTinted` zeminli içerik alanı:
///      kategori, başlık, alt spot, yayın zamanı.
///   3. İçerik alanının altında tam ortada, palet kırmızısı (actionRed) sayfa
///      göstergeleri.
class FeaturedSlider extends StatefulWidget {
  const FeaturedSlider({super.key, required this.items});

  final List<FeaturedNews> items;

  @override
  State<FeaturedSlider> createState() => _FeaturedSliderState();
}

class _FeaturedSliderState extends State<FeaturedSlider> {
  static const double _fallbackImageAspectRatio = 16 / 10;
  static const double _contentPanelMinHeight = 0;
  static const double _contentPanelOverlap = 94;
  static const double _imageBlendHeight = 210;
  static const double _contentTopPadding = 64;
  static const double _contentBottomPadding = 8;
  static const double _indicatorTopGap = 12;
  static const double _indicatorHeight = 8;
  static const double _metaIconSize = 13;
  static const double _contentSafetyPadding = 4;

  late final PageController _controller;
  int _index = 0;
  final Map<String, double> _resolvedImageAspectRatios = {};
  final Map<String, ImageStream> _pendingImageStreams = {};
  final Map<String, ImageStreamListener> _pendingImageListeners = {};

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _resolveImageAspectRatios(widget.items);
  }

  @override
  void didUpdateWidget(covariant FeaturedSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _resolveImageAspectRatios(widget.items);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final entry in _pendingImageListeners.entries) {
      _pendingImageStreams[entry.key]?.removeListener(entry.value);
    }
    super.dispose();
  }

  void _goToSlide(int index) {
    if (widget.items.isEmpty) return;
    final target = (index + widget.items.length) % widget.items.length;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePanelDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 180 || widget.items.length < 2) return;
    _goToSlide(velocity < 0 ? _index + 1 : _index - 1);
  }

  void _resolveImageAspectRatios(List<FeaturedNews> items) {
    for (final item in items) {
      final ratio = item.imageAspectRatio;
      if (ratio != null && ratio.isFinite && ratio > 0) {
        _resolvedImageAspectRatios[item.imageUrl] = ratio;
        continue;
      }

      final parsedRatio = _parseImageAspectRatioFromUrl(item.imageUrl);
      if (parsedRatio != null) {
        _resolvedImageAspectRatios[item.imageUrl] = parsedRatio;
        continue;
      }

      _resolveImageAspectRatioFromProvider(item.imageUrl);
    }
  }

  void _resolveImageAspectRatioFromProvider(String imageUrl) {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty ||
        _resolvedImageAspectRatios.containsKey(cleanUrl) ||
        _pendingImageStreams.containsKey(cleanUrl)) {
      return;
    }

    final stream = CachedNetworkImageProvider(
      cleanUrl,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((image, _) {
      _removePendingImageListener(cleanUrl);
      final width = image.image.width;
      final height = image.image.height;
      if (width <= 0 || height <= 0) return;
      if (!mounted) return;
      setState(() {
        _resolvedImageAspectRatios[cleanUrl] = width / height;
      });
    }, onError: (_, _) => _removePendingImageListener(cleanUrl));

    _pendingImageStreams[cleanUrl] = stream;
    _pendingImageListeners[cleanUrl] = listener;
    stream.addListener(listener);
  }

  void _removePendingImageListener(String imageUrl) {
    final stream = _pendingImageStreams.remove(imageUrl);
    final listener = _pendingImageListeners.remove(imageUrl);
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final safeIndex = _index.clamp(0, items.length - 1);
    final active = items[safeIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaWidth = MediaQuery.sizeOf(context).width;
        final constrainedWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : mediaWidth;
        final width = _resolveFiniteWidth(constrainedWidth, mediaWidth);
        final imageAspectRatio =
            _resolvedImageAspectRatios[active.imageUrl] ??
            active.imageAspectRatio ??
            _fallbackImageAspectRatio;
        final imageHeight = width / imageAspectRatio;
        final contentWidth = _resolveFiniteWidth(
          width - (AppSpacing.pageHorizontal * 2),
          mediaWidth - (AppSpacing.pageHorizontal * 2),
        );
        final textScaler = MediaQuery.textScalerOf(context);
        final contentPanelHeight = _resolveContentPanelHeight(
          item: active,
          contentWidth: contentWidth,
          textScaler: textScaler,
        );
        final sliderHeight =
            imageHeight + contentPanelHeight - _contentPanelOverlap;

        return SizedBox(
          height: sliderHeight,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: PageView.builder(
                    controller: _controller,
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      return FeaturedCard(news: items[i], onTap: () {});
                    },
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: imageHeight - _imageBlendHeight,
                height: _imageBlendHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: _featuredBlendGradient),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: imageHeight - _contentPanelOverlap,
                height: contentPanelHeight,
                child: _FeaturedContentPanel(
                  active: active,
                  itemCount: items.length,
                  activeIndex: safeIndex,
                  onHorizontalDragEnd: _handlePanelDragEnd,
                  onIndicatorTap: _goToSlide,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static double _resolveContentPanelHeight({
    required FeaturedNews item,
    required double contentWidth,
    required TextScaler textScaler,
  }) {
    final titleHeight = _measureTextHeight(
      item.title,
      _featuredTitleStyle,
      contentWidth,
      textScaler: textScaler,
    );
    final summaryHeight = _measureTextHeight(
      item.summary,
      _featuredSummaryStyle,
      contentWidth,
      textScaler: textScaler,
      maxLines: 2,
    );
    final timeHeight = _measureTextHeight(
      _formatFeaturedPublishedAt(item.publishedAt),
      _featuredTimeStyle,
      contentWidth,
      textScaler: textScaler,
      maxLines: 1,
    );
    final categoryHeight = _measureTextHeight(
      _formatFeaturedCategory(item.category),
      _featuredCategoryStyle,
      contentWidth,
      textScaler: textScaler,
      maxLines: 1,
    );
    final metaRowHeight = <double>[
      _metaIconSize,
      timeHeight,
      categoryHeight,
    ].reduce((a, b) => a > b ? a : b);
    final contentHeight =
        titleHeight +
        AppSpacing.sm +
        summaryHeight +
        AppSpacing.md +
        metaRowHeight;

    final naturalHeight =
        _contentTopPadding +
        contentHeight +
        _indicatorTopGap +
        _indicatorHeight +
        _contentBottomPadding +
        _contentSafetyPadding;

    return naturalHeight > _contentPanelMinHeight
        ? naturalHeight
        : _contentPanelMinHeight;
  }
}

double? _parseImageAspectRatioFromUrl(String url) {
  final segments = Uri.tryParse(url)?.pathSegments;
  if (segments == null || segments.length < 2) return null;

  final height = int.tryParse(segments[segments.length - 1]);
  final width = int.tryParse(segments[segments.length - 2]);
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }
  return width / height;
}

class _FeaturedContentPanel extends StatelessWidget {
  const _FeaturedContentPanel({
    required this.active,
    required this.itemCount,
    required this.activeIndex,
    required this.onHorizontalDragEnd,
    required this.onIndicatorTap,
  });

  final FeaturedNews active;
  final int itemCount;
  final int activeIndex;
  final GestureDragEndCallback onHorizontalDragEnd;
  final ValueChanged<int> onIndicatorTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: onHorizontalDragEnd,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          _FeaturedSliderState._contentTopPadding,
          AppSpacing.pageHorizontal,
          _FeaturedSliderState._contentBottomPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) =>
                  currentChild ?? const SizedBox.shrink(),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _ActiveContent(
                key: ValueKey<String>('featured-${active.id}'),
                news: active,
              ),
            ),
            const SizedBox(height: _FeaturedSliderState._indicatorTopGap),
            Center(
              child: _Indicator(
                count: itemCount,
                activeIndex: activeIndex,
                onTap: onIndicatorTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveContent extends StatelessWidget {
  const _ActiveContent({super.key, required this.news});

  final FeaturedNews news;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(news.title, style: _featuredTitleStyle),
        const SizedBox(height: AppSpacing.sm),
        Text(
          news.summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _featuredSummaryStyle,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Symbols.schedule_rounded,
              size: _FeaturedSliderState._metaIconSize,
              color: AppColors.inkSoft.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatFeaturedPublishedAt(news.publishedAt),
                    maxLines: 1,
                    softWrap: false,
                    style: _featuredTimeStyle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _formatFeaturedCategory(news.category),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: _featuredCategoryStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _formatFeaturedPublishedAt(DateTime value) {
  final date = value.toUtc().add(const Duration(hours: 3));
  final day = date.day;
  final month = _turkishMonths[date.month - 1];
  final year = date.year.toString().padLeft(4, '0');
  final weekday = _turkishWeekdays[date.weekday - 1];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day $month $year $weekday Saat: $hour:$minute';
}

const _turkishMonths = [
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

const _turkishWeekdays = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

String _formatFeaturedCategory(String category) {
  final trimmed = category.trim();
  if (trimmed.isEmpty) return trimmed;
  final lower = _toTurkishLower(trimmed);
  return _toTurkishUpper(lower.substring(0, 1)) + lower.substring(1);
}

TextStyle get _featuredTitleStyle => AppTypography.mobileFeaturedTitle.copyWith(
  color: AppColors.inkStrong,
  letterSpacing: 0,
  height: 1.08,
);

TextStyle get _featuredSummaryStyle => AppTypography.mobileFeaturedSummary
    .copyWith(color: AppColors.ink, height: 1.42);

TextStyle get _featuredTimeStyle => AppTypography.meta.copyWith(
  color: AppColors.inkSoft,
  fontSize: 11.5,
  fontWeight: FontWeight.w500,
);

TextStyle get _featuredCategoryStyle => AppTypography.eyebrow.copyWith(
  color: AppColors.support,
  fontSize: 10,
  letterSpacing: 1.0,
  fontWeight: FontWeight.w500,
);

const _featuredBlendGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x00F8F9FA),
    Color(0x04F8F9FA),
    Color(0x0AF8F9FA),
    Color(0x16F8F9FA),
    Color(0x2AF8F9FA),
    Color(0x4AF8F9FA),
    Color(0x76F8F9FA),
    Color(0xADF8F9FA),
    AppColors.surfaceTinted,
  ],
  stops: [0, 0.12, 0.26, 0.40, 0.54, 0.68, 0.80, 0.91, 1],
);

double _measureTextHeight(
  String text,
  TextStyle style,
  double maxWidth, {
  required TextScaler textScaler,
  int? maxLines,
}) {
  final textMaxWidth = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 1.0;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: maxLines,
    textScaler: textScaler,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: textMaxWidth);
  return painter.height;
}

double _resolveFiniteWidth(double preferred, double fallback) {
  if (preferred.isFinite && preferred > 0) return preferred;
  if (fallback.isFinite && fallback > 0) return fallback;
  return 1.0;
}

String _toTurkishLower(String value) {
  return value
      .replaceAll('I', 'ı')
      .replaceAll('İ', 'i')
      .replaceAll('Ğ', 'ğ')
      .replaceAll('Ü', 'ü')
      .replaceAll('Ş', 'ş')
      .replaceAll('Ö', 'ö')
      .replaceAll('Ç', 'ç')
      .toLowerCase();
}

String _toTurkishUpper(String value) {
  return value
      .replaceAll('ı', 'I')
      .replaceAll('i', 'İ')
      .replaceAll('ğ', 'Ğ')
      .replaceAll('ü', 'Ü')
      .replaceAll('ş', 'Ş')
      .replaceAll('ö', 'Ö')
      .replaceAll('ç', 'Ç')
      .toUpperCase();
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.count,
    required this.activeIndex,
    required this.onTap,
  });

  final int count;
  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == activeIndex;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3.5),
            height: 8,
            width: isActive ? 28 : 8,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.actionRed
                  : AppColors.support.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
