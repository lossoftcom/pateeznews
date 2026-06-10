import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

enum FrontendToastTone { success, info, error }

class FrontendToast {
  const FrontendToast._();

  static VoidCallback? _dismissActive;

  static void show(
    BuildContext context, {
    required String message,
    FrontendToastTone tone = FrontendToastTone.success,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

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
      builder: (context) => _FrontendToastOverlay(
        message: message,
        tone: tone,
        duration: duration,
        onDismissed: removeEntry,
      ),
    );
    _dismissActive = removeEntry;
    overlay.insert(entry);
  }

  static void dismiss() {
    _dismissActive?.call();
    _dismissActive = null;
  }
}

class _FrontendToastOverlay extends StatefulWidget {
  const _FrontendToastOverlay({
    required this.message,
    required this.tone,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final FrontendToastTone tone;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_FrontendToastOverlay> createState() => _FrontendToastOverlayState();
}

class _FrontendToastOverlayState extends State<_FrontendToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _hideTimer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
      reverseDuration: const Duration(milliseconds: 170),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.34),
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
      media.viewInsets.bottom + 16,
      media.padding.bottom + 82,
    );
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom,
      child: IgnorePointer(
        child: Center(
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: _FrontendStatusToast(
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

class _FrontendStatusToast extends StatelessWidget {
  const _FrontendStatusToast({required this.message, required this.tone});

  final String message;
  final FrontendToastTone tone;

  IconData get _icon {
    switch (tone) {
      case FrontendToastTone.error:
        return Symbols.close_rounded;
      case FrontendToastTone.info:
        return Symbols.info_outline_rounded;
      case FrontendToastTone.success:
        return Symbols.check_rounded;
    }
  }

  List<Color> get _backgroundColors {
    switch (tone) {
      case FrontendToastTone.error:
        return const [
          Color(0xFFF04C3E),
          AppColors.actionRed,
          Color(0xFFC62F24),
        ];
      case FrontendToastTone.info:
      case FrontendToastTone.success:
        return const [Color(0xE62C3E50), Color(0xF20B0F14)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 322),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _backgroundColors,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 10, 15, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 23,
                      height: 23,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(_icon, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        message,
                        style: AppTypography.titleS.copyWith(
                          color: Colors.white,
                          fontSize: 13.2,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: 0,
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
    );
  }
}
