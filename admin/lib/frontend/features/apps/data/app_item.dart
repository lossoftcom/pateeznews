import 'package:flutter/widgets.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';

/// Her uygulama için ayrı, uyumlu ama belirgin biçimde farklı vurgu renkleri.
/// Marka üçlüsünü (kırmızı/amber/deepOcean) korur, eksik tonları tamamlar.
const Color _eczaneRed = Color(0xFFE30613); // Nöbetçi Eczane (logo)
const Color _etkinlikViolet = Color(0xFF6C5CE7); // Etkinlik
const Color _havaSky = Color(0xFF2D9CDB); // Hava Durumu
const Color _dovizGreen = Color(0xFF1FA971); // Döviz & Altın

/// Nöbetçi Eczane resmi logosu — gerçek görselin optimize webp kopyası.
const String _eczaneLogoAsset = 'assets/images/nobetci_eczane.webp';

/// "Uygulamalar" sayfasındaki mini servis öğesi.
///
/// [glyph], öğenin ikonunu istenen boyut ve renkte üreten bir kurucudur; böylece
/// Nöbetçi Eczane gerçek logosunu (optimize webp) taşırken diğerleri doğrulanmış
/// RemixIcon gliflerini kullanır — hepsi aynı görsel dilde.
@immutable
class AppItem {
  const AppItem({
    required this.id,
    required this.label,
    required this.accent,
    required this.tagline,
    required this.description,
    required this.glyph,
  });

  final String id;
  final String label;
  final Color accent;
  final String tagline;
  final String description;
  final Widget Function(double size, Color color) glyph;
}

/// Pateez mini servisleri.
class AppItems {
  const AppItems._();

  static final nobetciEczane = AppItem(
    id: 'nobetci-eczane',
    label: 'Nöbetçi Eczane',
    accent: _eczaneRed,
    tagline: 'Bölgendeki açık eczaneler',
    description:
        'Şehrindeki nöbetçi eczaneler, adres ve yol tarifleriyle birlikte burada '
        'listelenecek. Bu bölüm yakında hizmete giriyor.',
    glyph: (size, color) => Image.asset(
      _eczaneLogoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );

  static final havaDurumu = AppItem(
    id: 'hava-durumu',
    label: 'Hava Durumu',
    accent: _havaSky,
    tagline: 'Saatlik ve 7 günlük tahmin',
    description:
        'Bulunduğun ilin saatlik ve haftalık hava tahmini, sıcaklık ve yağış '
        'bilgileriyle birlikte yakında bu ekranda olacak.',
    glyph: (size, color) => Icon(Symbols.sun_rounded, size: size, color: color),
  );

  static final duyurular = AppItem(
    id: 'duyurular',
    label: 'Duyurular',
    accent: AppColors.warmHorizon,
    tagline: 'Yerel bildirim ve ilanlar',
    description:
        'Şehirdeki önemli duyurular, etkinlikler ve güncel bilgilendirmeler '
        'yakında bu ekranda yayınlanacak.',
    glyph: (size, color) =>
        Icon(Symbols.notifications, size: size, color: color),
  );

  static final etkinlik = AppItem(
    id: 'etkinlik',
    label: 'Etkinlik',
    accent: _etkinlikViolet,
    tagline: 'Şehir programı ve etkinlikler',
    description:
        'Konser, söyleşi, belediye programları ve aile etkinlikleri yakında '
        'bu bölümde düzenli olarak listelenecek.',
    glyph: (size, color) =>
        Icon(Symbols.calendar_event_line, size: size, color: color),
  );

  static final dovizAltin = AppItem(
    id: 'doviz-altin',
    label: 'Döviz & Altın',
    accent: _dovizGreen,
    tagline: 'Anlık kur ve altın',
    description:
        'Döviz kurları ve altın fiyatları, günlük değişim oranlarıyla birlikte '
        'burada güncellenecek.',
    glyph: (size, color) => Icon(Symbols.coins_fill, size: size, color: color),
  );

  static final olumIlanlari = AppItem(
    id: 'olum-ilanlari',
    label: 'Ölüm İlanları',
    accent: AppColors.deepOcean,
    tagline: 'Vefat ve taziye ilanları',
    description:
        'Bölgenin vefat ve taziye ilanları saygıyla, güncel biçimde burada '
        'yayınlanacak. Bu bölüm hazırlanıyor.',
    glyph: (size, color) => Icon(Symbols.leaf_line, size: size, color: color),
  );

  /// "Uygulamalar" sheet'inde gösterilecek sıralı liste.
  static final all = <AppItem>[
    nobetciEczane,
    etkinlik,
    duyurular,
    havaDurumu,
    olumIlanlari,
    dovizAltin,
  ];
}
