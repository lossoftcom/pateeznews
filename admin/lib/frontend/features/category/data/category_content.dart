import 'package:flutter/widgets.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

/// Kategori sayfasının, yan menüden tıklanan gezinme öğesinden türetilen sade
/// içerik katmanı.
///
/// Gerçek API entegrasyonunda bu türetmeler repository'den gelen kategori
/// nesnesiyle değiştirilir; sunum katmanı yalnızca bu modele bağlı kalır.
@immutable
class CategoryContent {
  const CategoryContent({
    required this.title,
    required this.kindLabel,
    required this.icon,
    required this.description,
  });

  /// Yan menü öğesinin etiketi ve tipinden kategori içeriğini üretir.
  factory CategoryContent.fromNavigation({
    required String label,
    required String type,
  }) {
    final clean = label.trim().isEmpty ? 'Kategori' : label.trim();
    return CategoryContent(
      title: clean,
      kindLabel: _kindLabel(type),
      icon: _iconFor(type),
      description: _descriptionFor(clean, type),
    );
  }

  /// Sayfa başlığı (ör. "Ekonomi").
  final String title;

  /// Türü tanımlayan UPPERCASE eyebrow etiketi (ör. "KATEGORİ", "İLÇE").
  final String kindLabel;

  /// Eyebrow yanında gösterilen tür ikonu.
  final IconData icon;

  /// Masthead altında tek satırlık tanıtım metni.
  final String description;
}

String _kindLabel(String type) {
  return switch (type.trim().toLowerCase()) {
    'district' => 'İLÇE',
    'trends' => 'TREND',
    'category' || 'dropdown' || 'link' => 'KATEGORİ',
    _ => 'BÖLÜM',
  };
}

IconData _iconFor(String type) {
  return switch (type.trim().toLowerCase()) {
    'district' => Symbols.location_on_rounded,
    'trends' => Symbols.trending_up_rounded,
    'category' || 'dropdown' || 'link' => Symbols.grid_view_outlined,
    _ => Symbols.newspaper,
  };
}

String _descriptionFor(String name, String type) {
  return switch (type.trim().toLowerCase()) {
    'district' =>
      '$name bölgesinden son dakika haberleri, yerel gündem ve gelişmeler tek akışta.',
    'trends' =>
      'Bu hafta en çok konuşulan başlıklar ve yükselen gündem $name akışında.',
    _ =>
      '$name başlığındaki en güncel haberler, analizler ve öne çıkan gelişmeler.',
  };
}
