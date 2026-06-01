import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/frontend_font_settings.dart';
import '../features/shell/presentation/shell_screen.dart';

class PateeznewsApp extends StatefulWidget {
  const PateeznewsApp({
    super.key,
    this.accountPage,
    this.fontSettingsRepository = const FrontendFontSettingsRepository(),
  });

  final Widget? accountPage;
  final FrontendFontSettingsRepository fontSettingsRepository;

  @override
  State<PateeznewsApp> createState() => _PateeznewsAppState();
}

class _PateeznewsAppState extends State<PateeznewsApp> {
  var _fontSettings = FrontendFontSettings.empty();

  @override
  void initState() {
    super.initState();
    AppTypography.configure(_fontSettings);
    unawaited(_loadFontSettings());
  }

  Future<void> _loadFontSettings() async {
    final settings = await widget.fontSettingsRepository.fetch('tr');
    if (!mounted) return;
    setState(() => _fontSettings = settings);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(AppTheme.lightOverlay);
    return MaterialApp(
      title: 'Pateeznews',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(fontSettings: _fontSettings),
      home: ShellScreen(accountPage: widget.accountPage),
    );
  }
}
