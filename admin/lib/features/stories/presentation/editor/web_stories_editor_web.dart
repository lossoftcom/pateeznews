import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'web_stories_editor_types.dart';

/// Flutter Web host for the vendored Google Web Stories editor.
///
/// The editor bundle (admin/assets/web_stories) is loaded into an iframe and
/// talks to Flutter through `window.postMessage`, mirroring the posta_builder
/// (LOSPOSTA_*) bridge but on its own PATEEZ_WS_* namespace.
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
  web.HTMLIFrameElement? _iframe;
  late final web.EventListener _messageListener;
  bool _ready = false;
  bool _loadSent = false;

  @override
  void initState() {
    super.initState();
    _messageListener = ((web.Event event) {
      _handleMessage(event);
    }).toJS;
    web.window.addEventListener('message', _messageListener);
    widget.controller.attach(this);
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    web.window.removeEventListener('message', _messageListener);
    super.dispose();
  }

  @override
  void requestSave() {
    final contentWindow = _iframe?.contentWindow;
    if (contentWindow == null) return;
    contentWindow.postMessage(
      <String, dynamic>{
        'source': 'PATEEZ_WS_HOST',
        'type': 'SAVE_REQUEST',
      }.jsify(),
      '*'.toJS,
    );
  }

  void _configureIframe(Object element) {
    final iframe = element as web.HTMLIFrameElement;
    _iframe = iframe;
    iframe
      ..src = Uri.base
          .resolve('assets/assets/web_stories/index.html')
          .toString()
      ..allow = 'clipboard-read; clipboard-write; fullscreen'
      ..allowFullscreen = true
      ..loading = 'eager';
    iframe.style.cssText =
        'width:100%;height:100%;border:0;display:block;background:#1b1b1f;';
  }

  void _handleMessage(web.Event event) {
    final messageEvent = event as web.MessageEvent;
    final data = messageEvent.data.dartify();
    if (data is! Map) return;
    if (data['source'] != 'PATEEZ_WS_EDITOR') return;

    final type = data['type']?.toString();
    if (type == 'READY') {
      if (mounted) setState(() => _ready = true);
      _sendLoad();
      return;
    }
    if (type == 'SAVE') {
      final payload = data['payload'];
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

  void _sendLoad() {
    if (_loadSent) return;
    final contentWindow = _iframe?.contentWindow;
    if (contentWindow == null) return;
    _loadSent = true;
    contentWindow.postMessage(
      <String, dynamic>{
        'source': 'PATEEZ_WS_HOST',
        'type': 'LOAD',
        'story': widget.initialStory,
      }.jsify(),
      '*'.toJS,
    );
  }

  Map<String, dynamic> _asStringKeyedMap(Object? value) {
    if (value is Map) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    }
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HtmlElementView.fromTagName(
          tagName: 'iframe',
          onElementCreated: _configureIframe,
        ),
        if (!_ready) const Positioned.fill(child: WebStoriesEditorLoading()),
      ],
    );
  }
}
