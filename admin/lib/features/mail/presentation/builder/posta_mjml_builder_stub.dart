import 'package:flutter/material.dart';

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
  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    super.dispose();
  }

  @override
  Future<PostaMjmlBuilderValue> requestExport() async {
    return PostaMjmlBuilderValue(
      html: widget.initialHtml,
      mjml: widget.initialMjml ?? '',
      projectData: widget.initialProjectData ?? '',
    );
  }

  @override
  Future<bool> insertText(String text) async {
    return false;
  }

  @override
  Future<bool> addVariable(String key, String label, String varType) async {
    return false;
  }

  @override
  Future<bool> previewVariableDrop(
    String key,
    String label,
    String varType,
    double x,
    double y,
  ) async {
    return false;
  }

  @override
  Future<bool> commitVariableDrop(
    String key,
    String label,
    String varType,
    double x,
    double y,
  ) async {
    return false;
  }

  @override
  Future<void> clearVariableDrop() async {}

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Şablon editörü bu platformda desteklenmiyor.'),
    );
  }
}

class PostaMjmlPreview extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        child: SelectableText(
          html.trim().isEmpty ? 'Kayıtlı içerik yok.' : html,
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
            color: Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
