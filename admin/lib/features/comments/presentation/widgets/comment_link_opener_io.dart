import 'dart:io' as io;

import 'package:flutter/foundation.dart';

Future<void> openCommentLink(String url) async {
  if (url.trim().isEmpty) return;

  try {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.iOS:
        await io.Process.run('open', [url]);
        return;
      case TargetPlatform.windows:
        await io.Process.run('cmd', ['/c', 'start', '', url]);
        return;
      case TargetPlatform.linux:
        await io.Process.run('xdg-open', [url]);
        return;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return;
    }
  } catch (_) {}
}
