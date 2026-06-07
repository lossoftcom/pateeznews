import 'package:flutter/widgets.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

/// Duyuru kategorileri: resmî (valilik/belediye), elektrik kesintisi, yol durumu.
enum AnnouncementCategory { official, power, road }

extension AnnouncementCategoryInfo on AnnouncementCategory {
  static AnnouncementCategory fromApi(Object? value) {
    final category = value?.toString().trim().toLowerCase();
    return switch (category) {
      'power' => AnnouncementCategory.power,
      'road' => AnnouncementCategory.road,
      _ => AnnouncementCategory.official,
    };
  }

  /// Filtre çipinde görünen kısa etiket.
  String get label => switch (this) {
    AnnouncementCategory.official => 'Resmî',
    AnnouncementCategory.power => 'Elektrik',
    AnnouncementCategory.road => 'Yol',
  };

  /// Afiş/görsel üzerinde görünen uzun etiket.
  String get longLabel => switch (this) {
    AnnouncementCategory.official => 'Resmî Duyuru',
    AnnouncementCategory.power => 'Elektrik Kesintisi',
    AnnouncementCategory.road => 'Yol Durumu',
  };

  /// Kategoriyi temsil eden accent rengi (sol şerit, rozet, afiş gradyanı).
  Color get color => switch (this) {
    AnnouncementCategory.official => const Color(0xFF2F6F9F),
    AnnouncementCategory.power => const Color(0xFFE59A22),
    AnnouncementCategory.road => const Color(0xFF2F8F67),
  };

  IconData get icon => switch (this) {
    AnnouncementCategory.official => Symbols.building_line,
    AnnouncementCategory.power => Symbols.bolt_rounded,
    AnnouncementCategory.road => Symbols.navigation_fill,
  };
}

@immutable
class AnnouncementLinkedPost {
  const AnnouncementLinkedPost({
    required this.id,
    required this.title,
    required this.slug,
    required this.summary,
    required this.category,
    required this.imageUrl,
    required this.publishedAt,
  });

  const AnnouncementLinkedPost.empty()
    : id = '',
      title = '',
      slug = '',
      summary = '',
      category = '',
      imageUrl = '',
      publishedAt = '';

  factory AnnouncementLinkedPost.fromJson(Object? value) {
    if (value is! Map) return const AnnouncementLinkedPost.empty();
    return AnnouncementLinkedPost(
      id: _string(value['id']),
      title: _string(value['title']),
      slug: _string(value['slug']),
      summary: _string(value['summary']),
      category: _string(value['category']),
      imageUrl: _string(value['imageUrl'] ?? value['image_url']),
      publishedAt: _string(value['publishedAt'] ?? value['published_at']),
    );
  }

  final String id;
  final String title;
  final String slug;
  final String summary;
  final String category;
  final String imageUrl;
  final String publishedAt;

  bool get hasContent =>
      id.trim().isNotEmpty &&
      (title.trim().isNotEmpty || slug.trim().isNotEmpty);
}

/// Tek bir resmî duyuru kaydı.
///
/// [imageUrl] dolu ise kart ve büyütülmüş görünümde gerçek görsel (ağdan,
/// disk cache'li) gösterilir; boşsa kategori renginde markalı "afiş" placeholder
/// çizilir. Böylece gerçek duyuru API'si bağlandığında görseller otomatik gelir.
@immutable
class AnnouncementItem {
  const AnnouncementItem({
    required this.category,
    required this.source,
    required this.title,
    required this.summary,
    this.body = '',
    required this.place,
    required this.timeLabel,
    this.district = 'merkez',
    this.statusLabel = '',
    this.scheduleLabel = '',
    this.imageUrl = '',
    this.sourceUrl = '',
    this.canonicalUrl = '',
    this.publishedAt = '',
    this.startsAt = '',
    this.endsAt = '',
    this.linkedPost = const AnnouncementLinkedPost.empty(),
  });

  factory AnnouncementItem.fromJson(Map<dynamic, dynamic> json) {
    final nestedLinkedPost = AnnouncementLinkedPost.fromJson(
      json['linkedPost'],
    );
    final linkedPost = nestedLinkedPost.hasContent
        ? nestedLinkedPost
        : AnnouncementLinkedPost(
            id: _string(json['linkedPostId'] ?? json['linked_post_id']),
            title: _string(
              json['linkedPostTitle'] ?? json['linked_post_title'],
            ),
            slug: _string(json['linkedPostSlug'] ?? json['linked_post_slug']),
            summary: '',
            category: '',
            imageUrl: _string(
              json['linkedPostThumbnailUrl'] ??
                  json['linked_post_thumbnail_url'],
            ),
            publishedAt: '',
          );
    return AnnouncementItem(
      category: AnnouncementCategoryInfo.fromApi(json['category']),
      source: _string(json['source']),
      title: _string(json['title']),
      summary: _string(json['summary']),
      body: _string(json['body']),
      place: _string(json['place'], fallback: 'Niğde geneli'),
      timeLabel: _string(json['timeLabel'], fallback: 'Bugün'),
      district: _district(json['district']),
      statusLabel: _string(json['statusLabel']),
      scheduleLabel: _string(json['scheduleLabel']),
      imageUrl: _string(json['imageUrl']),
      sourceUrl: _string(json['sourceUrl']),
      canonicalUrl: _string(json['canonicalUrl'] ?? json['canonical_url']),
      publishedAt: _string(json['publishedAt'] ?? json['published_at']),
      startsAt: _string(json['startsAt'] ?? json['starts_at']),
      endsAt: _string(json['endsAt'] ?? json['ends_at']),
      linkedPost: linkedPost.hasContent
          ? linkedPost
          : const AnnouncementLinkedPost.empty(),
    );
  }

  final AnnouncementCategory category;

  /// Duyuruyu yapan kurum. Örn. "Niğde Valiliği", "MEDAŞ", "Karayolları 6. Bölge".
  final String source;
  final String title;
  final String summary;
  final String body;

  /// Etkilenen yer / güzergâh / mahalle bilgisi.
  final String place;
  final String district;

  /// İnsan-okur zaman etiketi. Örn. "Bugün 10:30", "6 Haziran", "5–7 Haziran".
  final String timeLabel;

  /// Durum etiketi (opsiyonel renkli pill): "Planlı", "Arıza", "Kapalı",
  /// "Çalışma", "Açık", "Uyarı".
  final String statusLabel;

  /// Saat aralığı (opsiyonel): elektrik/su kesintisi için "09:00 – 14:00".
  final String scheduleLabel;

  /// Gerçek duyuru görseli (opsiyonel). Boşsa markalı afiş placeholder çizilir.
  final String imageUrl;

  /// Duyurunun kurum sayfasındaki asıl bağlantısı.
  final String sourceUrl;
  final String canonicalUrl;
  final String publishedAt;
  final String startsAt;
  final String endsAt;

  /// Duyurudan uygulama içindeki haber detayına geçilecekse bağlı haber.
  final AnnouncementLinkedPost linkedPost;

  Color get color => category.color;
  IconData get icon => category.icon;
  bool get hasImage => imageUrl.trim().isNotEmpty;
  bool get hasLinkedPost => linkedPost.hasContent;
}

String _string(Object? value, {String fallback = ''}) {
  final result = (value ?? '').toString().trim();
  return result.isEmpty ? fallback : result;
}

String _district(Object? value) {
  final result = (value ?? '').toString().trim().toLowerCase();
  return switch (result) {
    'merkez' ||
    'altunhisar' ||
    'bor' ||
    'camardi' ||
    'ciftlik' ||
    'ulukisla' => result,
    _ => 'merkez',
  };
}
