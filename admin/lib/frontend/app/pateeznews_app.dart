import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../features/shell/presentation/shell_screen.dart';

class PateeznewsApp extends StatelessWidget {
  const PateeznewsApp({super.key, this.accountPage});

  final Widget? accountPage;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(AppTheme.lightOverlay);
    return MaterialApp(
      title: 'Pateeznews',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: ShellScreen(accountPage: accountPage),
    );
  }
}
