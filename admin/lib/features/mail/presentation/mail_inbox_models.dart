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
