import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

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

Future<MediaDownloadSaveTarget?> selectMediaDownloadSaveTarget({
  required String suggestedName,
  required String mimeType,
  String? extension,
}) async {
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

String _normalizeExtension(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return RegExp(r'^[a-z0-9]{2,5}$').hasMatch(normalized) ? normalized : '';
}
