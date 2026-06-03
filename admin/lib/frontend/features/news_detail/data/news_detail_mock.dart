import '../../../core/mock/home_mock_data.dart';

/// Detay sayfası için sade mock içerik üreticisi.
///
/// Gerçek API entegrasyonu sırasında bu dosya `repository` ile değiştirilir;
/// arayüz [NewsBody], [NewsReactionStats] ve [NewsCommentThread] modellerine
/// bağımlı kalır. Şimdilik makaleyi alır ve okunaklı, gerçekçi bir gövde
/// üretir.
class NewsDetailMock {
  const NewsDetailMock._();

  static NewsBody bodyFor(NewsArticle article) {
    return NewsBody(
      paragraphs: _paragraphsFor(article),
      pullQuote: _pullQuoteFor(article),
      sourceNote: 'Pateeznews muhabir ağı ve kurumsal açıklamalardan derlendi.',
    );
  }

  static NewsReactionStats reactionsFor(NewsArticle article) {
    // Yayın yaşı + beğeniye dayalı tutarlı dağılım.
    final base = (article.likes / 6).round();
    int v(int multiplier, int offset) =>
        (base * (0.25 + multiplier * 0.06)).round() + offset;

    return NewsReactionStats(
      counts: {
        NewsReaction.like: v(6, 12),
        NewsReaction.illuminating: v(4, 8),
        NewsReaction.thoughtful: v(3, 6),
        NewsReaction.surprised: v(2, 4),
        NewsReaction.saddened: v(1, 3),
        NewsReaction.angering: v(2, 5),
      },
    );
  }

  static NewsCommentThread commentsFor(NewsArticle article) {
    return NewsCommentThread(
      total: article.comments,
      preview: HomeMockData.samplePreviewComments,
      extras: _extraCommentsFor(article),
    );
  }

  /// Aynı [feed]'i baz alıp [current] sonrasındaki haberi döner.
  /// Listenin sonundaysa başa sarar; böylece sonsuz okuma deneyimi olur.
  static NewsArticle nextOf(NewsArticle current, List<NewsArticle> feed) {
    if (feed.isEmpty) return current;
    final index = feed.indexWhere((a) => a.id == current.id);
    if (index == -1 || index + 1 >= feed.length) return feed.first;
    return feed[index + 1];
  }
}

/// Detay sayfasında render edilen haber gövdesi.
class NewsBody {
  const NewsBody({
    required this.paragraphs,
    required this.pullQuote,
    required this.sourceNote,
  });

  final List<String> paragraphs;
  final String pullQuote;
  final String sourceNote;
}

/// Habere verilen emoji tepki türleri.
enum NewsReaction {
  like,
  illuminating,
  thoughtful,
  surprised,
  saddened,
  angering,
}

class NewsReactionStats {
  const NewsReactionStats({required this.counts});

  final Map<NewsReaction, int> counts;

  int get total => counts.values.fold(0, (a, b) => a + b);

  int countOf(NewsReaction r) => counts[r] ?? 0;
}

class NewsCommentThread {
  const NewsCommentThread({
    required this.total,
    required this.preview,
    required this.extras,
  });

  final int total;
  final List<NewsComment> preview;
  final List<NewsComment> extras;

  List<NewsComment> get visible => [...preview, ...extras];
}

/// Haberin kategori ve bölgesine uygun, kısa ve okunaklı paragraflar üretir.
/// İçerik gerçek dünya tonunda; demo için tutarlı kalmaya odaklıdır.
List<String> _paragraphsFor(NewsArticle a) {
  final region = a.region;
  final category = a.category;
  return [
    'Bugün ${a.publishedAt.day} ${_monthName(a.publishedAt.month)} tarihinde '
        '$region merkezli yapılan değerlendirme, kamuoyunda hızla ilgi gördü. '
        '"${a.title}" başlıklı gündem, $category alanında uzun süredir '
        'beklenen yapısal adımların hızlandığına işaret ediyor.',
    'Konunun en önemli tarafı, gelişmenin etkilerinin yalnızca tek bir '
        'kesimle sınırlı kalmaması. Yetkililer, sürecin önümüzdeki haftalarda '
        'daha geniş paydaş grubuyla şekilleneceğini belirtiyor. Bağımsız '
        'gözlemciler ise atılan adımın uzun vadeli sonuçlarını ölçmek için '
        'somut göstergelerin paylaşılmasını bekliyor.',
    'Pateeznews\'in görüştüğü uzmanlara göre konunun üç temel boyutu var: '
        'planlama, uygulama ve takip. Planlama tarafında yol haritasının net '
        'olması, uygulamada şeffaflık ve takip aşamasında bağımsız raporlama '
        'mekanizmaları kritik öneme sahip.',
    '"$region" özelinde yapılan açıklamada, vatandaşların gelişmeleri '
        'birinci ağızdan takip edebilmesi için resmi kanalların yanı sıra '
        'bağımsız haber kaynaklarının da önemine dikkat çekildi. Pateeznews, '
        'konunun seyrini sahadan ve veri masasından takip etmeye devam edecek.',
    'Önümüzdeki günlerde yapılması planlanan sunumlar ve panel '
        'oturumlarıyla birlikte detayların daha da netleşmesi bekleniyor. '
        'Pateeznews okurları, gündemin tamamına ilişkin güncellemeleri canlı '
        'akışlardan ve bildirimlerden takip edebilir.',
  ];
}

String _pullQuoteFor(NewsArticle a) {
  switch (a.category) {
    case 'Ekonomi':
      return 'Yapısal kararların etkisi yalnızca rakamlarda değil, '
          'vatandaşın güveninde de ölçülür.';
    case 'Spor':
      return 'Saha içinde belirleyici olan rakamlar değil, sahadaki '
          'inançtır.';
    case 'Kültür':
      return 'Bir kentin kültürel hafızası, paylaşılan anların ne kadar '
          'çoğaltıldığıyla canlanır.';
    case 'Teknoloji':
      return 'Türkiye\'nin dijital geleceği, açık kaynak işbirliklerinin '
          'derinleştiği oranda güç kazanacak.';
    case 'Sağlık':
      return 'Erken tanı, kazanılmış zaman demektir; sistem bunu '
          'kolaylaştırdıkça toplum kazanır.';
    case 'Bilim':
      return 'Bilim, ulusal sınırları aşan ortak bir lisan; ödüller bu '
          'lisanın takdir edildiğinin işaretidir.';
    case 'Eğitim':
      return 'Tercih dönemi, gencin yalnız bırakılmaması gereken en '
          'kritik kavşağıdır.';
    case 'Gündem':
      return 'Yerel kararların çoğu, sahaya inildiğinde gündemin asıl '
          'rengini gösterir.';
    case 'Yaşam':
      return 'Yerli turizmin gücü, mevsim rekorlarından çok yıl boyu '
          'sürdürülebilir bir hizmet anlayışıyla ölçülür.';
  }
  return 'Pateeznews, gündemi tek başlık değil, çoklu bakışla anlatır.';
}

/// Gerçek dünya hissi için 3 ek yorum.
List<NewsComment> _extraCommentsFor(NewsArticle a) {
  final base = a.publishedAt;
  return [
    NewsComment(
      author: const NewsAuthor(
        name: 'Mert Y.',
        avatarUrl: 'https://picsum.photos/seed/pateez-cm-mert/200/200',
        handle: '@merty',
      ),
      body:
          'Konunun saha tarafından nasıl göründüğü çok önemli. Pateez bu açıdan '
          'iyi bir özet çıkarmış, kalemine sağlık.',
      publishedAt: base.subtract(const Duration(minutes: 8)),
      likes: 18,
    ),
    NewsComment(
      author: const NewsAuthor(
        name: 'Selin D.',
        avatarUrl: 'https://picsum.photos/seed/pateez-cm-selind/200/200',
        handle: '@selind',
        isVerified: true,
      ),
      body:
          'Veriler net, dil sade. Özellikle önümüzdeki haftaya dair beklentinin '
          'çerçevelenmiş olması okumayı keyifli yaptı.',
      publishedAt: base.subtract(const Duration(minutes: 16)),
      likes: 32,
    ),
    NewsComment(
      author: const NewsAuthor(
        name: 'Kerem B.',
        avatarUrl: 'https://picsum.photos/seed/pateez-cm-keremb/200/200',
        handle: '@keremb',
      ),
      body:
          'Pateez\'in tarafsız üslubu beni her seferinde geri getiriyor. Diğer '
          'medya organlarından farkı burada.',
      publishedAt: base.subtract(const Duration(minutes: 32)),
      likes: 9,
    ),
  ];
}

String _monthName(int month) {
  const names = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  if (month < 1 || month > 12) return '';
  return names[month - 1];
}

/// Tepkilerin Türkçe etiketi ve görsel asset yolu.
extension NewsReactionMeta on NewsReaction {
  String get label {
    switch (this) {
      case NewsReaction.like:
        return 'Beğendim';
      case NewsReaction.illuminating:
        return 'Aydınlatıcı';
      case NewsReaction.thoughtful:
        return 'Düşündürdü';
      case NewsReaction.surprised:
        return 'Şaşırttı';
      case NewsReaction.saddened:
        return 'Üzdü';
      case NewsReaction.angering:
        return 'Kızdırdı';
    }
  }

  String get assetPath {
    switch (this) {
      case NewsReaction.like:
        return 'assets/images/reactions/reaction_like.webp';
      case NewsReaction.illuminating:
        return 'assets/images/reactions/reaction_illuminating.webp';
      case NewsReaction.thoughtful:
        return 'assets/images/reactions/reaction_thoughtful.webp';
      case NewsReaction.surprised:
        return 'assets/images/reactions/reaction_surprised.webp';
      case NewsReaction.saddened:
        return 'assets/images/reactions/reaction_saddened.webp';
      case NewsReaction.angering:
        return 'assets/images/reactions/reaction_angering.webp';
    }
  }
}
