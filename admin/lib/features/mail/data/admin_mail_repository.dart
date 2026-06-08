import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';
import '../presentation/bulk_mail_models.dart';
import '../presentation/contact_list_models.dart';
import '../presentation/mail_inbox_models.dart';
import '../presentation/mail_settings_models.dart';
import '../presentation/mail_template_models.dart';

class AdminMailException implements Exception {
  const AdminMailException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminMailComposePayload {
  const AdminMailComposePayload({
    required this.accountId,
    required this.recipients,
    required this.subject,
    required this.content,
    this.templateId,
    this.scheduledAt,
    this.draft = false,
  });

  final int? accountId;
  final String recipients;
  final String subject;
  final String content;
  final int? templateId;
  final DateTime? scheduledAt;
  final bool draft;
}

abstract class AdminMailRepository {
  Future<List<AdminMailAccount>> fetchAccounts(AdminSession session);

  Future<AdminMailAccount> saveAccount(
    AdminSession session, {
    int? id,
    required AdminMailAccount account,
  });

  Future<AdminMailAccount> updateAccount(
    AdminSession session,
    AdminMailAccount account,
    Map<String, Object?> values,
  );

  Future<void> checkAccountDns(AdminSession session, int accountId);

  Future<void> deleteAccounts(AdminSession session, Iterable<int> ids);

  Future<List<AdminMailTemplate>> fetchTemplates(AdminSession session);

  Future<AdminMailTemplate> saveTemplate(
    AdminSession session, {
    int? id,
    required AdminMailTemplate template,
  });

  Future<AdminMailTemplate> updateTemplate(
    AdminSession session,
    AdminMailTemplate template,
    Map<String, Object?> values,
  );

  Future<void> deleteTemplates(AdminSession session, Iterable<int> ids);

  Future<List<AdminContactList>> fetchContactLists(AdminSession session);

  Future<AdminContactList> saveContactList(
    AdminSession session, {
    int? id,
    required AdminContactList list,
  });

  Future<AdminContactList> updateContactList(
    AdminSession session,
    AdminContactList list,
    Map<String, Object?> values,
  );

  Future<AdminContactList> importContacts(
    AdminSession session,
    AdminContactList list,
    String text,
  );

  Future<void> deleteContactLists(AdminSession session, Iterable<int> ids);

  Future<List<AdminBulkMailCampaign>> fetchCampaigns(AdminSession session);

  Future<AdminBulkMailCampaign> saveCampaign(
    AdminSession session, {
    int? id,
    required AdminBulkMailCampaign campaign,
  });

  Future<AdminBulkMailCampaign> updateCampaignAction(
    AdminSession session,
    AdminBulkMailCampaign campaign,
    String action, {
    DateTime? scheduledAt,
  });

  Future<void> deleteCampaigns(AdminSession session, Iterable<int> ids);

  Future<List<AdminMailMessage>> fetchInbox(AdminSession session);

  Future<void> updateInboxMessages(
    AdminSession session,
    Iterable<int> ids,
    String action,
  );

  Future<void> deleteInboxMessages(AdminSession session, Iterable<int> ids);

  Future<void> sendMail(AdminSession session, AdminMailComposePayload payload);
}

class SupabaseAdminMailRepository implements AdminMailRepository {
  const SupabaseAdminMailRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 15);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<List<AdminMailAccount>> fetchAccounts(AdminSession session) async {
    final result = await _getJson('/api/admin/mail/accounts', session);
    final rows = result['accounts'];
    return rows is List
        ? rows.whereType<Map>().map(_accountFromJson).toList(growable: false)
        : const <AdminMailAccount>[];
  }

  @override
  Future<AdminMailAccount> saveAccount(
    AdminSession session, {
    int? id,
    required AdminMailAccount account,
  }) async {
    final body = _accountPayload(account);
    final result = id == null
        ? await _requestJson('POST', '/api/admin/mail/accounts', session, body)
        : await _requestJson('PATCH', '/api/admin/mail/accounts', session, {
            'id': id,
            ...body,
          });
    final row = result['account'];
    if (row is Map) return _accountFromJson(row);
    throw const AdminMailException('Mail hesabı kaydedilemedi');
  }

  @override
  Future<AdminMailAccount> updateAccount(
    AdminSession session,
    AdminMailAccount account,
    Map<String, Object?> values,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/mail/accounts',
      session,
      {'id': account.id, ...values},
    );
    final row = result['account'];
    if (row is Map) return _accountFromJson(row);
    throw const AdminMailException('Mail hesabı güncellenemedi');
  }

  @override
  Future<void> checkAccountDns(AdminSession session, int accountId) async {
    await _requestJson('PATCH', '/api/admin/mail/accounts', session, {
      'id': accountId,
      'action': 'dns-check',
    });
  }

  @override
  Future<void> deleteAccounts(AdminSession session, Iterable<int> ids) async {
    for (final id in ids) {
      await _requestJson('DELETE', '/api/admin/mail/accounts', session, {
        'id': id,
      });
    }
  }

  @override
  Future<List<AdminMailTemplate>> fetchTemplates(AdminSession session) async {
    final result = await _getJson('/api/admin/mail/templates', session, {
      'limit': '200',
    });
    final rows = result['items'];
    return rows is List
        ? rows.whereType<Map>().map(_templateFromJson).toList(growable: false)
        : const <AdminMailTemplate>[];
  }

  @override
  Future<AdminMailTemplate> saveTemplate(
    AdminSession session, {
    int? id,
    required AdminMailTemplate template,
  }) async {
    final body = _templatePayload(template);
    final result = id == null
        ? await _requestJson('POST', '/api/admin/mail/templates', session, body)
        : await _requestJson('PATCH', '/api/admin/mail/templates', session, {
            'id': id,
            ...body,
          });
    final row = result['template'];
    if (row is Map) return _templateFromJson(row);
    throw const AdminMailException('Mail şablonu kaydedilemedi');
  }

  @override
  Future<AdminMailTemplate> updateTemplate(
    AdminSession session,
    AdminMailTemplate template,
    Map<String, Object?> values,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/mail/templates',
      session,
      {'id': template.id, ...values},
    );
    final row = result['template'];
    if (row is Map) return _templateFromJson(row);
    throw const AdminMailException('Mail şablonu güncellenemedi');
  }

  @override
  Future<void> deleteTemplates(AdminSession session, Iterable<int> ids) async {
    for (final id in ids) {
      await _requestJson('DELETE', '/api/admin/mail/templates', session, {
        'id': id,
      });
    }
  }

  @override
  Future<List<AdminContactList>> fetchContactLists(AdminSession session) async {
    final result = await _getJson('/api/admin/mail/contact-lists', session, {
      'limit': '100',
    });
    final rows = result['items'];
    return rows is List
        ? rows
              .whereType<Map>()
              .map(_contactListFromJson)
              .toList(growable: false)
        : const <AdminContactList>[];
  }

  @override
  Future<AdminContactList> saveContactList(
    AdminSession session, {
    int? id,
    required AdminContactList list,
  }) async {
    final body = _contactListPayload(list);
    final result = id == null
        ? await _requestJson(
            'POST',
            '/api/admin/mail/contact-lists',
            session,
            body,
          )
        : await _requestJson(
            'PATCH',
            '/api/admin/mail/contact-lists',
            session,
            {'id': id, ...body},
          );
    final row = result['list'];
    if (row is Map) return _contactListFromJson(row);
    throw const AdminMailException('Kişi listesi kaydedilemedi');
  }

  @override
  Future<AdminContactList> updateContactList(
    AdminSession session,
    AdminContactList list,
    Map<String, Object?> values,
  ) async {
    final result = await _requestJson(
      'PATCH',
      '/api/admin/mail/contact-lists',
      session,
      {'id': list.id, ...values},
    );
    final row = result['list'];
    if (row is Map) return _contactListFromJson(row);
    throw const AdminMailException('Kişi listesi güncellenemedi');
  }

  @override
  Future<AdminContactList> importContacts(
    AdminSession session,
    AdminContactList list,
    String text,
  ) async {
    await _requestJson('POST', '/api/admin/mail/import', session, {
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
      await _requestJson('DELETE', '/api/admin/mail/contact-lists', session, {
        'id': id,
      });
    }
  }

  @override
  Future<List<AdminBulkMailCampaign>> fetchCampaigns(
    AdminSession session,
  ) async {
    final result = await _getJson('/api/admin/mail/campaigns', session, {
      'limit': '100',
    });
    final rows = result['items'];
    return rows is List
        ? rows.whereType<Map>().map(_campaignFromJson).toList(growable: false)
        : const <AdminBulkMailCampaign>[];
  }

  @override
  Future<AdminBulkMailCampaign> saveCampaign(
    AdminSession session, {
    int? id,
    required AdminBulkMailCampaign campaign,
  }) async {
    final body = _campaignPayload(campaign);
    final result = id == null
        ? await _requestJson('POST', '/api/admin/mail/campaigns', session, body)
        : await _requestJson('PATCH', '/api/admin/mail/campaigns', session, {
            'id': id,
            ...body,
          });
    final row = result['campaign'];
    if (row is Map) return _campaignFromJson(row);
    throw const AdminMailException('Mail kampanyası kaydedilemedi');
  }

  @override
  Future<AdminBulkMailCampaign> updateCampaignAction(
    AdminSession session,
    AdminBulkMailCampaign campaign,
    String action, {
    DateTime? scheduledAt,
  }) async {
    final result =
        await _requestJson('PATCH', '/api/admin/mail/campaigns', session, {
          'id': campaign.id,
          'action': action,
          if (scheduledAt != null)
            'scheduled_start_at': scheduledAt.toUtc().toIso8601String(),
        });
    final row = result['campaign'];
    if (row is Map) return _campaignFromJson(row);
    throw const AdminMailException('Mail kampanyası güncellenemedi');
  }

  @override
  Future<void> deleteCampaigns(AdminSession session, Iterable<int> ids) async {
    for (final id in ids) {
      await _requestJson('DELETE', '/api/admin/mail/campaigns', session, {
        'id': id,
      });
    }
  }

  @override
  Future<List<AdminMailMessage>> fetchInbox(AdminSession session) async {
    final result = await _getJson('/api/admin/mail/inbox', session, {
      'limit': '100',
    });
    final rows = result['items'];
    return rows is List
        ? rows.whereType<Map>().map(_messageFromJson).toList(growable: false)
        : const <AdminMailMessage>[];
  }

  @override
  Future<void> updateInboxMessages(
    AdminSession session,
    Iterable<int> ids,
    String action,
  ) async {
    final idList = ids.toList(growable: false);
    if (idList.isEmpty) return;
    await _requestJson('PATCH', '/api/admin/mail/inbox', session, {
      'ids': idList,
      'action': action,
    });
  }

  @override
  Future<void> deleteInboxMessages(
    AdminSession session,
    Iterable<int> ids,
  ) async {
    final idList = ids.toList(growable: false);
    if (idList.isEmpty) return;
    await _requestJson('DELETE', '/api/admin/mail/inbox', session, {
      'ids': idList,
    });
  }

  @override
  Future<void> sendMail(
    AdminSession session,
    AdminMailComposePayload payload,
  ) async {
    await _requestJson('POST', '/api/admin/mail/send', session, {
      if (payload.accountId != null) 'account_id': payload.accountId,
      if (payload.templateId != null) 'template_id': payload.templateId,
      'to': payload.recipients,
      'subject': payload.subject,
      'content_html': payload.content,
      'content_text': _plainText(payload.content),
      if (payload.scheduledAt != null)
        'scheduled_at': payload.scheduledAt!.toUtc().toIso8601String(),
      if (payload.draft) 'draft': true,
    });
  }

  Map<String, Object?> _accountPayload(AdminMailAccount account) {
    return {
      'account_name': account.accountName.trim(),
      'sender_name': account.senderName.trim(),
      'sender_email': account.senderEmail.trim().toLowerCase(),
      'domain': account.domain.trim(),
      'service_type': account.providerId.trim(),
      'sending_mode': account.mode.name,
      'api_base_url': account.apiBaseUrl.trim(),
      'smtp_host': account.smtpHost.trim(),
      'smtp_port': account.smtpPort,
      'smtp_username': account.smtpUser.trim(),
      if (account.smtpPassword.trim().isNotEmpty)
        'smtp_password': account.smtpPassword.trim(),
      'smtp_secure': _securityToApi(account.security),
      if (account.apiKey.trim().isNotEmpty) 'api_key': account.apiKey.trim(),
      if (account.apiSecret.trim().isNotEmpty)
        'api_secret': account.apiSecret.trim(),
      'daily_limit': account.dailyLimit,
      'monthly_limit': account.monthlyLimit,
      'hourly_limit': account.hourlyLimit,
      'spf_registered': account.spfReady,
      'dkim_registered': account.dkimReady,
      'dmarc_registered': account.dmarcReady,
      'tracking_domain': account.trackingDomain.trim(),
      'is_active': account.active,
    };
  }

  Map<String, Object?> _templatePayload(AdminMailTemplate template) {
    return {
      'template_name': template.nameKey.trim(),
      'category': _templateCategoryToDb(template.category),
      'subject': template.subject.trim(),
      'preview_text': template.previewText.trim(),
      'content_html': template.body.trim(),
      'variables': _templateVariables(template),
      'is_ready': template.ready,
      'is_active': template.active,
    };
  }

  Map<String, Object?> _contactListPayload(AdminContactList list) {
    return {
      'list_name': list.name.trim(),
      'description': list.description.trim(),
      'source': list.source.value,
      'auto_sync': list.syncEnabled,
      'sync_filter': {'source': list.source.value},
      'is_active': list.active,
    };
  }

  Map<String, Object?> _campaignPayload(AdminBulkMailCampaign campaign) {
    return {
      'account_id': _nullableIntString(campaign.accountId),
      'campaign_name': campaign.name.trim(),
      'subject': campaign.subject.trim(),
      'preview_text': campaign.preview.trim(),
      'content_html': campaign.preview.trim(),
      'template_id': _nullableIntString(campaign.templateId),
      'contact_list_id': _nullableIntString(campaign.contactListId),
      'recipient_count': campaign.recipientCount,
      'status': campaign.status.value,
      if (campaign.scheduledAt != null)
        'scheduled_start_at': campaign.scheduledAt!.toUtc().toIso8601String(),
    };
  }

  AdminMailAccount _accountFromJson(Map<dynamic, dynamic> json) {
    final providerId = json['service_type']?.toString() ?? 'smtp_generic';
    final preset = adminMailProviderById(providerId);
    final senderEmail = _decodeText(json['sender_email']);
    final domain = _decodeText(json['domain']);
    return AdminMailAccount(
      id: _asInt(json['id']),
      accountName: _decodeText(json['account_name']),
      senderName: _decodeText(json['sender_name']),
      senderEmail: senderEmail,
      domain: domain.isNotEmpty ? domain : _domainFromEmail(senderEmail),
      providerId: providerId,
      serviceName: preset.id == providerId ? preset.name : providerId,
      mode: _providerMode(json['sending_mode']),
      smtpHost: _decodeText(json['smtp_host']),
      smtpPort: _asInt(json['smtp_port'], fallback: preset.smtpPort),
      security: _securityFromApi(json['smtp_secure']),
      smtpUser: _decodeText(json['smtp_username']),
      apiBaseUrl: _decodeText(json['api_base_url']),
      dailyLimit: _asInt(json['daily_limit'], fallback: 500),
      monthlyLimit: _asInt(json['monthly_limit'], fallback: 15000),
      hourlyLimit: _asInt(json['hourly_limit'], fallback: 100),
      sentToday: _asInt(json['sent_today']),
      spfReady: _asBool(json['spf_registered']),
      dkimReady: _asBool(json['dkim_registered']),
      dmarcReady: _asBool(json['dmarc_registered']),
      trackingDomain: _decodeText(json['tracking_domain']),
      active: _asBool(json['is_active'], fallback: true),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    );
  }

  AdminMailTemplate _templateFromJson(Map<dynamic, dynamic> json) {
    final body = _decodeText(json['content_html']);
    final subject = _decodeText(json['subject']);
    final name = _decodeText(json['template_name']);
    final variables = _asList(json['variables']);
    return AdminMailTemplate(
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

  AdminContactList _contactListFromJson(Map<dynamic, dynamic> json) {
    return AdminContactList(
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

  AdminBulkMailCampaign _campaignFromJson(Map<dynamic, dynamic> json) {
    return AdminBulkMailCampaign(
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
      senderEmail: _decodeText(json['account_email']),
      recipientList: _decodeText(json['contact_list_name']),
      recipientCount: _asInt(json['recipient_count']),
      sentCount: _asInt(json['sent_count']),
      openCount: _asInt(json['opened_count']),
      clickCount: _asInt(json['clicked_count']),
      bounceCount: _asInt(json['bounce_count']),
      status: _campaignStatus(json['status']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      startedAt: _parseDate(json['started_at']),
      scheduledAt: _parseDate(json['scheduled_start_at']),
    );
  }

  AdminMailMessage _messageFromJson(Map<dynamic, dynamic> json) {
    final attachments = _asList(json['attachments']);
    final images = _asList(json['images']);
    final contentText = _decodeText(json['content_text']);
    final contentHtml = _decodeText(json['content_html']);
    return AdminMailMessage(
      id: _asInt(json['id']),
      senderName: _decodeText(json['sender_name']),
      senderEmail: _decodeText(json['sender_email']),
      recipientEmail: _decodeText(json['recipient_email']),
      subject: _decodeText(json['subject']),
      preview: contentText.isNotEmpty ? contentText : _plainText(contentHtml),
      account: _decodeText(json['account_name']),
      folder: _decodeText(json['folder']).isEmpty
          ? mailFolderInbox
          : _decodeText(json['folder']),
      labels: _asList(
        json['labels'],
      ).map((item) => item.toString()).toList(growable: false),
      sentAt: _parseDate(json['mail_date']) ?? DateTime.now(),
      read: _asBool(json['is_read']),
      starred: _asBool(json['is_starred']),
      hasAttachments: attachments.isNotEmpty,
      hasImages: images.isNotEmpty,
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
      throw const AdminMailException('Sunucu yanıtı zaman aşımına uğradı');
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
      throw const AdminMailException('Sunucu yanıtı zaman aşımına uğradı');
    } finally {
      if (closeClient) client.close();
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminMailException('Geçersiz sunucu yanıtı');
    }
    final result = decoded.map((key, value) => MapEntry(key.toString(), value));
    final error = result['error'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        error != null) {
      if (error is Map) {
        final message = error['message']?.toString();
        if (message != null && message.isNotEmpty) {
          throw AdminMailException(message);
        }
      }
      throw const AdminMailException('Mail isteği başarısız oldu');
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
                : 'http://127.0.0.1:4321',
          )
        : Uri.base;
    final uri = base.resolve(path);
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  String _decodeText(Object? value) => value?.toString() ?? '';

  String _domainFromEmail(String email) {
    final at = email.indexOf('@');
    return at == -1 ? '' : email.substring(at + 1);
  }

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

  List<dynamic> _asList(Object? value) {
    if (value is List) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return const [];
  }

  AdminMailProviderMode _providerMode(Object? value) {
    return switch (value?.toString()) {
      'api' => AdminMailProviderMode.api,
      'sendmail' => AdminMailProviderMode.sendmail,
      'oauth' => AdminMailProviderMode.oauth,
      _ => AdminMailProviderMode.smtp,
    };
  }

  AdminMailSecurity _securityFromApi(Object? value) {
    return switch (value?.toString().toLowerCase()) {
      'ssl' => AdminMailSecurity.ssl,
      'none' => AdminMailSecurity.none,
      _ => AdminMailSecurity.tls,
    };
  }

  String _securityToApi(AdminMailSecurity security) {
    return switch (security) {
      AdminMailSecurity.ssl => 'ssl',
      AdminMailSecurity.none => 'none',
      AdminMailSecurity.tls => 'starttls',
    };
  }

  AdminMailTemplateCategory _templateCategoryFromDb(Object? value) {
    return switch (value?.toString()) {
      'campaign' || 'kampanya' => AdminMailTemplateCategory.campaign,
      'info' || 'bilgi' => AdminMailTemplateCategory.info,
      'invitation' || 'davet' => AdminMailTemplateCategory.invitation,
      'order' || 'siparis' => AdminMailTemplateCategory.order,
      'quote' || 'teklif' => AdminMailTemplateCategory.quote,
      _ => AdminMailTemplateCategory.campaign,
    };
  }

  String _templateCategoryToDb(AdminMailTemplateCategory category) {
    return switch (category) {
      AdminMailTemplateCategory.campaign => 'kampanya',
      AdminMailTemplateCategory.info => 'bilgi',
      AdminMailTemplateCategory.invitation => 'davet',
      AdminMailTemplateCategory.order => 'siparis',
      AdminMailTemplateCategory.quote => 'teklif',
    };
  }

  String _templateCategoryLabel(Object? value) {
    return switch (_templateCategoryFromDb(value)) {
      AdminMailTemplateCategory.campaign => 'Kampanya',
      AdminMailTemplateCategory.info => 'Bilgi',
      AdminMailTemplateCategory.invitation => 'Davet',
      AdminMailTemplateCategory.order => 'Sipariş',
      AdminMailTemplateCategory.quote => 'Teklif',
    };
  }

  AdminContactImportSource _contactSource(Object? value) {
    return value?.toString() == 'excel'
        ? AdminContactImportSource.excel
        : AdminContactImportSource.csv;
  }

  AdminBulkMailStatus _campaignStatus(Object? value) {
    return AdminBulkMailStatus.values.firstWhere(
      (status) => status.value == value?.toString(),
      orElse: () => AdminBulkMailStatus.draft,
    );
  }

  List<Map<String, String>> _templateVariables(AdminMailTemplate template) {
    final matches = RegExp(r'\{\{([^}]+)\}\}').allMatches(
      '${template.subject} ${template.previewText} ${template.body}',
    );
    return [
      for (final token
          in matches.map((match) => match.group(1)).whereType<String>().toSet())
        {'key': token, 'label': token, 'fallback': ''},
    ];
  }

  int _variableCount(String value) {
    return RegExp(
      r'\{\{[^}]+\}\}',
    ).allMatches(value).map((match) => match.group(0)).toSet().length;
  }

  String? _nullableIntString(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || int.tryParse(trimmed) == null) return null;
    return trimmed;
  }

  String _plainText(String html) {
    return html
        .replaceAll(
          RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
