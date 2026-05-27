import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../social_platform_data.dart';

class SocialBrandLogo extends StatelessWidget {
  const SocialBrandLogo({
    super.key,
    required this.info,
    this.size = 24,
    this.iconSize,
    this.active = true,
    this.showBackground = true,
  });

  final SocialPlatformInfo info;
  final double size;
  final double? iconSize;
  final bool active;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final color = active ? info.color : AppColors.iconMuted;
    final svg = SvgPicture.asset(
      info.logoAsset,
      width: iconSize ?? size * 0.54,
      height: iconSize ?? size * 0.54,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

    if (!showBackground) return svg;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.10 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      alignment: Alignment.center,
      child: svg,
    );
  }
}
