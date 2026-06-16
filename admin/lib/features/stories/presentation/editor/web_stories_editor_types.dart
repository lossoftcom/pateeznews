import 'package:flutter/material.dart';

import '../../../../core/localization/admin_language_controller.dart';

/// Bridge implemented by each platform's editor state so the host UI can drive
/// the embedded editor (e.g. trigger a save from the dialog's "Save" button).
abstract class WebStoriesEditorBridge {
  void requestSave();
}

/// Controller handed to [WebStoriesEditor] so the surrounding dialog can ask the
/// editor to save the current story.
class WebStoriesEditorController {
  WebStoriesEditorBridge? _bridge;

  void attach(WebStoriesEditorBridge bridge) => _bridge = bridge;

  void detach(WebStoriesEditorBridge bridge) {
    if (identical(_bridge, bridge)) _bridge = null;
  }

  /// Triggers the editor's save flow (mirrors the editor's own publish button).
  void requestSave() => _bridge?.requestSave();
}

/// Result emitted by the embedded Google Web Stories editor whenever the user
/// saves a story from inside the editor (its `saveStoryById` callback fires).
class WebStorySaveResult {
  const WebStorySaveResult({
    required this.title,
    required this.markup,
    required this.storyData,
  });

  /// Plain-text story title typed inside the editor.
  final String title;

  /// Editor-generated AMP markup for the full story (stored in `story_markup`).
  final String markup;

  /// Re-openable editor state (stored in `story_data`); fed straight back into
  /// `initialEdits.story` when the story is edited again.
  final Map<String, dynamic> storyData;
}

/// Shared loading overlay used by both the web (iframe) and native (webview)
/// editor implementations while the editor bundle boots.
class WebStoriesEditorLoading extends StatelessWidget {
  const WebStoriesEditorLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1B1B1F),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              context.t('common.loading'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared error overlay used by both editor implementations.
class WebStoriesEditorError extends StatelessWidget {
  const WebStoriesEditorError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1B1B1F),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEA4335)),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
