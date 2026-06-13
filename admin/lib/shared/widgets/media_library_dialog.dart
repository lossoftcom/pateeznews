import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:video_player/video_player.dart';

import '../../core/localization/admin_language_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../data/media_service.dart';
import 'admin_cached_image.dart';

const _mlBorder = Color(0xFFDDE5E8);
const _mlSoftBorder = Color(0xFFE8EEF1);
const _mlMuted = Color(0xFF5F6F78);
const _mlSurface = Color(0xFFFAFBFC);
const _mlSelected = Color(0xFF10B981);
const _mlSelectedDeep = Color(0xFF047857);

String _fileExtension(String value) {
  final clean = value.split('?').first.split('#').first.toLowerCase();
  final dotIndex = clean.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == clean.length - 1) return '';
  return clean.substring(dotIndex + 1);
}

String _formatMegabytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  if (mb == mb.roundToDouble()) return mb.toInt().toString();
  return mb.toStringAsFixed(1);
}

Future<String?> showMediaLibraryDialog(
  BuildContext context, {
  String type = 'image',
  MediaService? mediaService,
}) async {
  final result = await showGeneralDialog<Object?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'MediaLibrary',
    barrierColor: AppColors.deepOcean.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (context, a1, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.97,
            end: 1.0,
          ).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, _) => _MediaLibraryDialog(
      type: type,
      multiSelect: false,
      mediaService: mediaService ?? MediaService(),
    ),
  );
  return result is String ? result : null;
}

Future<List<String>?> showMediaLibraryMultiDialog(
  BuildContext context, {
  String type = 'image',
  MediaService? mediaService,
}) async {
  final result = await showGeneralDialog<Object?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'MediaLibrary',
    barrierColor: AppColors.deepOcean.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (context, a1, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.97,
            end: 1.0,
          ).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, _) => _MediaLibraryDialog(
      type: type,
      multiSelect: true,
      mediaService: mediaService ?? MediaService(),
    ),
  );
  return result is List<String> ? result : null;
}

class _MediaLibraryDialog extends StatefulWidget {
  const _MediaLibraryDialog({
    required this.type,
    required this.multiSelect,
    required this.mediaService,
  });

  final String type;
  final bool multiSelect;
  final MediaService mediaService;

  @override
  State<_MediaLibraryDialog> createState() => _MediaLibraryDialogState();
}

class _MediaLibraryDialogState extends State<_MediaLibraryDialog> {
  final _files = <MediaItem>[];
  final _resolvedUrls = <String, String>{};
  final _selectedSrcs = ValueNotifier<Set<String>>(<String>{});
  final _searchTerm = ValueNotifier<String>('');
  String? _lastSelectedSrc;

  var _loading = true;
  var _uploading = false;
  var _uploadProcessing = false;
  double? _uploadProgress;
  Duration? _uploadRemaining;
  var _uploadBatchIndex = 0;
  var _uploadBatchTotal = 0;
  var _busyFileId = '';
  var _uploadSettings = MediaUploadSettings.defaults();
  String? _uploadSettingsLanguageCode;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = AdminLocalizationScope.maybeOf(context)?.code ?? 'tr';
    if (_uploadSettingsLanguageCode == languageCode) return;
    _uploadSettingsLanguageCode = languageCode;
    final cached = MediaService.cachedUploadSettings(
      languageCode: languageCode,
    );
    if (cached != null) {
      _uploadSettings = cached;
    }
    unawaited(_loadUploadSettings(languageCode));
  }

  @override
  void dispose() {
    _selectedSrcs.dispose();
    _searchTerm.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    try {
      final files = await widget.mediaService.listFiles(type: widget.type);
      if (!mounted) return;
      setState(() {
        _files
          ..clear()
          ..addAll(files);
        for (final f in files) {
          final raw = f.thumb ?? f.src;
          _resolvedUrls[f.id] = widget.type == 'image'
              ? widget.mediaService.resolveImageUrl(
                  raw,
                  width: 260,
                  quality: 86,
                )
              : widget.mediaService.resolveUrl(raw);
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadUploadSettings(String languageCode) async {
    try {
      final settings = await widget.mediaService.fetchUploadSettings(
        languageCode: languageCode,
      );
      if (!mounted || _uploadSettingsLanguageCode != languageCode) return;
      setState(() => _uploadSettings = settings);
    } catch (_) {}
  }

  List<MediaItem> get _filteredFiles {
    final q = _searchTerm.value.trim().toLowerCase();
    if (q.isEmpty) return _files;
    return _files.where((f) => f.value.toLowerCase().contains(q)).toList();
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    final extensions = _uploadSettings.extensionsFor(widget.type);
    final typeNotAllowedMessage = context.t('media.uploadTypeNotAllowed');
    final tooLargeMessageTemplate = context.t('media.uploadTooLarge');
    final files = extensions.isEmpty
        ? await openFiles()
        : await openFiles(
            acceptedTypeGroups: [
              XTypeGroup(label: widget.type, extensions: extensions),
            ],
          );
    if (files.isEmpty) return;

    final maxBytes = _uploadSettings.maxBytesFor(widget.type);
    for (final file in files) {
      final fileExtension = _fileExtension(file.name);
      if (extensions.isNotEmpty &&
          (fileExtension.isEmpty || !extensions.contains(fileExtension))) {
        if (!mounted) return;
        _showUploadMessage(typeNotAllowedMessage);
        return;
      }

      final fileLength = await file.length();
      if (fileLength > maxBytes) {
        if (!mounted) return;
        _showUploadMessage(
          tooLargeMessageTemplate.replaceAll(
            '{size}',
            _formatMegabytes(maxBytes),
          ),
        );
        return;
      }
    }

    setState(() {
      _uploading = true;
      _uploadProcessing = false;
      _uploadProgress = 0;
      _uploadRemaining = null;
      _uploadBatchIndex = 0;
      _uploadBatchTotal = files.length;
    });
    final uploaded = <MediaItem>[];
    try {
      for (var index = 0; index < files.length; index += 1) {
        final file = files[index];
        if (!mounted) return;
        setState(() {
          _uploadBatchIndex = index + 1;
          _uploadProcessing = false;
          _uploadProgress = files.length == 1 ? 0 : index / files.length;
          _uploadRemaining = null;
        });

        final bytes = await file.readAsBytes();
        final result = await widget.mediaService.uploadFile(
          fileName: file.name,
          bytes: bytes,
          type: widget.type,
          onTransferProgress: (progress) {
            if (!mounted) return;
            final fileProgress = progress.progress;
            final aggregateProgress = fileProgress == null
                ? null
                : ((index + fileProgress) / files.length).clamp(0.0, 1.0);
            setState(() {
              _uploadProgress = aggregateProgress;
              _uploadProcessing = progress.phase == 'processing';
              _uploadRemaining = progress.remaining;
            });
          },
        );
        if (result == null || !mounted) continue;
        final raw = result.thumb ?? result.src;
        _resolvedUrls[result.id] = widget.type == 'image'
            ? widget.mediaService.resolveImageUrl(raw, width: 260, quality: 86)
            : widget.mediaService.resolveUrl(raw);
        uploaded.add(result);
        _lastSelectedSrc = result.src;
      }
      if (uploaded.isNotEmpty && mounted) {
        setState(() {
          _files
            ..insertAll(0, uploaded.reversed)
            ..sort(compareNewestMedia);
        });
        _selectedSrcs.value = widget.multiSelect
            ? uploaded.map((file) => file.src).toSet()
            : {_lastSelectedSrc ?? uploaded.last.src};
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _uploading = false;
        _uploadProcessing = false;
        _uploadProgress = null;
        _uploadRemaining = null;
        _uploadBatchIndex = 0;
        _uploadBatchTotal = 0;
      });
    }
  }

  void _showUploadMessage(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteFile(MediaItem file) async {
    if (_busyFileId.isNotEmpty) return;
    setState(() => _busyFileId = file.id);
    try {
      final ok = await widget.mediaService.deleteFile(file.id, type: file.type);
      if (ok && mounted) {
        setState(() {
          _files.removeWhere((f) => f.id == file.id);
          _resolvedUrls.remove(file.id);
        });
        if (_selectedSrcs.value.contains(file.src)) {
          final next = Set<String>.of(_selectedSrcs.value)..remove(file.src);
          _selectedSrcs.value = next;
          _lastSelectedSrc = next.lastOrNull;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _busyFileId = '');
  }

  Future<void> _deleteSelectedFromFooter() async {
    final selected = _selectedSrcs.value;
    if (selected.isEmpty) return;
    final files = _files.where((f) => selected.contains(f.src)).toList();
    for (final file in files) {
      await _deleteFile(file);
    }
  }

  Future<void> _openEditModal(MediaItem file) async {
    if (file.type == 'image') {
      await _openImageEditor(file);
      return;
    }

    if (file.type == 'audio') {
      final audioUrl = file.src.startsWith('http')
          ? file.src
          : widget.mediaService.resolveUrl(file.src);
      await showDialog<void>(
        context: context,
        barrierColor: AppColors.deepOcean.withValues(alpha: 0.45),
        builder: (_) =>
            _AudioPreviewModal(fileName: file.value, mediaUrl: audioUrl),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.deepOcean.withValues(alpha: 0.45),
      builder: (_) => _ImageEditModal(initialName: file.value),
    );
  }

  Future<void> _openPreviewModal(MediaItem file) async {
    if (file.type != 'image') return;
    final imageUrl = widget.mediaService.resolveImageUrl(
      file.src,
      width: 1600,
      quality: 90,
    );
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.deepOcean.withValues(alpha: 0.50),
      builder: (_) =>
          _ImagePreviewModal(fileName: file.value, imageUrl: imageUrl),
    );
  }

  Future<void> _openImageEditor(MediaItem file) async {
    final imageUrl = file.src.startsWith('http')
        ? file.src
        : widget.mediaService.resolveUrl(file.src);
    if (!mounted) return;

    final baseTheme = Theme.of(context);
    var editorClosing = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.deepOcean.withValues(alpha: 0.58),
      builder: (editorContext) {
        final size = MediaQuery.sizeOf(editorContext);
        final width = (size.width * 0.76).clamp(860.0, 1280.0);
        final height = (size.height * 0.72).clamp(560.0, 760.0);

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 48,
            vertical: 42,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            height: height,
            child: ProImageEditor.network(
              imageUrl,
              configs: ProImageEditorConfigs(
                theme: baseTheme.copyWith(
                  colorScheme: baseTheme.colorScheme.copyWith(
                    primary: AppColors.deepOcean,
                    secondary: AppColors.actionRed,
                  ),
                ),
                imageGeneration: const ImageGenerationConfigs(
                  outputFormat: OutputFormat.png,
                  maxOutputSize: Size(7680, 7680),
                ),
                textEditor: const TextEditorConfigs(
                  showSelectFontStyleBottomBar: true,
                  showTextAlignButton: true,
                  showFontScaleButton: true,
                  showBackgroundModeButton: true,
                  defaultTextStyle: TextStyle(
                    fontFamily: 'PateezSans',
                    fontWeight: FontWeight.w600,
                  ),
                  customTextStyles: [
                    TextStyle(
                      fontFamily: 'PateezSans',
                      fontWeight: FontWeight.w400,
                    ),
                    TextStyle(
                      fontFamily: 'PateezSans',
                      fontWeight: FontWeight.w700,
                    ),
                    TextStyle(
                      fontFamily: 'PateezSans',
                      fontWeight: FontWeight.w800,
                    ),
                    TextStyle(
                      fontFamily: 'PateezSans',
                      fontStyle: FontStyle.italic,
                    ),
                    TextStyle(
                      fontFamily: 'PateezSans',
                      decoration: TextDecoration.underline,
                    ),
                    TextStyle(
                      fontFamily: 'PateezSans',
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                    ),
                    TextStyle(
                      fontFamily: 'PateezSans',
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ],
                ),
              ),
              callbacks: ProImageEditorCallbacks(
                onCloseEditor: (_) {
                  if (editorClosing || !editorContext.mounted) return;
                  editorClosing = true;
                  Navigator.of(editorContext).pop();
                },
                onImageEditingComplete: (bytes) async {
                  if (mounted) setState(() => _busyFileId = file.id);
                  try {
                    final result = await widget.mediaService.replaceFile(
                      fileId: file.id,
                      fileName: file.value,
                      bytes: bytes,
                      type: file.type,
                    );
                    if (result != null && mounted) {
                      final version = DateTime.now().millisecondsSinceEpoch;
                      setState(() {
                        final index = _files.indexWhere((f) => f.id == file.id);
                        if (index != -1) {
                          _files[index] = result;
                        }
                        _resolvedUrls[result.id] = widget.mediaService
                            .resolveImageUrl(
                              '${result.thumb ?? result.src}?v=$version',
                              width: 260,
                              quality: 86,
                            );
                      });
                    }
                  } finally {
                    if (mounted) setState(() => _busyFileId = '');
                    if (editorContext.mounted) {
                      editorClosing = true;
                      Navigator.of(editorContext).pop();
                    }
                  }
                },
                mainEditorCallbacks: MainEditorCallbacks(
                  onKeyboardEvent: (event) {
                    if (event is! KeyDownEvent ||
                        event.logicalKey != LogicalKeyboardKey.escape) {
                      return false;
                    }
                    if (!editorClosing && editorContext.mounted) {
                      editorClosing = true;
                      Navigator.of(editorContext).pop();
                    }
                    return true;
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
    if (mounted && _busyFileId == file.id) setState(() => _busyFileId = '');
  }

  void _close([Object? value]) => Navigator.of(context).pop(value);

  void _clearSelection() {
    if (_selectedSrcs.value.isEmpty) return;
    _lastSelectedSrc = null;
    _selectedSrcs.value = <String>{};
  }

  void _toggleSelection(MediaItem file) {
    final selected = Set<String>.of(_selectedSrcs.value);
    if (HardwareKeyboard.instance.isShiftPressed) {
      if (!selected.remove(file.src)) {
        selected.add(file.src);
        _lastSelectedSrc = file.src;
      } else if (_lastSelectedSrc == file.src) {
        _lastSelectedSrc = selected.lastOrNull;
      }
    } else {
      selected
        ..clear()
        ..add(file.src);
      _lastSelectedSrc = file.src;
    }
    _selectedSrcs.value = selected;
  }

  MediaItem? _fileBySrc(String? src) {
    if (src == null) return null;
    for (final file in _files) {
      if (file.src == src) return file;
    }
    return null;
  }

  MediaItem? _selectedImageFile() {
    final selected = _selectedSrcs.value;
    if (selected.isEmpty) return null;

    final lastSelected = _fileBySrc(_lastSelectedSrc);
    if (lastSelected != null &&
        selected.contains(lastSelected.src) &&
        lastSelected.type == 'image') {
      return lastSelected;
    }

    for (final src in selected.toList().reversed) {
      final file = _fileBySrc(src);
      if (file != null && file.type == 'image') return file;
    }
    return null;
  }

  Future<void> _openSelectedImagePreviewOr(
    FutureOr<void> Function() fallback,
  ) async {
    final file = _selectedImageFile();
    if (file == null) {
      await fallback();
      return;
    }
    await _openPreviewModal(file);
  }

  void _useFile(MediaItem file) {
    if (widget.multiSelect) {
      _toggleSelection(file);
      return;
    }
    _lastSelectedSrc = file.src;
    _selectedSrcs.value = {file.src};
    _close(file.src);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.86).clamp(720.0, 1240.0);
    final height = (size.height * 0.80).clamp(500.0, 820.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _Header(searchTerm: _searchTerm, onClose: _close),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _UploadSidebar(
                      type: widget.type,
                      settings: _uploadSettings,
                      uploading: _uploading,
                      uploadProgress: _uploadProgress,
                      processing: _uploadProcessing,
                      remaining: _uploadRemaining,
                      batchIndex: _uploadBatchIndex,
                      batchTotal: _uploadBatchTotal,
                      onPickFile: _pickAndUpload,
                      onEmptyTap: () => unawaited(
                        _openSelectedImagePreviewOr(_pickAndUpload),
                      ),
                    ),
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: _searchTerm,
                        builder: (_, _, _) {
                          if (_loading) return const _LoadingState();
                          final filtered = _filteredFiles;
                          if (filtered.isEmpty) {
                            return _EmptyState(type: widget.type);
                          }
                          return _ImageGrid(
                            files: filtered,
                            resolvedUrls: _resolvedUrls,
                            selectedSrcs: _selectedSrcs,
                            busyFileId: _busyFileId,
                            onSelect: _toggleSelection,
                            onUseFile: _useFile,
                            onGridTap: () => unawaited(
                              _openSelectedImagePreviewOr(_clearSelection),
                            ),
                            onPreview: (file) =>
                                unawaited(_openPreviewModal(file)),
                            onEdit: _openEditModal,
                            onDelete: _deleteFile,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _Footer(
                selectedSrcs: _selectedSrcs,
                uploading: _uploading,
                onUse: () {
                  if (widget.multiSelect) {
                    _close(_selectedSrcs.value.toList(growable: false));
                    return;
                  }
                  _close(_lastSelectedSrc ?? _selectedSrcs.value.lastOrNull);
                },
                onClose: _close,
                onDeleteSelected: _deleteSelectedFromFooter,
                type: widget.type,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.searchTerm, required this.onClose});

  final ValueNotifier<String> searchTerm;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _mlSoftBorder)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _SearchField(searchTerm: searchTerm),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.actionRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  context.t('media.title'),
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _HoverIconButton(
              icon: Icons.close_rounded,
              onTap: onClose,
              hoverColor: AppColors.actionRed.withValues(alpha: 0.08),
              hoverIconColor: AppColors.actionRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.searchTerm});

  final ValueNotifier<String> searchTerm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextField(
        onChanged: (v) => searchTerm.value = v,
        cursorColor: AppColors.deepOcean,
        cursorHeight: 14,
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: context.t('media.search'),
          hintStyle: TextStyle(
            color: AppColors.placeholder.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 8),
            child: Icon(
              Icons.search_rounded,
              size: 18,
              color: AppColors.placeholder,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          filled: true,
          fillColor: _mlSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            borderSide: const BorderSide(color: _mlBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            borderSide: const BorderSide(color: _mlBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            borderSide: const BorderSide(
              color: AppColors.deepOcean,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UPLOAD SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────
class _UploadSidebar extends StatelessWidget {
  const _UploadSidebar({
    required this.type,
    required this.settings,
    required this.uploading,
    required this.uploadProgress,
    required this.processing,
    required this.remaining,
    required this.batchIndex,
    required this.batchTotal,
    required this.onPickFile,
    required this.onEmptyTap,
  });

  final String type;
  final MediaUploadSettings settings;
  final bool uploading;
  final double? uploadProgress;
  final bool processing;
  final Duration? remaining;
  final int batchIndex;
  final int batchTotal;
  final VoidCallback onPickFile;
  final VoidCallback onEmptyTap;

  List<String> _extensions(BuildContext context) {
    final extensions = settings.extensionsFor(type);
    if (extensions.isEmpty) return [context.t('media.allFiles')];
    return extensions.map((extension) => extension.toUpperCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      decoration: const BoxDecoration(
        color: _mlSurface,
        border: Border(right: BorderSide(color: _mlSoftBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MouseRegion(
          cursor: uploading
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: GestureDetector(
            onTap: uploading ? null : onEmptyTap,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              child: CustomPaint(
                painter: _DashedPainter(color: _mlBorder, active: uploading),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 22,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Extension chips
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        alignment: WrapAlignment.center,
                        children: _extensions(context)
                            .map((ext) => _ExtChip(text: ext, type: type))
                            .toList(),
                      ),
                      const SizedBox(height: 26),
                      // Upload icon disc
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: uploading
                              ? AppColors.deepOcean.withValues(alpha: 0.08)
                              : AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: uploading
                                ? AppColors.deepOcean.withValues(alpha: 0.15)
                                : _mlSoftBorder,
                            width: 1.2,
                          ),
                        ),
                        child: uploading
                            ? Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: processing ? null : uploadProgress,
                                  color: AppColors.deepOcean,
                                ),
                              )
                            : Icon(
                                Icons.cloud_upload_outlined,
                                size: 26,
                                color: _mlMuted.withValues(alpha: 0.55),
                              ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        uploading
                            ? _uploadStatusText(context)
                            : context.t('media.dragDrop'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _mlMuted.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          letterSpacing: 0.1,
                        ),
                      ),
                      if (uploading) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 210,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.value,
                            ),
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              value: uploadProgress,
                              backgroundColor: _mlSoftBorder,
                              color: processing
                                  ? AppColors.actionRed
                                  : AppColors.deepOcean,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _remainingText(context),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _mlMuted.withValues(alpha: 0.7),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _BrowseButton(enabled: !uploading, onTap: onPickFile),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _uploadStatusText(BuildContext context) {
    final progress = uploadProgress;
    final percent = progress == null
        ? null
        : (progress.clamp(0, 1) * 100).round();
    final phase = processing
        ? context.t('media.processingVideo')
        : context.t('media.uploading');
    final batch = batchTotal > 1 ? ' $batchIndex/$batchTotal' : '';
    if (percent == null) return '$phase$batch';
    return '$phase$batch $percent%';
  }

  String _remainingText(BuildContext context) {
    final value = remaining;
    if (value == null) return context.t('media.remainingCalculating');
    return '${context.t('media.remaining')}: ${_formatRemaining(value)}';
  }

  String _formatRemaining(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 24 * 60 * 60).toInt();
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final hourMinutes = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${hourMinutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }
}

class _ExtChip extends StatelessWidget {
  const _ExtChip({required this.text, required this.type});

  final String text;
  final String type;

  Color get _accentColor => switch (type) {
    'video' => AppColors.actionRed,
    'audio' => AppColors.warmHorizon,
    'file' => AppColors.support,
    _ => _mlMuted,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final solid = type == 'video' || type == 'audio' || type == 'file';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: solid ? accent : _mlSurface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(
          color: solid ? accent.withValues(alpha: 0.92) : _mlSoftBorder,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: solid ? Colors.white : _mlMuted.withValues(alpha: 0.75),
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _BrowseButton extends StatefulWidget {
  const _BrowseButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_BrowseButton> createState() => _BrowseButtonState();
}

class _BrowseButtonState extends State<_BrowseButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled;
    return SizedBox(
      width: 210,
      height: 40,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: disabled ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: disabled
                  ? AppColors.deepOcean.withValues(alpha: 0.4)
                  : _hover
                  ? AppColors.deepOcean
                  : const Color(0xFF34495E),
              borderRadius: BorderRadius.circular(AppRadius.value),
              boxShadow: _hover && !disabled
                  ? [
                      BoxShadow(
                        color: AppColors.deepOcean.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  context.t('media.browse'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE GRID
// ─────────────────────────────────────────────────────────────────────────────
class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.files,
    required this.resolvedUrls,
    required this.selectedSrcs,
    required this.busyFileId,
    required this.onSelect,
    required this.onUseFile,
    required this.onGridTap,
    required this.onPreview,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MediaItem> files;
  final Map<String, String> resolvedUrls;
  final ValueNotifier<Set<String>> selectedSrcs;
  final String busyFileId;
  final ValueChanged<MediaItem> onSelect;
  final ValueChanged<MediaItem> onUseFile;
  final VoidCallback onGridTap;
  final ValueChanged<MediaItem> onPreview;
  final ValueChanged<MediaItem> onEdit;
  final ValueChanged<MediaItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final videoMode = files.every((file) => file.type == 'video');
    return Container(
      color: Colors.white,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onGridTap,
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: videoMode ? 148 : 126,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: videoMode ? 0.74 : 0.66,
          ),
          itemCount: files.length,
          itemBuilder: (_, index) {
            final file = files[index];
            return RepaintBoundary(
              child: _ImageCard(
                file: file,
                thumbUrl: resolvedUrls[file.id] ?? file.src,
                selectedSrcs: selectedSrcs,
                busy: busyFileId == file.id,
                onSelect: () => onSelect(file),
                onDoubleSelect: () => onUseFile(file),
                onPreview: () => onPreview(file),
                onEdit: () => onEdit(file),
                onDelete: () => onDelete(file),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ImageCard extends StatefulWidget {
  const _ImageCard({
    required this.file,
    required this.thumbUrl,
    required this.selectedSrcs,
    required this.busy,
    required this.onSelect,
    required this.onDoubleSelect,
    required this.onPreview,
    required this.onEdit,
    required this.onDelete,
  });

  final MediaItem file;
  final String thumbUrl;
  final ValueNotifier<Set<String>> selectedSrcs;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onDoubleSelect;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<_ImageCard> {
  var _hover = false;
  DateTime? _lastTapAt;

  void _handleTap() {
    final now = DateTime.now();
    final isDoubleTap =
        _lastTapAt != null &&
        now.difference(_lastTapAt!) <= const Duration(milliseconds: 320);
    _lastTapAt = isDoubleTap ? null : now;
    if (isDoubleTap) {
      widget.onDoubleSelect();
      return;
    }
    widget.onSelect();
  }

  Future<void> _showMenu(BuildContext context, Offset position) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final result = await showMenu<String>(
      context: context,
      color: Colors.white,
      elevation: 10,
      shadowColor: AppColors.deepOcean.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
        side: const BorderSide(color: _mlBorder),
      ),
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        _menuItem(
          value: 'edit',
          icon: Icons.edit_outlined,
          label: context.t('media.edit'),
          color: AppColors.deepOcean,
        ),
        _menuItem(
          value: 'delete',
          icon: Icons.delete_outline_rounded,
          label: context.t('media.delete'),
          color: AppColors.actionRed,
        ),
      ],
    );

    if (result == 'edit') widget.onEdit();
    if (result == 'delete') widget.onDelete();
  }

  PopupMenuItem<String> _menuItem({
    required String value,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: widget.selectedSrcs,
      builder: (_, selectedSrcs, _) {
        final selected = selectedSrcs.contains(widget.file.src);
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _handleTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.value),
                      border: Border.all(
                        color: selected
                            ? _mlSelected
                            : _hover
                            ? AppColors.deepOcean.withValues(alpha: 0.35)
                            : _mlBorder,
                        width: selected ? 1.8 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: _mlSelected.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : _hover
                          ? [
                              BoxShadow(
                                color: AppColors.deepOcean.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _CardContent(
                          fileType: widget.file.type,
                          thumbUrl: widget.thumbUrl,
                        ),
                        // Ext badge
                        if (_hover && !selected)
                          Positioned(
                            top: 5,
                            left: 5,
                            child: _ExtBadge(
                              text:
                                  widget.file.value
                                      .split('.')
                                      .lastOrNull
                                      ?.toUpperCase() ??
                                  '',
                            ),
                          ),
                        // Hover overlay menu button - instant show/hide
                        if (_hover || selected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Builder(
                              builder: (btnCtx) => _MenuDotButton(
                                onTap: () {
                                  final box =
                                      btnCtx.findRenderObject() as RenderBox?;
                                  if (box == null) return;
                                  final pos = box.localToGlobal(
                                    Offset(box.size.width, 0),
                                  );
                                  _showMenu(context, pos);
                                },
                              ),
                            ),
                          ),
                        // Selected overlay
                        if (selected)
                          Container(
                            color: _mlSelected.withValues(alpha: 0.06),
                            child: Center(
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _mlSelected,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _mlSelected.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        if ((_hover || selected) && widget.file.type == 'image')
                          Positioned(
                            left: 5,
                            bottom: 5,
                            child: _ImageActionButton(
                              icon: Icons.open_in_full_rounded,
                              tooltip: context.t('media.preview'),
                              size: 24,
                              iconSize: 13,
                              onTap: widget.onPreview,
                            ),
                          ),
                        if ((_hover || selected) && widget.file.type == 'image')
                          Positioned(
                            right: 5,
                            bottom: 5,
                            child: _ImageActionButton(
                              icon: Icons.edit_outlined,
                              onTap: widget.onEdit,
                            ),
                          ),
                        // Busy overlay
                        if (widget.busy)
                          ColoredBox(
                            color: Colors.white.withValues(alpha: 0.7),
                            child: const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.actionRed,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.file.value,
                  maxLines: 3,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    color: selected
                        ? _mlSelectedDeep
                        : _hover
                        ? AppColors.deepOcean
                        : _mlMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({required this.fileType, required this.thumbUrl});

  final String fileType;
  final String thumbUrl;

  @override
  Widget build(BuildContext context) {
    if (fileType == 'video') {
      return _VideoCardContent(url: thumbUrl);
    }
    if (fileType == 'audio') {
      return ColoredBox(
        color: const Color(0xFFFFF7ED),
        child: Center(
          child: Icon(
            Icons.graphic_eq_rounded,
            size: 32,
            color: AppColors.warmHorizon.withValues(alpha: 0.5),
          ),
        ),
      );
    }
    if (fileType == 'file') {
      return ColoredBox(
        color: AppColors.surface,
        child: Center(
          child: Icon(
            Icons.description_outlined,
            size: 32,
            color: _mlMuted.withValues(alpha: 0.4),
          ),
        ),
      );
    }
    return AdminCachedImage(
      url: thumbUrl,
      fit: BoxFit.contain,
      memCacheWidth: 280,
      useOldImageOnUrlChange: true,
      errorWidget: ColoredBox(
        color: AppColors.surface,
        child: Icon(
          Icons.broken_image_outlined,
          size: 26,
          color: AppColors.placeholder.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _VideoCardContent extends StatelessWidget {
  const _VideoCardContent({required this.url});

  final String url;

  bool get _hasImageThumb {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif');
  }

  String get _extension {
    final path = Uri.tryParse(url)?.path ?? url;
    final fileName = path.split('/').last;
    final parts = fileName.split('.');
    if (parts.length < 2) return 'VIDEO';
    return parts.last.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasImageThumb) {
      return Stack(
        fit: StackFit.expand,
        children: [
          AdminCachedImage(
            url: url,
            fit: BoxFit.contain,
            memCacheWidth: 280,
            useOldImageOnUrlChange: true,
            errorWidget: _VideoFallback(extension: _extension),
          ),
          Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      );
    }
    return _VideoFallback(extension: _extension);
  }
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback({required this.extension});

  final String extension;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1E293B),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_outlined,
              size: 34,
              color: Colors.white.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 8),
            Text(
              extension,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtBadge extends StatelessWidget {
  const _ExtBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.deepOcean.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _MenuDotButton extends StatefulWidget {
  const _MenuDotButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_MenuDotButton> createState() => _MenuDotButtonState();
}

class _MenuDotButtonState extends State<_MenuDotButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover
                ? AppColors.deepOcean.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.more_vert_rounded,
            size: 15,
            color: _hover ? Colors.white : AppColors.deepOcean,
          ),
        ),
      ),
    );
  }
}

class _ImageActionButton extends StatefulWidget {
  const _ImageActionButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 28,
    this.iconSize = 15,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final double iconSize;

  @override
  State<_ImageActionButton> createState() => _ImageActionButtonState();
}

class _ImageActionButtonState extends State<_ImageActionButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover
                ? AppColors.deepOcean
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: _hover
                  ? AppColors.deepOcean
                  : AppColors.deepOcean.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _hover ? Colors.white : AppColors.deepOcean,
          ),
        ),
      ),
    );

    final tooltip = widget.tooltip;
    if (tooltip == null || tooltip.isEmpty) return button;
    return Tooltip(message: tooltip, child: button);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATES
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.deepOcean,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      'video' => Icons.movie_outlined,
      'audio' => Icons.mic_none_rounded,
      'file' => Icons.description_outlined,
      _ => Icons.image_outlined,
    };
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 56,
            color: AppColors.placeholder.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 14),
          Text(
            context.t('media.empty'),
            style: TextStyle(
              color: AppColors.placeholder.withValues(alpha: 0.55),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer({
    required this.selectedSrcs,
    required this.uploading,
    required this.onUse,
    required this.onClose,
    required this.onDeleteSelected,
    required this.type,
  });

  final ValueNotifier<Set<String>> selectedSrcs;
  final bool uploading;
  final VoidCallback onUse;
  final VoidCallback onClose;
  final VoidCallback onDeleteSelected;
  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: _mlSurface,
        border: Border(top: BorderSide(color: _mlSoftBorder)),
      ),
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: selectedSrcs,
        builder: (_, selected, _) {
          final selectedCount = selected.length;
          final hasSelection = selectedCount > 0 && !uploading;
          return Row(
            children: [
              _PrimaryButton(
                enabled: hasSelection,
                color: AppColors.actionRed,
                icon: Icons.delete_outline_rounded,
                label: context.t('media.delete'),
                onTap: onDeleteSelected,
              ),
              const SizedBox(width: 10),
              _OutlinedActionButton(
                enabled: hasSelection,
                color: AppColors.actionRed,
                icon: Icons.delete_sweep_outlined,
                label: '${context.t('media.deleteSelected')} ($selectedCount)',
                onTap: onDeleteSelected,
              ),
              const Spacer(),
              _PrimaryButton(
                enabled: hasSelection,
                color: AppColors.warmHorizon,
                icon: Icons.check_circle_outline_rounded,
                label: _useLabel(context, type),
                onTap: onUse,
              ),
              const SizedBox(width: 10),
              _SecondaryButton(label: context.t('media.close'), onTap: onClose),
            ],
          );
        },
      ),
    );
  }

  String _useLabel(BuildContext context, String type) => switch (type) {
    'video' => context.t('media.useVideo'),
    'audio' => context.t('media.useAudio'),
    'file' => context.t('media.useFile'),
    _ => context.t('media.useThis'),
  };
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.actionRed,
  });

  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  var _hover = false;

  Color _darken(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness - 0.06).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled;
    return SizedBox(
      height: 40,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: disabled ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: disabled
                  ? widget.color.withValues(alpha: 0.32)
                  : _hover
                  ? _darken(widget.color)
                  : widget.color,
              borderRadius: BorderRadius.circular(AppRadius.value),
              boxShadow: !disabled && _hover
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatefulWidget {
  const _SecondaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _hover ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(
                color: _hover
                    ? AppColors.deepOcean.withValues(alpha: 0.3)
                    : _mlBorder,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: TextStyle(
                color: _hover ? AppColors.deepOcean : _mlMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedActionButton extends StatefulWidget {
  const _OutlinedActionButton({
    required this.enabled,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_OutlinedActionButton> createState() => _OutlinedActionButtonState();
}

class _OutlinedActionButtonState extends State<_OutlinedActionButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled;
    final effectiveColor = disabled
        ? widget.color.withValues(alpha: 0.3)
        : widget.color;

    return SizedBox(
      height: 40,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: disabled ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: !disabled && _hover
                  ? widget.color.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(
                color: !disabled && _hover
                    ? widget.color.withValues(alpha: 0.4)
                    : widget.color.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: effectiveColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: effectiveColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT MODAL
// ─────────────────────────────────────────────────────────────────────────────
class _ImagePreviewModal extends StatelessWidget {
  const _ImagePreviewModal({required this.fileName, required this.imageUrl});

  final String fileName;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.74).clamp(680.0, 1120.0);
    final height = (size.height * 0.76).clamp(500.0, 760.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.22),
                blurRadius: 38,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.deepOcean.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    child: const Icon(
                      Icons.open_in_full_rounded,
                      size: 15,
                      color: AppColors.deepOcean,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  _HoverIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.value),
                  child: ColoredBox(
                    color: AppColors.surface,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: AdminCachedImage(
                          url: imageUrl,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          useOldImageOnUrlChange: true,
                          errorWidget: Icon(
                            Icons.broken_image_outlined,
                            size: 42,
                            color: AppColors.placeholder.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioPreviewModal extends StatelessWidget {
  const _AudioPreviewModal({required this.fileName, required this.mediaUrl});

  final String fileName;
  final String mediaUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 480,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.2),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.warmHorizon.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    child: const Icon(
                      Icons.mic_none_rounded,
                      size: 16,
                      color: AppColors.warmHorizon,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  _HoverIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _MediaAudioPlayer(mediaUrl: mediaUrl),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaAudioPlayer extends StatefulWidget {
  const _MediaAudioPlayer({required this.mediaUrl});

  final String mediaUrl;

  @override
  State<_MediaAudioPlayer> createState() => _MediaAudioPlayerState();
}

class _MediaAudioPlayerState extends State<_MediaAudioPlayer> {
  VideoPlayerController? _controller;
  var _failed = false;
  double _lastAudibleVolume = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_refresh);
    controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uri = Uri.tryParse(widget.mediaUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(1);
      controller.addListener(_refresh);
      if (!mounted || _controller != controller) return;
      setState(() {});
    } catch (_) {
      if (!mounted || _controller != controller) return;
      await controller.dispose();
      _controller = null;
      setState(() => _failed = true);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final volume = controller.value.volume;
    if (volume > 0) {
      _lastAudibleVolume = volume;
      controller.setVolume(0);
      return;
    }
    controller.setVolume(_lastAudibleVolume <= 0 ? 1 : _lastAudibleVolume);
  }

  void _seekTo(double milliseconds) {
    _controller?.seekTo(Duration(milliseconds: milliseconds.round()));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized ?? false;
    final value = controller?.value;
    final duration = initialized ? value!.duration : Duration.zero;
    final position = initialized ? value!.position : Duration.zero;
    final volume = initialized ? value!.volume.clamp(0, 1).toDouble() : 1.0;
    final maxMs = duration.inMilliseconds
        .toDouble()
        .clamp(1, double.infinity)
        .toDouble();
    final currentMs = position.inMilliseconds
        .toDouble()
        .clamp(0, maxMs)
        .toDouble();

    return Container(
      height: 104,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _mlBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: _failed
          ? Center(
              child: Text(
                context.t('media.audioPlaybackError'),
                style: const TextStyle(
                  color: AppColors.actionRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : Row(
              children: [
                _MediaAudioPlayButton(
                  enabled: initialized,
                  playing: value?.isPlaying ?? false,
                  onTap: _togglePlayback,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: initialized
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _formatMediaDuration(position),
                                  style: const TextStyle(
                                    color: AppColors.deepOcean,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatMediaDuration(duration),
                                  style: const TextStyle(
                                    color: AppColors.deepOcean,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 10,
                                ),
                                activeTrackColor: AppColors.deepOcean,
                                inactiveTrackColor: _mlSoftBorder,
                                thumbColor: AppColors.deepOcean,
                                overlayColor: AppColors.deepOcean.withValues(
                                  alpha: 0.10,
                                ),
                              ),
                              child: Slider(
                                min: 0,
                                max: maxMs,
                                value: currentMs,
                                onChanged: _seekTo,
                              ),
                            ),
                          ],
                        )
                      : const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.deepOcean,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                _MediaAudioIconButton(
                  icon: volume <= 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  enabled: initialized,
                  onTap: _toggleMute,
                ),
              ],
            ),
    );
  }
}

class _MediaAudioPlayButton extends StatelessWidget {
  const _MediaAudioPlayButton({
    required this.enabled,
    required this.playing,
    required this.onTap,
  });

  final bool enabled;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.deepOcean
                : AppColors.deepOcean.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _MediaAudioIconButton extends StatelessWidget {
  const _MediaAudioIconButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            color: enabled ? _mlMuted : AppColors.placeholder,
            size: 20,
          ),
        ),
      ),
    );
  }
}

String _formatMediaDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  final hours = totalSeconds ~/ 3600;
  if (hours <= 0) return '$minutes:$seconds';
  final remainingMinutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(
    2,
    '0',
  );
  return '$hours:$remainingMinutes:$seconds';
}

class _ImageEditModal extends StatefulWidget {
  const _ImageEditModal({required this.initialName});

  final String initialName;

  @override
  State<_ImageEditModal> createState() => _ImageEditModalState();
}

class _ImageEditModalState extends State<_ImageEditModal> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _altCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _altCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _altCtrl.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 460,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.2),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.actionRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 15,
                      color: AppColors.actionRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.t('media.editTitle'),
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  _HoverIconButton(
                    icon: Icons.close_rounded,
                    onTap: _close,
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ModalLabel(text: context.t('media.fileName')),
              const SizedBox(height: 6),
              _ModalTextField(
                controller: _nameCtrl,
                hint: context.t('media.fileNameHint'),
              ),
              const SizedBox(height: 16),
              _ModalLabel(text: context.t('media.altTag')),
              const SizedBox(height: 6),
              _ModalTextField(
                controller: _altCtrl,
                hint: context.t('media.altTagHint'),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SecondaryButton(
                    label: context.t('media.cancel'),
                    onTap: _close,
                  ),
                  const SizedBox(width: 10),
                  _PrimaryButton(
                    enabled: true,
                    icon: Icons.check_rounded,
                    label: context.t('media.saveChanges'),
                    onTap: _close,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalLabel extends StatelessWidget {
  const _ModalLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: _mlMuted,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _ModalTextField extends StatelessWidget {
  const _ModalTextField({
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        cursorColor: AppColors.deepOcean,
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.placeholder.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          filled: true,
          fillColor: _mlSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            borderSide: const BorderSide(color: _mlBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            borderSide: const BorderSide(color: _mlBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            borderSide: const BorderSide(
              color: AppColors.deepOcean,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED
// ─────────────────────────────────────────────────────────────────────────────
class _HoverIconButton extends StatefulWidget {
  const _HoverIconButton({
    required this.icon,
    required this.onTap,
    this.size = 34,
    this.hoverColor,
    this.hoverIconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? hoverColor;
  final Color? hoverIconColor;

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover
                ? (widget.hoverColor ?? _mlSurface)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _hover ? _mlBorder : Colors.transparent),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: _hover
                ? (widget.hoverIconColor ?? AppColors.deepOcean)
                : AppColors.placeholder,
          ),
        ),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter({required this.color, this.active = false});

  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = active
          ? AppColors.deepOcean.withValues(alpha: 0.4)
          : color.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter oldDelegate) =>
      oldDelegate.active != active;
}

// ─────────────────────────────────────────────────────────────────────────────
// URL DIALOG
// ─────────────────────────────────────────────────────────────────────────────
Future<String?> showUrlImageDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: AppColors.deepOcean.withValues(alpha: 0.45),
    builder: (_) => const _UrlImageDialog(),
  );
}

Future<String?> showUrlVideoDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: AppColors.deepOcean.withValues(alpha: 0.45),
    builder: (_) => const _UrlVideoDialog(),
  );
}

Future<String?> showUrlAudioDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: AppColors.deepOcean.withValues(alpha: 0.45),
    builder: (_) => const _UrlAudioDialog(),
  );
}

Future<String?> showUrlFileDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: AppColors.deepOcean.withValues(alpha: 0.45),
    builder: (_) => const _UrlFileDialog(),
  );
}

class _UrlImageDialog extends StatefulWidget {
  const _UrlImageDialog();

  @override
  State<_UrlImageDialog> createState() => _UrlImageDialogState();
}

class _UrlImageDialogState extends State<_UrlImageDialog> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _previewUrl = '';
  var _previewError = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onUrlChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      final trimmed = value.trim();
      if (!mounted) return;
      setState(() {
        _previewError = false;
        _previewUrl = _looksLikeUrl(trimmed) ? trimmed : '';
      });
    });
  }

  bool _looksLikeUrl(String s) {
    if (s.isEmpty) return false;
    final uri = Uri.tryParse(s);
    return uri != null && uri.hasAbsolutePath && uri.hasScheme;
  }

  void _close([String? value]) => Navigator.of(context).pop(value);

  bool get _canUse =>
      _previewUrl.isNotEmpty && !_previewError && _looksLikeUrl(_ctrl.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 480,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.2),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.actionRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    child: const Icon(
                      Icons.link_rounded,
                      size: 16,
                      color: AppColors.actionRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.t('media.urlTitle'),
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  _HoverIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => _close(),
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ModalLabel(text: context.t('media.urlLabel')),
              const SizedBox(height: 6),
              _ModalTextField(
                controller: _ctrl,
                hint: context.t('media.urlHint'),
                onChanged: _onUrlChanged,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              _ModalLabel(text: context.t('media.preview')),
              const SizedBox(height: 6),
              _UrlPreviewBox(
                url: _previewUrl,
                error: _previewError,
                onError: () {
                  if (!mounted) return;
                  setState(() => _previewError = true);
                },
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SecondaryButton(
                    label: context.t('media.cancel'),
                    onTap: () => _close(),
                  ),
                  const SizedBox(width: 10),
                  _PrimaryButton(
                    enabled: _canUse,
                    icon: Icons.check_rounded,
                    label: context.t('media.use'),
                    onTap: () => _close(_ctrl.text.trim()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrlVideoDialog extends StatefulWidget {
  const _UrlVideoDialog();

  @override
  State<_UrlVideoDialog> createState() => _UrlVideoDialogState();
}

class _UrlVideoDialogState extends State<_UrlVideoDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _looksLikeUrl(String s) {
    if (s.isEmpty) return false;
    final uri = Uri.tryParse(s);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  void _close([String? value]) => Navigator.of(context).pop(value);

  String get _normalizedUrl => _ctrl.text.trim();

  bool get _canUse => _looksLikeUrl(_normalizedUrl);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 480,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.2),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.actionRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    child: const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 16,
                      color: AppColors.actionRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.t('media.videoUrlTitle'),
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  _HoverIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => _close(),
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ModalLabel(text: context.t('media.videoUrlLabel')),
              const SizedBox(height: 6),
              _ModalTextField(
                controller: _ctrl,
                hint: context.t('media.videoUrlHint'),
                onChanged: (_) => setState(() {}),
                autofocus: true,
                onSubmitted: (_) {
                  if (_canUse) _close(_normalizedUrl);
                },
              ),
              const SizedBox(height: 16),
              _ModalLabel(text: context.t('media.preview')),
              const SizedBox(height: 6),
              _UrlVideoPreviewBox(url: _normalizedUrl, valid: _canUse),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SecondaryButton(
                    label: context.t('media.cancel'),
                    onTap: () => _close(),
                  ),
                  const SizedBox(width: 10),
                  _PrimaryButton(
                    enabled: _canUse,
                    icon: Icons.check_rounded,
                    label: context.t('media.use'),
                    onTap: () => _close(_normalizedUrl),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrlAudioDialog extends StatefulWidget {
  const _UrlAudioDialog();

  @override
  State<_UrlAudioDialog> createState() => _UrlAudioDialogState();
}

class _UrlAudioDialogState extends State<_UrlAudioDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _looksLikeUrl(String s) {
    if (s.isEmpty) return false;
    final uri = Uri.tryParse(s);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  void _close([String? value]) => Navigator.of(context).pop(value);

  String get _normalizedUrl => _ctrl.text.trim();

  bool get _canUse => _looksLikeUrl(_normalizedUrl);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 480,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.2),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.warmHorizon.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      size: 16,
                      color: AppColors.warmHorizon,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.t('media.audioUrlTitle'),
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  _HoverIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => _close(),
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ModalLabel(text: context.t('media.audioUrlLabel')),
              const SizedBox(height: 6),
              _ModalTextField(
                controller: _ctrl,
                hint: context.t('media.audioUrlHint'),
                onChanged: (_) => setState(() {}),
                autofocus: true,
                onSubmitted: (_) {
                  if (_canUse) _close(_normalizedUrl);
                },
              ),
              const SizedBox(height: 16),
              _ModalLabel(text: context.t('media.preview')),
              const SizedBox(height: 6),
              _UrlAudioPreviewBox(url: _normalizedUrl, valid: _canUse),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SecondaryButton(
                    label: context.t('media.cancel'),
                    onTap: () => _close(),
                  ),
                  const SizedBox(width: 10),
                  _PrimaryButton(
                    enabled: _canUse,
                    icon: Icons.check_rounded,
                    label: context.t('media.use'),
                    onTap: () => _close(_normalizedUrl),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrlFileDialog extends StatefulWidget {
  const _UrlFileDialog();

  @override
  State<_UrlFileDialog> createState() => _UrlFileDialogState();
}

class _UrlFileDialogState extends State<_UrlFileDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _looksLikeUrl(String s) {
    if (s.isEmpty) return false;
    final uri = Uri.tryParse(s);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  void _close([String? value]) => Navigator.of(context).pop(value);

  String get _normalizedUrl => _ctrl.text.trim();

  bool get _canUse => _looksLikeUrl(_normalizedUrl);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 480,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.2),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.support.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    child: const Icon(
                      Icons.insert_drive_file_outlined,
                      size: 16,
                      color: AppColors.support,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.t('media.fileUrlTitle'),
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  _HoverIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => _close(),
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ModalLabel(text: context.t('media.fileUrlLabel')),
              const SizedBox(height: 6),
              _ModalTextField(
                controller: _ctrl,
                hint: context.t('media.fileUrlHint'),
                onChanged: (_) => setState(() {}),
                autofocus: true,
                onSubmitted: (_) {
                  if (_canUse) _close(_normalizedUrl);
                },
              ),
              const SizedBox(height: 16),
              _ModalLabel(text: context.t('media.preview')),
              const SizedBox(height: 6),
              _UrlFilePreviewBox(url: _normalizedUrl, valid: _canUse),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SecondaryButton(
                    label: context.t('media.cancel'),
                    onTap: () => _close(),
                  ),
                  const SizedBox(width: 10),
                  _PrimaryButton(
                    enabled: _canUse,
                    icon: Icons.check_rounded,
                    label: context.t('media.use'),
                    onTap: () => _close(_normalizedUrl),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrlVideoPreviewBox extends StatelessWidget {
  const _UrlVideoPreviewBox({required this.url, required this.valid});

  final String url;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    final youtubeId = valid ? _youtubeVideoId(url) : null;

    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _mlSurface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _mlBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: !valid
          ? _VideoPreviewEmpty()
          : youtubeId != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                AdminCachedImage(
                  url: 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg',
                  fit: BoxFit.contain,
                  useOldImageOnUrlChange: true,
                  errorWidget: _DirectVideoPreview(url: url),
                ),
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.deepOcean.withValues(alpha: 0.78),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            )
          : _DirectVideoPreview(url: url),
    );
  }
}

class _UrlAudioPreviewBox extends StatelessWidget {
  const _UrlAudioPreviewBox({required this.url, required this.valid});

  final String url;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    final youtubeId = valid ? _youtubeVideoId(url) : null;
    final youtubeLabel = _isYoutubeMusicUrl(url) ? 'YouTube Music' : 'YouTube';

    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _mlSurface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _mlBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: !valid
          ? _AudioPreviewEmpty()
          : youtubeId != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                AdminCachedImage(
                  url: 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg',
                  fit: BoxFit.contain,
                  useOldImageOnUrlChange: true,
                  errorWidget: _AudioUrlLabelPreview(url: url),
                ),
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.deepOcean.withValues(alpha: 0.78),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.deepOcean.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          youtubeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : _looksLikeDirectAudioUrl(url)
          ? Padding(
              padding: const EdgeInsets.all(22),
              child: _MediaAudioPlayer(mediaUrl: url),
            )
          : _AudioUrlLabelPreview(url: url),
    );
  }
}

class _AudioPreviewEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: 32,
            color: AppColors.placeholder.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('media.audioUrlHint'),
            style: TextStyle(
              color: AppColors.placeholder.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioUrlLabelPreview extends StatelessWidget {
  const _AudioUrlLabelPreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_note_rounded,
            size: 34,
            color: AppColors.deepOcean.withValues(alpha: 0.48),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _mlMuted.withValues(alpha: 0.7),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlFilePreviewBox extends StatelessWidget {
  const _UrlFilePreviewBox({required this.url, required this.valid});

  final String url;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _mlSurface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _mlBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: valid ? _FileUrlLabelPreview(url: url) : _FilePreviewEmpty(),
    );
  }
}

class _FilePreviewEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 32,
            color: AppColors.placeholder.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('media.fileUrlHint'),
            style: TextStyle(
              color: AppColors.placeholder.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _FileUrlLabelPreview extends StatelessWidget {
  const _FileUrlLabelPreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final fileName = _fileDialogFileName(url);
    final extension = _fileDialogExtension(url).toUpperCase();
    final accent = _fileDialogAccent(extension);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(color: _mlBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepOcean.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(_fileDialogIcon(extension), color: accent, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$extension ${context.t('media.assetLabel')}',
              style: TextStyle(
                color: _mlMuted.withValues(alpha: 0.68),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _mlMuted.withValues(alpha: 0.58),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreviewEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 32,
            color: AppColors.placeholder.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('media.videoUrlHint'),
            style: TextStyle(
              color: AppColors.placeholder.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectVideoPreview extends StatefulWidget {
  const _DirectVideoPreview({required this.url});

  final String url;

  @override
  State<_DirectVideoPreview> createState() => _DirectVideoPreviewState();
}

class _DirectVideoPreviewState extends State<_DirectVideoPreview> {
  VideoPlayerController? _controller;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _DirectVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _failed = false;
      _load();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  Future<void> _load() async {
    final url = widget.url.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!_looksLikeDirectVideoUrl(url)) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(0);
      if (!mounted || _controller != controller) return;
      setState(() {});
    } catch (_) {
      if (!mounted || _controller != controller) return;
      await controller.dispose();
      _controller = null;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_failed && controller != null && controller.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _UrlPreviewVideoFrame(controller: controller),
          Center(
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.deepOcean.withValues(alpha: 0.74),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            size: 34,
            color: AppColors.deepOcean.withValues(alpha: 0.48),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _mlMuted.withValues(alpha: 0.7),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlPreviewVideoFrame extends StatelessWidget {
  const _UrlPreviewVideoFrame({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) return VideoPlayer(controller);
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

bool _looksLikeDirectVideoUrl(String value) {
  final path = Uri.tryParse(value)?.path.toLowerCase() ?? value.toLowerCase();
  if (path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.png') ||
      path.endsWith('.webp') ||
      path.endsWith('.gif')) {
    return false;
  }
  final fileName = path.split('/').last;
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return true;
  final extension = fileName.substring(dot + 1);
  return const {'mp4', 'm4v', 'mov', 'webm', 'avi', 'mkv'}.contains(extension);
}

bool _looksLikeDirectAudioUrl(String value) {
  final path = Uri.tryParse(value)?.path.toLowerCase() ?? value.toLowerCase();
  final fileName = path.split('/').last;
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return true;
  final extension = fileName.substring(dot + 1);
  return const {
    'mp3',
    'wav',
    'ogg',
    'oga',
    'm4a',
    'aac',
    'opus',
  }.contains(extension);
}

bool _isYoutubeMusicUrl(String value) {
  final host = Uri.tryParse(value)?.host.toLowerCase().replaceFirst('www.', '');
  return host == 'music.youtube.com';
}

String _fileDialogFileName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  final rawPath = uri != null && uri.path.trim().isNotEmpty
      ? uri.path
      : trimmed;
  final segments = rawPath.split('/').where((part) => part.isNotEmpty).toList();
  final rawName = segments.isNotEmpty
      ? segments.last
      : (uri != null && uri.host.isNotEmpty ? uri.host : trimmed);
  return _safeFileDialogDecode(rawName.split('?').first);
}

String _fileDialogExtension(String value) {
  final fileName = _fileDialogFileName(value);
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return 'FILE';
  return fileName.substring(dot + 1);
}

String _safeFileDialogDecode(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

IconData _fileDialogIcon(String extension) {
  switch (extension.toLowerCase()) {
    case 'pdf':
      return Icons.description_outlined;
    case 'doc':
    case 'docx':
      return Icons.text_snippet_outlined;
    case 'xls':
    case 'xlsx':
      return Icons.table_chart_outlined;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow_outlined;
    case 'txt':
    case 'md':
      return Icons.article_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

Color _fileDialogAccent(String extension) {
  switch (extension.toLowerCase()) {
    case 'pdf':
      return AppColors.actionRed;
    case 'doc':
    case 'docx':
      return const Color(0xFF2563EB);
    case 'xls':
    case 'xlsx':
      return const Color(0xFF059669);
    case 'ppt':
    case 'pptx':
      return AppColors.warmHorizon;
    default:
      return AppColors.support;
  }
}

String? _youtubeVideoId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return null;

  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
    return _cleanYoutubeId(uri.pathSegments.first);
  }

  if (!host.endsWith('youtube.com') && host != 'youtube-nocookie.com') {
    return null;
  }

  final directId = uri.queryParameters['v'];
  if (directId != null && directId.isNotEmpty) {
    return _cleanYoutubeId(directId);
  }

  if (uri.pathSegments.length >= 2 &&
      const {'shorts', 'embed', 'live'}.contains(uri.pathSegments.first)) {
    return _cleanYoutubeId(uri.pathSegments[1]);
  }

  return null;
}

String? _cleanYoutubeId(String raw) {
  final id = raw.trim();
  if (id.isEmpty) return null;
  return id.split(RegExp(r'[?&#/]')).first;
}

class _UrlPreviewBox extends StatelessWidget {
  const _UrlPreviewBox({
    required this.url,
    required this.error,
    required this.onError,
  });

  final String url;
  final bool error;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _mlSurface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _mlBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? _PreviewEmpty()
          : error
          ? _PreviewError(message: context.t('media.urlPreviewError'))
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              useOldImageOnUrlChange: true,
              errorWidget: (_, _, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) => onError());
                return _PreviewError(
                  message: context.t('media.urlPreviewError'),
                );
              },
              progressIndicatorBuilder: (_, _, _) => const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.deepOcean,
                  ),
                ),
              ),
            ),
    );
  }
}

class _PreviewEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 32,
            color: AppColors.placeholder.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('media.urlHint'),
            style: TextStyle(
              color: AppColors.placeholder.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 28,
            color: AppColors.actionRed.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: AppColors.actionRed.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
