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
    required this.type,
    required this.value,
  });

  /// Yan menü öğesinin etiketi ve tipinden kategori içeriğini üretir.
  factory CategoryContent.fromNavigation({
    required String label,
    required String type,
    String value = '',
  }) {
    final clean = label.trim().isEmpty ? 'Kategori' : label.trim();
    return CategoryContent(
      title: clean,
      kindLabel: _kindLabel(type),
      icon: _iconFor(type),
      description: _descriptionFor(clean, type, value),
      type: type.trim().toLowerCase(),
      value: value.trim().toLowerCase(),
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

  final String type;
  final String value;

  bool get isTrend => type == 'trends' || value.startsWith('weekly_');

  String get trendMetricLabel => _trendMetricLabel(value);
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

String _descriptionFor(String name, String type, String value) {
  final normalizedValue = value.trim().toLowerCase();
  return switch (type.trim().toLowerCase()) {
    'district' =>
      '$name bölgesinden son dakika haberleri, yerel gündem ve gelişmeler tek akışta.',
    'trends' => switch (normalizedValue) {
      'weekly_reads' =>
        'Son 7 günde en çok okunan haberler ve yükselen başlıklar canlı sıralamayla burada.',
      'weekly_likes' =>
        'Son 7 günde en çok beğenilen haberler ve öne çıkan tepkiler burada.',
      'weekly_comments' =>
        'Son 7 günde en çok yorum alan haberler ve konuşulan gündemler burada.',
      'weekly_shares' =>
        'Son 7 günde en çok paylaşılan haberler ve yayılan başlıklar burada.',
      _ =>
        'Bu hafta en çok konuşulan başlıklar ve yükselen gündem $name akışında.',
    },
    _ =>
      '$name başlığındaki en güncel haberler, analizler ve öne çıkan gelişmeler.',
  };
}

String _trendMetricLabel(String value) {
  return switch (value.trim().toLowerCase()) {
    'weekly_reads' => 'Okunma odaklı',
    'weekly_likes' => 'Beğeni odaklı',
    'weekly_comments' => 'Yorum odaklı',
    'weekly_shares' => 'Paylaşım odaklı',
    _ => 'Karma skor',
  };
}
