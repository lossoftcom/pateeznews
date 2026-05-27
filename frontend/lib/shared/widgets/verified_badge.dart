import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Onaylı yazar / kurumsal hesap için minimal tick rozeti.
///
/// İki varyantı vardır:
/// - `default` (kişisel verified): deep ocean
/// - `official` (Pateez kurumsal hesap): warm horizon
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.official = false, this.size = 14});

  final bool official;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = official ? AppColors.warmHorizon : AppColors.deepOcean;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(
        Icons.check_rounded,
        size: size * 0.7,
        color: Colors.white,
      ),
    );
  }
}
