#!/usr/bin/env node
import fs from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';
import { delimiter, resolve } from 'node:path';
import { mergedCloudflareEnv } from './env-utils.mjs';

const cwd = process.cwd();
const env = withLocalBinPath(mergedCloudflareEnv(cwd), cwd);
const adminCwd = `${cwd}/admin`;
env.XDG_CONFIG_HOME = ensureLocalFlutterConfig(adminCwd);
const supabaseUrl = env.PUBLIC_SUPABASE_URL || env.SUPABASE_URL;
const publishableKey = env.PUBLIC_SUPABASE_PUBLISHABLE_KEY || env.SUPABASE_PUBLISHABLE_KEY;

if (!supabaseUrl || !publishableKey) {
  console.error('Missing Supabase public env values: PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_PUBLISHABLE_KEY are required for admin web build.');
  process.exit(1);
}

if (shouldRunPubGet(adminCwd)) {
  const pubGet = spawnSync(commandForPlatform('flutter'), argsForPlatform('flutter', ['pub', 'get']), {
    cwd: adminCwd,
    env,
    stdio: 'inherit',
  });
  if (pubGet.status !== 0) {
    process.exit(pubGet.status ?? 1);
  }
}

applyMediaLibrarySelectionPatch(adminCwd);
applyAutomaticNewsPreviewPatch(adminCwd);

const flutterArgs = [
  'build',
  'web',
  '--release',
  '--no-pub',
  '--no-wasm-dry-run',
  '--no-web-resources-cdn',
  '--base-href=/admin/',
  `--dart-define=SUPABASE_URL=${supabaseUrl}`,
  `--dart-define=SUPABASE_PUBLISHABLE_KEY=${publishableKey}`,
];

const child = spawn(commandForPlatform('flutter'), argsForPlatform('flutter', flutterArgs), {
  cwd: adminCwd,
  env,
  stdio: 'inherit',
});

child.on('exit', (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 0);
});

child.on('error', (error) => {
  console.error(error.message);
  process.exit(1);
});

function applyAutomaticNewsPreviewPatch(projectDir) {
  const file = `${projectDir}/lib/features/automatic_news/presentation/automatic_news_screen.dart`;
  if (!fs.existsSync(file)) return;

  let source = fs.readFileSync(file, 'utf8');
  let next = source;

  if (!next.includes("import 'package:url_launcher/url_launcher.dart';")) {
    next = next.replace(
      "import 'package:share_plus/share_plus.dart' hide XFile;\n",
      "import 'package:share_plus/share_plus.dart' hide XFile;\nimport 'package:url_launcher/url_launcher.dart';\n",
    );
  }

  next = next.replace(
    "                      fit: BoxFit.cover,\n                      memCacheWidth: compact ? 720 : 920,",
    "                      fit: BoxFit.contain,\n                      memCacheWidth: compact ? 720 : 920,",
  );

  next = next.replace(
    `          _PreviewInfoBlock(
            label: hasVideo ? 'Medya / Video Linki' : 'Medya Linki',
            value: mediaUrl,
            compactValue: _compactUrl(mediaUrl),
          ),`,
    `          _PreviewLinkInfoBlock(
            label: hasVideo ? 'Medya / Video Linki' : 'Medya Linki',
            value: mediaUrl,
          ),
          if (draft.sourceUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PreviewLinkInfoBlock(
              label: 'Haberin Tam Linki',
              value: draft.sourceUrl,
            ),
          ],`,
  );

  next = next.replace(
    `          _PreviewInfoBlock(
            label: 'Haber Linki',
            value: draft.sourceUrl,
            compactValue: _compactUrl(draft.sourceUrl),
          ),`,
    `          _PreviewLinkInfoBlock(
            label: 'Haber Linki',
            value: draft.sourceUrl,
          ),`,
  );

  const headersFunction = String.raw`Map<String, String>? _automaticNewsImageHttpHeaders(
  Map<String, String> imageRequestHeaders,
) {
  return kIsWeb && imageRequestHeaders.isNotEmpty ? imageRequestHeaders : null;
}`;
  if (next.includes(headersFunction) && !next.includes('Future<void> _openPreviewExternalUrl(String value)')) {
    next = next.replace(
      headersFunction,
      String.raw`Map<String, String>? _automaticNewsImageHttpHeaders(
  Map<String, String> imageRequestHeaders,
) {
  return kIsWeb && imageRequestHeaders.isNotEmpty ? imageRequestHeaders : null;
}

Future<void> _openPreviewExternalUrl(String value) async {
  final raw = value.trim();
  if (raw.isEmpty) return;
  final uri = Uri.tryParse(raw);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
  await launchUrl(uri, webOnlyWindowName: '_blank');
}`,
    );
  }

  if (!next.includes('class _PreviewLinkInfoBlock extends StatelessWidget')) {
    next = next.replace(
      'class _PreviewInfoBlock extends StatelessWidget {',
      String.raw`class _PreviewLinkInfoBlock extends StatelessWidget {
  const _PreviewLinkInfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final displayValue = _readableText(value);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_openPreviewExternalUrl(value)),
              child: Text(
                displayValue,
                softWrap: true,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.actionRed,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  height: 1.35,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.actionRed.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewInfoBlock extends StatelessWidget {`,
    );
  }

  if (next !== source) {
    fs.writeFileSync(file, next);
    console.log('Applied automatic news preview modal patch.');
  }
}

function applyMediaLibrarySelectionPatch(projectDir) {
  const file = `${projectDir}/lib/shared/widgets/media_library_dialog.dart`;
  if (!fs.existsSync(file)) return;

  let source = fs.readFileSync(file, 'utf8');
  let next = source;

  if (!next.includes("import 'dart:math' as math;")) {
    next = next.replace(
      "import 'dart:async';\n",
      "import 'dart:async';\nimport 'dart:math' as math;\n",
    );
  }

  if (!next.includes("  String? _selectionAnchorSrc;")) {
    next = next.replace(
      "  final _searchTerm = ValueNotifier<String>('');\n  String? _lastSelectedSrc;",
      "  final _searchTerm = ValueNotifier<String>('');\n  String? _lastSelectedSrc;\n  String? _selectionAnchorSrc;",
    );
  }

  next = next.replace(
    "  void initState() {\n    super.initState();\n    _loadFiles();\n  }",
    "  void initState() {\n    super.initState();\n    HardwareKeyboard.instance.addHandler(_handleKeyboardSelection);\n    _loadFiles();\n  }",
  );

  next = next.replace(
    "  void dispose() {\n    _selectedSrcs.dispose();\n    _searchTerm.dispose();\n    super.dispose();\n  }",
    "  void dispose() {\n    HardwareKeyboard.instance.removeHandler(_handleKeyboardSelection);\n    _selectedSrcs.dispose();\n    _searchTerm.dispose();\n    super.dispose();\n  }",
  );

  next = next.replace(
    "          final next = Set<String>.of(_selectedSrcs.value)..remove(file.src);\n          _selectedSrcs.value = next;\n          _lastSelectedSrc = next.lastOrNull;",
    "          final next = Set<String>.of(_selectedSrcs.value)..remove(file.src);\n          _selectedSrcs.value = next;\n          if (_lastSelectedSrc == file.src) _lastSelectedSrc = next.lastOrNull;\n          if (_selectionAnchorSrc == file.src) _selectionAnchorSrc = next.lastOrNull;",
  );

  next = next.replace(
    "  void _clearSelection() {\n    if (_selectedSrcs.value.isEmpty) return;\n    _lastSelectedSrc = null;\n    _selectedSrcs.value = <String>{};\n  }",
    "  void _clearSelection() {\n    if (_selectedSrcs.value.isEmpty) return;\n    _lastSelectedSrc = null;\n    _selectionAnchorSrc = null;\n    _selectedSrcs.value = <String>{};\n  }",
  );

  const oldToggle = String.raw`  void _toggleSelection(MediaItem file) {
    final selected = Set<String>.of(_selectedSrcs.value);
    if (HardwareKeyboard.instance.isShiftPressed) {
      if (!selected.remove(file.src)) {
        selected.add(file.src);
        _lastSelectedSrc = file.src;
      } else if (_lastSelectedSrc == file.src) {
        _lastSelectedSrc = selected.lastOrNull;
      }
    } else {
      selected
        ..clear()
        ..add(file.src);
      _lastSelectedSrc = file.src;
    }
    _selectedSrcs.value = selected;
  }`;

  const newToggle = String.raw`  bool get _isTextInputFocused {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    return focusedContext != null && focusedContext.widget is EditableText;
  }

  void _selectAllFiltered() {
    final filtered = _filteredFiles;
    if (filtered.isEmpty) return;
    _selectedSrcs.value = {for (final file in filtered) file.src};
    _selectionAnchorSrc = filtered.first.src;
    _lastSelectedSrc = filtered.last.src;
  }

  bool _handleKeyboardSelection(KeyEvent event) {
    if (event is! KeyDownEvent || _isTextInputFocused) return false;
    final selectAll = event.logicalKey == LogicalKeyboardKey.keyA &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed);
    if (!selectAll) return false;
    _selectAllFiltered();
    return true;
  }

  void _toggleSelection(MediaItem file) {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = Set<String>.of(_selectedSrcs.value);
    final shiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final togglePressed = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (shiftPressed) {
      final filtered = _filteredFiles;
      final anchorSrc = _selectionAnchorSrc ?? _lastSelectedSrc;
      final anchorIndex = filtered.indexWhere((item) => item.src == anchorSrc);
      final currentIndex = filtered.indexWhere((item) => item.src == file.src);
      if (anchorIndex >= 0 && currentIndex >= 0) {
        final start = math.min(anchorIndex, currentIndex);
        final end = math.max(anchorIndex, currentIndex);
        for (var index = start; index <= end; index += 1) {
          selected.add(filtered[index].src);
        }
      } else {
        selected.add(file.src);
      }
      _selectionAnchorSrc ??= file.src;
      _lastSelectedSrc = file.src;
    } else if (togglePressed) {
      if (selected.contains(file.src)) {
        selected.remove(file.src);
        if (_lastSelectedSrc == file.src) _lastSelectedSrc = selected.lastOrNull;
      } else {
        selected.add(file.src);
        _lastSelectedSrc = file.src;
      }
      _selectionAnchorSrc = file.src;
    } else {
      selected
        ..clear()
        ..add(file.src);
      _lastSelectedSrc = file.src;
      _selectionAnchorSrc = file.src;
    }
    _selectedSrcs.value = selected;
  }`;

  if (next.includes(oldToggle) && !next.includes('bool _handleKeyboardSelection(KeyEvent event)')) {
    next = next.replace(oldToggle, newToggle);
  }

  if (next !== source) {
    fs.writeFileSync(file, next);
    console.log('Applied admin media library keyboard selection patch.');
  }
}

function shouldRunPubGet(projectDir) {
  const packageConfig = `${projectDir}/.dart_tool/package_config.json`;
  const pubspec = `${projectDir}/pubspec.yaml`;
  const lockfile = `${projectDir}/pubspec.lock`;
  if (!fs.existsSync(packageConfig)) return true;

  const packageConfigTime = fs.statSync(packageConfig).mtimeMs;
  for (const file of [pubspec, lockfile]) {
    if (fs.existsSync(file) && fs.statSync(file).mtimeMs > packageConfigTime) {
      return true;
    }
  }
  return false;
}

function ensureLocalFlutterConfig(projectDir) {
  const configHome = `${projectDir}/.dart_tool/flutter_config`;
  const flutterConfigDir = `${configHome}/flutter`;
  const settingsFile = `${flutterConfigDir}/settings`;
  fs.mkdirSync(flutterConfigDir, { recursive: true });
  fs.writeFileSync(settingsFile, `${JSON.stringify({
    'enable-swift-package-manager': true,
    'cli-animations': false,
  }, null, 2)}\n`);
  return configHome;
}

function withLocalBinPath(env, cwd) {
  const nextEnv = { ...env };
  const key = Object.keys(nextEnv).find((name) => name.toLowerCase() === 'path') || 'PATH';
  const localBin = resolve(cwd, 'node_modules', '.bin');
  nextEnv[key] = nextEnv[key] ? `${localBin}${delimiter}${nextEnv[key]}` : localBin;
  return nextEnv;
}

function commandForPlatform(command) {
  return process.platform === 'win32'
    ? process.env.ComSpec || 'cmd.exe'
    : command;
}

function argsForPlatform(command, args) {
  if (process.platform !== 'win32') return args;
  return [
    '/d',
    '/s',
    '/c',
    [command, ...args].map(quoteWindowsArg).join(' '),
  ];
}

function quoteWindowsArg(value) {
  const arg = String(value);
  if (!/[\s"&|<>^]/.test(arg)) return arg;
  return `"${arg.replace(/"/g, '\\"')}"`;
}
