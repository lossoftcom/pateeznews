import 'package:flutter/material.dart';

import 'web_stories_editor_types.dart';

/// Fallback used on platforms that expose neither `dart:html` (web) nor
/// `dart:io` (native). In practice every Flutter target hits one of the two
/// real implementations; this only exists to keep the conditional export valid.
class WebStoriesEditor extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const WebStoriesEditorError(
      message: 'Web Stories editor is not supported on this platform.',
    );
  }
}
