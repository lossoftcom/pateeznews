import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/pateeznews_admin_app.dart';
import 'frontend/app/pateeznews_app.dart';
import 'shared/branding/desktop_window_title.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

Future<void> _initializeSupabase() async {
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
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
