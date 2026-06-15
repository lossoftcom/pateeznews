import 'package:flutter/material.dart';

class SymbolIcon extends StatelessWidget {
  const SymbolIcon(
    this.icon, {
    super.key,
    this.color,
    this.size = 20,
    this.visualScale = 0.88,
  });

  final IconData icon;
  final Color? color;
  final double size;
  final double visualScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Icon(icon, color: color, size: size * visualScale),
      ),
    );
  }
}
