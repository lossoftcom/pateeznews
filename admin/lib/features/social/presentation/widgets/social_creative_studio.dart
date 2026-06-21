import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/media_service.dart';
import '../social_platform_data.dart';
import 'social_media_preview.dart';

class SocialCreativeStudio extends StatefulWidget {
  const SocialCreativeStudio({
    super.key,
    required this.data,
    required this.onMediaUrlsChanged,
    required this.onPickImage,
    required this.onPickVideo,
    this.mediaService,
  });

  final SocialPublishData data;
  final ValueChanged<List<String>> onMediaUrlsChanged;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final MediaService? mediaService;

  @override
  State<SocialCreativeStudio> createState() => _SocialCreativeStudioState();
}

class _SocialCreativeStudioState extends State<SocialCreativeStudio> {
  var _editing = false;

  MediaService get _mediaService => widget.mediaService ?? MediaService();

  @override
  Widget build(BuildContext context) {
    final mediaUrl = widget.data.mediaUrls.isNotEmpty
        ? widget.data.mediaUrls.first
        : '';
    final hasMedia = mediaUrl.trim().isNotEmpty;
    final isVideo = hasMedia && isSocialVideoUrl(mediaUrl);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value * 2),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StudioIcon(icon: Symbols.auto_fix_high_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yaratıcı stüdyo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepOcean,
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Metin, sticker, çizim ve link görünümü tek medya çıktısına gömülür.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.support,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FormatGuide(postType: widget.data.postType),
            const SizedBox(height: 12),
            if (hasMedia)
              _MediaStudioBody(
                url: mediaUrl,
                isVideo: isVideo,
                editing: _editing,
                onEdit: isVideo || _editing ? null : _openImageEditor,
                onPickImage: widget.onPickImage,
                onPickVideo: widget.onPickVideo,
              )
            else
              _EmptyStudioBody(
                onPickImage: widget.onPickImage,
                onPickVideo: widget.onPickVideo,
              ),
            const SizedBox(height: 12),
            const _SupportNotice(),
          ],
        ),
      ),
    );
  }

  Future<void> _openImageEditor() async {
    final mediaUrl = widget.data.mediaUrls.isNotEmpty
        ? widget.data.mediaUrls.first.trim()
        : '';
    if (mediaUrl.isEmpty || isSocialVideoUrl(mediaUrl)) return;

    final editorUrl = mediaUrl.startsWith('http')
        ? mediaUrl
        : _mediaService.resolveUrl(mediaUrl);
    if (editorUrl.trim().isEmpty) return;

    final baseTheme = Theme.of(context);
    var editorClosing = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.deepOcean.withValues(alpha: 0.58),
      builder: (editorContext) {
        final size = MediaQuery.sizeOf(editorContext);
        final width = (size.width * 0.78).clamp(820.0, 1280.0);
        final height = (size.height * 0.76).clamp(560.0, 820.0);

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 42,
            vertical: 34,
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
              editorUrl,
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
                  if (mounted) setState(() => _editing = true);
                  try {
                    final fileName =
                        'social-creative-${DateTime.now().millisecondsSinceEpoch}.png';
                    final result = await _mediaService.uploadFile(
                      fileName: fileName,
                      bytes: bytes,
                      type: 'image',
                    );
                    if (result == null) {
                      throw const _CreativeStudioException(
                        'Düzenlenen görsel yüklenemedi.',
                      );
                    }
                    final next = List<String>.from(widget.data.mediaUrls);
                    if (next.isEmpty) {
                      next.add(result.src);
                    } else {
                      next[0] = result.src;
                    }
                    widget.onMediaUrlsChanged(next);
                    if (mounted) {
                      AdminToast.show(
                        context,
                        message:
                            'Düzenlenen görsel paylaşım medyasına eklendi.',
                        tone: AdminToastTone.success,
                      );
                    }
                  } catch (error) {
                    if (mounted) {
                      AdminToast.show(
                        context,
                        message: error.toString(),
                        tone: AdminToastTone.error,
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _editing = false);
                    if (editorContext.mounted) {
                      editorClosing = true;
                      Navigator.of(editorContext).pop();
                    }
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MediaStudioBody extends StatelessWidget {
  const _MediaStudioBody({
    required this.url,
    required this.isVideo,
    required this.editing,
    required this.onEdit,
    required this.onPickImage,
    required this.onPickVideo,
  });

  final String url;
  final bool isVideo;
  final bool editing;
  final VoidCallback? onEdit;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final preview = _StudioPreview(url: url, isVideo: isVideo);
        final actions = _StudioActions(
          isVideo: isVideo,
          editing: editing,
          onEdit: onEdit,
          onPickImage: onPickImage,
          onPickVideo: onPickVideo,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [preview, const SizedBox(height: 12), actions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 188, child: preview),
            const SizedBox(width: 14),
            Expanded(child: actions),
          ],
        );
      },
    );
  }
}

class _StudioPreview extends StatelessWidget {
  const _StudioPreview({required this.url, required this.isVideo});

  final String url;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
        child: AspectRatio(
          aspectRatio: 1,
          child: isVideo
              ? SocialVideoThumb(url: url)
              : SocialMediaPreview(
                  url: url,
                  fit: BoxFit.contain,
                  memCacheWidth: 640,
                  placeholderColor: AppColors.surface,
                  errorWidget: const Center(
                    child: Icon(
                      Symbols.image_rounded,
                      color: AppColors.iconMuted,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _StudioActions extends StatelessWidget {
  const _StudioActions({
    required this.isVideo,
    required this.editing,
    required this.onEdit,
    required this.onPickImage,
    required this.onPickVideo,
  });

  final bool isVideo;
  final bool editing;
  final VoidCallback? onEdit;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onEdit,
              icon: editing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.brush_outlined, size: 16),
              label: Text(editing ? 'Kaydediliyor' : 'Tasarımı düzenle'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepOcean,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'PateezSans',
                  letterSpacing: 0,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onPickImage,
              icon: const Icon(Symbols.add_photo_alternate_outlined, size: 16),
              label: const Text('Görsel değiştir'),
              style: _outlineButtonStyle(),
            ),
            OutlinedButton.icon(
              onPressed: onPickVideo,
              icon: const Icon(Symbols.video_library_outlined, size: 16),
              label: const Text('Video seç'),
              style: _outlineButtonStyle(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          isVideo
              ? 'Video seçildi. Görsel katman editörü yalnızca görsellerde açılır; Reels/TikTok kapak ve yayın ayarları aşağıdaki platform alanlarından yönetilir.'
              : 'Görsel editörde metin, çıkartma, çizim, kırpma ve link görünümü ekleyebilirsiniz. Kaydedilen çıktı tek görsel olarak yayın listesine döner.',
          style: const TextStyle(
            fontSize: 11,
            height: 1.36,
            color: AppColors.support,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _EmptyStudioBody extends StatelessWidget {
  const _EmptyStudioBody({
    required this.onPickImage,
    required this.onPickVideo,
  });

  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          children: [
            const Icon(
              Symbols.image_rounded,
              size: 28,
              color: AppColors.iconMuted,
            ),
            const SizedBox(height: 8),
            const Text(
              'Önce görsel veya video seçin.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.deepOcean,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onPickImage,
                  icon: const Icon(
                    Symbols.add_photo_alternate_outlined,
                    size: 16,
                  ),
                  label: const Text('Görsel seç'),
                  style: _outlineButtonStyle(),
                ),
                OutlinedButton.icon(
                  onPressed: onPickVideo,
                  icon: const Icon(Symbols.video_library_outlined, size: 16),
                  label: const Text('Video seç'),
                  style: _outlineButtonStyle(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatGuide extends StatelessWidget {
  const _FormatGuide({required this.postType});

  final SocialPostType postType;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FormatChip(
          label: 'Akış 1:1',
          active: postType == SocialPostType.feed,
          icon: Symbols.crop_square_outlined,
        ),
        _FormatChip(
          label: 'Dikey 4:5',
          active: postType == SocialPostType.feed,
          icon: Symbols.view_stream_rounded,
        ),
        _FormatChip(
          label: 'Hikaye/Reels 9:16',
          active:
              postType == SocialPostType.story ||
              postType == SocialPostType.reels ||
              postType == SocialPostType.shortVideo,
          icon: Symbols.amp_stories_rounded,
        ),
      ],
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.active,
    required this.icon,
  });

  final String label;
  final bool active;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? AppColors.actionRed.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
        border: Border.all(
          color: active
              ? AppColors.actionRed.withValues(alpha: 0.26)
              : AppColors.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: active ? AppColors.actionRed : AppColors.iconMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active ? AppColors.actionRed : AppColors.deepOcean,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportNotice extends StatelessWidget {
  const _SupportNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.16)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Symbols.info_outline_rounded,
              size: 16,
              color: AppColors.actionRed,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bağlantı etiketi görsele gömülür; Instagram/Facebook API tıklanabilir hikaye stickeri göndermez.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioIcon extends StatelessWidget {
  const _StudioIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
      ),
      child: Icon(icon, size: 16, color: AppColors.actionRed),
    );
  }
}

ButtonStyle _outlineButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: AppColors.deepOcean,
    side: const BorderSide(color: AppColors.line),
    minimumSize: const Size(0, 34),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
    ),
    textStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      fontFamily: 'PateezSans',
      letterSpacing: 0,
    ),
  );
}

class _CreativeStudioException implements Exception {
  const _CreativeStudioException(this.message);

  final String message;

  @override
  String toString() => message;
}
