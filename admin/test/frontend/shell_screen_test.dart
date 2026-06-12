import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/core/mock/home_mock_data.dart';
import 'package:pateeznews_admin/frontend/core/theme/app_typography.dart';
import 'package:pateeznews_admin/frontend/features/account/data/frontend_auth_repository.dart';
import 'package:pateeznews_admin/frontend/features/home/presentation/video_feed_screen.dart';
import 'package:pateeznews_admin/frontend/features/home/presentation/widgets/news_video_player.dart';
import 'package:pateeznews_admin/frontend/features/shell/data/app_shell_repository.dart';
import 'package:pateeznews_admin/frontend/features/shell/presentation/shell_screen.dart';
import 'package:pateeznews_admin/frontend/features/shell/presentation/widgets/pateez_side_menu.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

    await tester.tap(find.text('Arama'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Nöbetçi Eczane'), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_left_line), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.arrow_left_line));
    await tester.pump();

    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Hesap'));
    await _pumpShellTransition(tester);

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
    await _pumpShellTransition(tester);

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
    await _pumpShellTransition(tester);

    expect(find.text('Anasayfa'), findsOneWidget);

    await tester.tap(find.text('Hesap'));
    await _pumpShellTransition(tester);

    await tester.ensureVisible(find.text('Üye ol'));
    await _pumpShellTransition(tester);
    await tester.tap(find.text('Üye ol'));
    await _pumpShellTransition(tester);

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
    await _pumpShellTransition(tester);

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
    await _pumpShellTransition(tester);

    await tester.tap(find.text('Çıkış yap'));
    await _pumpShellTransition(tester);

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
    await _pumpShellTransition(tester);

    await tester.tap(find.text('Admin panel'));
    await tester.pump();

    expect(opened, isTrue);
    expect(find.text('Admin panel'), findsNothing);
  });

  testWidgets('video sekmesi tam ekran acar ve kapatinca ana sayfayi yeniler', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    var refreshCount = 0;

    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: ShellScreen(
          onRefreshHome: () async => refreshCount++,
          homeFeedItems: [
            _videoArticle(
              id: 'old-video',
              title: 'Daha eski video',
              publishedAt: DateTime.utc(2026, 6, 7, 9),
            ),
            _videoArticle(
              id: 'new-video',
              title: 'En yeni video',
              publishedAt: DateTime.utc(2026, 6, 8, 9),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.text('Video'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.bySemanticsLabel('Tam ekrandan çık'), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_left_line), findsOneWidget);
    expect(find.text('En yeni video'), findsOneWidget);
    expect(find.text('Anasayfa'), findsNothing);
    final player = tester.widget<NewsVideoPlayer>(find.byType(NewsVideoPlayer));
    expect(player.autoPlayWhenReady, isTrue);
    expect(player.showFullscreenButton, isFalse);
    final detectorKeys = tester
        .widgetList<VisibilityDetector>(find.byType(VisibilityDetector))
        .map((detector) => detector.key)
        .toList(growable: false);
    expect(detectorKeys.toSet(), hasLength(detectorKeys.length));
    expect(
      detectorKeys.whereType<ValueKey<String>>().any(
        (key) => key.value.contains('fullscreen-feed'),
      ),
      isTrue,
    );

    await tester.tap(find.bySemanticsLabel('Tam ekrandan çık'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    expect(find.text('Anasayfa'), findsOneWidget);
    expect(find.bySemanticsLabel('Tam ekrandan çık'), findsNothing);
    expect(find.text('En yeni'), findsOneWidget);
    expect(refreshCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    VisibilityDetectorController.instance.notifyNow();
    await tester.pump(const Duration(milliseconds: 60));
  });

  test('video feed haber icindeki tum video urllerini item yapar', () {
    final article = _videoArticle(
      id: 'multi-video',
      title: 'Coklu video',
      publishedAt: DateTime.utc(2026, 6, 8, 9),
      videoUrl: 'https://example.invalid/primary.mp4',
      videoUrls: const [
        'https://example.invalid/primary.mp4',
        'https://www.youtube.com/watch?v=abcDEF12345',
        'https://youtube.com/shorts/shortID1234',
        'http://127.0.0.1:4321/api/storage/file/video/test.mov',
      ],
      videoThumbUrls: const [
        'https://example.invalid/primary-poster.webp',
        '',
        '',
        'http://127.0.0.1:4321/local-upload/video/test_thumb.webp',
      ],
    );

    final items = videoFeedItemsFromArticles(
      articles: [article],
      shellSettings: const AppShellSettings.empty(),
      navigationItems: const [],
    );

    expect(items.map((item) => item.url), [
      'https://example.invalid/primary.mp4',
      'https://www.youtube.com/watch?v=abcDEF12345',
      'https://youtube.com/shorts/shortID1234',
      'http://127.0.0.1:4321/api/storage/file/video/test.mov',
    ]);
    expect(items.map((item) => item.poster), [
      'https://example.invalid/primary-poster.webp',
      'https://img.youtube.com/vi/abcDEF12345/hqdefault.jpg',
      'https://img.youtube.com/vi/shortID1234/hqdefault.jpg',
      'http://127.0.0.1:4321/local-upload/video/test_thumb.webp',
    ]);
    expect(
      items.any(
        (item) => item.poster == 'https://example.invalid/multi-video.jpg',
      ),
      isFalse,
    );
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
    await _pumpShellTransition(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Kullanıcı adı veya e-posta'),
      '@nasip',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Şifre'), '123456');
    await tester.tap(find.text('Giriş yap').last);
    await _pumpShellTransition(tester);

    expect(capturedIdentifier, '@nasip');
    expect(capturedPassword, '123456');
    expect(find.text('Hesabına giriş yap'), findsNothing);
    expect(find.text('NG'), findsOneWidget);
  });

  testWidgets('yan menu sol menu kokunu en ustte gosterir', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ShellScreen(shellData: _shellData())),
    );
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.byIcon(Symbols.menu_rounded));
    await tester.pump(const Duration(milliseconds: 360));

    final sideMenu = find.byType(PateezSideMenu);
    final root = find.descendant(of: sideMenu, matching: find.text('Niğde'));
    final district = find.descendant(of: sideMenu, matching: find.text('Bor'));
    final category = find.descendant(
      of: sideMenu,
      matching: find.text('Anketler'),
    );
    final topMenuItem = find.descendant(
      of: sideMenu,
      matching: find.text('Etkinlik'),
    );
    final trend = find.descendant(
      of: sideMenu,
      matching: find.text('Haftanın Trendleri'),
    );
    final secondRoot = find.descendant(
      of: sideMenu,
      matching: find.text('Nevşehir'),
    );
    final toggleIcon = find.descendant(
      of: sideMenu,
      matching: find.byIcon(Symbols.keyboard_arrow_down_rounded),
    );

    expect(
      find.descendant(of: sideMenu, matching: find.text('Ana Sayfa')),
      findsNothing,
    );
    expect(
      find.descendant(of: sideMenu, matching: find.text('Etkinlik')),
      findsNothing,
    );
    expect(
      find.descendant(of: sideMenu, matching: find.text('Navbar')),
      findsNothing,
    );
    expect(
      find.descendant(of: sideMenu, matching: find.text('Sol menü')),
      findsNothing,
    );
    expect(
      find.descendant(of: sideMenu, matching: find.text('Kısa yollar')),
      findsNothing,
    );
    expect(root, findsOneWidget);
    expect(secondRoot, findsNothing);
    expect(topMenuItem, findsNothing);
    expect(district, findsOneWidget);
    expect(category, findsOneWidget);
    expect(trend, findsOneWidget);
    expect(
      find.descendant(of: sideMenu, matching: find.text('İlçeler')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sideMenu, matching: find.text('Kategoriler')),
      findsNothing,
    );
    expect(
      find.descendant(of: sideMenu, matching: find.text('Trendler')),
      findsOneWidget,
    );

    await tester.tap(toggleIcon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(secondRoot, findsNothing);
    expect(topMenuItem, findsNothing);
    expect(district, findsNothing);
    expect(category, findsNothing);
    expect(trend, findsNothing);

    await tester.tap(toggleIcon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(topMenuItem, findsNothing);
    expect(district, findsOneWidget);
    expect(category, findsOneWidget);
    expect(trend, findsOneWidget);
    expect(
      find.descendant(of: sideMenu, matching: find.text('İlçeler')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sideMenu, matching: find.text('Kategoriler')),
      findsNothing,
    );
    expect(
      find.descendant(of: sideMenu, matching: find.text('Trendler')),
      findsOneWidget,
    );

    final rootTop = tester.getTopLeft(root).dy;
    final borTop = tester.getTopLeft(district).dy;
    final categoryTop = tester.getTopLeft(category).dy;
    final trendTop = tester.getTopLeft(trend).dy;
    expect(rootTop, lessThan(categoryTop));
    expect(categoryTop, lessThan(borTop));
    expect(borTop, lessThan(trendTop));

    await tester.tap(root);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(root, findsOneWidget);
    expect(secondRoot, findsOneWidget);
    expect(topMenuItem, findsNothing);
    expect(district, findsNothing);
    expect(category, findsNothing);
    expect(trend, findsNothing);

    await tester.tap(root);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(secondRoot, findsNothing);
    expect(topMenuItem, findsNothing);
    expect(district, findsOneWidget);
    expect(category, findsOneWidget);
    expect(trend, findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('yan menu kok basligini admin verisinden okur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShellScreen(shellData: _shellData(rootLabel: 'Nevşehir')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.byIcon(Symbols.menu_rounded));
    await tester.pump(const Duration(milliseconds: 360));

    final sideMenu = find.byType(PateezSideMenu);
    expect(
      find.descendant(of: sideMenu, matching: find.text('Nevşehir')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sideMenu, matching: find.text('Niğde')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('yan menu hakkimizda linki kurumsal sayfalari acar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShellScreen(
          shellData: _shellData(
            pages: const [
              AppShellPage(
                id: 'page-about',
                title: 'Hakkımızda',
                slug: 'hakkimizda',
                categoryId: 'side-root',
                category: 'Niğde',
                pageType: 'custom',
                menuOrder: 1,
                contentPlain:
                    'Pattez.com Niğde haberlerini anlaşılır şekilde sunar.',
                metaDescription:
                    'Pattez.com Niğde merkezli haber platformudur.',
                canonicalUrl: 'https://www.pateez.com/kurumsal/hakkimizda',
              ),
              AppShellPage(
                id: 'page-press',
                title: 'Basın Odası',
                slug: 'basin-odasi',
                categoryId: 'side-root',
                category: 'Niğde',
                pageType: 'custom',
                menuOrder: 2,
                contentPlain:
                    'Basın kiti ve duyurular bu sayfadan takip edilir.',
                metaDescription:
                    'Basın talepleri için bizimle iletişime geçin.',
                canonicalUrl: 'https://www.pateez.com/kurumsal/basin-odasi',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.byIcon(Symbols.menu_rounded));
    await tester.pump(const Duration(milliseconds: 360));

    final sideMenu = find.byType(PateezSideMenu);
    final aboutLink = find.descendant(
      of: sideMenu,
      matching: find.text('Hakkımızda'),
    );
    expect(aboutLink, findsOneWidget);

    await tester.tap(aboutLink);
    await _pumpShellTransition(tester);

    expect(find.text('Basın Odası'), findsOneWidget);
    expect(
      find.text('Pattez.com Niğde merkezli haber platformudur.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Basın Odası'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.text('Basın kiti ve duyurular bu sayfadan takip edilir.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('yan menudeki video kategorisi tam ekran video akisini acar', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;

    await tester.pumpWidget(
      MaterialApp(
        home: ShellScreen(
          shellData: _shellData(),
          homeFeedItems: [
            _videoArticle(
              id: 'side-video',
              title: 'Yan menü videosu',
              publishedAt: DateTime.utc(2026, 6, 10, 9),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.byIcon(Symbols.menu_rounded));
    await tester.pump(const Duration(milliseconds: 360));

    final sideMenu = find.byType(PateezSideMenu);
    final sideMenuVideo = find.descendant(
      of: sideMenu,
      matching: find.text('Video'),
    );
    expect(sideMenuVideo, findsWidgets);

    await tester.tap(sideMenuVideo.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.bySemanticsLabel('Tam ekrandan çık'), findsOneWidget);
    expect(find.text('Yan menü videosu'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Tam ekrandan çık'));
    VisibilityDetectorController.instance.notifyNow();
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 70));
  });
}

Future<void> _pumpShellTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 720));
  await tester.pump();
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
      coverUrl: '',
      role: role,
      email: 'nasip@example.com',
    ),
  );
}

NewsArticle _videoArticle({
  required String id,
  required String title,
  required DateTime publishedAt,
  String? videoUrl,
  List<String> videoUrls = const [],
  List<String> videoThumbUrls = const [],
}) {
  return NewsArticle(
    id: id,
    author: const NewsAuthor(name: 'Pateeznews', avatarUrl: ''),
    region: 'Niğde',
    category: 'Gündem',
    title: title,
    summary: 'Video özeti',
    imageUrl: 'https://example.invalid/$id.jpg',
    publishedAt: publishedAt,
    readMinutes: 1,
    likes: 10,
    dislikes: 1,
    comments: 2,
    shares: 3,
    videoUrl: videoUrl ?? 'https://example.invalid/$id.mp4',
    videoUrls: videoUrls,
    videoThumbUrls: videoThumbUrls,
  );
}

AppShellData _shellData({
  String rootLabel = 'Niğde',
  List<AppShellPage> pages = const [],
}) {
  return AppShellData(
    languageCode: 'tr',
    siteSettings: const AppShellSettings(
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
        label: rootLabel,
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
        id: 'side-video',
        menuId: 'side',
        menuCode: 'sidebar_main',
        parentId: 'side-root',
        label: 'Video',
        type: 'category',
        value: 'video',
        icon: 'video',
        orderIndex: 3,
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
      AppShellNavigationItem(
        id: 'side-nevsehir',
        menuId: 'side',
        menuCode: 'sidebar_main',
        parentId: null,
        label: 'Nevşehir',
        type: 'dropdown',
        value: '',
        icon: '',
        orderIndex: 4,
        isActive: true,
        languageCode: 'tr',
      ),
    ],
    pages: pages,
  );
}
