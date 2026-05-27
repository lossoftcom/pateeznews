import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../auth/data/admin_auth_models.dart';
import '../presentation/whatsapp_bulk_models.dart';
import '../presentation/whatsapp_contact_list_models.dart';
import '../presentation/whatsapp_models.dart';
import '../presentation/whatsapp_settings_models.dart';
import '../presentation/whatsapp_template_models.dart';

class AdminWhatsappException implements Exception {
  const AdminWhatsappException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AdminWhatsappRepository {
  Future<List<AdminWhatsappAccount>> fetchAccounts(AdminSession session);

  Future<AdminWhatsappAccount> saveAccount(
    AdminSession session, {
    int? id,
    required AdminWhatsappAccount account,
  });

  Future<AdminWhatsappAccount> updateAccount(
    AdminSession session,
    AdminWhatsappAccount account,
    Map<String, Object?> values,
  );

  Future<AdminWhatsappAccount> checkAccount(
    AdminSession session,
    int accountId,
  );

  Future<void> deleteAccounts(AdminSession session, Iterable<int> ids);

  Future<List<AdminWhatsappTemplate>> fetchTemplates(AdminSession session);

  Future<AdminWhatsappTemplate> saveTemplate(
    AdminSession session, {
    int? id,
    required AdminWhatsappTemplate template,
  });

  Future<AdminWhatsappTemplate> updateTemplate(
    AdminSession session,
    AdminWhatsappTemplate template,
    Map<String, Object?> values,
  );

  Future<void> deleteTemplates(AdminSession session, Iterable<int> ids);

  Future<List<AdminWhatsappContactList>> fetchContactLists(
    AdminSession session,
  );

  Future<AdminWhatsappContactList> saveContactList(
    AdminSession session, {
    int? id,
    required AdminWhatsappContactList list,
  });

  Future<AdminWhatsappContactList> updateContactList(
    AdminSession session,
    AdminWhatsappContactList list,
    Map<String, Object?> values,
  );

  Future<AdminWhatsappContactList> importContacts(
    AdminSession session,
    AdminWhatsappContactList list,
    String text,
  );

  Future<void> deleteContactLists(AdminSession session, Iterable<int> ids);

  Future<List<AdminWhatsappBulkCampaign>> fetchCampaigns(AdminSession session);

  Future<AdminWhatsappBulkCampaign> saveCampaign(
    AdminSession session, {
    int? id,
    required AdminWhatsappBulkCampaign campaign,
  });

  Future<AdminWhatsappBulkCampaign> updateCampaignAction(
    AdminSession session,
    AdminWhatsappBulkCampaign campaign,
    String action, {
    DateTime? scheduledAt,
  });

  Future<void> deleteCampaigns(AdminSession session, Iterable<int> ids);

  Future<List<WhatsappChat>> fetchChats(AdminSession session);

  Future<List<WhatsappMessage>> markChatRead(AdminSession session, int chatId);

  Future<WhatsappChat> sendMessage(
    AdminSession session, {
    required int chatId,
    required String text,
  });
}

class NeonAdminWhatsappRepository implements AdminWhatsappRepository {
  const NeonAdminWhatsappRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 15);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<List<AdminWhatsappAccount>> fetchAccounts(AdminSession session) async {
    final result = await _getJson('/api/admin/whatsapp/accounts', session);
    final rows = result['accounts'];
    return rows is List
        ? rows.whereType<Map>().map(_accountFromJson).toList(growable: false)
        : const <AdminWhatsappAccount>[];
  }

  @override
  Future<AdminWhatsappAccount> saveAccount(
    AdminSession session, {
    int? id,
    required AdminWhatsappAccount account,
  }) async {
    final body = _accountPayload(account);
    final result = id == null
        ? await _requestJson(
            'POST',
            '/api/admin/whatsapp/accounts',
            session,
            body,
          )
        : await _requestJson('PATCH', '/api/admin/whatsapp/accounts', session, {
            'id': id,
            ...body,
          });
    final row = result['account'];
    if (row is Map) return _accountFromJson(row);
    throw const AdminWhatsappException('WhatsApp hesabı kaydedilemedi');
  }

  @override
  Future<AdminWhatsappAccount> updateAccount(
    AdminSession session,
    AdminWhatsappAccount account,
    Map<String, Object?> values,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/whatsapp/accounts',
      session,
      {'id': account.id, ...values},
    );
    final row = result['account'];
    if (row is Map) return _accountFromJson(row);
    throw const AdminWhatsappException('WhatsApp hesabı güncellenemedi');
  }

  @override
  Future<AdminWhatsappAccount> checkAccount(
    AdminSession session,
    int accountId,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/whatsapp/accounts',
      session,
      {'id': accountId, 'action': 'connection-check'},
    );
    final row = result['account'];
    if (row is Map) return _accountFromJson(row);
    throw const AdminWhatsappException('WhatsApp hesabı kontrol edilemedi');
  }

  @override
  Future<void> deleteAccounts(AdminSession session, Iterable<int> ids) async {
    for (final id in ids) {
      await _requestJson('DELETE', '/api/admin/whatsapp/accounts', session, {
        'id': id,
      });
    }
  }

  @override
  Future<List<AdminWhatsappTemplate>> fetchTemplates(
    AdminSession session,
  ) async {
    final result = await _getJson('/api/admin/whatsapp/templates', session, {
      'limit': '200',
    });
    final rows = result['items'];
    return rows is List
        ? rows.whereType<Map>().map(_templateFromJson).toList(growable: false)
        : const <AdminWhatsappTemplate>[];
  }

  @override
  Future<AdminWhatsappTemplate> saveTemplate(
    AdminSession session, {
    int? id,
    required AdminWhatsappTemplate template,
  }) async {
    final body = _templatePayload(template);
    final result = id == null
        ? await _requestJson(
            'POST',
            '/api/admin/whatsapp/templates',
            session,
            body,
          )
        : await _requestJson(
            'PATCH',
            '/api/admin/whatsapp/templates',
            session,
            {'id': id, ...body},
          );
    final row = result['template'];
    if (row is Map) return _templateFromJson(row);
    throw const AdminWhatsappException('WhatsApp şablonu kaydedilemedi');
  }

  @override
  Future<AdminWhatsappTemplate> updateTemplate(
    AdminSession session,
    AdminWhatsappTemplate template,
    Map<String, Object?> values,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/whatsapp/templates',
      session,
      {'id': template.id, ...values},
    );
    final row = result['template'];
    if (row is Map) return _templateFromJson(row);
    throw const AdminWhatsappException('WhatsApp şablonu güncellenemedi');
  }

  @override
  Future<void> deleteTemplates(AdminSession session, Iterable<int> ids) async {
    for (final id in ids) {
      await _requestJson('DELETE', '/api/admin/whatsapp/templates', session, {
        'id': id,
      });
    }
  }

  @override
  Future<List<AdminWhatsappContactList>> fetchContactLists(
    AdminSession session,
  ) async {
    final result = await _getJson(
      '/api/admin/whatsapp/contact-lists',
      session,
      {'limit': '100'},
    );
    final rows = result['items'];
    return rows is List
        ? rows
              .whereType<Map>()
              .map(_contactListFromJson)
              .toList(growable: false)
        : const <AdminWhatsappContactList>[];
  }

  @override
  Future<AdminWhatsappContactList> saveContactList(
    AdminSession session, {
    int? id,
    required AdminWhatsappContactList list,
  }) async {
    final body = _contactListPayload(list);
    final result = id == null
        ? await _requestJson(
            'POST',
            '/api/admin/whatsapp/contact-lists',
            session,
            body,
          )
        : await _requestJson(
            'PATCH',
            '/api/admin/whatsapp/contact-lists',
            session,
            {'id': id, ...body},
          );
    final row = result['list'];
    if (row is Map) return _contactListFromJson(row);
    throw const AdminWhatsappException('WhatsApp kişi listesi kaydedilemedi');
  }

  @override
  Future<AdminWhatsappContactList> updateContactList(
    AdminSession session,
    AdminWhatsappContactList list,
    Map<String, Object?> values,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/whatsapp/contact-lists',
      session,
      {'id': list.id, ...values},
    );
    final row = result['list'];
    if (row is Map) return _contactListFromJson(row);
    throw const AdminWhatsappException('WhatsApp kişi listesi güncellenemedi');
  }

  @override
  Future<AdminWhatsappContactList> importContacts(
    AdminSession session,
    AdminWhatsappContactList list,
    String text,
  ) async {
    await _requestJson('POST', '/api/admin/whatsapp/import', session, {
      'list_id': list.id,
      'list_name': list.name,
      'description': list.description,
      'source': list.source.value,
      'text': text,
    });
    final lists = await fetchContactLists(session);
    return lists.firstWhere((item) => item.id == list.id, orElse: () => list);
  }

  @override
  Future<void> deleteContactLists(
    AdminSession session,
    Iterable<int> ids,
  ) async {
    for (final id in ids) {
      await _requestJson(
        'DELETE',
        '/api/admin/whatsapp/contact-lists',
        session,
        {'id': id},
      );
    }
  }

  @override
  Future<List<AdminWhatsappBulkCampaign>> fetchCampaigns(
    AdminSession session,
  ) async {
    final result = await _getJson('/api/admin/whatsapp/campaigns', session, {
      'limit': '100',
    });
    final rows = result['items'];
    return rows is List
        ? rows.whereType<Map>().map(_campaignFromJson).toList(growable: false)
        : const <AdminWhatsappBulkCampaign>[];
  }

  @override
  Future<AdminWhatsappBulkCampaign> saveCampaign(
    AdminSession session, {
    int? id,
    required AdminWhatsappBulkCampaign campaign,
  }) async {
    final body = _campaignPayload(campaign);
    final result = id == null
        ? await _requestJson(
            'POST',
            '/api/admin/whatsapp/campaigns',
            session,
            body,
          )
        : await _requestJson(
            'PATCH',
            '/api/admin/whatsapp/campaigns',
            session,
            {'id': id, ...body},
          );
    final row = result['campaign'];
    if (row is Map) return _campaignFromJson(row);
    throw const AdminWhatsappException('WhatsApp kampanyası kaydedilemedi');
  }

  @override
  Future<AdminWhatsappBulkCampaign> updateCampaignAction(
    AdminSession session,
    AdminWhatsappBulkCampaign campaign,
    String action, {
    DateTime? scheduledAt,
  }) async {
    final result =
        await _requestJson('PATCH', '/api/admin/whatsapp/campaigns', session, {
          'id': campaign.id,
          'action': action,
          if (scheduledAt != null)
            'scheduled_start_at': scheduledAt.toUtc().toIso8601String(),
        });
    final row = result['campaign'];
    if (row is Map) return _campaignFromJson(row);
    throw const AdminWhatsappException('WhatsApp kampanyası güncellenemedi');
  }

  @override
  Future<void> deleteCampaigns(AdminSession session, Iterable<int> ids) async {
    for (final id in ids) {
      await _requestJson('DELETE', '/api/admin/whatsapp/campaigns', session, {
        'id': id,
      });
    }
  }

  @override
  Future<List<WhatsappChat>> fetchChats(AdminSession session) async {
    final result = await _getJson('/api/admin/whatsapp/chats', session);
    final rows = result['items'];
    return rows is List
        ? rows.whereType<Map>().map(_chatFromJson).toList(growable: false)
        : const <WhatsappChat>[];
  }

  @override
  Future<List<WhatsappMessage>> markChatRead(
    AdminSession session,
    int chatId,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/whatsapp/chats',
      session,
      {'chat_id': chatId, 'action': 'mark_read'},
    );
    final rows = result['messages'];
    return rows is List
        ? rows.whereType<Map>().map(_messageFromJson).toList(growable: false)
        : const <WhatsappMessage>[];
  }

  @override
  Future<WhatsappChat> sendMessage(
    AdminSession session, {
    required int chatId,
    required String text,
  }) async {
    final result = await _requestJson(
      'POST',
      '/api/admin/whatsapp/chats',
      session,
      {'chat_id': chatId, 'text': text},
    );
    final chat = result['chat'];
    if (chat is! Map) {
      throw const AdminWhatsappException('WhatsApp mesajı gönderilemedi');
    }
    final messages = result['messages'] is List
        ? (result['messages'] as List)
              .whereType<Map>()
              .map(_messageFromJson)
              .toList(growable: false)
        : const <WhatsappMessage>[];
    return _chatFromJson({...chat, 'messages': messages});
  }

  Map<String, Object?> _accountPayload(AdminWhatsappAccount account) {
    return {
      'account_name': account.accountName.trim(),
      'sender_name': account.senderName.trim(),
      'sender_phone': account.senderEmail.trim(),
      'business_account_id': account.domain.trim(),
      'service_type': account.providerId.trim(),
      'sending_mode': account.mode.name,
      'api_base_url': account.apiBaseUrl.trim(),
      if (account.apiKey.trim().isNotEmpty) 'api_token': account.apiKey.trim(),
      if (account.apiSecret.trim().isNotEmpty)
        'api_secret': account.apiSecret.trim(),
      'daily_limit': account.dailyLimit,
      'monthly_limit': account.monthlyLimit,
      'hourly_limit': account.hourlyLimit,
      'webhook_url': account.trackingDomain.trim(),
      'is_active': account.active,
    };
  }

  Map<String, Object?> _templatePayload(AdminWhatsappTemplate template) {
    return {
      'template_name': template.nameKey.trim(),
      'category': template.category.value,
      'subject': template.subject.trim(),
      'preview_text': template.previewText.trim(),
      'content_text': template.body.trim(),
      'variables': _templateVariables(template),
      'is_ready': template.ready,
      'is_active': template.active,
    };
  }

  Map<String, Object?> _contactListPayload(AdminWhatsappContactList list) {
    return {
      'list_name': list.name.trim(),
      'description': list.description.trim(),
      'source': list.source.value,
      'auto_sync': list.syncEnabled,
      'sync_filter': {'source': list.source.value},
      'is_active': list.active,
    };
  }

  Map<String, Object?> _campaignPayload(AdminWhatsappBulkCampaign campaign) {
    return {
      'account_id': _nullableIntString(campaign.accountId),
      'campaign_name': campaign.name.trim(),
      'subject': campaign.subject.trim(),
      'preview_text': campaign.preview.trim(),
      'content_text': campaign.preview.trim(),
      'template_id': _nullableIntString(campaign.templateId),
      'contact_list_id': _nullableIntString(campaign.contactListId),
      'recipient_count': campaign.recipientCount,
      'status': campaign.status.value,
      if (campaign.scheduledAt != null)
        'scheduled_start_at': campaign.scheduledAt!.toUtc().toIso8601String(),
    };
  }

  AdminWhatsappAccount _accountFromJson(Map<dynamic, dynamic> json) {
    final providerId = json['service_type']?.toString() ?? 'meta_cloud_api';
    final preset = adminWhatsappProviderById(providerId);
    return AdminWhatsappAccount(
      id: _asInt(json['id']),
      accountName: _decodeText(json['account_name']),
      senderName: _decodeText(json['sender_name']),
      senderEmail: _decodeText(json['sender_phone']),
      domain: _decodeText(json['business_account_id']),
      providerId: providerId,
      serviceName: preset.id == providerId ? preset.name : providerId,
      mode: _providerMode(json['sending_mode']),
      smtpHost: '',
      smtpPort: 0,
      security: AdminWhatsappSecurity.none,
      smtpUser: '',
      apiBaseUrl: _decodeText(json['api_base_url']),
      dailyLimit: _asInt(json['daily_limit'], fallback: 5000),
      monthlyLimit: _asInt(json['monthly_limit'], fallback: 150000),
      hourlyLimit: _asInt(json['hourly_limit'], fallback: 700),
      sentToday: _asInt(json['sent_today']),
      spfReady: _asBool(json['token_verified']),
      dkimReady: _asBool(json['webhook_verified']),
      dmarcReady: _asBool(json['templates_synced']),
      trackingDomain: _decodeText(json['webhook_url']),
      active: _asBool(json['is_active'], fallback: true),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    );
  }

  AdminWhatsappTemplate _templateFromJson(Map<dynamic, dynamic> json) {
    final body = _decodeText(json['content_text']);
    final subject = _decodeText(json['subject']);
    final name = _decodeText(json['template_name']);
    final variables = _asList(json['variables']);
    return AdminWhatsappTemplate(
      id: _asInt(json['id']),
      nameKey: name,
      category: _templateCategoryFromDb(json['category']),
      variableCount: variables.isNotEmpty
          ? variables.length
          : _variableCount('$subject $body'),
      ready: _asBool(json['is_ready']),
      active: _asBool(json['is_active'], fallback: true),
      updatedAt:
          _parseDate(json['updated_at']) ??
          _parseDate(json['created_at']) ??
          DateTime.now(),
      subject: subject.isNotEmpty ? subject : name,
      previewText: _decodeText(json['preview_text']),
      body: body,
    );
  }

  AdminWhatsappContactList _contactListFromJson(Map<dynamic, dynamic> json) {
    return AdminWhatsappContactList(
      id: _asInt(json['id']),
      name: _decodeText(json['list_name']),
      description: _decodeText(json['description']),
      contactCount: _asInt(json['contact_count']),
      syncEnabled: _asBool(json['auto_sync']),
      active: _asBool(json['is_active'], fallback: true),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      source: _contactSource(json['source']),
    );
  }

  AdminWhatsappBulkCampaign _campaignFromJson(Map<dynamic, dynamic> json) {
    return AdminWhatsappBulkCampaign(
      id: _asInt(json['id']),
      accountId: json['account_id']?.toString() ?? '',
      templateId: json['template_id']?.toString() ?? '',
      contactListId: json['contact_list_id']?.toString() ?? '',
      name: _decodeText(json['campaign_name']),
      subject: _decodeText(json['subject']),
      preview: _decodeText(json['preview_text']),
      templateName: _decodeText(json['template_name']),
      templateCategory: _templateCategoryLabel(json['template_category']),
      senderAccount: _decodeText(json['account_name']),
      senderEmail: _decodeText(json['account_phone']),
      recipientList: _decodeText(json['contact_list_name']),
      recipientCount: _asInt(json['recipient_count']),
      sentCount: _asInt(json['sent_count']),
      openCount: _asInt(json['read_count']),
      clickCount: _asInt(json['clicked_count']),
      bounceCount: _asInt(json['bounce_count']),
      status: _campaignStatus(json['status']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      startedAt: _parseDate(json['started_at']),
      scheduledAt: _parseDate(json['scheduled_start_at']),
    );
  }

  WhatsappChat _chatFromJson(Map<dynamic, dynamic> json) {
    final messagesValue = json['messages'];
    final messages = messagesValue is List
        ? messagesValue
              .map(
                (item) => item is WhatsappMessage
                    ? item
                    : item is Map
                    ? _messageFromJson(item)
                    : null,
              )
              .whereType<WhatsappMessage>()
              .toList(growable: false)
        : const <WhatsappMessage>[];
    return WhatsappChat(
      id: _asInt(json['id']),
      name: _decodeText(json['name']),
      lastMessage: _decodeText(json['last_message']),
      time: _parseDate(json['last_message_at']) ?? DateTime.now(),
      unreadCount: _asInt(json['unread_count']),
      isOnline: _asBool(json['is_online']),
      avatarUrl: _decodeText(json['avatar_url']).isEmpty
          ? null
          : _decodeText(json['avatar_url']),
      messages: messages,
      aiReplies: const [],
    );
  }

  WhatsappMessage _messageFromJson(Map<dynamic, dynamic> json) {
    final direction = _decodeText(json['direction']);
    final readAt = _parseDate(json['read_at']);
    return WhatsappMessage(
      id: _asInt(json['id']),
      text: _decodeText(json['body']),
      timestamp:
          _parseDate(json['created_at']) ??
          _parseDate(json['sent_at']) ??
          DateTime.now(),
      isOutgoing: direction != 'incoming',
      isRead: readAt != null || _decodeText(json['status']) == 'read',
      attachmentName: _decodeText(json['attachment_name']).isEmpty
          ? null
          : _decodeText(json['attachment_name']),
      attachmentType: _decodeText(json['attachment_type']).isEmpty
          ? null
          : _decodeText(json['attachment_type']),
    );
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    AdminSession session, [
    Map<String, String>? query,
  ]) async {
    final client = httpClient ?? http.Client();
    final closeClient = httpClient == null;
    try {
      final response = await client
          .get(
            _uri(path, query),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
          )
          .timeout(_requestTimeout);
      return _decodeResponse(response);
    } on TimeoutException {
      throw const AdminWhatsappException('Sunucu yanıtı zaman aşımına uğradı');
    } finally {
      if (closeClient) client.close();
    }
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path,
    AdminSession session,
    Map<String, Object?> body,
  ) async {
    final client = httpClient ?? http.Client();
    final closeClient = httpClient == null;
    try {
      final request = http.Request(method, _uri(path))
        ..headers.addAll({
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${session.accessToken}',
        })
        ..body = jsonEncode({'token': session.accessToken, ...body});
      final streamed = await client.send(request).timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamed);
      return _decodeResponse(response);
    } on TimeoutException {
      throw const AdminWhatsappException('Sunucu yanıtı zaman aşımına uğradı');
    } finally {
      if (closeClient) client.close();
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminWhatsappException('Geçersiz sunucu yanıtı');
    }
    final result = decoded.map((key, value) => MapEntry(key.toString(), value));
    final error = result['error'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        error != null) {
      if (error is Map) {
        final message = error['message']?.toString();
        if (message != null && message.isNotEmpty) {
          throw AdminWhatsappException(message);
        }
      }
      throw const AdminWhatsappException('WhatsApp isteği başarısız oldu');
    }
    return result;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final configured = (apiBaseUrl ?? _apiBaseUrl).trim();
    final base = configured.isNotEmpty
        ? Uri.parse(configured)
        : !kIsWeb
        ? Uri.parse(
            defaultTargetPlatform == TargetPlatform.android
                ? 'http://10.0.2.2:4321'
                : 'http://localhost:4321',
          )
        : Uri.base;
    final uri = base.resolve(path);
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  String _decodeText(Object? value) => value?.toString() ?? '';

  int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _asBool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    final text = value?.toString().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return fallback;
  }

  DateTime? _parseDate(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  List<Object?> _asList(Object? value) {
    if (value is List) return value;
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return const <Object?>[];
  }

  String _nullableIntString(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return int.tryParse(trimmed)?.toString() ?? '';
  }

  AdminWhatsappProviderMode _providerMode(Object? value) {
    final raw = value?.toString();
    return AdminWhatsappProviderMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => AdminWhatsappProviderMode.api,
    );
  }

  AdminWhatsappTemplateCategory _templateCategoryFromDb(Object? value) {
    final raw = value?.toString();
    return AdminWhatsappTemplateCategory.values.firstWhere(
      (category) => category.value == raw,
      orElse: () => AdminWhatsappTemplateCategory.campaign,
    );
  }

  String _templateCategoryLabel(Object? value) {
    return switch (_templateCategoryFromDb(value)) {
      AdminWhatsappTemplateCategory.campaign => 'Kampanya',
      AdminWhatsappTemplateCategory.info => 'Bilgi',
      AdminWhatsappTemplateCategory.invitation => 'Davet',
      AdminWhatsappTemplateCategory.order => 'Sipariş',
      AdminWhatsappTemplateCategory.quote => 'Teklif',
    };
  }

  AdminContactImportSource _contactSource(Object? value) {
    final raw = value?.toString();
    return AdminContactImportSource.values.firstWhere(
      (source) => source.value == raw,
      orElse: () => AdminContactImportSource.csv,
    );
  }

  AdminWhatsappBulkStatus _campaignStatus(Object? value) {
    final raw = value?.toString();
    return AdminWhatsappBulkStatus.values.firstWhere(
      (status) => status.value == raw,
      orElse: () => AdminWhatsappBulkStatus.draft,
    );
  }

  int _variableCount(String text) {
    final matches = RegExp(r'\{\{[^}]+\}\}').allMatches(text);
    return matches.map((match) => match.group(0)).toSet().length;
  }

  List<Map<String, String>> _templateVariables(AdminWhatsappTemplate template) {
    final text = '${template.subject} ${template.previewText} ${template.body}';
    final tokens = RegExp(r'\{\{([^}]+)\}\}')
        .allMatches(text)
        .map((match) => match.group(1)?.trim() ?? '')
        .where((token) => token.isNotEmpty)
        .toSet();
    return tokens
        .map((token) => {'token': '{{$token}}', 'label': token})
        .toList(growable: false);
  }
}
