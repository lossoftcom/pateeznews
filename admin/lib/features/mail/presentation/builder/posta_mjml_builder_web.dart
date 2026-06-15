import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/core/localization/admin_language_controller.dart';
import 'package:pateeznews_admin/shared/data/media_service.dart';
import 'package:web/web.dart' as web;

import 'posta_mjml_builder_types.dart';

class PostaMjmlBuilder extends StatefulWidget {
  const PostaMjmlBuilder({
    super.key,
    required this.controller,
    this.initialHtml = '',
    this.initialMjml,
    this.initialProjectData,
    this.previewSiteName = '',
    this.previewLogoUrl = '',
    this.previewLogoDataUri = '',
    this.onChanged,
  });

  final PostaMjmlBuilderController controller;
  final String initialHtml;
  final String? initialMjml;
  final String? initialProjectData;
  final String previewSiteName;
  final String previewLogoUrl;
  final String previewLogoDataUri;
  final ValueChanged<PostaMjmlBuilderValue>? onChanged;

  @override
  State<PostaMjmlBuilder> createState() => _PostaMjmlBuilderState();
}

class _PostaMjmlBuilderState extends State<PostaMjmlBuilder>
    implements PostaMjmlBuilderBridge {
  web.HTMLIFrameElement? _iframe;
  late final web.EventListener _messageListener;
  final Map<String, Completer<PostaMjmlBuilderValue>> _pendingExports =
      <String, Completer<PostaMjmlBuilderValue>>{};

  bool _ready = false;
  bool _initialTemplateSent = false;
  int _requestCounter = 0;
  int _dropCommandSequence = 0;
  late PostaMjmlBuilderValue _lastValue;
  final _mediaService = MediaService();

  Map<String, dynamic> get _initialPayload {
    return <String, dynamic>{
      'html': widget.initialHtml,
      'mjml': widget.initialMjml ?? '',
      'projectData': widget.initialProjectData ?? '',
      'previewSiteName': widget.previewSiteName,
      'previewLogoUrl': widget.previewLogoUrl,
      'previewLogoDataUri': widget.previewLogoDataUri,
    };
  }

  bool _looksLikeMjmlText(String value) {
    return value.trim().toLowerCase().startsWith('<mjml');
  }

  PostaMjmlBuilderValue _mergeBuilderValue(PostaMjmlBuilderValue value) {
    final incomingHtml = value.html.trim();
    final previousHtml = _lastValue.html.trim();
    final mergedHtml =
        incomingHtml.isNotEmpty && !_looksLikeMjmlText(incomingHtml)
        ? value.html
        : previousHtml.isNotEmpty && !_looksLikeMjmlText(previousHtml)
        ? _lastValue.html
        : incomingHtml.isNotEmpty
        ? value.html
        : _lastValue.html;

    final incomingMjml = value.mjml.trim();
    final incomingProjectData = value.projectData.trim();

    return PostaMjmlBuilderValue(
      html: mergedHtml,
      mjml: incomingMjml.isNotEmpty ? value.mjml : _lastValue.mjml,
      projectData: incomingProjectData.isNotEmpty
          ? value.projectData
          : _lastValue.projectData,
      errors: value.errors,
    );
  }

  @override
  void initState() {
    super.initState();
    _lastValue = PostaMjmlBuilderValue(
      html: widget.initialHtml,
      mjml: widget.initialMjml ?? '',
      projectData: widget.initialProjectData ?? '',
    );
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
    for (final completer in _pendingExports.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Posta şablon editörü kapatıldı.'));
      }
    }
    _pendingExports.clear();
    super.dispose();
  }

  @override
  Future<PostaMjmlBuilderValue> requestExport() {
    final iframe = _iframe;
    final contentWindow = iframe?.contentWindow;
    if (!_ready || contentWindow == null) {
      return Future<PostaMjmlBuilderValue>.error(
        StateError('Posta şablon editörü henüz hazır değil.'),
      );
    }

    final requestId =
        'posta-builder-${DateTime.now().microsecondsSinceEpoch}-${_requestCounter++}';
    final completer = Completer<PostaMjmlBuilderValue>();
    _pendingExports[requestId] = completer;
    contentWindow.postMessage(
      <String, dynamic>{
        'type': 'LOSPOSTA_REQUEST_EXPORT',
        'requestId': requestId,
      }.jsify(),
      '*'.toJS,
    );

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _pendingExports.remove(requestId);
        throw TimeoutException('Posta şablon editörü yanıt vermedi.');
      },
    );
  }

  @override
  Future<bool> insertText(String text) async {
    final contentWindow = _iframe?.contentWindow;
    if (contentWindow == null) {
      return false;
    }
    contentWindow.postMessage(
      <String, dynamic>{'type': 'LOSPOSTA_INSERT_TEXT', 'text': text}.jsify(),
      '*'.toJS,
    );
    return true;
  }

  @override
  Future<bool> addVariable(String key, String label, String varType) async {
    final contentWindow = _iframe?.contentWindow;
    if (contentWindow == null) {
      return false;
    }
    contentWindow.postMessage(
      <String, dynamic>{
        'type': 'LOSPOSTA_ADD_VARIABLE',
        'key': key,
        'label': label,
        'varType': varType,
      }.jsify(),
      '*'.toJS,
    );
    return true;
  }

  @override
  Future<bool> previewVariableDrop(
    String key,
    String label,
    String varType,
    double x,
    double y,
  ) async {
    return _postVariableDropMessage(
      'LOSPOSTA_PREVIEW_VARIABLE_DROP',
      key: key,
      label: label,
      varType: varType,
      x: x,
      y: y,
    );
  }

  @override
  Future<bool> commitVariableDrop(
    String key,
    String label,
    String varType,
    double x,
    double y,
  ) async {
    return _postVariableDropMessage(
      'LOSPOSTA_COMMIT_VARIABLE_DROP',
      key: key,
      label: label,
      varType: varType,
      x: x,
      y: y,
    );
  }

  @override
  Future<void> clearVariableDrop() async {
    final contentWindow = _iframe?.contentWindow;
    if (contentWindow == null) {
      return;
    }
    contentWindow.postMessage(
      <String, dynamic>{
        'type': 'LOSPOSTA_CLEAR_VARIABLE_DROP',
        'sequence': ++_dropCommandSequence,
      }.jsify(),
      '*'.toJS,
    );
  }

  bool _postVariableDropMessage(
    String type, {
    required String key,
    required String label,
    required String varType,
    required double x,
    required double y,
  }) {
    final contentWindow = _iframe?.contentWindow;
    if (contentWindow == null) {
      return false;
    }
    contentWindow.postMessage(
      <String, dynamic>{
        'type': type,
        'key': key,
        'label': label,
        'varType': varType,
        'x': x,
        'y': y,
        'sequence': ++_dropCommandSequence,
      }.jsify(),
      '*'.toJS,
    );
    return true;
  }

  void _configureIframe(Object element) {
    final iframe = element as web.HTMLIFrameElement;
    _iframe = iframe;
    iframe
      ..src = Uri.base
          .resolve('assets/assets/posta_builder/index.html')
          .toString()
      ..allow = 'clipboard-read; clipboard-write; fullscreen'
      ..allowFullscreen = true
      ..loading = 'eager';
    iframe.style.cssText =
        'width:100%;height:100%;border:0;display:block;background:#fff;';
  }

  void _handleMessage(web.Event event) {
    final messageEvent = event as web.MessageEvent;
    final data = messageEvent.data.dartify();
    if (data is! Map) {
      return;
    }

    final type = data['type']?.toString();
    if (type == 'LOSPOSTA_UPLOAD_ASSET') {
      unawaited(_handleAssetUploadRequest(data));
      return;
    }

    final payload = data['payload'];
    if (payload is Map) {
      final value = _mergeBuilderValue(PostaMjmlBuilderValue.fromMap(payload));
      _lastValue = value;
      if (type == 'LOSPOSTA_BUILDER_CHANGED') {
        widget.onChanged?.call(value);
      }
    }

    if (type == 'LOSPOSTA_BUILDER_READY') {
      if (mounted) {
        setState(() => _ready = true);
      }
      _sendInitialTemplate();
      return;
    }

    if (type == 'LOSPOSTA_EXPORT_RESULT') {
      final requestId = data['requestId']?.toString();
      final completer = requestId == null
          ? null
          : _pendingExports.remove(requestId);
      if (completer != null && !completer.isCompleted) {
        final value = payload is Map
            ? _mergeBuilderValue(PostaMjmlBuilderValue.fromMap(payload))
            : _lastValue;
        _lastValue = value;
        completer.complete(value);
      }
    }
  }

  Future<void> _handleAssetUploadRequest(Map<dynamic, dynamic> data) async {
    final requestId = data['requestId']?.toString() ?? '';
    final payload = data['payload'];
    if (requestId.isEmpty || payload is! Map) {
      return;
    }

    try {
      final dataUrl = payload['dataUrl']?.toString() ?? '';
      final bytes = _bytesFromDataUrl(dataUrl);
      if (bytes.isEmpty) {
        throw StateError('Görsel verisi okunamadı.');
      }

      final item = await _mediaService.uploadFile(
        fileName: _assetFileName(payload['name']?.toString()),
        bytes: bytes,
        type: 'image',
        customPath: 'mail-templates',
      );
      final src = item == null ? '' : _mediaService.resolveImageUrl(item.src);
      if (src.trim().isEmpty) {
        throw StateError('Görsel yüklenemedi.');
      }

      _postAssetUploadResult(
        requestId: requestId,
        success: true,
        src: src,
        name: payload['name']?.toString() ?? '',
      );
    } catch (error) {
      _postAssetUploadResult(
        requestId: requestId,
        success: false,
        message: error.toString(),
      );
    }
  }

  List<int> _bytesFromDataUrl(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    final payload = comma == -1 ? dataUrl : dataUrl.substring(comma + 1);
    return base64Decode(payload);
  }

  String _assetFileName(String? rawName) {
    final fallback =
        'posta-gorsel-${DateTime.now().millisecondsSinceEpoch}.png';
    final name = (rawName ?? '').trim();
    if (name.isEmpty) return fallback;
    return name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
  }

  void _postAssetUploadResult({
    required String requestId,
    required bool success,
    String src = '',
    String name = '',
    String message = '',
  }) {
    final contentWindow = _iframe?.contentWindow;
    if (contentWindow == null) {
      return;
    }
    contentWindow.postMessage(
      <String, dynamic>{
        'type': 'LOSPOSTA_UPLOAD_ASSET_RESULT',
        'requestId': requestId,
        'success': success,
        'src': src,
        'name': name,
        'message': message,
      }.jsify(),
      '*'.toJS,
    );
  }

  void _sendInitialTemplate() {
    final contentWindow = _iframe?.contentWindow;
    if (contentWindow == null || _initialTemplateSent) {
      return;
    }
    _initialTemplateSent = true;
    contentWindow.postMessage(
      <String, dynamic>{
        'type': 'LOSPOSTA_LOAD_TEMPLATE',
        'payload': _initialPayload,
      }.jsify(),
      '*'.toJS,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: <Widget>[
          HtmlElementView.fromTagName(
            tagName: 'iframe',
            onElementCreated: _configureIframe,
          ),
          if (!_ready)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.94),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.t('common.loading'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PostaMjmlPreview extends StatefulWidget {
  const PostaMjmlPreview({
    super.key,
    required this.html,
    this.mjml = '',
    this.projectData = '',
    this.previewSiteName = '',
    this.previewLogoUrl = '',
    this.previewLogoDataUri = '',
  });

  final String html;
  final String mjml;
  final String projectData;
  final String previewSiteName;
  final String previewLogoUrl;
  final String previewLogoDataUri;

  @override
  State<PostaMjmlPreview> createState() => _PostaMjmlPreviewState();
}

class _PostaMjmlPreviewState extends State<PostaMjmlPreview> {
  web.HTMLIFrameElement? _iframe;
  late final web.EventListener _messageListener;
  bool _ready = false;
  String? _errorMessage;

  Map<String, dynamic> get _payload {
    return <String, dynamic>{
      'html': widget.html,
      'mjml': widget.mjml,
      'projectData': widget.projectData,
      'previewSiteName': widget.previewSiteName,
      'previewLogoUrl': widget.previewLogoUrl,
      'previewLogoDataUri': widget.previewLogoDataUri,
    };
  }

  @override
  void initState() {
    super.initState();
    _messageListener = ((web.Event event) {
      _handleMessage(event);
    }).toJS;
    web.window.addEventListener('message', _messageListener);
  }

  @override
  void didUpdateWidget(covariant PostaMjmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html ||
        oldWidget.mjml != widget.mjml ||
        oldWidget.projectData != widget.projectData) {
      _sendPreview();
    }
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _messageListener);
    super.dispose();
  }

  void _configureIframe(Object element) {
    final iframe = element as web.HTMLIFrameElement;
    _iframe = iframe;
    iframe
      ..src = Uri.base
          .resolve('assets/assets/posta_builder/preview.html')
          .toString()
      ..allow = 'fullscreen'
      ..allowFullscreen = true
      ..loading = 'eager';
    iframe.style.cssText =
        'width:100%;height:100%;border:0;display:block;background:#f4f7fb;';
  }

  void _handleMessage(web.Event event) {
    final messageEvent = event as web.MessageEvent;
    final data = messageEvent.data.dartify();
    if (data is! Map) return;

    final type = data['type']?.toString();
    if (type == 'LOSPOSTA_PREVIEW_READY') {
      if (mounted) {
        setState(() {
          _ready = true;
          _errorMessage = null;
        });
      }
      _sendPreview();
      return;
    }

    if (type == 'LOSPOSTA_PREVIEW_ERROR') {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _errorMessage = data['message']?.toString();
      });
    }
  }

  void _sendPreview() {
    final contentWindow = _iframe?.contentWindow;
    if (!_ready || contentWindow == null) return;
    contentWindow.postMessage(
      <String, dynamic>{
        'type': 'LOSPOSTA_LOAD_PREVIEW',
        'payload': _payload,
      }.jsify(),
      '*'.toJS,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        HtmlElementView.fromTagName(
          tagName: 'iframe',
          onElementCreated: _configureIframe,
        ),
        if (!_ready || _errorMessage != null)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.white.withValues(alpha: 0.92),
              child: Center(
                child: _errorMessage == null
                    ? _PostaPreviewLoading(label: context.t('common.loading'))
                    : _PostaPreviewError(message: _errorMessage!),
              ),
            ),
          ),
      ],
    );
  }
}

class _PostaPreviewLoading extends StatelessWidget {
  const _PostaPreviewLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

class _PostaPreviewError extends StatelessWidget {
  const _PostaPreviewError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.error_outline_rounded, color: Color(0xFFEA4335)),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}
