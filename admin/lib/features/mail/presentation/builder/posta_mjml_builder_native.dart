import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pateeznews_admin/core/localization/admin_language_controller.dart';
import 'package:pateeznews_admin/shared/data/media_service.dart';

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
  InAppWebViewController? _webViewController;
  bool _ready = false;
  String? _errorMessage;
  int _dropCommandSequence = 0;
  late PostaMjmlBuilderValue _lastValue;
  final _mediaService = MediaService();

  bool get _isSupportedPlatform {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

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
    widget.controller.attach(this);
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    super.dispose();
  }

  @override
  Future<PostaMjmlBuilderValue> requestExport() async {
    final controller = _webViewController;
    if (!_isSupportedPlatform) {
      return _lastValue;
    }
    if (!_ready || controller == null) {
      throw StateError('Posta şablon editörü henüz hazır değil.');
    }

    final result = await controller.evaluateJavascript(
      source:
          'JSON.stringify(window.LosposMailBuilder ? window.LosposMailBuilder.exportTemplate() : null)',
    );
    final value = _mergeBuilderValue(_valueFromJavascriptResult(result));
    _lastValue = value;
    return value;
  }

  @override
  Future<bool> insertText(String text) async {
    final controller = _webViewController;
    if (!_isSupportedPlatform || controller == null) {
      return false;
    }

    final escaped = text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n');
    final result = await controller.evaluateJavascript(
      source:
          "window.LosposMailBuilder && window.LosposMailBuilder.insertTextAtCursor('$escaped')",
    );
    return result == true || result == 'true';
  }

  @override
  Future<bool> addVariable(String key, String label, String varType) async {
    final controller = _webViewController;
    if (!_isSupportedPlatform || controller == null) {
      return false;
    }

    String escape(String v) => v
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n');

    final result = await controller.evaluateJavascript(
      source:
          "window.LosposMailBuilder && window.LosposMailBuilder.addVariable('${escape(key)}','${escape(label)}','${escape(varType)}')",
    );
    return result == true || result == 'true';
  }

  @override
  Future<bool> previewVariableDrop(
    String key,
    String label,
    String varType,
    double x,
    double y,
  ) {
    return _callVariableDropMethod(
      'previewVariableDrop',
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
  ) {
    return _callVariableDropMethod(
      'commitVariableDrop',
      key: key,
      label: label,
      varType: varType,
      x: x,
      y: y,
    );
  }

  @override
  Future<void> clearVariableDrop() async {
    final controller = _webViewController;
    if (!_isSupportedPlatform || controller == null) {
      return;
    }

    final payload = jsonEncode(<String, Object>{
      'sequence': ++_dropCommandSequence,
    });
    await controller.evaluateJavascript(
      source:
          'window.LosposMailBuilder && window.LosposMailBuilder.clearVariableDrop($payload)',
    );
  }

  Future<bool> _callVariableDropMethod(
    String method, {
    required String key,
    required String label,
    required String varType,
    required double x,
    required double y,
  }) async {
    final controller = _webViewController;
    if (!_isSupportedPlatform || controller == null) {
      return false;
    }

    final payload = jsonEncode(<String, Object>{
      'key': key,
      'label': label,
      'varType': varType,
      'x': x,
      'y': y,
      'sequence': ++_dropCommandSequence,
    });
    final result = await controller.evaluateJavascript(
      source:
          'window.LosposMailBuilder && window.LosposMailBuilder.$method($payload)',
    );
    return result == true || result == 'true';
  }

  Future<void> _loadInitialTemplate() async {
    final controller = _webViewController;
    if (controller == null) return;

    final payload = jsonEncode(_initialPayload);
    await controller.evaluateJavascript(
      source:
          'window.LosposMailBuilder && window.LosposMailBuilder.loadTemplate($payload);',
    );
  }

  void _handleBuilderMessage(dynamic message) {
    final map = _messageToMap(message);
    if (map == null) return;

    final type = map['type']?.toString();
    if (type == 'LOSPOSTA_UPLOAD_ASSET') {
      unawaited(_handleAssetUploadRequest(map));
      return;
    }

    final payload = map['payload'];
    if (payload is Map) {
      final value = _mergeBuilderValue(PostaMjmlBuilderValue.fromMap(payload));
      _lastValue = value;
      if (type == 'LOSPOSTA_BUILDER_CHANGED') {
        widget.onChanged?.call(value);
      }
    }

    if (type == 'LOSPOSTA_BUILDER_READY') {
      if (mounted) {
        setState(() {
          _ready = true;
          _errorMessage = null;
        });
      }
      return;
    }

    if (type == 'LOSPOSTA_BUILDER_ERROR') {
      if (mounted) {
        setState(() => _errorMessage = map['message']?.toString());
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

      await _postAssetUploadResult(
        requestId: requestId,
        success: true,
        src: src,
        name: payload['name']?.toString() ?? '',
      );
    } catch (error) {
      await _postAssetUploadResult(
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

  Future<void> _postAssetUploadResult({
    required String requestId,
    required bool success,
    String src = '',
    String name = '',
    String message = '',
  }) async {
    final controller = _webViewController;
    if (!_isSupportedPlatform || controller == null) {
      return;
    }
    final payload = jsonEncode(<String, Object>{
      'type': 'LOSPOSTA_UPLOAD_ASSET_RESULT',
      'requestId': requestId,
      'success': success,
      'src': src,
      'name': name,
      'message': message,
    });
    await controller.evaluateJavascript(
      source:
          'window.LosposMailBuilder && window.LosposMailBuilder.handleAssetUploadResult($payload);',
    );
  }

  Map<dynamic, dynamic>? _messageToMap(dynamic message) {
    if (message is Map) {
      return message;
    }

    if (message is String && message.trim().isNotEmpty) {
      final decoded = jsonDecode(message);
      if (decoded is Map) {
        return decoded;
      }
    }

    return null;
  }

  PostaMjmlBuilderValue _valueFromJavascriptResult(dynamic result) {
    if (result is Map) {
      return PostaMjmlBuilderValue.fromMap(result);
    }

    if (result is String && result.trim().isNotEmpty && result != 'null') {
      final decoded = jsonDecode(result);
      if (decoded is Map) {
        return PostaMjmlBuilderValue.fromMap(decoded);
      }
    }

    return _lastValue;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupportedPlatform) {
      return _PostaBuilderFallback(
        message: 'Şablon editörü bu platformda desteklenmiyor.',
        html: widget.initialHtml,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: <Widget>[
          InAppWebView(
            initialFile: 'assets/posta_builder/index.html',
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              isInspectable: kDebugMode,
              transparentBackground: false,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
            ),
            onWebViewCreated: (InAppWebViewController controller) {
              _webViewController = controller;
              controller.addJavaScriptHandler(
                handlerName: 'LosposMailBuilder',
                callback: (List<dynamic> args) {
                  if (args.isNotEmpty) {
                    _handleBuilderMessage(args.first);
                  }
                  return null;
                },
              );
            },
            onLoadStop: (controller, url) => _loadInitialTemplate(),
            onReceivedError: (controller, request, WebResourceError error) {
              if (!mounted) return;
              setState(() => _errorMessage = error.description);
            },
          ),
          if (!_ready || _errorMessage != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.92),
                child: Center(
                  child: _errorMessage == null
                      ? Column(
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
                        )
                      : _PostaBuilderError(message: _errorMessage!),
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
  InAppWebViewController? _webViewController;
  bool _ready = false;
  String? _errorMessage;

  bool get _isSupportedPlatform {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

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
  void didUpdateWidget(covariant PostaMjmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html ||
        oldWidget.mjml != widget.mjml ||
        oldWidget.projectData != widget.projectData) {
      unawaited(_sendPreview());
    }
  }

  void _handlePreviewMessage(dynamic message) {
    final map = _messageToMap(message);
    if (map == null) return;

    final type = map['type']?.toString();
    if (type == 'LOSPOSTA_PREVIEW_READY') {
      if (mounted) {
        setState(() {
          _ready = true;
          _errorMessage = null;
        });
      }
      unawaited(_sendPreview());
      return;
    }

    if (type == 'LOSPOSTA_PREVIEW_ERROR') {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _errorMessage = map['message']?.toString();
      });
    }
  }

  Future<void> _sendPreview() async {
    final controller = _webViewController;
    if (!_isSupportedPlatform || !_ready || controller == null) return;
    final payload = jsonEncode(_payload);
    await controller.evaluateJavascript(
      source:
          'window.LosposMailPreview && window.LosposMailPreview.loadPreview($payload);',
    );
  }

  Map<dynamic, dynamic>? _messageToMap(dynamic message) {
    if (message is Map) {
      return message;
    }

    if (message is String && message.trim().isNotEmpty) {
      final decoded = jsonDecode(message);
      if (decoded is Map) {
        return decoded;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupportedPlatform) {
      return _PostaBuilderFallback(
        message: 'Şablon önizlemesi bu platformda desteklenmiyor.',
        html: widget.html,
      );
    }

    return Stack(
      children: <Widget>[
        InAppWebView(
          initialFile: 'assets/posta_builder/preview.html',
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            isInspectable: kDebugMode,
            transparentBackground: false,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
          ),
          onWebViewCreated: (InAppWebViewController controller) {
            _webViewController = controller;
            controller.addJavaScriptHandler(
              handlerName: 'LosposMailPreview',
              callback: (List<dynamic> args) {
                if (args.isNotEmpty) {
                  _handlePreviewMessage(args.first);
                }
                return null;
              },
            );
          },
          onLoadStop: (controller, url) => _sendPreview(),
          onReceivedError: (controller, request, WebResourceError error) {
            if (!mounted) return;
            setState(() {
              _ready = true;
              _errorMessage = error.description;
            });
          },
        ),
        if (!_ready || _errorMessage != null)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.white.withValues(alpha: 0.92),
              child: Center(
                child: _errorMessage == null
                    ? _PostaPreviewLoading(label: context.t('common.loading'))
                    : _PostaBuilderError(message: _errorMessage!),
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

class _PostaBuilderError extends StatelessWidget {
  const _PostaBuilderError({required this.message});

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

class _PostaBuilderFallback extends StatelessWidget {
  const _PostaBuilderFallback({required this.message, required this.html});

  final String message;
  final String html;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                html.isEmpty ? 'Kayıtlı içerik yok.' : html,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
