import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/core/theme/app_theme.dart';
import 'package:pateeznews_admin/features/auth/data/admin_auth_models.dart';
import 'package:pateeznews_admin/features/sms/data/admin_sms_repository.dart';
import 'package:pateeznews_admin/features/sms/presentation/sms_bulk_models.dart';
import 'package:pateeznews_admin/features/sms/presentation/sms_contact_list_models.dart';
import 'package:pateeznews_admin/features/sms/presentation/sms_settings_models.dart';
import 'package:pateeznews_admin/features/sms/presentation/sms_template_models.dart';
import 'package:pateeznews_admin/features/sms/presentation/sms_outbox_screen.dart';

const _testUser = AdminUser(
  id: '6c1a27d3-ce8e-4c42-bec1-fc092139e3ee',
  email: 'demo.user@gmail.com',
  role: 'authenticated',
  aud: 'authenticated',
  userMetadata: {},
  appMetadata: {},
);

const _testSession = AdminSession(
  accessToken: 'test-token',
  tokenType: 'bearer',
  expiresAt: 4102444800,
  user: _testUser,
);

class _FakeAdminSmsRepository implements AdminSmsRepository {
  const _FakeAdminSmsRepository();

  @override
  Future<List<AdminSmsOutboxMessage>> fetchOutboxMessages(
    AdminSession session,
  ) async {
    return [
      AdminSmsOutboxMessage(
        id: 1,
        recipient: 'Ayse Yilmaz',
        phone: '+905320000000',
        message: 'Canlı test mesajı',
        senderLine: 'SMS hesabı',
        status: 'queued',
        createdAt: DateTime(2026, 5, 26, 10),
      ),
    ];
  }

  @override
  Future<AdminSmsOutboxMessage> sendOutboxMessage(
    AdminSession session, {
    required String phone,
    required String text,
    String recipient = '',
    String senderLine = '',
  }) async {
    return AdminSmsOutboxMessage(
      id: 2,
      recipient: recipient,
      phone: phone,
      message: text,
      senderLine: senderLine,
      status: 'queued',
      createdAt: DateTime(2026, 5, 26, 11),
    );
  }

  @override
  Future<List<AdminSmsAccount>> fetchAccounts(AdminSession session) async =>
      const [];

  @override
  Future<AdminSmsAccount> saveAccount(
    AdminSession session, {
    int? id,
    required AdminSmsAccount account,
  }) async => account;

  @override
  Future<AdminSmsAccount> updateAccount(
    AdminSession session,
    AdminSmsAccount account,
    Map<String, Object?> values,
  ) async => account;

  @override
  Future<AdminSmsAccount> checkAccount(
    AdminSession session,
    int accountId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAccounts(AdminSession session, Iterable<int> ids) async {}

  @override
  Future<List<AdminSmsTemplate>> fetchTemplates(AdminSession session) async =>
      const [];

  @override
  Future<AdminSmsTemplate> saveTemplate(
    AdminSession session, {
    int? id,
    required AdminSmsTemplate template,
  }) async => template;

  @override
  Future<AdminSmsTemplate> updateTemplate(
    AdminSession session,
    AdminSmsTemplate template,
    Map<String, Object?> values,
  ) async => template;

  @override
  Future<void> deleteTemplates(AdminSession session, Iterable<int> ids) async {}

  @override
  Future<List<AdminSmsContactList>> fetchContactLists(
    AdminSession session,
  ) async => const [];

  @override
  Future<AdminSmsContactList> saveContactList(
    AdminSession session, {
    int? id,
    required AdminSmsContactList list,
  }) async => list;

  @override
  Future<AdminSmsContactList> updateContactList(
    AdminSession session,
    AdminSmsContactList list,
    Map<String, Object?> values,
  ) async => list;

  @override
  Future<AdminSmsContactList> importContacts(
    AdminSession session,
    AdminSmsContactList list,
    String text,
  ) async => list;

  @override
  Future<void> deleteContactLists(
    AdminSession session,
    Iterable<int> ids,
  ) async {}

  @override
  Future<List<AdminSmsBulkCampaign>> fetchCampaigns(
    AdminSession session,
  ) async => const [];

  @override
  Future<AdminSmsBulkCampaign> saveCampaign(
    AdminSession session, {
    int? id,
    required AdminSmsBulkCampaign campaign,
  }) async => campaign;

  @override
  Future<AdminSmsBulkCampaign> updateCampaignAction(
    AdminSession session,
    AdminSmsBulkCampaign campaign,
    String action, {
    DateTime? scheduledAt,
  }) async => campaign;

  @override
  Future<void> deleteCampaigns(AdminSession session, Iterable<int> ids) async {}
}

void main() {
  testWidgets('SMS giden kutusu app theme ile render olur', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SmsOutboxScreen(
            session: _testSession,
            repository: _FakeAdminSmsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Giden Kutusu'), findsOneWidget);
    expect(find.text('Yeni SMS'), findsOneWidget);

    await tester.tap(find.text('Yeni SMS'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('SMS Gönder'), findsOneWidget);
    expect(find.text('Ayse Yilmaz'), findsOneWidget);
  });
}
