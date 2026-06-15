import 'dart:async';

class PostaMjmlBuilderValue {
  const PostaMjmlBuilderValue({
    required this.html,
    required this.mjml,
    required this.projectData,
    this.errors = const <String>[],
  });

  final String html;
  final String mjml;
  final String projectData;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;

  factory PostaMjmlBuilderValue.fromMap(Map<dynamic, dynamic> map) {
    return PostaMjmlBuilderValue(
      html: map['html']?.toString() ?? '',
      mjml: map['mjml']?.toString() ?? '',
      projectData: map['projectData']?.toString() ?? '',
      errors: (map['errors'] as List? ?? const <Object?>[])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'html': html,
      'mjml': mjml,
      'projectData': projectData,
      'errors': errors,
    };
  }
}

abstract class PostaMjmlBuilderBridge {
  Future<PostaMjmlBuilderValue> requestExport();
  Future<bool> insertText(String text);
  Future<bool> addVariable(String key, String label, String varType);
  Future<bool> previewVariableDrop(
    String key,
    String label,
    String varType,
    double x,
    double y,
  );
  Future<bool> commitVariableDrop(
    String key,
    String label,
    String varType,
    double x,
    double y,
  );
  Future<void> clearVariableDrop();
}

class PostaMjmlBuilderController {
  PostaMjmlBuilderBridge? _bridge;

  void attach(PostaMjmlBuilderBridge bridge) {
    _bridge = bridge;
  }

  void detach(PostaMjmlBuilderBridge bridge) {
    if (identical(_bridge, bridge)) {
      _bridge = null;
    }
  }

  Future<PostaMjmlBuilderValue> requestExport() {
    final bridge = _bridge;
    if (bridge == null) {
      return Future<PostaMjmlBuilderValue>.error(
        StateError('Posta şablon editörü henüz hazır değil.'),
      );
    }
    return bridge.requestExport();
  }

  Future<bool> insertText(String text) {
    final bridge = _bridge;
    if (bridge == null) {
      return Future<bool>.value(false);
    }
    return bridge.insertText(text);
  }

  Future<bool> addVariable(String key, String label, String varType) {
    final bridge = _bridge;
    if (bridge == null) {
      return Future<bool>.value(false);
    }
    return bridge.addVariable(key, label, varType);
  }

  Future<bool> previewVariableDrop(
    String key,
    String label,
    String varType,
    double x,
    double y,
  ) {
    final bridge = _bridge;
    if (bridge == null) {
      return Future<bool>.value(false);
    }
    return bridge.previewVariableDrop(key, label, varType, x, y);
  }

  Future<bool> commitVariableDrop(
    String key,
    String label,
    String varType,
    double x,
    double y,
  ) {
    final bridge = _bridge;
    if (bridge == null) {
      return Future<bool>.value(false);
    }
    return bridge.commitVariableDrop(key, label, varType, x, y);
  }

  Future<void> clearVariableDrop() {
    final bridge = _bridge;
    if (bridge == null) {
      return Future<void>.value();
    }
    return bridge.clearVariableDrop();
  }
}
