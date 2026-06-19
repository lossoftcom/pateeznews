import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/services/frontend_link_launcher.dart';
import '../../../shared/widgets/cached_image.dart';
import '../data/frontend_ads_repository.dart';

class FrontendAdSlot extends StatelessWidget {
  const FrontendAdSlot({
    super.key,
    required this.slotKey,
    this.repository = const FrontendAdsRepository(),
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.pageHorizontal,
      vertical: AppSpacing.md,
    ),
    this.maxWidth,
  });

  final String slotKey;
  final FrontendAdsRepository repository;
  final EdgeInsetsGeometry margin;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FrontendAdSettings>(
      future: repository.fetchMobileAds(),
      builder: (context, snapshot) {
        final slot = snapshot.data?.slotByKey(slotKey);
        if (slot == null || slot.creatives.isEmpty) {
          return const SizedBox.shrink();
        }
        final creative = _pickCreative(slot);
        if (creative == null) return const SizedBox.shrink();
        return _FrontendImageAd(
          slot: slot,
          creative: creative,
          margin: margin,
          maxWidth: maxWidth,
        );
      },
    );
  }
}

class _FrontendImageAd extends StatelessWidget {
  const _FrontendImageAd({
    required this.slot,
    required this.creative,
    required this.margin,
    required this.maxWidth,
  });

  final FrontendAdSlotData slot;
  final FrontendAdCreative creative;
  final EdgeInsetsGeometry margin;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final naturalWidth = _positive(creative.width) ?? _positive(slot.width);
    final naturalHeight = _positive(creative.height) ?? _positive(slot.height);
    final ratio = naturalWidth != null && naturalHeight != null
        ? naturalWidth / naturalHeight
        : null;

    return Padding(
      padding: margin,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final targetMaxWidth = maxWidth ?? naturalWidth ?? availableWidth;
          final width = math.min(availableWidth, targetMaxWidth);
          final height = ratio != null ? width / ratio : null;

          final image = ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: width,
              height: height,
              child: CachedImage(
                url: creative.imageUrl,
                fit: BoxFit.contain,
                placeholderColor: AppColors.surfaceSoft,
              ),
            ),
          );

          return Center(
            child: creative.linkUrl.isEmpty
                ? image
                : Semantics(
                    button: true,
                    label: creative.name,
                    child: InkWell(
                      onTap: () => openFrontendLink(creative.linkUrl),
                      borderRadius: BorderRadius.circular(4),
                      child: image,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

FrontendAdCreative? _pickCreative(FrontendAdSlotData slot) {
  if (slot.creatives.isEmpty) return null;
  final totalWeight = slot.creatives.fold<int>(
    0,
    (total, creative) => total + creative.weight,
  );
  if (totalWeight <= 0) return slot.creatives.first;

  final target =
      _hashString(
        '${slot.key}:${slot.creatives.map((creative) => creative.id).join('|')}',
      ) %
      totalWeight;
  var cursor = 0;
  for (final creative in slot.creatives) {
    cursor += creative.weight;
    if (target < cursor) return creative;
  }
  return slot.creatives.first;
}

int _hashString(String value) {
  var hash = 0;
  for (var index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.codeUnitAt(index)) & 0x7fffffff;
  }
  return hash;
}

double? _positive(num value) => value > 0 ? value.toDouble() : null;
