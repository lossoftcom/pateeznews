class AdminMailMessage {
  const AdminMailMessage({
    required this.id,
    required this.senderName,
    required this.senderEmail,
    required this.recipientEmail,
    required this.subject,
    required this.preview,
    required this.account,
    required this.folder,
    required this.labels,
    required this.sentAt,
    required this.read,
    required this.starred,
    required this.hasAttachments,
    required this.hasImages,
  });

  final int id;
  final String senderName;
  final String senderEmail;
  final String recipientEmail;
  final String subject;
  final String preview;
  final String account;
  final String folder;
  final List<String> labels;
  final DateTime sentAt;
  final bool read;
  final bool starred;
  final bool hasAttachments;
  final bool hasImages;

  AdminMailMessage copyWith({String? folder, bool? read, bool? starred}) {
    return AdminMailMessage(
      id: id,
      senderName: senderName,
      senderEmail: senderEmail,
      recipientEmail: recipientEmail,
      subject: subject,
      preview: preview,
      account: account,
      folder: folder ?? this.folder,
      labels: labels,
      sentAt: sentAt,
      read: read ?? this.read,
      starred: starred ?? this.starred,
      hasAttachments: hasAttachments,
      hasImages: hasImages,
    );
  }
}

const mailFolderInbox = 'inbox';
const mailFolderArchive = 'archive';
const mailFolderSent = 'sent';
const mailFolderSpam = 'spam';
const mailFolderTrash = 'trash';

final List<AdminMailMessage> sampleAdminMailMessages = <AdminMailMessage>[
  AdminMailMessage(
    id: 1058,
    senderName: 'Pateez Haber Merkezi',
    senderEmail: 'haber@pateez.com',
    recipientEmail: 'editor@pateez.com',
    subject: 'Gunun one cikan haberleri yayina hazir',
    preview:
        'Nigde, Konya ve Kayseri bolgesinden derlenen haber secimi kontrol icin bekliyor.',
    account: 'Pateez Ana Mail',
    folder: mailFolderInbox,
    labels: ['Editoryal', 'Haber'],
    sentAt: DateTime(2026, 5, 23, 10, 48),
    read: false,
    starred: true,
    hasAttachments: true,
    hasImages: true,
  ),
  AdminMailMessage(
    id: 1057,
    senderName: 'Reklam Operasyon',
    senderEmail: 'reklam@pateez.com',
    recipientEmail: 'admin@pateez.com',
    subject: 'Mayis reklam yerlesimleri onay listesi',
    preview:
        'Ana sayfa banner ve kategori sponsor alanlari icin guncel yerlesim notlari ektedir.',
    account: 'Pateez Ana Mail',
    folder: mailFolderInbox,
    labels: ['Reklam'],
    sentAt: DateTime(2026, 5, 23, 9, 12),
    read: true,
    starred: false,
    hasAttachments: true,
    hasImages: false,
  ),
  AdminMailMessage(
    id: 1056,
    senderName: 'Sistem Bildirimi',
    senderEmail: 'no-reply@pateez.com',
    recipientEmail: 'tech@pateez.com',
    subject: 'SMTP teslimat raporu tamamlandi',
    preview:
        'Son senkronizasyonda gelen kutusu, spam ve arsiv klasorleri basariyla tarandi.',
    account: 'Teknik Mail',
    folder: mailFolderArchive,
    labels: ['Sistem'],
    sentAt: DateTime(2026, 5, 22, 18, 36),
    read: true,
    starred: false,
    hasAttachments: false,
    hasImages: false,
  ),
  AdminMailMessage(
    id: 1055,
    senderName: 'Okur Iletisim',
    senderEmail: 'okur@pateez.com',
    recipientEmail: 'iletisim@pateez.com',
    subject: 'Yerel etkinlik duyurusu hakkinda',
    preview:
        'Nigde tiyatro festivali icin gonderilen duyuru metni ve gorselleri incelemenizi rica ederiz.',
    account: 'Iletisim Mail',
    folder: mailFolderInbox,
    labels: ['Etkinlik', 'Gorsel'],
    sentAt: DateTime(2026, 5, 22, 15, 20),
    read: false,
    starred: false,
    hasAttachments: true,
    hasImages: true,
  ),
  AdminMailMessage(
    id: 1054,
    senderName: 'Muhasebe',
    senderEmail: 'muhasebe@pateez.com',
    recipientEmail: 'admin@pateez.com',
    subject: 'Fatura bilgilendirmesi',
    preview:
        'Mayis ayi yayin ve servis faturalarina ait dokumanlar kontrol icin paylasildi.',
    account: 'Pateez Ana Mail',
    folder: mailFolderInbox,
    labels: ['Fatura'],
    sentAt: DateTime(2026, 5, 21, 11, 5),
    read: true,
    starred: true,
    hasAttachments: true,
    hasImages: false,
  ),
  AdminMailMessage(
    id: 1053,
    senderName: 'Guvenlik Tarama',
    senderEmail: 'scanner@example.net',
    recipientEmail: 'tech@pateez.com',
    subject: 'Supheli teslimat uyarisi',
    preview:
        'Kimlik dogrulamasi gecersiz olan bir ileti spam klasorune alinmistir.',
    account: 'Teknik Mail',
    folder: mailFolderSpam,
    labels: ['Uyari'],
    sentAt: DateTime(2026, 5, 20, 8, 42),
    read: false,
    starred: false,
    hasAttachments: false,
    hasImages: false,
  ),
  AdminMailMessage(
    id: 1052,
    senderName: 'Pateez Admin',
    senderEmail: 'admin@pateez.com',
    recipientEmail: 'ajans@pateez.com',
    subject: 'Haftalik bulten gonderim onayi',
    preview:
        'Hazirlanan bulten tasarimi ve hedef liste onay icin ajansa iletildi.',
    account: 'Pateez Ana Mail',
    folder: mailFolderSent,
    labels: ['Bulten'],
    sentAt: DateTime(2026, 5, 20, 16, 25),
    read: true,
    starred: false,
    hasAttachments: false,
    hasImages: true,
  ),
  AdminMailMessage(
    id: 1051,
    senderName: 'Eski Kampanya',
    senderEmail: 'campaign@pateez.com',
    recipientEmail: 'editor@pateez.com',
    subject: 'Silinen kampanya taslagi',
    preview:
        'Tamamlanmayan bulten taslagi cop klasorunde saklanmaya devam ediyor.',
    account: 'Pateez Ana Mail',
    folder: mailFolderTrash,
    labels: ['Bulten'],
    sentAt: DateTime(2026, 5, 19, 14, 18),
    read: true,
    starred: false,
    hasAttachments: false,
    hasImages: false,
  ),
];
