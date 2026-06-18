import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/pateeznews_admin_app.dart';
import 'firebase_options.dart';
import 'frontend/app/pateeznews_app.dart';
import 'shared/branding/desktop_window_title.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  if (!kIsWeb && _isMobileTarget(defaultTargetPlatform)) {
    FirebaseMessaging.onBackgroundMessage(
      pateezFirebaseMessagingBackgroundHandler,
    );
  }
  await _initializeSupabase();
  if (!kIsWeb && _isMobileTarget(defaultTargetPlatform)) {
    runApp(const PateeznewsApp());
    return;
  }

  // Masaüstü pencere başlığını genel ayarlardaki site adına bağla (macOS).
  DesktopWindowTitle.start();
  runApp(const PateeznewsAdminApp());
}

bool _isMobileTarget(TargetPlatform platform) {
  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

@pragma('vm:entry-point')
Future<void> pateezFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await _initializeFirebase();
}

Future<void> _initializeFirebase() async {
  if (!kIsWeb && !_isMobileTarget(defaultTargetPlatform)) return;
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    debugPrint('Firebase initialization skipped: $error');
  }
}

Future<void> _initializeSupabase() async {
  const definedSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const definedSupabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  const fallbackSupabaseUrl = 'https://debgdvrkcqhtwdyrqves.supabase.co';
  const fallbackSupabasePublishableKey =
      'sb_publishable_7Pg0aLwv26Ja4w92KeHChg_zW6DqoQB';
  final supabaseUrl = definedSupabaseUrl.isNotEmpty
      ? definedSupabaseUrl
      : fallbackSupabaseUrl;
  final supabasePublishableKey = definedSupabasePublishableKey.isNotEmpty
      ? definedSupabasePublishableKey
      : fallbackSupabasePublishableKey;
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
}
