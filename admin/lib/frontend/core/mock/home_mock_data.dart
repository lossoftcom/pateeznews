import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

/// Ana sayfa için sade mock veri katmanı.
///
/// Gerçek API entegrasyonu yapıldığında bu dosya `repository` ile değiştirilir;
/// widget'lar veri modellerine bağlı kalır.

@immutable
class StoryHighlight {
  const StoryHighlight({
    required this.id,
    required this.label,
    required this.icon,
    required this.isLive,
    required this.isUnviewed,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool isLive;
  final bool isUnviewed;
}

@immutable
class FeaturedNews {
  const FeaturedNews({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.publishedAt,
    required this.source,
    this.slug = '',
    this.imageAspectRatio,
    this.isBreaking = false,
    this.isLive = false,
  });

  final String id;
  final String category;
  final String title;
  final String summary;
  final String imageUrl;
  final DateTime publishedAt;
  final String source;
  final String slug;
  final double? imageAspectRatio;
  final bool isBreaking;
  final bool isLive;
}

@immutable
class NewsAuthor {
  const NewsAuthor({
    this.id = '',
    required this.name,
    required this.avatarUrl,
    this.handle,
    this.isVerified = false,
    this.isOfficial = false,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final String? handle;
  final bool isVerified;
  final bool isOfficial;
}

@immutable
class NewsComment {
  const NewsComment({
    this.id = '',
    this.parentId = '',
    required this.author,
    required this.body,
    required this.publishedAt,
    this.likes = 0,
    this.userLiked = false,
    this.canDelete = false,
    this.replies = const [],
  });

  final String id;
  final String parentId;
  final NewsAuthor author;
  final String body;
  final DateTime publishedAt;
  final int likes;
  final bool userLiked;
  final bool canDelete;
  final List<NewsComment> replies;

  NewsComment copyWith({
    String? id,
    String? parentId,
    NewsAuthor? author,
    String? body,
    DateTime? publishedAt,
    int? likes,
    bool? userLiked,
    bool? canDelete,
    List<NewsComment>? replies,
  }) {
    return NewsComment(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      author: author ?? this.author,
      body: body ?? this.body,
      publishedAt: publishedAt ?? this.publishedAt,
      likes: likes ?? this.likes,
      userLiked: userLiked ?? this.userLiked,
      canDelete: canDelete ?? this.canDelete,
      replies: replies ?? this.replies,
    );
  }
}

@immutable
class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.author,
    required this.region,
    required this.category,
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.publishedAt,
    required this.readMinutes,
    required this.likes,
    required this.dislikes,
    required this.comments,
    required this.shares,
    this.views = 0,
    this.saves = 0,
    this.userLiked = false,
    this.userDisliked = false,
    this.userSaved = false,
    this.slug = '',
    this.imageAspectRatio,
    this.isManset = false,
    this.isPinned = false,
    this.sliderImages = const [],
    this.videoUrl = '',
    this.videoUrls = const [],
    this.videoThumbUrls = const [],
    this.audioUrl = '',
    this.socialEmbed = '',
    this.socialSourceUrl = '',
    this.socialPlatform = '',
    this.flipData,
    this.beforeAfterData,
    this.reviewData,
    this.pollData,
    this.vsData,
    this.quoteData,
    this.previewComments = const [],
  });

  final String id;
  final NewsAuthor author;
  final String region;
  final String category;
  final String title;
  final String summary;
  final String imageUrl;
  final DateTime publishedAt;
  final int readMinutes;
  final int likes;
  final int dislikes;
  final int comments;
  final int shares;
  final int views;
  final int saves;
  final bool userLiked;
  final bool userDisliked;
  final bool userSaved;
  final String slug;
  final double? imageAspectRatio;
  final bool isManset;
  final bool isPinned;

  /// Ana sayfada "slider" bloğu seçiliyse gösterilecek görseller (sırayla).
  /// Boşsa tek görsel / kapak gösterilir.
  final List<String> sliderImages;

  /// Kartta oynatılacak ana video (yerel/uzak/YouTube/Shorts). Boşsa ilk
  /// videoUrls elemanı kullanılır; ikisi de boşsa slider / görsel / kapak gösterilir.
  final String videoUrl;

  /// Haberdeki tüm video blokları. Tam ekran video akışı bu listeyi kullanır.
  final List<String> videoUrls;

  /// [videoUrls] ile aynı sıradaki video-özel poster görselleri.
  /// Haber kapak görseli değildir; tam ekran video akışı bunu kullanır.
  final List<String> videoThumbUrls;

  String get primaryVideoUrl {
    final primary = videoUrl.trim();
    if (primary.isNotEmpty) return primary;
    for (final url in videoUrls) {
      final clean = url.trim();
      if (clean.isNotEmpty) return clean;
    }
    return '';
  }

  List<String> get videoFeedUrls {
    final urls = <String>[];
    for (final url in videoUrls) {
      final clean = url.trim();
      if (clean.isNotEmpty) urls.add(clean);
    }
    final primary = videoUrl.trim();
    if (urls.isEmpty && primary.isNotEmpty) {
      urls.add(primary);
    } else if (primary.isNotEmpty && !urls.contains(primary)) {
      urls.insert(0, primary);
    }
    return urls;
  }

  String videoFeedPosterFor(String url, int index) {
    if (index >= 0 && index < videoThumbUrls.length) {
      final poster = videoThumbUrls[index].trim();
      if (poster.isNotEmpty) return poster;
    }
    return _youtubeThumbnailFor(url);
  }

  /// Ana sayfada "ses" bloğu seçiliyse çalınacak ses (yerel/uzak dosya veya
  /// YouTube Music). Boşsa video / slider / görsel / kapak gösterilir.
  final String audioUrl;

  /// Ana sayfada "sosyal medya" bloğu seçiliyse gösterilecek URL veya embed
  /// HTML'i. Boşsa mevcut medya sıralaması değişmeden çalışır.
  final String socialEmbed;
  final String socialSourceUrl;
  final String socialPlatform;

  /// Ana sayfada "flip kart" bloğu seçiliyse gösterilecek ön/arka yüz verisi.
  /// Boşsa mevcut medya sıralaması (video/slider/görsel) değişmeden çalışır.
  final NewsFlipData? flipData;

  /// Ana sayfada "önce & sonra" bloğu seçiliyse gösterilecek karşılaştırma
  /// verisi. Boşsa mevcut medya sıralaması değişmeden çalışır.
  final NewsBeforeAfterData? beforeAfterData;

  /// Ana sayfada "inceleme" bloğu seçiliyse gösterilecek puanlama verisi.
  /// Boşsa mevcut medya sıralaması değişmeden çalışır.
  final NewsReviewData? reviewData;

  /// Ana sayfada "anket" bloğu seçiliyse gösterilecek soru, cevap ve oy
  /// verisi. Boşsa mevcut medya sıralaması değişmeden çalışır.
  final NewsPollData? pollData;

  /// Ana sayfada "VS / Düello" bloğu seçiliyse gösterilecek karşılaştırma
  /// verisi. Boşsa mevcut medya sıralaması değişmeden çalışır.
  final NewsVsData? vsData;

  /// Ana sayfada "alıntı" bloğu seçiliyse gösterilecek metin ve sahip bilgisi.
  /// Boşsa mevcut medya sıralaması değişmeden çalışır.
  final NewsQuoteData? quoteData;

  /// Haber kartında gösterilecek gerçek yorum önizlemesi.
  /// Boşsa yalnızca yorum yazma composer'ı gösterilir.
  final List<NewsComment> previewComments;
}

String _youtubeThumbnailFor(String url) {
  final id = _youtubeIdFrom(url);
  return id == null ? '' : 'https://img.youtube.com/vi/$id/hqdefault.jpg';
}

String? _youtubeIdFrom(String url) {
  final raw = url.trim();
  if (RegExp(r'^[_\-a-zA-Z0-9]{11}$').hasMatch(raw)) return raw;

  var uri = Uri.tryParse(raw);
  if (uri != null && !uri.hasScheme && raw.contains('youtube')) {
    uri = Uri.tryParse('https://$raw');
  }
  final host = uri?.host.toLowerCase() ?? '';
  if (!host.contains('youtube.com') &&
      !host.contains('youtu.be') &&
      !host.contains('youtube-nocookie.com')) {
    return null;
  }

  if (host.contains('youtu.be')) {
    return _cleanYoutubeId(uri?.pathSegments.firstOrNull);
  }
  final fromQuery = _cleanYoutubeId(uri?.queryParameters['v']);
  if (fromQuery != null) return fromQuery;
  final segments = uri?.pathSegments ?? const <String>[];
  for (var index = 0; index < segments.length - 1; index += 1) {
    final segment = segments[index].toLowerCase();
    if (segment == 'shorts' || segment == 'embed' || segment == 'live') {
      return _cleanYoutubeId(segments[index + 1]);
    }
  }
  return null;
}

String? _cleanYoutubeId(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  return RegExp(r'[_\-a-zA-Z0-9]{11}').firstMatch(raw)?.group(0);
}

/// Flip (çevrilebilir) kart verisi: ön ve arka yüz için görsel, başlık ve
/// (opsiyonel) açıklama. Karta dokununca ön/arka yüz arası 3B döner.
class NewsFlipData {
  const NewsFlipData({
    required this.frontImage,
    required this.frontTitle,
    required this.backImage,
    required this.backTitle,
    this.frontDescription = '',
    this.backDescription = '',
    this.frontLink = '',
    this.backLink = '',
  });

  final String frontImage;
  final String frontTitle;
  final String backImage;
  final String backTitle;
  final String frontDescription;
  final String backDescription;
  final String frontLink;
  final String backLink;

  bool get isValid =>
      frontImage.trim().isNotEmpty && backImage.trim().isNotEmpty;
}

/// Önce & Sonra verisi: iki görsel tek karede, parmakla sürüklenen dikey
/// sürgüyle karşılaştırılır. Etiketler opsiyoneldir.
class NewsBeforeAfterData {
  const NewsBeforeAfterData({
    required this.beforeImage,
    required this.afterImage,
    this.beforeLabel = '',
    this.afterLabel = '',
  });

  final String beforeImage;
  final String afterImage;
  final String beforeLabel;
  final String afterLabel;

  bool get isValid =>
      beforeImage.trim().isNotEmpty && afterImage.trim().isNotEmpty;
}

/// İnceleme verisi: ürün/konu görseli, genel skor, artılar-eksiler, detay
/// puanları ve kısa karar metni.
class NewsReviewData {
  const NewsReviewData({
    required this.productName,
    required this.productImage,
    required this.score,
    this.pros = const [],
    this.cons = const [],
    this.breakdown = const [],
    this.verdict = '',
  });

  final String productName;
  final String productImage;
  final int score;
  final List<String> pros;
  final List<String> cons;
  final List<NewsReviewCriterion> breakdown;
  final String verdict;

  bool get isValid =>
      productName.trim().isNotEmpty ||
      productImage.trim().isNotEmpty ||
      pros.isNotEmpty ||
      cons.isNotEmpty ||
      breakdown.isNotEmpty ||
      verdict.trim().isNotEmpty;
}

class NewsReviewCriterion {
  const NewsReviewCriterion({required this.label, required this.score});

  final String label;
  final int score;
}

class NewsPollData {
  const NewsPollData({
    required this.title,
    required this.options,
    this.description = '',
    this.isImagePoll = false,
    this.columns = 1,
    this.totalVotes = 0,
  });

  final String title;
  final String description;
  final List<NewsPollOption> options;
  final bool isImagePoll;
  final int columns;
  final int totalVotes;

  int get resolvedTotalVotes {
    final optionTotal = options.fold<int>(0, (total, option) {
      final votes = option.votes;
      return total + (votes < 0 ? 0 : votes);
    });
    return totalVotes > optionTotal ? totalVotes : optionTotal;
  }

  bool get isValid => title.trim().isNotEmpty && options.length >= 2;
}

class NewsPollOption {
  const NewsPollOption({
    required this.id,
    required this.text,
    this.imageUrl = '',
    this.votes = 0,
  });

  final String id;
  final String text;
  final String imageUrl;
  final int votes;
}

class NewsVsData {
  const NewsVsData({
    required this.title,
    required this.options,
    this.description = '',
    this.totalVotes = 0,
  });

  final String title;
  final String description;
  final List<NewsVsOption> options;
  final int totalVotes;

  int get resolvedTotalVotes {
    final optionTotal = options.fold<int>(0, (total, option) {
      final votes = option.votes;
      return total + (votes < 0 ? 0 : votes);
    });
    return totalVotes > optionTotal ? totalVotes : optionTotal;
  }

  bool get isValid => title.trim().isNotEmpty && options.length >= 2;
}

class NewsVsOption {
  const NewsVsOption({
    required this.id,
    required this.text,
    this.imageUrl = '',
    this.votes = 0,
  });

  final String id;
  final String text;
  final String imageUrl;
  final int votes;
}

class NewsQuoteData {
  const NewsQuoteData({
    required this.text,
    this.author = '',
    this.sourceUrl = '',
  });

  final String text;
  final String author;
  final String sourceUrl;

  bool get isValid => text.trim().isNotEmpty;
}

class _Authors {
  const _Authors._();

  static const nasip = NewsAuthor(
    name: 'Nasip Gündoğu',
    avatarUrl: 'https://picsum.photos/seed/pateez-author-nasip/200/200',
    handle: '@nasipgundogu',
    isVerified: true,
  );

  static const aylin = NewsAuthor(
    name: 'Aylin Yılmaz',
    avatarUrl: 'https://picsum.photos/seed/pateez-author-aylin/200/200',
    handle: '@aylinyilmaz',
    isVerified: true,
  );

  static const mehmet = NewsAuthor(
    name: 'Mehmet Demir',
    avatarUrl: 'https://picsum.photos/seed/pateez-author-mehmet/200/200',
    handle: '@mehmetdemir',
  );

  static const ece = NewsAuthor(
    name: 'Ece Türkmen',
    avatarUrl: 'https://picsum.photos/seed/pateez-author-ece/200/200',
    handle: '@eceturkmen',
    isVerified: true,
  );

  static const burak = NewsAuthor(
    name: 'Burak Şahin',
    avatarUrl: 'https://picsum.photos/seed/pateez-author-burak/200/200',
    handle: '@buraksahin',
  );

  static const selin = NewsAuthor(
    name: 'Selin Kaya',
    avatarUrl: 'https://picsum.photos/seed/pateez-author-selin/200/200',
    handle: '@selinkaya',
    isVerified: true,
  );

  static const pateezEkonomi = NewsAuthor(
    name: 'Pateez Ekonomi',
    avatarUrl: 'https://picsum.photos/seed/pateez-desk-eco/200/200',
    handle: '@pateezekonomi',
    isOfficial: true,
  );

  static const pateezBilim = NewsAuthor(
    name: 'Pateez Bilim',
    avatarUrl: 'https://picsum.photos/seed/pateez-desk-sci/200/200',
    handle: '@pateezbilim',
    isOfficial: true,
  );

  static const pateezSaglik = NewsAuthor(
    name: 'Pateez Sağlık',
    avatarUrl: 'https://picsum.photos/seed/pateez-desk-health/200/200',
    handle: '@pateezsaglik',
    isOfficial: true,
  );

  static const pateezKultur = NewsAuthor(
    name: 'Pateez Kültür',
    avatarUrl: 'https://picsum.photos/seed/pateez-desk-culture/200/200',
    handle: '@pateezkultur',
    isOfficial: true,
  );

  // Okuyucu yorumcuları (preview yorumlar için)
  static const ahmet = NewsAuthor(
    name: 'Ahmet K.',
    avatarUrl: 'https://picsum.photos/seed/pateez-cm-ahmet/200/200',
    handle: '@ahmetk',
  );

  static const zeynep = NewsAuthor(
    name: 'Zeynep T.',
    avatarUrl: 'https://picsum.photos/seed/pateez-cm-zeynep/200/200',
    handle: '@zeynept',
    isVerified: true,
  );

  static const emre = NewsAuthor(
    name: 'Emre A.',
    avatarUrl: 'https://picsum.photos/seed/pateez-cm-emre/200/200',
    handle: '@emrea',
  );

  // Composer için temsili oturum açmış kullanıcı
  static const currentUser = NewsAuthor(
    name: 'Sen',
    avatarUrl: 'https://picsum.photos/seed/pateez-me/200/200',
  );
}

class HomeMockData {
  const HomeMockData._();

  static final DateTime _now = DateTime(2026, 5, 26, 13, 20);

  /// Composer'da gösterilecek oturum kullanıcısı.
  static NewsAuthor get currentUser => _Authors.currentUser;

  /// Tüm haber kartlarında gösterilen örnek yorum önizlemesi.
  /// Üstte iki yorum + ikincisinin altında bir alt yorum.
  static final List<NewsComment> samplePreviewComments = [
    NewsComment(
      author: _Authors.ahmet,
      body: 'Konuyu farklı bir açıdan ele almışsınız, kalemine sağlık.',
      publishedAt: _now.subtract(const Duration(minutes: 28)),
      likes: 24,
    ),
    NewsComment(
      author: _Authors.zeynep,
      body: 'Veriler net, tarafsız bir özet olmuş. Pateez böyle devam.',
      publishedAt: _now.subtract(const Duration(minutes: 42)),
      likes: 11,
      replies: [
        NewsComment(
          author: _Authors.emre,
          body: 'Grafikler özellikle çok aydınlatıcı oldu.',
          publishedAt: _now.subtract(const Duration(minutes: 18)),
          likes: 3,
        ),
      ],
    ),
  ];

  static List<StoryHighlight> stories = [
    StoryHighlight(
      id: 'live',
      label: 'Canlı',
      icon: Symbols.podcasts_rounded,
      isLive: true,
      isUnviewed: true,
    ),
    StoryHighlight(
      id: 'agenda',
      label: 'Gündem',
      icon: Symbols.bolt_rounded,
      isLive: false,
      isUnviewed: true,
    ),
    StoryHighlight(
      id: 'sport',
      label: 'Spor',
      icon: Symbols.sports_soccer_rounded,
      isLive: false,
      isUnviewed: true,
    ),
    StoryHighlight(
      id: 'economy',
      label: 'Ekonomi',
      icon: Symbols.trending_up_rounded,
      isLive: false,
      isUnviewed: true,
    ),
    StoryHighlight(
      id: 'tech',
      label: 'Teknoloji',
      icon: Symbols.memory_rounded,
      isLive: false,
      isUnviewed: false,
    ),
    StoryHighlight(
      id: 'culture',
      label: 'Kültür',
      icon: Symbols.theater_comedy_rounded,
      isLive: false,
      isUnviewed: false,
    ),
    StoryHighlight(
      id: 'health',
      label: 'Sağlık',
      icon: Symbols.favorite_rounded,
      isLive: false,
      isUnviewed: false,
    ),
    StoryHighlight(
      id: 'world',
      label: 'Dünya',
      icon: Symbols.public_rounded,
      isLive: false,
      isUnviewed: false,
    ),
    StoryHighlight(
      id: 'science',
      label: 'Bilim',
      icon: Symbols.science_rounded,
      isLive: false,
      isUnviewed: false,
    ),
  ];

  static List<FeaturedNews> featured = [
    FeaturedNews(
      id: 'f1',
      category: 'Teknoloji',
      title: 'Yapay Zeka Türkiye\'de Yeni Bir Dönem Başlatıyor',
      summary:
          'Yerli geliştirilen yeni nesil dil modeli, Türkçe içerik üretiminde bağımsızlık vaat ediyor.',
      imageUrl: 'https://picsum.photos/seed/pateez-ai/1200/720',
      publishedAt: _now.subtract(const Duration(hours: 2)),
      source: 'Pateeznews',
      isBreaking: true,
    ),
    FeaturedNews(
      id: 'f2',
      category: 'Spor',
      title: 'Süper Lig\'de Şampiyonluk Yarışı Son Hafta Belirlenecek',
      summary:
          'Lider takım deplasmandan üç puanla dönerek farkı korumayı başardı.',
      imageUrl: 'https://picsum.photos/seed/pateez-sport/1200/720',
      publishedAt: _now.subtract(const Duration(hours: 4)),
      source: 'Pateeznews Spor',
      isLive: true,
    ),
    FeaturedNews(
      id: 'f3',
      category: 'Kültür',
      title: 'Niğde Belediyesi 3. Tiyatro Festivali Perdelerini Açıyor',
      summary:
          'On günlük programda yerli ve uluslararası toplulukların sahne aldığı festival sanatseverleri bekliyor.',
      imageUrl: 'https://picsum.photos/seed/pateez-culture/1200/720',
      publishedAt: _now.subtract(const Duration(days: 1)),
      source: 'Niğde Belediyesi',
    ),
  ];

  static List<NewsArticle> feed = [
    NewsArticle(
      id: 'n1',
      author: _Authors.pateezEkonomi,
      region: 'Türkiye',
      category: 'Ekonomi',
      title: 'Merkez Bankası faiz kararını açıkladı, piyasada hareketlilik var',
      summary:
          'Politika faizinde değişikliğe gidilmedi; yıl sonu enflasyon beklentisi güncellendi.',
      imageUrl: 'https://picsum.photos/seed/pateez-eco/1200/800',
      publishedAt: _now.subtract(const Duration(minutes: 12)),
      readMinutes: 3,
      likes: 1240,
      dislikes: 82,
      comments: 214,
      shares: 96,
    ),
    NewsArticle(
      id: 'n2',
      author: _Authors.nasip,
      region: 'Niğde',
      category: 'Kültür',
      title:
          'Niğde\'de yeni nesil sanat galerisi sanatseverleri ağırlamaya başladı',
      summary:
          'Galeri, genç sanatçılar için açık çağrı dönemini de bugün itibarıyla başlatıyor.',
      imageUrl: 'https://picsum.photos/seed/pateez-gallery/1200/800',
      publishedAt: _now.subtract(const Duration(minutes: 45)),
      readMinutes: 4,
      likes: 326,
      dislikes: 5,
      comments: 41,
      shares: 28,
    ),
    NewsArticle(
      id: 'n3',
      author: _Authors.aylin,
      region: 'Ankara',
      category: 'Eğitim',
      title: 'Üniversite sınav sonuçları açıklandı, tercih dönemi başlıyor',
      summary:
          'Bu yıl rekor sayıda aday tercih ekranını bekliyor; uzmanlar sabırlı olunmasını öneriyor.',
      imageUrl: 'https://picsum.photos/seed/pateez-edu/1200/800',
      publishedAt: _now.subtract(const Duration(hours: 1)),
      readMinutes: 5,
      likes: 4820,
      dislikes: 312,
      comments: 1230,
      shares: 412,
    ),
    NewsArticle(
      id: 'n4',
      author: _Authors.mehmet,
      region: 'Antalya',
      category: 'Yaşam',
      title:
          'Sahil turizminde sezon rekoru, doluluk oranları yüzde 90\'a koştu',
      summary:
          'Erken rezervasyon kampanyaları ve yurt içi talebi destinasyonları erkenden hareketlendirdi.',
      imageUrl: 'https://picsum.photos/seed/pateez-life/1200/800',
      publishedAt: _now.subtract(const Duration(hours: 2)),
      readMinutes: 3,
      likes: 612,
      dislikes: 24,
      comments: 88,
      shares: 53,
    ),
    NewsArticle(
      id: 'n5',
      author: _Authors.pateezBilim,
      region: 'İstanbul',
      category: 'Bilim',
      title: 'Türk bilim insanı Nobel ödülüne aday gösterildi',
      summary:
          'Genetik araştırmalar alanında yıllardır yürüttüğü çalışmalar uluslararası takdir gördü.',
      imageUrl: 'https://picsum.photos/seed/pateez-science/1200/800',
      publishedAt: _now.subtract(const Duration(hours: 3)),
      readMinutes: 6,
      likes: 9210,
      dislikes: 73,
      comments: 1840,
      shares: 1102,
    ),
    NewsArticle(
      id: 'n6',
      author: _Authors.ece,
      region: 'Niğde',
      category: 'Gündem',
      title: 'Yeni köprü törenle açıldı, bölge ulaşımına can suyu olacak',
      summary:
          'Bölge esnafı yıl sonuna kadar trafik yoğunluğunun yüzde 40 azalmasını bekliyor.',
      imageUrl: 'https://picsum.photos/seed/pateez-bridge/1200/800',
      publishedAt: _now.subtract(const Duration(hours: 5)),
      readMinutes: 2,
      likes: 412,
      dislikes: 18,
      comments: 64,
      shares: 22,
    ),
    NewsArticle(
      id: 'n7',
      author: _Authors.pateezSaglik,
      region: 'Türkiye',
      category: 'Sağlık',
      title: 'Sağlık Bakanlığı koruyucu sağlık programını güncelledi',
      summary:
          'Aile hekimliği muayenelerinde yıllık tarama paketi kapsamı genişletildi.',
      imageUrl: 'https://picsum.photos/seed/pateez-health/1200/800',
      publishedAt: _now.subtract(const Duration(hours: 8)),
      readMinutes: 4,
      likes: 1840,
      dislikes: 47,
      comments: 312,
      shares: 188,
    ),
    NewsArticle(
      id: 'n8',
      author: _Authors.burak,
      region: 'İstanbul',
      category: 'Ekonomi',
      title: 'Borsa İstanbul rekor seviyeden günü kapattı',
      summary:
          'Bankacılık endeksi öncülüğünde yükseliş, yabancı yatırımcı ilgisini de canlandırdı.',
      imageUrl: 'https://picsum.photos/seed/pateez-borsa/1200/800',
      publishedAt: _now.subtract(const Duration(hours: 10)),
      readMinutes: 3,
      likes: 2105,
      dislikes: 96,
      comments: 488,
      shares: 240,
    ),
    NewsArticle(
      id: 'n9',
      author: _Authors.pateezKultur,
      region: 'Niğde',
      category: 'Kültür',
      title:
          'Anadolu Tarih Müzesi modern restorasyonla yeniden ziyarete açıldı',
      summary:
          'Dijital deneyim alanları ve sanal rehber ile müze artık daha erişilebilir.',
      imageUrl: 'https://picsum.photos/seed/pateez-museum/1200/800',
      publishedAt: _now.subtract(const Duration(hours: 14)),
      readMinutes: 5,
      likes: 782,
      dislikes: 9,
      comments: 124,
      shares: 92,
    ),
    NewsArticle(
      id: 'n10',
      author: _Authors.selin,
      region: 'İstanbul',
      category: 'Teknoloji',
      title: 'İstanbul Yapay Zeka Konferansı global isimleri bir araya getirdi',
      summary:
          'Üç günlük programda etik, regülasyon ve üretken yapay zeka ana başlıkları konuşuldu.',
      imageUrl: 'https://picsum.photos/seed/pateez-aiconf/1200/800',
      publishedAt: _now.subtract(const Duration(days: 1)),
      readMinutes: 7,
      likes: 5630,
      dislikes: 142,
      comments: 920,
      shares: 612,
    ),
  ];
}

/// Zaman damgalarını "12 dk", "2 sa", "1 g" gibi kısa, okunaklı biçimde
/// sunan yardımcı.
class RelativeTime {
  const RelativeTime._();

  static String format(DateTime time, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(time);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inDays < 7) return '${diff.inDays} g';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '$weeks hf';
    return '${(diff.inDays / 30).floor()} ay';
  }
}

/// Etkileşim sayılarını Türkçeye uygun, kompakt biçimde formatlar.
///
/// Örnek:
///   942      → "942"
///   1.240    → "1,2B"
///   12.400   → "12B"
///   1.250.000 → "1,3M"
class CountFormat {
  const CountFormat._();

  static String compact(int value) {
    if (value < 1000) return value.toString();
    if (value < 10000) {
      final n = (value / 1000);
      return '${_trim(n.toStringAsFixed(1))}B';
    }
    if (value < 1000000) {
      return '${(value / 1000).round()}B';
    }
    if (value < 10000000) {
      return '${_trim((value / 1000000).toStringAsFixed(1))}M';
    }
    return '${(value / 1000000).round()}M';
  }

  static String _trim(String s) {
    // 1.0 → 1, 1.2 → 1,2 (TR ondalık ayracı)
    if (s.endsWith('.0')) return s.substring(0, s.length - 2);
    return s.replaceAll('.', ',');
  }
}
