import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:web/web.dart' as web;

abstract class MediaDownloadSaveTarget {
  Future<void> saveBytes({required List<int> bytes, required String mimeType});
}

class _FileSelectorMediaDownloadSaveTarget implements MediaDownloadSaveTarget {
  const _FileSelectorMediaDownloadSaveTarget({
    required this.location,
    required this.fileName,
  });

  final FileSaveLocation location;
  final String fileName;

  @override
  Future<void> saveBytes({
    required List<int> bytes,
    required String mimeType,
  }) async {
    await XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: mimeType,
      name: fileName,
    ).saveTo(location.path);
  }
}

class _FileSystemAccessMediaDownloadSaveTarget
    implements MediaDownloadSaveTarget {
  const _FileSystemAccessMediaDownloadSaveTarget(this.handle);

  final web.FileSystemFileHandle handle;

  @override
  Future<void> saveBytes({
    required List<int> bytes,
    required String mimeType,
  }) async {
    final writable = await handle.createWritable().toDart;
    final blob = web.Blob(
      <JSUint8Array>[Uint8List.fromList(bytes).toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    await writable.write(blob).toDart;
    await writable.close().toDart;
  }
}

Future<MediaDownloadSaveTarget?> selectMediaDownloadSaveTarget({
  required String suggestedName,
  required String mimeType,
  String? extension,
}) async {
  final pickerResult = await _selectFileSystemAccessTarget(suggestedName);
  if (pickerResult.cancelled) return null;
  if (pickerResult.target != null) return pickerResult.target;

  final normalizedExtension = _normalizeExtension(extension);
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: [
      XTypeGroup(
        label: 'Görsel',
        extensions: [if (normalizedExtension.isNotEmpty) normalizedExtension],
        mimeTypes: [if (mimeType.trim().isNotEmpty) mimeType.trim()],
      ),
    ],
  );
  if (location == null) return null;
  return _FileSelectorMediaDownloadSaveTarget(
    location: location,
    fileName: suggestedName,
  );
}

Future<_SavePickerResult> _selectFileSystemAccessTarget(
  String suggestedName,
) async {
  if (!web.window.hasProperty('showSaveFilePicker'.toJS).toDart) {
    return const _SavePickerResult.unsupported();
  }
  try {
    final handle = await _SavePickerWindow(web.window)
        .showSaveFilePicker(
          _SaveFilePickerOptions(suggestedName: suggestedName),
        )
        .toDart;
    return _SavePickerResult.selected(
      _FileSystemAccessMediaDownloadSaveTarget(handle),
    );
  } catch (error) {
    if (_isPickerCancel(error)) return const _SavePickerResult.cancelled();
    return const _SavePickerResult.unsupported();
  }
}

bool _isPickerCancel(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('aborterror') ||
      text.contains('aborted') ||
      text.contains('cancel');
}

String _normalizeExtension(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return RegExp(r'^[a-z0-9]{2,5}$').hasMatch(normalized) ? normalized : '';
}

class _SavePickerResult {
  const _SavePickerResult._({this.target, this.cancelled = false});

  const _SavePickerResult.selected(MediaDownloadSaveTarget target)
    : this._(target: target);

  const _SavePickerResult.cancelled() : this._(cancelled: true);

  const _SavePickerResult.unsupported() : this._();

  final MediaDownloadSaveTarget? target;
  final bool cancelled;
}

extension type _SavePickerWindow(JSObject _) implements JSObject {
  external JSPromise<web.FileSystemFileHandle> showSaveFilePicker(
    _SaveFilePickerOptions options,
  );
}

extension type _SaveFilePickerOptions._(JSObject _) implements JSObject {
  external factory _SaveFilePickerOptions({String suggestedName});
}
