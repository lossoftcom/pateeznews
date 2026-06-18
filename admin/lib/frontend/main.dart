import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/pateeznews_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://debgdvrkcqhtwdyrqves.supabase.co',
    anonKey: 'sb_publishable_7Pg0aLwv26Ja4w92KeHChg_zW6DqoQB',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  runApp(const PateeznewsApp());
}
