import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../data/frontend_ads_repository.dart';
import 'frontend_ad_slot.dart';

class FrontendAnchorAdDock extends StatefulWidget {
  const FrontendAnchorAdDock({
    super.key,
    this.repository = const FrontendAdsRepository(),
  });

  final FrontendAdsRepository repository;

  @override
  State<FrontendAnchorAdDock> createState() => _FrontendAnchorAdDockState();
}

class _FrontendAnchorAdDockState extends State<FrontendAnchorAdDock> {
  static const _slotKey = 'mobile_anchor';
  late Future<FrontendAdSettings> _future;
  FrontendAdSettings? _initialData;
  var _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  @override
  void didUpdateWidget(covariant FrontendAnchorAdDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _loadAds();
    }
  }

  void _loadAds() {
    _initialData = widget.repository.cachedMobileAds;
    _future = widget.repository.fetchMobileAds();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return FutureBuilder<FrontendAdSettings>(
      future: _future,
      initialData: _initialData,
      builder: (context, snapshot) {
        final slot = snapshot.data?.slotByKey(_slotKey);
        if (slot == null || slot.creatives.isEmpty) {
          return const SizedBox.shrink();
        }

        final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
        final bottomPadding = math.max(bottomInset + 8, 8).toDouble();
        return Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width - 24;
                final frameWidth = math.min(availableWidth, 336).toDouble();
                final adWidth = math.min(frameWidth, 320).toDouble();

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: AppColors.softLine),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.deepOcean.withValues(alpha: 0.16),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: frameWidth,
                        height: 50,
                        child: Center(
                          child: FrontendAdSlot(
                            slotKey: _slotKey,
                            margin: EdgeInsets.zero,
                            maxWidth: adWidth,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -11,
                      right: -9,
                      child: Material(
                        color: Colors.transparent,
                        child: Semantics(
                          button: true,
                          label: 'Reklamı kapat',
                          child: InkWell(
                            onTap: () => setState(() => _dismissed = true),
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.surface.withValues(
                                  alpha: 0.98,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.softLine),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.deepOcean.withValues(
                                      alpha: 0.14,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Symbols.close_rounded,
                                size: 14,
                                color: AppColors.deepOcean,
                                semanticLabel: '',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
