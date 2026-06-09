import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const int _debugDarwinPlatformViewReserveCount = 32;
const int _debugDarwinPlatformViewDisposeProbeCount = 256;

Future<void>? _debugDarwinPlatformViewHotRestartPreparation;

Future<void> prepareDebugDarwinPlatformViewsForHotRestart() {
  if (!kDebugMode || kIsWeb) return Future<void>.value();
  if (!_isDarwinPlatform(defaultTargetPlatform)) return Future<void>.value();

  return _debugDarwinPlatformViewHotRestartPreparation ??=
      _prepareDebugDarwinPlatformViewsForHotRestart();
}

bool _isDarwinPlatform(TargetPlatform platform) {
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

Future<void> _prepareDebugDarwinPlatformViewsForHotRestart() async {
  await Future.wait<void>([
    for (var id = 0; id < _debugDarwinPlatformViewDisposeProbeCount; id++)
      _disposeDebugDarwinPlatformView(id),
  ]);

  await SchedulerBinding.instance.endOfFrame;

  for (var i = 0; i < _debugDarwinPlatformViewReserveCount; i++) {
    platformViewsRegistry.getNextPlatformViewId();
  }
}

Future<void> _disposeDebugDarwinPlatformView(int id) async {
  try {
    await SystemChannels.platform_views.invokeMethod<void>('dispose', id);
  } on PlatformException catch (error) {
    if (error.code != 'unknown_view') rethrow;
  } on MissingPluginException {
    // Widget tests do not have the native platform-views channel registered.
  }
}
