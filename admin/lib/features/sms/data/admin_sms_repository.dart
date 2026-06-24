import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';
import '../presentation/sms_bulk_models.dart';
import '../presentation/sms_contact_list_models.dart';
import '../presentation/sms_settings_models.dart';
import '../presentation/sms_template_models.dart';

class AdminSmsException implements Exception {
  const AdminSmsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminSmsOutboxMessage {
  const AdminSmsOutboxMessage({
    required this.id,
    required this.recipient,
    required this.phone,
    required this.message,
    required this.senderLine,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String recipient;
  final String phone;
  final String message;
  final String senderLine;
  final String status;
  final DateTime createdAt;
}

abstract class AdminSmsRepository {
  Future<List<AdminSmsAccount>> fetchAccounts(AdminSession session);

  Future<AdminSmsAccount> saveAccount(
    AdminSession session, {
    int? id,
    required AdminSmsAccount account,
  });

  Future<AdminSmsAccount> updateAccount(
    AdminSession session,
    AdminSmsAccount account,
    Map<String, Object?> values,
  );

  Future<AdminSmsAccount> checkAccount(AdminSession session, int accountId);

  Future<void> deleteAccounts(AdminSession session, Iterable<int> ids);

  Future<List<AdminSmsTemplate>> fetchTemplates(AdminSession session);

  Future<AdminSmsTemplate> saveTemplate(
    AdminSession session, {
    int? id,
    required AdminSmsTemplate template,
  });

  Future<AdminSmsTemplate> updateTemplate(
    AdminSession session,
    AdminSmsTemplate template,
    Map<String, Object?> values,
  );

  Future<void> deleteTemplates(AdminSession session, Iterable<int> ids);

  Future<List<AdminSmsContactList>> fetchContactLists(AdminSession session);

  Future<AdminSmsContactList> saveContactList(
    AdminSession session, {
    int? id,
    required AdminSmsContactList list,
  });

  Future<AdminSmsContactList> updateContactList(
    AdminSession session,
    AdminSmsContactList list,
    Map<String, Object?> values,
  );

  Future<AdminSmsContactList> importContacts(
    AdminSession session,
    AdminSmsContactList list,
    String text,
  );

  Future<void> deleteContactLists(AdminSession session, Iterable<int> ids);

  Future<List<AdminSmsBulkCampaign>> fetchCampaigns(AdminSession session);

  Future<AdminSmsBulkCampaign> saveCampaign(
    AdminSession session, {
    int? id,
    required AdminSmsBulkCampaign campaign,
  });

  Future<AdminSmsBulkCampaign> updateCampaignAction(
    AdminSession session,
    AdminSmsBulkCampaign campaign,
    String action, {
    DateTime? scheduledAt,
  });

  Future<void> deleteCampaigns(AdminSession session, Iterable<int> ids);

  Future<List<AdminSmsOutboxMessage>> fetchOutboxMessages(AdminSession session);

  Future<AdminSmsOutboxMessage> sendOutboxMessage(
    AdminSession session, {
    required String phone,
    required String text,
    String recipient,
    String senderLine,
  });
}

class SupabaseAdminSmsRepository implements AdminSmsRepository {
  const SupabaseAdminSmsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 15);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<List<AdminSmsAccount>> fetchAccounts(AdminSession session) async {
    final result = await _getJson('/api/admin/sms/accounts', session);
    final rows = result['accounts'];
    return rows is List
        ? rows.whereType<Map>().map(_accountFromJson).toList(growable: false)
        : const <AdminSmsAccount>[];
  }

  @override
  Future<AdminSmsAccount> saveAccount(
    AdminSession session, {
    int? id,
    required AdminSmsAccount account,
  }) async {
    final body = _accountPayload(account);
    final result = id == null
        ? await _requestJson('POST', '/api/admin/sms/accounts', session, body)
        : await _requestJson('PATCH', '/api/admin/sms/accounts', session, {
            'id': id,
            ...body,
          });
    final row = result['account'];
    if (row is Map) return _accountFromJson(row);
    throw const AdminSmsException('SMS hesabı kaydedilemedi');
  }

  @override
  Future<AdminSmsAccount> updateAccount(
    AdminSession session,
    AdminSmsAccount account,
    Map<String, Object?> values,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/sms/accounts',
      session,
      {'id': account.id, ...values},
    );
    final row = result['account'];
    if (row is Map) return _accountFromJson(row);
    throw const AdminSmsException('SMS hesabı güncellenemedi');
  }

  @override
  Future<AdminSmsAccount> checkAccount(
    AdminSession session,
    int accountId,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/sms/accounts',
      session,
      {'id': accountId, 'action': 'connection-check'},
    );
    final row = result['account'];
    if (row is Map) return _accountFromJson(row);
    throw const AdminSmsException('SMS hesabı kontrol edilemedi');
  }

  @override
  Future<void> deleteAccounts(AdminSession session, Iterable<int> ids) async {
    for (final id in ids) {
      await _requestJson('DELETE', '/api/admin/sms/accounts', session, {
        'id': id,
      });
    }
  }

  @override
  Future<List<AdminSmsTemplate>> fetchTemplates(AdminSession session) async {
    final result = await _getJson('/api/admin/sms/templates', session, {
      'limit': '200',
    });
    final rows = result['items'];
    return rows is List
        ? rows.whereType<Map>().map(_templateFromJson).toList(growable: false)
        : const <AdminSmsTemplate>[];
  }

  @override
  Future<AdminSmsTemplate> saveTemplate(
    AdminSession session, {
    int? id,
    required AdminSmsTemplate template,
  }) async {
    final body = _templatePayload(template);
    final result = id == null
        ? await _requestJson('POST', '/api/admin/sms/templates', session, body)
        : await _requestJson('PATCH', '/api/admin/sms/templates', session, {
            'id': id,
            ...body,
          });
    final row = result['template'];
    if (row is Map) return _templateFromJson(row);
    throw const AdminSmsException('SMS şablonu kaydedilemedi');
  }

  @override
  Future<AdminSmsTemplate> updateTemplate(
    AdminSession session,
    AdminSmsTemplate template,
    Map<String, Object?> values,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/sms/templates',
      session,
      {'id': template.id, ...values},
    );
    final row = result['template'];
    if (row is Map) return _templateFromJson(row);
    throw const AdminSmsException('SMS şablonu güncellenemedi');
  }

  @override
  Future<void> deleteTemplates(AdminSession session, Iterable<int> ids) async {
    for (final id in ids) {
      await _requestJson('DELETE', '/api/admin/sms/templates', session, {
        'id': id,
      });
    }
  }

  @override
  Future<List<AdminSmsContactList>> fetchContactLists(
    AdminSession session,
  ) async {
    final result = await _getJson('/api/admin/sms/contact-lists', session, {
      'limit': '100',
    });
    final rows = result['items'];
    return rows is List
        ? rows
              .whereType<Map>()
              .map(_contactListFromJson)
              .toList(growable: false)
        : const <AdminSmsContactList>[];
  }

  @override
  Future<AdminSmsContactList> saveContactList(
    AdminSession session, {
    int? id,
    required AdminSmsContactList list,
  }) async {
    final body = _contactListPayload(list);
    final result = id == null
        ? await _requestJson(
            'POST',
            '/api/admin/sms/contact-lists',
            session,
            body,
          )
        : await _requestJson('PATCH', '/api/admin/sms/contact-lists', session, {
            'id': id,
            ...body,
          });
    final row = result['list'];
    if (row is Map) return _contactListFromJson(row);
    throw const AdminSmsException('SMS kişi listesi kaydedilemedi');
  }

  @override
  Future<AdminSmsContactList> updateContactList(
    AdminSession session,
    AdminSmsContactList list,
    Map<String, Object?> values,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/sms/contact-lists',
      session,
      {'id': list.id, ...values},
    );
    final row = result['list'];
    if (row is Map) return _contactListFromJson(row);
    throw const AdminSmsException('SMS kişi listesi güncellenemedi');
  }

  @override
  Future<AdminSmsContactList> importContacts(
    AdminSession session,
    AdminSmsContactList list,
    String text,
  ) async {
    await _requestJson('POST', '/api/admin/sms/import', session, {
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
      await _requestJson('DELETE', '/api/admin/sms/contact-lists', session, {
        'id': id,
      });
    }
  }

  @override
  Future<List<AdminSmsBulkCampaign>> fetchCampaigns(
    AdminSession session,
  ) async {
    final result = await _getJson('/api/admin/sms/campaigns', session, {
      'limit': '100',
    });
    final rows = result['items'];
    return rows is List
        ? rows.whereType<Map>().map(_campaignFromJson).toList(growable: false)
        : const <AdminSmsBulkCampaign>[];
  }

  @override
  Future<AdminSmsBulkCampaign> saveCampaign(
    AdminSession session, {
    int? id,
    required AdminSmsBulkCampaign campaign,
  }) async {
    final body = _campaignPayload(campaign);
    final result = id == null
        ? await _requestJson('POST', '/api/admin/sms/campaigns', session, body)
        : await _requestJson('PATCH', '/api/admin/sms/campaigns', session, {
            'id': id,
            ...body,
          });
    final row = result['campaign'];
    if (row is Map) return _campaignFromJson(row);
    throw const AdminSmsException('SMS kampanyası kaydedilemedi');
  }

  @override
  Future<AdminSmsBulkCampaign> updateCampaignAction(
    AdminSession session,
    AdminSmsBulkCampaign campaign,
    String action, {
    DateTime? scheduledAt,
  }) async {
    final result =
        await _requestJson('PATCH', '/api/admin/sms/campaigns', session, {
          'id': campaign.id,
          'action': action,
          if (scheduledAt != null)
            'scheduled_start_at': scheduledAt.toUtc().toIso8601String(),
        });
    final row = result['campaign'];
    if (row is Map) return _campaignFromJson(row);
    throw const AdminSmsException('SMS kampanyası güncellenemedi');
  }

  @override
  Future<void> deleteCampaigns(AdminSession session, Iterable<int> ids) async {
    for (final id in ids) {
      await _requestJson('DELETE', '/api/admin/sms/campaigns', session, {
        'id': id,
      });
    }
  }

  @override
  Future<List<AdminSmsOutboxMessage>> fetchOutboxMessages(
    AdminSession session,
  ) async {
    final result = await _getJson('/api/admin/sms/outbox', session);
    final rows = result['items'];
    return rows is List
        ? rows
              .whereType<Map>()
              .map(_outboxMessageFromJson)
              .toList(growable: false)
        : const <AdminSmsOutboxMessage>[];
  }

  @override
  Future<AdminSmsOutboxMessage> sendOutboxMessage(
    AdminSession session, {
    required String phone,
    required String text,
    String recipient = '',
    String senderLine = '',
  }) async {
    final result = await _requestJson(
      'POST',
      '/api/admin/sms/outbox',
      session,
      {
        'phone': phone,
        'name': recipient,
        'sender_line': senderLine,
        'text': text,
      },
    );
    final message = result['message'];
    if (message is! Map) {
      throw const AdminSmsException('SMS mesajı gönderilemedi');
    }
    return _outboxMessageFromJson(message);
  }

  Map<String, Object?> _accountPayload(AdminSmsAccount account) {
    return {
      'account_name': account.accountName.trim(),
      'sender_name': account.senderName.trim(),
      'sender_phone': account.senderEmail.trim(),
      'business_account_id': account.domain.trim(),
      'service_type': account.providerId.trim(),
      'sending_mode': account.mode.name,
      'api_base_url': account.apiBaseUrl.trim(),
      if (account.apiKey.trim().isNotEmpty) 'api_key': account.apiKey.trim(),
      if (account.apiSecret.trim().isNotEmpty)
        'api_secret': account.apiSecret.trim(),
      'daily_limit': account.dailyLimit,
      'monthly_limit': account.monthlyLimit,
      'hourly_limit': account.hourlyLimit,
      'webhook_url': account.trackingDomain.trim(),
      'is_active': account.active,
    };
  }

  Map<String, Object?> _templatePayload(AdminSmsTemplate template) {
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

  Map<String, Object?> _contactListPayload(AdminSmsContactList list) {
    return {
      'list_name': list.name.trim(),
      'description': list.description.trim(),
      'source': list.source.value,
      'auto_sync': list.syncEnabled,
      'sync_filter': {'source': list.source.value},
      'is_active': list.active,
    };
  }

  Map<String, Object?> _campaignPayload(AdminSmsBulkCampaign campaign) {
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

  AdminSmsAccount _accountFromJson(Map<dynamic, dynamic> json) {
    final providerId = json['service_type']?.toString() ?? 'custom_sms_api';
    final preset = adminSmsProviderById(providerId);
    return AdminSmsAccount(
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
      security: AdminSmsSecurity.none,
      smtpUser: '',
      apiBaseUrl: _decodeText(json['api_base_url']),
      apiKey: '',
      apiSecret: '',
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

  AdminSmsTemplate _templateFromJson(Map<dynamic, dynamic> json) {
    final body = _decodeText(json['content_text']);
    final subject = _decodeText(json['subject']);
    final name = _decodeText(json['template_name']);
    final variables = _asList(json['variables']);
    return AdminSmsTemplate(
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

  AdminSmsContactList _contactListFromJson(Map<dynamic, dynamic> json) {
    return AdminSmsContactList(
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

  AdminSmsBulkCampaign _campaignFromJson(Map<dynamic, dynamic> json) {
    return AdminSmsBulkCampaign(
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

  AdminSmsOutboxMessage _outboxMessageFromJson(Map<dynamic, dynamic> json) {
    return AdminSmsOutboxMessage(
      id: _asInt(json['id']),
      recipient: _decodeText(json['recipient']),
      phone: _decodeText(json['phone']),
      message: _decodeText(json['body']),
      senderLine: _decodeText(json['sender_line']),
      status: _decodeText(json['status']).isEmpty
          ? 'queued'
          : _decodeText(json['status']),
      createdAt:
          _parseDate(json['created_at']) ??
          _parseDate(json['sent_at']) ??
          DateTime.now(),
    );
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    AdminSession session, [
    Map<String, String>? query,
  ]) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      final response = await client
          .get(
            _uri(path, query),
            headers: await adminAuthHeaders(token: session.accessToken),
          )
          .timeout(_requestTimeout);
      return _decodeResponse(response);
    } on TimeoutException {
      throw const AdminSmsException('Sunucu yanıtı zaman aşımına uğradı');
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
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      final headers = await adminJsonHeaders(token: session.accessToken);
      final request = http.Request(method, _uri(path))
        ..headers.addAll(headers)
        ..body = jsonEncode(body);
      final streamed = await client.send(request).timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamed);
      return _decodeResponse(response);
    } on TimeoutException {
      throw const AdminSmsException('Sunucu yanıtı zaman aşımına uğradı');
    } finally {
      if (closeClient) client.close();
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminSmsException('Geçersiz sunucu yanıtı');
    }
    final result = decoded.map((key, value) => MapEntry(key.toString(), value));
    final error = result['error'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        error != null) {
      if (error is Map) {
        final message = error['message']?.toString();
        if (message != null && message.isNotEmpty) {
          throw AdminSmsException(message);
        }
      }
      throw const AdminSmsException('SMS isteği başarısız oldu');
    }
    return result;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final configured = (apiBaseUrl ?? _apiBaseUrl).trim();
    final base = configured.isNotEmpty && !isLocalAdminApiBaseUrl(configured)
        ? Uri.parse(configured)
        : Uri.parse('https://pateez.com');
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

  AdminSmsProviderMode _providerMode(Object? value) {
    final raw = value?.toString();
    return AdminSmsProviderMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => AdminSmsProviderMode.api,
    );
  }

  AdminSmsTemplateCategory _templateCategoryFromDb(Object? value) {
    final raw = value?.toString();
    return AdminSmsTemplateCategory.values.firstWhere(
      (category) => category.value == raw,
      orElse: () => AdminSmsTemplateCategory.campaign,
    );
  }

  String _templateCategoryLabel(Object? value) {
    return switch (_templateCategoryFromDb(value)) {
      AdminSmsTemplateCategory.campaign => 'Kampanya',
      AdminSmsTemplateCategory.info => 'Bilgi',
      AdminSmsTemplateCategory.invitation => 'Davet',
      AdminSmsTemplateCategory.order => 'Sipariş',
      AdminSmsTemplateCategory.quote => 'Teklif',
    };
  }

  AdminContactImportSource _contactSource(Object? value) {
    final raw = value?.toString();
    return AdminContactImportSource.values.firstWhere(
      (source) => source.value == raw,
      orElse: () => AdminContactImportSource.csv,
    );
  }

  AdminSmsBulkStatus _campaignStatus(Object? value) {
    final raw = value?.toString();
    return AdminSmsBulkStatus.values.firstWhere(
      (status) => status.value == raw,
      orElse: () => AdminSmsBulkStatus.draft,
    );
  }

  int _variableCount(String text) {
    final matches = RegExp(r'\{\{[^}]+\}\}').allMatches(text);
    return matches.map((match) => match.group(0)).toSet().length;
  }

  List<Map<String, String>> _templateVariables(AdminSmsTemplate template) {
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
