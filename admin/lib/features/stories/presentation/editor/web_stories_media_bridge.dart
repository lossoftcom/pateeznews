import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pateeznews_admin/shared/data/media_service.dart';

typedef WebStoriesMediaPicker = Future<String?> Function(String mediaType);

/// Bridges the embedded Web Stories editor's media apiCallbacks
/// (MEDIA_LIST / MEDIA_PICK / MEDIA_UPLOAD / MEDIA_UPDATE / MEDIA_DELETE) to the admin's
/// storage backend via [MediaService]. Shared by the native (webview) and web
/// (iframe) editor hosts so the wiring lives in exactly one place.
class WebStoriesMediaBridge {
  WebStoriesMediaBridge({MediaService? mediaService, this.pickMedia})
    : _media = mediaService ?? MediaService();

  final MediaService _media;
  final WebStoriesMediaPicker? pickMedia;

  /// Handles a single editor->host media request and returns the result message
  /// to post back (already shaped as `${type}_RESULT` with the requestId), or
  /// null if [message] is not a media request this bridge owns.
  Future<Map<String, dynamic>?> handle(Map<String, dynamic> message) async {
    final type = message['type']?.toString();
    final requestId = message['requestId']?.toString();
    if (type == null || requestId == null) return null;
    switch (type) {
      case 'MEDIA_LIST':
        return _list(requestId, message);
      case 'MEDIA_PICK':
        return _pick(requestId, message);
      case 'MEDIA_UPLOAD':
        return _upload(requestId, message);
      case 'MEDIA_DELETE':
        return _delete(requestId, message);
      case 'MEDIA_UPDATE':
        // Alt-text/metadata edits are best-effort; acknowledge so the editor
        // never blocks on them.
        return {
          'type': 'MEDIA_UPDATE_RESULT',
          'requestId': requestId,
          'ok': true,
        };
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>> _list(
    String requestId,
    Map<String, dynamic> message,
  ) async {
    final mediaType = (message['mediaType'] ?? '').toString().trim();
    try {
      final types = mediaType.isEmpty
          ? const ['image', 'video', 'audio']
          : <String>[mediaType];
      final items = <Map<String, dynamic>>[];
      for (final type in types) {
        final files = await _media.listFiles(type: type);
        for (final file in files) {
          items.add(_mapItem(file, type));
        }
      }
      return {
        'type': 'MEDIA_LIST_RESULT',
        'requestId': requestId,
        'ok': true,
        'items': items,
      };
    } catch (error) {
      return {
        'type': 'MEDIA_LIST_RESULT',
        'requestId': requestId,
        'ok': false,
        'error': error.toString(),
        'items': const <Map<String, dynamic>>[],
      };
    }
  }

  Future<Map<String, dynamic>> _pick(
    String requestId,
    Map<String, dynamic> message,
  ) async {
    final picker = pickMedia;
    if (picker == null) {
      return {
        'type': 'MEDIA_PICK_RESULT',
        'requestId': requestId,
        'ok': false,
        'error': 'Media picker unavailable',
      };
    }

    final mediaType = _mediaTypeFromMessage(message);
    try {
      final selected = await picker(mediaType);
      if (selected == null || selected.trim().isEmpty) {
        return {
          'type': 'MEDIA_PICK_RESULT',
          'requestId': requestId,
          'ok': false,
          'cancelled': true,
        };
      }
      final item = await _findSelectedItem(selected, mediaType);
      return {
        'type': 'MEDIA_PICK_RESULT',
        'requestId': requestId,
        'ok': true,
        'item': item != null
            ? _mapItem(item, mediaType)
            : _mapSelectedUrl(selected, mediaType),
      };
    } catch (error) {
      return {
        'type': 'MEDIA_PICK_RESULT',
        'requestId': requestId,
        'ok': false,
        'error': error.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _upload(
    String requestId,
    Map<String, dynamic> message,
  ) async {
    try {
      final fileName = (message['fileName'] ?? 'upload').toString();
      final type = _mediaTypeFromMessage(message);
      final bytes = base64Decode((message['dataBase64'] ?? '').toString());
      final item = await _media.uploadFile(
        fileName: fileName,
        bytes: bytes,
        type: type,
      );
      if (item == null) {
        return {
          'type': 'MEDIA_UPLOAD_RESULT',
          'requestId': requestId,
          'ok': false,
          'error': 'Yukleme basarisiz',
        };
      }
      return {
        'type': 'MEDIA_UPLOAD_RESULT',
        'requestId': requestId,
        'ok': true,
        'item': _mapItem(item, type),
      };
    } catch (error) {
      return {
        'type': 'MEDIA_UPLOAD_RESULT',
        'requestId': requestId,
        'ok': false,
        'error': error.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _delete(
    String requestId,
    Map<String, dynamic> message,
  ) async {
    try {
      final id = (message['id'] ?? '').toString();
      final mediaType = (message['mediaType'] ?? '').toString().trim();
      final ok = await _media.deleteFile(
        id,
        type: mediaType.isEmpty ? null : mediaType,
      );
      return {'type': 'MEDIA_DELETE_RESULT', 'requestId': requestId, 'ok': ok};
    } catch (error) {
      return {
        'type': 'MEDIA_DELETE_RESULT',
        'requestId': requestId,
        'ok': false,
        'error': error.toString(),
      };
    }
  }

  Map<String, dynamic> _mapItem(MediaItem file, String fallbackType) {
    final thumb = file.thumb;
    return {
      'id': file.id,
      'src': _absolute(file.src),
      'thumb': (thumb != null && thumb.isNotEmpty) ? _absolute(thumb) : null,
      'type': file.type.isNotEmpty ? file.type : fallbackType,
      'value': file.value,
    };
  }

  Future<MediaItem?> _findSelectedItem(String selected, String type) async {
    final resolvedSelected = _absolute(selected);
    final files = await _media.listFiles(type: type);
    for (final file in files) {
      if (file.src == selected ||
          _absolute(file.src) == selected ||
          _absolute(file.src) == resolvedSelected) {
        return file;
      }
    }
    return null;
  }

  Map<String, dynamic> _mapSelectedUrl(String src, String fallbackType) {
    final absoluteSrc = _absolute(src);
    return {
      'id': absoluteSrc,
      'src': absoluteSrc,
      'thumb': fallbackType == 'image' ? absoluteSrc : null,
      'type': fallbackType,
      'value': _fileNameFromUrl(src),
    };
  }

  String _mediaTypeFromMessage(Map<String, dynamic> message) {
    final raw = (message['mediaType'] ?? message['kind'] ?? 'image')
        .toString()
        .trim()
        .toLowerCase();
    return switch (raw) {
      'video' => 'video',
      'audio' => 'audio',
      _ => 'image',
    };
  }

  // The native host serves the editor from a localhost server, so relative
  // storage paths must be absolutized against the real API base.
  String _absolute(String url) {
    final value = url.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:')) {
      return _editorSafeUrl(value);
    }
    return _editorSafeUrl(_media.resolveUrl(value));
  }

  String _editorSafeUrl(String value) {
    final uri = Uri.tryParse(value);
    if (kIsWeb || uri == null || uri.host != '127.0.0.1') return value;
    return uri.replace(host: 'localhost').toString();
  }

  String _fileNameFromUrl(String value) {
    final uri = Uri.tryParse(value);
    final path = uri?.path.trim().isNotEmpty == true ? uri!.path : value;
    final raw = path.split('/').where((part) => part.isNotEmpty).lastOrNull;
    if (raw == null || raw.trim().isEmpty) return value;
    try {
      return Uri.decodeComponent(raw);
    } catch (_) {
      return raw;
    }
  }
}
