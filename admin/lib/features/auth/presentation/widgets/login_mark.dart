import 'package:flutter/material.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/branding/admin_branding.dart';
import '../../../../shared/widgets/admin_brand_mark.dart';
import '../../../../shared/widgets/admin_cached_image.dart';

/// Giriş ekranı marka başlığı.
///
/// Genel ayarlardaki **geniş logo** (logoUrl) varsa onu gösterir — "pateez"
/// yazan tam logo. Geniş logo yoksa kare marka + site adına düşer (asla boş
/// kalmaz). Hiçbir yerde sabit "Pateeznews" yazısı yok; her şey ayarlardan.
class LoginMark extends StatelessWidget {
  const LoginMark({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdminBrandingData>(
      valueListenable: adminBranding,
      builder: (context, branding, _) {
        final wideLogo = branding.logoUrl.trim();
        if (wideLogo.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 48,
                width: 210,
                child: AdminCachedImage(
                  url: wideLogo,
                  fit: BoxFit.contain,
                  memCacheWidth: 480,
                  placeholderColor: Colors.transparent,
                  errorWidget: AdminBrandMark(branding: branding, size: 42),
                ),
              ),
              const SizedBox(height: 10),
              _subtitle(context),
            ],
          );
        }
        // Geniş logo yoksa: kare marka + site adı (ayarlardan) + alt başlık.
        return Row(
          children: [
            AdminBrandMark(branding: branding, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branding.hasSiteName ? branding.siteName : 'Pateez',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _subtitle(context),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _subtitle(BuildContext context) {
    return Text(
      context.t('Editor sign-in'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.support,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    );
  }
}
