import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/network/admin_api_headers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../data/media_download_saver.dart';
import '../data/media_service.dart';
import '../icons/symbols.dart';
import 'admin_toast.dart';

class MediaImageDownloadButton extends StatefulWidget {
  const MediaImageDownloadButton({
    super.key,
    required this.imageUrl,
    this.fileNameSeed,
    this.size = 30,
    this.iconSize = 15,
    this.color = AppColors.deepOcean,
    this.borderColor,
    this.borderRadius,
    this.boxShadow,
  });

  final String imageUrl;
  final String? fileNameSeed;
  final double size;
  final double iconSize;
  final Color color;
  final Color? borderColor;
  final double? borderRadius;
  final List<BoxShadow>? boxShadow;

  @override
  State<MediaImageDownloadButton> createState() =>
      _MediaImageDownloadButtonState();
}

class _MediaImageDownloadButtonState extends State<MediaImageDownloadButton> {
  var _downloading = false;

  Future<void> _download() async {
    final imageUrl = widget.imageUrl.trim();
    if (imageUrl.isEmpty || _downloading) return;
    setState(() => _downloading = true);
    try {
      await downloadMediaImage(
        context,
        imageUrl: imageUrl,
        fileNameSeed: widget.fileNameSeed,
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Görseli indir',
      waitDuration: const Duration(milliseconds: 450),
      child: MouseRegion(
        cursor: _downloading
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _downloading ? null : _download,
          child: Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? AppRadius.value,
              ),
              border: Border.all(
                color: widget.borderColor ?? AppColors.softLine,
              ),
              boxShadow:
                  widget.boxShadow ??
                  [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                    ),
                  ],
            ),
            child: _downloading
                ? SizedBox(
                    width: widget.iconSize,
                    height: widget.iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.7,
                      color: widget.color,
                    ),
                  )
                : Icon(
                    Symbols.download,
                    size: widget.iconSize,
                    color: widget.color,
                  ),
          ),
        ),
      ),
    );
  }
}

Future<void> downloadMediaImage(
  BuildContext context, {
  required String imageUrl,
  String? fileNameSeed,
}) async {
  final current = imageUrl.trim();
  if (current.isEmpty) return;

  final inlineData = _decodeInlineImage(current);
  final extension = inlineData == null
      ? _imageExtension(current)
      : _imageExtensionForMimeType(inlineData.mimeType);
  final mimeType = inlineData?.mimeType ?? _imageMimeType(extension);
  final target = await selectMediaDownloadSaveTarget(
    suggestedName: _imageFileName(
      imageUrl: current,
      fileNameSeed: fileNameSeed,
      extension: extension,
    ),
    mimeType: mimeType,
    extension: extension,
  );
  if (target == null) return;

  try {
    if (inlineData != null) {
      await target.saveBytes(bytes: inlineData.bytes, mimeType: mimeType);
    } else {
      final response = await adminHttpClient
          .get(
            _resolvedImageUri(current),
            headers: {
              ...await adminAuthHeaders(),
              'Accept':
                  'image/avif,image/webp,image/png,image/jpeg,image/*,*/*',
            },
          )
          .timeout(const Duration(seconds: 35));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      await target.saveBytes(
        bytes: response.bodyBytes,
        mimeType: _responseImageMimeType(response.headers) ?? mimeType,
      );
    }
    if (!context.mounted) return;
    AdminToast.show(
      context,
      message: 'Görsel indirildi',
      tone: AdminToastTone.success,
    );
  } catch (error) {
    if (!context.mounted) return;
    AdminToast.show(
      context,
      message: 'Görsel indirilemedi: $error',
      tone: AdminToastTone.error,
    );
  }
}

Uri _resolvedImageUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) return uri;
  return Uri.parse(MediaService().resolveUrl(value));
}

String _imageFileName({
  required String imageUrl,
  required String? fileNameSeed,
  required String extension,
}) {
  final seedSlug = _slug(fileNameSeed ?? '');
  if (seedSlug.isNotEmpty) return '$seedSlug.$extension';

  final uri = Uri.tryParse(imageUrl);
  final lastSegment = uri?.pathSegments.isNotEmpty == true
      ? uri!.pathSegments.last.trim()
      : '';
  if (lastSegment.isNotEmpty && !lastSegment.contains('/')) {
    final clean = lastSegment.split('?').first.split('#').first;
    final dotIndex = clean.lastIndexOf('.');
    if (dotIndex > 0 && dotIndex < clean.length - 1) {
      final name = clean.substring(0, dotIndex);
      final ext = clean.substring(dotIndex + 1).toLowerCase();
      if (_validExtension(ext)) return '${_slug(name)}.$ext';
    }
  }
  return 'haber-gorseli.$extension';
}

String _imageExtension(String value) {
  final clean = value.split('?').first.split('#').first.toLowerCase();
  final dotIndex = clean.lastIndexOf('.');
  if (dotIndex >= 0 && dotIndex < clean.length - 1) {
    final extension = clean.substring(dotIndex + 1);
    if (_validExtension(extension)) return extension;
  }
  return 'webp';
}

bool _validExtension(String value) {
  return RegExp(r'^[a-z0-9]{2,5}$').hasMatch(value);
}

String _imageMimeType(String extension) {
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'avif' => 'image/avif',
    'svg' => 'image/svg+xml',
    _ => 'image/webp',
  };
}

String _imageExtensionForMimeType(String mimeType) {
  return switch (mimeType.split(';').first.trim().toLowerCase()) {
    'image/jpeg' || 'image/jpg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/avif' => 'avif',
    'image/svg+xml' => 'svg',
    _ => 'webp',
  };
}

String? _responseImageMimeType(Map<String, String> headers) {
  final contentType =
      headers['content-type']?.split(';').first.trim().toLowerCase() ?? '';
  return contentType.startsWith('image/') ? contentType : null;
}

_InlineImageData? _decodeInlineImage(String value) {
  if (!value.startsWith('data:image/')) return null;
  final commaIndex = value.indexOf(',');
  if (commaIndex < 0) return null;
  final meta = value.substring(5, commaIndex).toLowerCase();
  final payload = value.substring(commaIndex + 1);
  final mimeType = meta.split(';').first.trim();
  if (!mimeType.startsWith('image/')) return null;
  final bytes = meta.contains(';base64')
      ? base64Decode(payload)
      : Uint8List.fromList(utf8.encode(Uri.decodeComponent(payload)));
  return _InlineImageData(bytes: bytes, mimeType: mimeType);
}

String _slug(String value) {
  var output = value.trim().toLowerCase();
  const replacements = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'i̇': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
  };
  replacements.forEach((key, replacement) {
    output = output.replaceAll(key, replacement);
  });
  output = output
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  if (output.length <= 70) return output;
  return output.substring(0, 70).replaceAll(RegExp(r'-$'), '');
}

class _InlineImageData {
  const _InlineImageData({required this.bytes, required this.mimeType});

  final List<int> bytes;
  final String mimeType;
}
