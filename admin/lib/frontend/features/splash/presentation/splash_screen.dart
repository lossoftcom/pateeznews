import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'widgets/pateez_logo_intro.dart';

/// Uygulama ilk açılışında gösterilen kısa açılış (splash) ekranı.
///
/// Arka planda font ayarları, kabuk verisi (logo/menü) ve oturum durumu
/// yüklenirken bu ekran görünür ve [PateezLogoIntro] ile markanın resmi açılış
/// animasyonunu oynatır. Yükleme bitince [PateeznewsApp] bu ekrandan asıl
/// kabuğa çapraz geçiş (cross-fade) yapar.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.logoUrl = '', this.siteName = ''});

  final String logoUrl;
  final String siteName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: PateezLogoIntro(
        logoUrl: logoUrl,
        semanticLabel: siteName.isEmpty ? 'Pateeznews' : siteName,
      ),
    );
  }
}
