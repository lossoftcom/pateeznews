import 'package:flutter/foundation.dart';

@immutable
class WhatsappMessage {
  final int id;
  final String text;
  final DateTime timestamp;
  final bool isOutgoing;
  final bool isRead;
  final String? attachmentName;
  final String? attachmentType;

  const WhatsappMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isOutgoing,
    required this.isRead,
    this.attachmentName,
    this.attachmentType,
  });

  WhatsappMessage copyWith({
    int? id,
    String? text,
    DateTime? timestamp,
    bool? isOutgoing,
    bool? isRead,
    String? attachmentName,
    String? attachmentType,
  }) {
    return WhatsappMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      isRead: isRead ?? this.isRead,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentType: attachmentType ?? this.attachmentType,
    );
  }
}

@immutable
class WhatsappChat {
  final int id;
  final String name;
  final String lastMessage;
  final DateTime time;
  final int unreadCount;
  final bool isOnline;
  final String? avatarUrl;
  final List<WhatsappMessage> messages;
  final List<String> aiReplies;

  const WhatsappChat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
    this.avatarUrl,
    required this.messages,
    required this.aiReplies,
  });

  WhatsappChat copyWith({
    int? id,
    String? name,
    String? lastMessage,
    DateTime? time,
    int? unreadCount,
    bool? isOnline,
    String? avatarUrl,
    List<WhatsappMessage>? messages,
    List<String>? aiReplies,
  }) {
    return WhatsappChat(
      id: id ?? this.id,
      name: name ?? this.name,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      messages: messages ?? this.messages,
      aiReplies: aiReplies ?? this.aiReplies,
    );
  }
}

final List<WhatsappChat> sampleWhatsappChats = [
  WhatsappChat(
    id: 1,
    name: 'Kemal Sunal (Reklam Ortaklığı)',
    lastMessage: 'Ayrıca sponsorlu içerik yayınlıyor musunuz?',
    time: DateTime.now().subtract(const Duration(minutes: 5)),
    unreadCount: 3,
    isOnline: true,
    messages: [
      WhatsappMessage(
        id: 101,
        text: 'Merhaba Pateeznews ekibi, Niğde yöresindeki gazoz reklamları için sitenizde banner alanları kiralamak istiyoruz.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        isOutgoing: false,
        isRead: true,
      ),
      WhatsappMessage(
        id: 102,
        text: 'Fiyat teklifinizi ve detayları iletebilir misiniz?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        isOutgoing: false,
        isRead: true,
      ),
      WhatsappMessage(
        id: 103,
        text: 'Ayrıca sponsorlu içerik yayınlıyor musunuz?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isOutgoing: false,
        isRead: false,
      ),
    ],
    aiReplies: [
      'Merhaba Kemal Bey, ilgi duyduğunuz için teşekkür ederiz. Güncel reklam ve sponsorlu içerik fiyat listemizi mail adresinize gönderdik. Ayrıca detaylı görüşmek için arayabiliriz.',
      'Selamlar Kemal Bey, Pateeznews olarak reklam ortaklıklarına çok önem veriyoruz. Sitenin üst kısmındaki ana banner alanımız boşta. Size özel %15 indirimli bir teklif sunabiliriz.',
      'Kemal Bey merhaba, reklam birimimiz sizinle en kısa sürede iletişime geçecektir. Telefon numaranızı paylaşırsanız seviniriz.',
    ],
  ),
  WhatsappChat(
    id: 2,
    name: 'Ailemmm ❤️',
    lastMessage: 'Aferin oğlum yorulma çok.',
    time: DateTime.now().subtract(const Duration(hours: 1)),
    unreadCount: 0,
    isOnline: false,
    messages: [
      WhatsappMessage(
        id: 201,
        text: 'Oğlum akşam eve gelirken patates almayı unutma ha, yemek yapacağız.',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        isOutgoing: false,
        isRead: true,
      ),
      WhatsappMessage(
        id: 202,
        text: 'Niğde patatesi olsun, diğerleri çabuk eriyor.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 50)),
        isOutgoing: false,
        isRead: true,
      ),
      WhatsappMessage(
        id: 203,
        text: 'Tamam anne, en kalitelisinden alıp geliyorum.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
        isOutgoing: true,
        isRead: true,
      ),
      WhatsappMessage(
        id: 204,
        text: 'Aferin oğlum yorulma çok.',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        isOutgoing: false,
        isRead: true,
      ),
    ],
    aiReplies: [
      'Tamam annecim, yoldayım şimdi marketten geçip alıyorum.',
      'Anne biraz geç kalabilirim ama kesinlikle patatesleri alacağım, merak etme.',
      'Görüşürüz anne, kendinize iyi bakın.',
    ],
  ),
  WhatsappChat(
    id: 3,
    name: 'Haluk Bilginer (Kültür-Sanat)',
    lastMessage: 'Haftaya çekimlerim başlıyor, bu hafta içi tamamlayalım.',
    time: DateTime.now().subtract(const Duration(hours: 4)),
    unreadCount: 1,
    isOnline: true,
    messages: [
      WhatsappMessage(
        id: 301,
        text: 'Merhaba, Pateeznews Kültür-Sanat bölümündeki tiyatro söyleşisi için röportaj sorularınızı bekliyorum.',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        isOutgoing: false,
        isRead: true,
      ),
      WhatsappMessage(
        id: 302,
        text: 'Haftaya çekimlerim başlıyor, bu hafta içi tamamlayalım.',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        isOutgoing: false,
        isRead: false,
      ),
    ],
    aiReplies: [
      'Haluk Bey merhaba, röportaj sorularımız hazırlandı ve editörlerimiz tarafından son kontrolleri yapılıyor. Bugün saat 17:00\'ye kadar tarafınıza iletmiş olacağız. Sabrınız için teşekkürler.',
      'Sayın Bilginer, öncelikle zaman ayırdığınız için teşekkür ederiz. Soruları e-posta üzerinden de gönderdik. Kolaylıklar dileriz.',
      'Sorular yola çıktı Haluk Bey, heyecanla yanıtlarınızı bekliyoruz!',
    ],
  ),
  WhatsappChat(
    id: 4,
    name: 'Pateez Destek (Okur)',
    lastMessage: 'Dün akşam yaptığım yorum hala görünmüyor.',
    time: DateTime.now().subtract(const Duration(days: 1)),
    unreadCount: 0,
    isOnline: false,
    messages: [
      WhatsappMessage(
        id: 401,
        text: 'Sitemizde haber yorumları bazen geç onaylanıyor, bununla ilgili teknik bir sorun mu var?',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        isOutgoing: false,
        isRead: true,
      ),
      WhatsappMessage(
        id: 402,
        text: 'Dün akşam yaptığım yorum hala görünmüyor.',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isOutgoing: false,
        isRead: true,
      ),
    ],
    aiReplies: [
      'Merhaba, yorum onay süreci moderatörlerimizin kontrolünde yürütülmektedir. Yoğunluktan ötürü gecikmeler yaşanabilir. Yorumunuz kurallara uygunsa en kısa sürede yayına alınacaktır.',
      'Teknik bir aksaklık bulunmamaktadır. Spam filtrelerimizi kontrol ettik, yorumunuz onay aşamasındadır. İlginiz için teşekkürler.',
      'Konuyu hemen moderasyon ekibine iletiyorum, kontrol edip onaylayacaklardır.',
    ],
  ),
];
