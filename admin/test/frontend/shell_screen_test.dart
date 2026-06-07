import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/core/theme/app_typography.dart';
import 'package:pateeznews_admin/frontend/features/account/data/frontend_auth_repository.dart';
import 'package:pateeznews_admin/frontend/features/shell/data/app_shell_repository.dart';
import 'package:pateeznews_admin/frontend/features/shell/presentation/shell_screen.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

void main() {
  testWidgets('hesap sekmesi verilmis admin yuzeyini tiklayinca acar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ShellScreen(accountPage: Text('Admin giris yuzeyi')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Admin giris yuzeyi'), findsNothing);
    expect(find.text('Anasayfa'), findsOneWidget);

    expect(find.text('Arama'), findsOneWidget);

    await tester.tap(find.text('Hesap'));
    await tester.pumpAndSettle();

    expect(find.text('Admin giris yuzeyi'), findsOneWidget);
    expect(find.text('Anasayfa'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('hesap sekmesi varsayilan giris ve kayit tasarimini acar', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ShellScreen()));
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.text('Hesap'));
    await tester.pumpAndSettle();

    expect(find.text('Hesabına giriş yap'), findsOneWidget);
    expect(find.text('Google ile giriş'), findsOneWidget);
    expect(find.text('Apple ile giriş'), findsOneWidget);
    expect(find.text('Kullanıcı adı veya e-posta'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
    expect(find.text('Giriş yap'), findsOneWidget);
    expect(find.text('Üye ol'), findsOneWidget);
    expect(find.text('Anasayfa'), findsNothing);
    expect(find.byIcon(Symbols.arrow_left_line), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.arrow_left_line));
    await tester.pumpAndSettle();

    expect(find.text('Anasayfa'), findsOneWidget);

    await tester.tap(find.text('Hesap'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Üye ol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Üye ol'));
    await tester.pumpAndSettle();

    expect(find.text('Hesabını oluştur'), findsOneWidget);
    expect(find.text('Google ile kayıt ol'), findsOneWidget);
    expect(find.text('Apple ile kayıt ol'), findsOneWidget);
    expect(find.text('Ad soyad'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Şifre tekrar'), findsOneWidget);
  });

  testWidgets('giris sonrasi bottom nav avatar menusu acar ve cikis yapar', (
    tester,
  ) async {
    var signedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ShellScreen(
          authState: _authState(role: 'admin'),
          onSignOut: () async => signedOut = true,
          onOpenAdminPanel: () async {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Hesap'), findsOneWidget);
    expect(find.text('NG'), findsOneWidget);

    await tester.tap(find.text('Hesap'));
    await tester.pumpAndSettle();

    expect(find.text('Admin panel'), findsOneWidget);
    expect(find.text('Profilim'), findsOneWidget);
    expect(find.text('Çıkış yap'), findsOneWidget);

    final adminPanelText = tester.widget<Text>(find.text('Admin panel'));
    expect(
      adminPanelText.style?.fontFamily,
      AppTypography.mobileMenuLabel.fontFamily,
    );
    expect(
      adminPanelText.style?.fontSize,
      AppTypography.mobileMenuLabel.fontSize,
    );
    expect(
      adminPanelText.style?.fontWeight,
      AppTypography.mobileMenuLabel.fontWeight,
    );

    await tester.tapAt(const Offset(12, 12));
    await tester.pump();

    expect(find.text('Admin panel'), findsNothing);
    expect(find.text('Profilim'), findsNothing);
    expect(find.text('Çıkış yap'), findsNothing);

    await tester.tap(find.text('Hesap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Çıkış yap'));
    await tester.pumpAndSettle();

    expect(signedOut, isTrue);
  });

  testWidgets('admin panel satiri flutter admin callbackini calistirir', (
    tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ShellScreen(
          authState: _authState(role: 'admin'),
          onOpenAdminPanel: () async => opened = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.text('Hesap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Admin panel'));
    await tester.pump();

    expect(opened, isTrue);
    expect(find.text('Admin panel'), findsNothing);
  });

  testWidgets('hesap girisi basarili olunca route kapanir ve avatar gorunur', (
    tester,
  ) async {
    String? capturedIdentifier;
    String? capturedPassword;
    FrontendAuthState? authState;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: ShellScreen(
              authState: authState,
              onSignIn: ({required identifier, required password}) async {
                capturedIdentifier = identifier;
                capturedPassword = password;
                final nextState = _authState();
                setState(() => authState = nextState);
                return nextState;
              },
            ),
          );
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.text('Hesap'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Kullanıcı adı veya e-posta'),
      '@nasip',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Şifre'), '123456');
    await tester.tap(find.text('Giriş yap').last);
    await tester.pumpAndSettle();

    expect(capturedIdentifier, '@nasip');
    expect(capturedPassword, '123456');
    expect(find.text('Hesabına giriş yap'), findsNothing);
    expect(find.text('NG'), findsOneWidget);
  });

  testWidgets('yan menu canlı navbar ve sol menu verisini gosterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ShellScreen(shellData: _shellData())),
    );
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.byIcon(Symbols.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Navbar'), findsNothing);
    expect(find.text('Etkinlik'), findsOneWidget);
    expect(find.text('Sol menü'), findsNothing);
    expect(find.text('Niğde'), findsOneWidget);
    expect(find.text('Bor'), findsOneWidget);
    expect(find.text('Kısa yollar'), findsNothing);
    expect(find.text('İlçeler'), findsOneWidget);
    expect(find.text('Kategoriler'), findsOneWidget);
    expect(find.text('Trendler'), findsOneWidget);
    expect(find.text('Anketler'), findsOneWidget);
    expect(find.text('Haftanın Trendleri'), findsOneWidget);

    final borTop = tester.getTopLeft(find.text('Bor')).dy;
    final categoryTop = tester.getTopLeft(find.text('Anketler')).dy;
    final trendTop = tester.getTopLeft(find.text('Haftanın Trendleri')).dy;
    expect(borTop, lessThan(categoryTop));
    expect(categoryTop, lessThan(trendTop));
  });
}

FrontendAuthState _authState({String role = 'member'}) {
  return FrontendAuthState(
    session: const FrontendAuthSession(
      accessToken: 'token',
      tokenType: 'bearer',
      expiresAt: 4102444800,
      user: FrontendAuthUser(
        id: 'user-1',
        email: 'nasip@example.com',
        userMetadata: {},
      ),
    ),
    profile: FrontendProfile(
      id: 'user-1',
      username: 'nasip',
      fullName: 'Nasip Gündoğdu',
      avatarUrl: '',
      role: role,
      email: 'nasip@example.com',
    ),
  );
}

AppShellData _shellData() {
  return const AppShellData(
    languageCode: 'tr',
    siteSettings: AppShellSettings(
      siteName: 'Pateez.com',
      logoUrl: '',
      darkLogoUrl: '',
      faviconUrl: '',
    ),
    navigationItems: [
      AppShellNavigationItem(
        id: 'top-home',
        menuId: 'top',
        menuCode: 'top_navbar',
        parentId: null,
        label: 'Ana Sayfa',
        type: 'link',
        value: '/',
        icon: 'home',
        orderIndex: 0,
        isActive: true,
        languageCode: 'tr',
      ),
      AppShellNavigationItem(
        id: 'top-event',
        menuId: 'top',
        menuCode: 'top_navbar',
        parentId: null,
        label: 'Etkinlik',
        type: 'category',
        value: 'etkinlik',
        icon: 'calendar_month',
        orderIndex: 1,
        isActive: true,
        languageCode: 'tr',
      ),
      AppShellNavigationItem(
        id: 'side-root',
        menuId: 'side',
        menuCode: 'sidebar_main',
        parentId: null,
        label: 'Niğde',
        type: 'dropdown',
        value: '',
        icon: 'location_on',
        orderIndex: 0,
        isActive: true,
        languageCode: 'tr',
      ),
      AppShellNavigationItem(
        id: 'side-bor',
        menuId: 'side',
        menuCode: 'sidebar_main',
        parentId: 'side-root',
        label: 'Bor',
        type: 'district',
        value: '',
        icon: '',
        orderIndex: 1,
        isActive: true,
        languageCode: 'tr',
      ),
      AppShellNavigationItem(
        id: 'side-poll',
        menuId: 'side',
        menuCode: 'sidebar_main',
        parentId: 'side-root',
        label: 'Anketler',
        type: 'category',
        value: 'anketler',
        icon: 'poll',
        orderIndex: 2,
        isActive: true,
        languageCode: 'tr',
      ),
      AppShellNavigationItem(
        id: 'side-trend',
        menuId: 'side',
        menuCode: 'sidebar_main',
        parentId: 'side-root',
        label: 'Haftanın Trendleri',
        type: 'trends',
        value: 'weekly_trends',
        icon: 'trending_up',
        orderIndex: 1,
        isActive: true,
        languageCode: 'tr',
      ),
    ],
  );
}
