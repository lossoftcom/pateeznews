import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

enum AdminToastTone { info, success, error }

class AdminToast {
  const AdminToast._();

  static const defaultDuration = Duration(milliseconds: 3200);
  static VoidCallback? _dismissActive;

  static SnackBarThemeData theme() {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 420,
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
      backgroundColor: AppColors.deepOcean,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value * 3),
      ),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.28,
        letterSpacing: 0,
        fontFamily: 'PateezSans',
      ),
      dismissDirection: DismissDirection.down,
    );
  }

  static void show(
    BuildContext context, {
    required String message,
    AdminToastTone tone = AdminToastTone.info,
    Duration duration = defaultDuration,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    _dismissActive?.call();
    _dismissActive = null;

    late final OverlayEntry entry;
    var removed = false;
    void removeEntry() {
      if (removed) return;
      removed = true;
      if (_dismissActive == removeEntry) _dismissActive = null;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (context) => _AdminToastOverlay(
        message: message,
        tone: tone,
        duration: duration,
        onDismissed: removeEntry,
      ),
    );
    _dismissActive = removeEntry;
    overlay.insert(entry);
  }

  static SnackBar snackBar({
    required String message,
    AdminToastTone tone = AdminToastTone.info,
    Duration duration = defaultDuration,
  }) {
    return SnackBar(
      content: _AdminToastCard(message: message, tone: tone),
      duration: duration,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      width: 420,
    );
  }

  static void dismiss() {
    _dismissActive?.call();
    _dismissActive = null;
  }
}

class _AdminToastOverlay extends StatefulWidget {
  const _AdminToastOverlay({
    required this.message,
    required this.tone,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final AdminToastTone tone;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AdminToastOverlay> createState() => _AdminToastOverlayState();
}

class _AdminToastOverlayState extends State<_AdminToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _hideTimer;
  var _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 170),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.28),
      end: Offset.zero,
    ).animate(curve);
    _controller.forward();
    _hideTimer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    _hideTimer?.cancel();
    _controller.reverse().whenComplete(() {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = math.max(
      media.viewInsets.bottom + 18,
      media.padding.bottom + 28,
    );
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: IgnorePointer(
        child: Center(
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: _AdminToastCard(
                message: widget.message,
                tone: widget.tone,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminToastCard extends StatelessWidget {
  const _AdminToastCard({required this.message, required this.tone});

  final String message;
  final AdminToastTone tone;

  Color get _accent {
    return switch (tone) {
      AdminToastTone.error => AppColors.actionRed,
      AdminToastTone.success => const Color(0xFF20B486),
      AdminToastTone.info => AppColors.warmHorizon,
    };
  }

  IconData get _icon {
    return switch (tone) {
      AdminToastTone.error => Symbols.close_rounded,
      AdminToastTone.success => Symbols.check_rounded,
      AdminToastTone.info => Symbols.info_outline_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.value * 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: _accent.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.value * 3),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.deepOcean.withValues(alpha: 0.96),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 4, color: _accent),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.value * 2,
                                  ),
                                  border: Border.all(
                                    color: _accent.withValues(alpha: 0.28),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(_icon, size: 16, color: _accent),
                              ),
                              const SizedBox(width: 11),
                              Flexible(
                                child: Text(
                                  message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    height: 1.28,
                                    letterSpacing: 0,
                                    decoration: TextDecoration.none,
                                    fontFamily: 'PateezSans',
                                  ),
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
            ),
          ),
        ),
      ),
    );
  }
}
