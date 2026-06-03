import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/features/auth/data/admin_auth_models.dart';
import 'package:pateeznews_admin/features/dashboard/presentation/widgets/top_bar.dart';

void main() {
  testWidgets('mobil topbar on yuz ikonunu avatarin solunda calistirir', (
    tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopBar(
            compact: true,
            session: _session,
            profile: _profile,
            onLogout: () {},
            onAccountSettings: () {},
            onOpenFrontend: () => opened = true,
          ),
        ),
      ),
    );

    final preview = find.byTooltip('Siteyi Görüntüle');
    expect(preview, findsOneWidget);
    expect(find.text('PN'), findsOneWidget);
    expect(
      tester.getTopLeft(preview).dx,
      lessThan(tester.getTopLeft(find.text('PN')).dx),
    );

    await tester.tap(preview);
    await tester.pump();

    expect(opened, isTrue);
  });
}

const _session = AdminSession(
  accessToken: 'token',
  tokenType: 'bearer',
  expiresAt: 4102444800,
  user: AdminUser(
    id: 'user-1',
    email: 'nasip@example.com',
    role: 'authenticated',
    aud: 'authenticated',
    userMetadata: {},
    appMetadata: {},
  ),
);

const _profile = AdminProfile(
  id: 'user-1',
  username: 'nasip',
  fullName: 'Pateez Nigde',
  avatarUrl: '',
  role: 'admin',
  email: 'nasip@example.com',
);
