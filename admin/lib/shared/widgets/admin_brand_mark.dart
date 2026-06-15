import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../branding/admin_branding.dart';
import 'admin_cached_image.dart';
import 'symbol_icon.dart';

/// Giriş ekranı ve kenar çubuğu başlığındaki kare marka kutusu.
///
/// Genel ayarlardaki logo/favicon varsa (önbellekli, hızlı) onu gösterir;
/// yoksa eski varsayılan gazete ikonuna düşer. [branding] dışarıdan verilir
/// (tek ValueListenableBuilder ile hem kutu hem yazı birlikte tazelensin diye).
class AdminBrandMark extends StatelessWidget {
  const AdminBrandMark({
    super.key,
    required this.branding,
    required this.size,
  });

  final AdminBrandingData branding;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = SymbolIcon(
      Symbols.newspaper,
      color: AppColors.actionRed,
      size: size * 0.48,
    );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      child: branding.hasMark
          ? Padding(
              padding: EdgeInsets.all(size * 0.16),
              child: AdminCachedImage(
                url: branding.markUrl,
                fit: BoxFit.contain,
                memCacheWidth: (size * 2).round(),
                placeholderColor: AppColors.surface,
                errorWidget: Center(child: fallback),
              ),
            )
          : fallback,
    );
  }
}
