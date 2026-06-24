class PreparedMediaUpload {
  const PreparedMediaUpload({required this.fileName, required this.bytes});

  final String fileName;
  final List<int> bytes;
}

Future<PreparedMediaUpload> prepareMediaUploadForStorage({
  required String fileName,
  required List<int> bytes,
  required String type,
  required String imageFileFormat,
  bool forceImageEncoding = false,
}) async {
  return PreparedMediaUpload(fileName: fileName, bytes: bytes);
}
