import 'package:flutter/material.dart';

class PinchZoomSurface extends StatefulWidget {
  const PinchZoomSurface({super.key, required this.child, this.maxScale = 4});

  final Widget child;
  final double maxScale;

  @override
  State<PinchZoomSurface> createState() => _PinchZoomSurfaceState();
}

class _PinchZoomSurfaceState extends State<PinchZoomSurface> {
  late final TransformationController _controller;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncZoomState() {
    final scale = _controller.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.01;
    if (zoomed != _zoomed && mounted) {
      setState(() => _zoomed = zoomed);
    }
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    final scale = _controller.value.getMaxScaleOnAxis();
    if (scale <= 1.01) {
      _controller.value = Matrix4.identity();
      if (_zoomed && mounted) setState(() => _zoomed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      minScale: 1,
      maxScale: widget.maxScale,
      panEnabled: _zoomed,
      scaleEnabled: true,
      clipBehavior: Clip.hardEdge,
      boundaryMargin: EdgeInsets.zero,
      onInteractionUpdate: (_) => _syncZoomState(),
      onInteractionEnd: _handleInteractionEnd,
      child: widget.child,
    );
  }
}
