import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'web_stories_editor_types.dart';

/// The vendored editor uses ES module scripts which Chromium/WebView2 refuses to
/// load over `file://`, so on native platforms we serve the bundle over a local
/// http server and point the webview at it.
const int _localhostPort = 8765;
InAppLocalhostServer? _localhostServer;

/// Native (Android/iOS/macOS/Windows) host for the Google Web Stories editor.
class WebStoriesEditor extends StatefulWidget {
  const WebStoriesEditor({
    super.key,
    required this.initialStory,
    required this.onSave,
    required this.controller,
  });

  final Map<String, dynamic> initialStory;
  final ValueChanged<WebStorySaveResult> onSave;
  final WebStoriesEditorController controller;

  @override
  State<WebStoriesEditor> createState() => _WebStoriesEditorState();
}

class _WebStoriesEditorState extends State<WebStoriesEditor>
    implements WebStoriesEditorBridge {
  InAppWebViewController? _controller;
  bool _serverReady = false;
  bool _ready = false;
  bool _loadSent = false;
  String? _error;

  bool get _isSupportedPlatform {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
    if (_isSupportedPlatform) {
      unawaited(_ensureServer());
    }
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    super.dispose();
  }

  @override
  void requestSave() {
    unawaited(_postHostMessage({'type': 'SAVE_REQUEST'}));
  }

  Future<void> _postHostMessage(Map<String, dynamic> body) async {
    final controller = _controller;
    if (controller == null) return;
    final payload = jsonEncode(<String, dynamic>{
      'source': 'PATEEZ_WS_HOST',
      ...body,
    });
    final jsArgument = jsonEncode(payload);
    await controller.evaluateJavascript(
      source:
          'window.__pateezWsReceive && window.__pateezWsReceive($jsArgument);',
    );
  }

  Future<void> _ensureServer() async {
    try {
      final server = _localhostServer ??= InAppLocalhostServer(
        port: _localhostPort,
      );
      if (!server.isRunning()) {
        await server.start();
      }
      if (mounted) setState(() => _serverReady = true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _handleEditorMessage(dynamic raw) {
    final map = _messageToMap(raw);
    if (map == null || map['source'] != 'PATEEZ_WS_EDITOR') return;

    final type = map['type']?.toString();
    if (type == 'READY') {
      if (mounted) setState(() => _ready = true);
      unawaited(_sendLoad());
      return;
    }
    if (type == 'SAVE') {
      final payload = map['payload'];
      if (payload is Map) {
        widget.onSave(
          WebStorySaveResult(
            title: payload['title']?.toString() ?? '',
            markup: payload['markup']?.toString() ?? '',
            storyData: _asStringKeyedMap(payload['story']),
          ),
        );
      }
    }
  }

  Future<void> _sendLoad() async {
    if (_loadSent || _controller == null) return;
    _loadSent = true;
    await _postHostMessage({'type': 'LOAD', 'story': widget.initialStory});
  }

  Map<String, dynamic>? _messageToMap(dynamic message) {
    if (message is Map) {
      return message.map((key, dynamic value) => MapEntry(key.toString(), value));
    }
    if (message is String && message.trim().isNotEmpty) {
      final decoded = jsonDecode(message);
      if (decoded is Map) {
        return decoded.map((key, dynamic value) => MapEntry(key.toString(), value));
      }
    }
    return null;
  }

  Map<String, dynamic> _asStringKeyedMap(Object? value) {
    if (value is Map) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    }
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupportedPlatform) {
      return const WebStoriesEditorError(
        message: 'Web Stories editor is not supported on this platform.',
      );
    }
    if (_error != null) {
      return WebStoriesEditorError(message: _error!);
    }
    if (!_serverReady) {
      return const WebStoriesEditorLoading();
    }

    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(
              'http://localhost:$_localhostPort/assets/web_stories/index.html',
            ),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            isInspectable: kDebugMode,
            transparentBackground: false,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            supportZoom: false,
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
            controller.addJavaScriptHandler(
              handlerName: 'PateezWebStories',
              callback: (args) {
                if (args.isNotEmpty) {
                  _handleEditorMessage(args.first);
                }
                return null;
              },
            );
          },
          onReceivedError: (controller, request, error) {
            if (!mounted) return;
            setState(() => _error = error.description);
          },
        ),
        if (!_ready) const Positioned.fill(child: WebStoriesEditorLoading()),
      ],
    );
  }
}
