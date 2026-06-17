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
  final String phone;
  final String lastMessage;
  final DateTime time;
  final int unreadCount;
  final bool isOnline;
  final String? avatarUrl;
  final List<WhatsappMessage> messages;
  final List<String> aiReplies;
  final DateTime? lastInboundAt;
  final DateTime? customerServiceExpiresAt;
  final bool canSendFreeform;

  const WhatsappChat({
    required this.id,
    required this.name,
    this.phone = '',
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
    this.avatarUrl,
    required this.messages,
    required this.aiReplies,
    this.lastInboundAt,
    this.customerServiceExpiresAt,
    this.canSendFreeform = true,
  });

  bool get requiresTemplate => !canSendFreeform;

  WhatsappChat copyWith({
    int? id,
    String? name,
    String? phone,
    String? lastMessage,
    DateTime? time,
    int? unreadCount,
    bool? isOnline,
    String? avatarUrl,
    List<WhatsappMessage>? messages,
    List<String>? aiReplies,
    DateTime? lastInboundAt,
    DateTime? customerServiceExpiresAt,
    bool? canSendFreeform,
  }) {
    return WhatsappChat(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      messages: messages ?? this.messages,
      aiReplies: aiReplies ?? this.aiReplies,
      lastInboundAt: lastInboundAt ?? this.lastInboundAt,
      customerServiceExpiresAt:
          customerServiceExpiresAt ?? this.customerServiceExpiresAt,
      canSendFreeform: canSendFreeform ?? this.canSendFreeform,
    );
  }
}
