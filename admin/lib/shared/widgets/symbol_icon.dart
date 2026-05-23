import 'package:flutter/material.dart';

class SymbolIcon extends StatelessWidget {
  const SymbolIcon(this.icon, {super.key, this.color, this.size = 20});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      color: color,
      size: size,
      fill: 0,
      grade: 100,
      opticalSize: 20,
      weight: 100,
    );
  }
}
