import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class PreparedMediaUpload {
  const PreparedMediaUpload({required this.fileName, required this.bytes});

  final String fileName;
  final List<int> bytes;
}

const _maxImageDimension = 7680;
const _browserConvertibleImageExtensions = {
  'bmp',
  'jpeg',
  'jpg',
  'png',
  'webp',
};

Future<PreparedMediaUpload> prepareMediaUploadForStorage({
  required String fileName,
  required List<int> bytes,
  required String type,
  required String imageFileFormat,
  bool forceImageEncoding = false,
}) async {
  final outputFormat = _normalizeImageOutputFormat(imageFileFormat);
  if (type != 'image' || outputFormat == null) {
    return PreparedMediaUpload(fileName: fileName, bytes: bytes);
  }

  final sourceExtension = _fileExtension(fileName);
  if (!forceImageEncoding &&
      _extensionMatchesOutput(sourceExtension, outputFormat)) {
    return PreparedMediaUpload(fileName: fileName, bytes: bytes);
  }
  if (!_browserConvertibleImageExtensions.contains(sourceExtension)) {
    return PreparedMediaUpload(fileName: fileName, bytes: bytes);
  }

  try {
    final converted = await _convertImageBytes(bytes, outputFormat);
    return PreparedMediaUpload(
      fileName: _withOutputExtension(fileName, outputFormat),
      bytes: converted,
    );
  } catch (_) {
    return PreparedMediaUpload(fileName: fileName, bytes: bytes);
  }
}

String? _normalizeImageOutputFormat(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == 'jpg' || normalized == 'jpeg') return 'jpeg';
  if (normalized == 'png') return 'png';
  if (normalized == 'webp') return 'webp';
  return null;
}

String _extensionForImageOutputFormat(String format) {
  return format == 'jpeg' ? 'jpg' : format;
}

String _mimeTypeForImageOutputFormat(String format) {
  if (format == 'jpeg') return 'image/jpeg';
  if (format == 'png') return 'image/png';
  return 'image/webp';
}

String _fileExtension(String fileName) {
  final clean = fileName.split('?').first.split('#').first.toLowerCase();
  final dotIndex = clean.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == clean.length - 1) return '';
  return clean.substring(dotIndex + 1);
}

bool _extensionMatchesOutput(String extension, String outputFormat) {
  if (outputFormat == 'jpeg') return extension == 'jpg' || extension == 'jpeg';
  return extension == outputFormat;
}

String _withOutputExtension(String fileName, String outputFormat) {
  final extension = _extensionForImageOutputFormat(outputFormat);
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0) return '$fileName.$extension';
  return '${fileName.substring(0, dotIndex)}.$extension';
}

Future<Uint8List> _convertImageBytes(
  List<int> bytes,
  String outputFormat,
) async {
  final source = Uint8List.fromList(bytes);
  final sourceBlob = web.Blob(<JSUint8Array>[source.toJS].toJS);
  final bitmap = await web.window.createImageBitmap(sourceBlob).toDart;
  try {
    final scale = math.min(
      1,
      math.min(
        _maxImageDimension / bitmap.width,
        _maxImageDimension / bitmap.height,
      ),
    );
    final width = math.max(1, (bitmap.width * scale).round());
    final height = math.max(1, (bitmap.height * scale).round());
    final canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (context == null) throw StateError('Canvas 2D context unavailable');
    if (outputFormat == 'jpeg') {
      context
        ..fillStyle = '#ffffff'.toJS
        ..fillRect(0, 0, width, height);
    }
    context.drawImage(bitmap, 0, 0, width, height);

    final blob = await _canvasToBlob(
      canvas,
      _mimeTypeForImageOutputFormat(outputFormat),
    );
    if (blob == null ||
        blob.type.toLowerCase() !=
            _mimeTypeForImageOutputFormat(outputFormat)) {
      throw StateError('Browser did not encode requested image format');
    }
    final buffer = await blob.arrayBuffer().toDart;
    return Uint8List.fromList(buffer.toDart.asUint8List());
  } finally {
    bitmap.close();
  }
}

Future<web.Blob?> _canvasToBlob(web.HTMLCanvasElement canvas, String mimeType) {
  final completer = Completer<web.Blob?>();
  canvas.toBlob(
    ((web.Blob? blob) {
      completer.complete(blob);
    }).toJS,
    mimeType,
    0.92.toJS,
  );
  return completer.future;
}
