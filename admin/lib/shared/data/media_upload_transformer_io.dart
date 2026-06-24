import 'dart:io';
import 'dart:typed_data';

class PreparedMediaUpload {
  const PreparedMediaUpload({required this.fileName, required this.bytes});

  final String fileName;
  final List<int> bytes;
}

const _directCwebpExtensions = {
  'bmp',
  'jpeg',
  'jpg',
  'png',
  'tif',
  'tiff',
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

  final converted = await _convertImageBytes(
    sourceExtension: sourceExtension,
    bytes: bytes,
    outputFormat: outputFormat,
  );
  if (converted == null) {
    return PreparedMediaUpload(fileName: fileName, bytes: bytes);
  }

  return PreparedMediaUpload(
    fileName: _withOutputExtension(fileName, outputFormat),
    bytes: converted,
  );
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

Future<Uint8List?> _convertImageBytes({
  required String sourceExtension,
  required List<int> bytes,
  required String outputFormat,
}) async {
  final tempDir = await Directory.systemTemp.createTemp('pateez-media-upload-');
  final inputExtension = sourceExtension.isEmpty ? 'bin' : sourceExtension;
  final inputFile = File('${tempDir.path}/input.$inputExtension');
  final outputFile = File(
    '${tempDir.path}/output.${_extensionForImageOutputFormat(outputFormat)}',
  );
  try {
    await inputFile.writeAsBytes(bytes, flush: true);
    final result = outputFormat == 'webp'
        ? await _convertToWebp(inputFile, outputFile, sourceExtension)
        : await _convertWithSips(inputFile, outputFile, outputFormat);
    if (!result || !await outputFile.exists()) return null;
    return await outputFile.readAsBytes();
  } finally {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  }
}

Future<bool> _convertToWebp(
  File inputFile,
  File outputFile,
  String sourceExtension,
) async {
  final cwebp = await _resolveExecutable('cwebp', const [
    '/opt/homebrew/bin/cwebp',
    '/usr/local/bin/cwebp',
  ]);
  if (cwebp == null) return false;

  File cwebpInput = inputFile;
  File? normalizedInput;
  if (!_directCwebpExtensions.contains(sourceExtension)) {
    normalizedInput = File('${inputFile.parent.path}/normalized.png');
    final normalized = await _convertWithSips(
      inputFile,
      normalizedInput,
      'png',
    );
    if (!normalized) return false;
    cwebpInput = normalizedInput;
  }

  try {
    final result = await Process.run(cwebp, [
      '-quiet',
      '-q',
      '92',
      cwebpInput.path,
      '-o',
      outputFile.path,
    ]);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Future<bool> _convertWithSips(
  File inputFile,
  File outputFile,
  String outputFormat,
) async {
  final sips = await _resolveExecutable('sips', const ['/usr/bin/sips']);
  if (sips == null) return false;
  final sipsFormat = outputFormat == 'jpeg' ? 'jpeg' : outputFormat;
  try {
    final result = await Process.run(sips, [
      '-s',
      'format',
      sipsFormat,
      inputFile.path,
      '--out',
      outputFile.path,
    ]);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Future<String?> _resolveExecutable(
  String executable,
  List<String> absoluteCandidates,
) async {
  for (final candidate in absoluteCandidates) {
    if (await File(candidate).exists()) return candidate;
  }
  try {
    final result = await Process.run('which', [executable]);
    if (result.exitCode != 0) return null;
    final paths = result.stdout.toString().trim().split('\n');
    final path = paths.isEmpty ? null : paths.first;
    return path == null || path.isEmpty ? null : path;
  } on ProcessException {
    return null;
  }
}
