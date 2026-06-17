import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import 'mail_html_document.dart';

class MailHtmlView extends StatefulWidget {
  const MailHtmlView({
    super.key,
    required this.html,
    required this.fallbackText,
    this.height = 520,
  });

  final String html;
  final String fallbackText;
  final double? height;

  @override
  State<MailHtmlView> createState() => _MailHtmlViewState();
}

class _MailHtmlViewState extends State<MailHtmlView> {
  InAppWebViewController? _controller;

  bool get _isSupportedPlatform {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  @override
  void didUpdateWidget(covariant MailHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html ||
        oldWidget.fallbackText != widget.fallbackText) {
      _loadHtml();
    }
  }

  Future<void> _loadHtml() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.loadData(
      data: mailHtmlDocument(widget.html, widget.fallbackText),
      mimeType: 'text/html',
      encoding: 'utf8',
      baseUrl: WebUri('about:blank'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupportedPlatform) {
      return _MailHtmlFallbackText(
        html: widget.html,
        fallbackText: widget.fallbackText,
        height: widget.height ?? 360,
      );
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: InAppWebView(
        initialData: InAppWebViewInitialData(
          data: mailHtmlDocument(widget.html, widget.fallbackText),
          mimeType: 'text/html',
          encoding: 'utf8',
          baseUrl: WebUri('about:blank'),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: false,
          transparentBackground: false,
          isInspectable: kDebugMode,
          supportZoom: false,
          useWideViewPort: true,
          loadWithOverviewMode: true,
          horizontalScrollBarEnabled: false,
          verticalScrollBarEnabled: true,
          disableHorizontalScroll: true,
          disableVerticalScroll: false,
        ),
        onWebViewCreated: (controller) {
          _controller = controller;
        },
      ),
    );
  }
}

class _MailHtmlFallbackText extends StatelessWidget {
  const _MailHtmlFallbackText({
    required this.html,
    required this.fallbackText,
    required this.height,
  });

  final String html;
  final String fallbackText;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 160, maxHeight: height),
      child: SingleChildScrollView(
        child: SelectableText(
          fallbackText.trim().isEmpty ? html : fallbackText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.deepOcean,
            height: 1.55,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
