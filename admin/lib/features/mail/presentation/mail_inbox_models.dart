class AdminMailMessage {
  const AdminMailMessage({
    required this.id,
    int? displayId,
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
    this.contentHtml = '',
    this.attachments = const <AdminMailAttachment>[],
    this.images = const <AdminMailAttachment>[],
    this.status = '',
    this.source = mailMessageSourceInbox,
    this.scheduledAt,
  }) : displayId = displayId ?? id;

  final int id;
  final int displayId;
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
  final String contentHtml;
  final List<AdminMailAttachment> attachments;
  final List<AdminMailAttachment> images;
  final String status;
  final String source;
  final DateTime? scheduledAt;

  bool get isInboxSource => source == mailMessageSourceInbox;
  bool get isOutboxSource => source == mailMessageSourceOutbox;

  AdminMailMessage copyWith({String? folder, bool? read, bool? starred}) {
    return AdminMailMessage(
      id: id,
      displayId: displayId,
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
      contentHtml: contentHtml,
      attachments: attachments,
      images: images,
      status: status,
      source: source,
      scheduledAt: scheduledAt,
    );
  }
}

class AdminMailAttachment {
  const AdminMailAttachment({
    required this.filename,
    required this.contentType,
    required this.size,
    this.inline = false,
  });

  final String filename;
  final String contentType;
  final int size;
  final bool inline;

  bool get isImage => contentType.toLowerCase().startsWith('image/');
}

const mailMessageSourceInbox = 'inbox';
const mailMessageSourceOutbox = 'outbox';
const mailFolderInbox = 'inbox';
const mailFolderArchive = 'archive';
const mailFolderSent = 'sent';
const mailFolderOutbox = 'outbox';
const mailFolderDraft = 'draft';
const mailFolderScheduled = 'scheduled';
const mailFolderSpam = 'spam';
const mailFolderTrash = 'trash';
