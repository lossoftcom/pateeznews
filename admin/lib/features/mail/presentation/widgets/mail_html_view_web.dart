import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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
  web.HTMLIFrameElement? _iframe;

  @override
  void didUpdateWidget(covariant MailHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html ||
        oldWidget.fallbackText != widget.fallbackText) {
      _loadHtml();
    }
  }

  void _configureIframe(Object element) {
    final iframe = element as web.HTMLIFrameElement;
    _iframe = iframe;
    iframe
      ..loading = 'eager'
      ..style.cssText =
          'width:100%;height:100%;border:0;display:block;background:#fff;';
    iframe.setAttribute(
      'sandbox',
      'allow-popups allow-popups-to-escape-sandbox',
    );
    iframe.setAttribute('referrerpolicy', 'no-referrer');
    _loadHtml();
  }

  void _loadHtml() {
    final iframe = _iframe;
    if (iframe == null) return;
    iframe.setAttribute(
      'srcdoc',
      mailHtmlDocument(widget.html, widget.fallbackText),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: HtmlElementView.fromTagName(
        tagName: 'iframe',
        onElementCreated: _configureIframe,
      ),
    );
  }
}
