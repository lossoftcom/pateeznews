import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/media_service.dart';
import '../social_platform_data.dart';
import 'social_media_preview.dart';

Future<void> showSocialCreativeEditor(
  BuildContext context, {
  required SocialPublishData data,
  required ValueChanged<List<String>> onMediaUrlsChanged,
  MediaService? mediaService,
}) async {
  final mediaUrl = data.mediaUrls.isNotEmpty ? data.mediaUrls.first.trim() : '';
  if (mediaUrl.isEmpty) {
    AdminToast.show(
      context,
      message: 'Önce yukarıdaki Paylaşım görseli alanından medya seçin.',
      tone: AdminToastTone.info,
    );
    return;
  }

  if (isSocialVideoUrl(mediaUrl)) {
    AdminToast.show(
      context,
      message:
          'Video üzerine tıklanabilir link/sticker API ile eklenmez. Video katmanı için ayrı video render hattı gerekir.',
      tone: AdminToastTone.info,
    );
    return;
  }

  final service = mediaService ?? MediaService();
  final editorUrl = mediaUrl.startsWith('http')
      ? mediaUrl
      : service.resolveUrl(mediaUrl);
  if (editorUrl.trim().isEmpty) {
    AdminToast.show(
      context,
      message: 'Düzenlenecek görsel adresi bulunamadı.',
      tone: AdminToastTone.error,
    );
    return;
  }

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
        insetPadding: const EdgeInsets.symmetric(horizontal: 42, vertical: 34),
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
                try {
                  final fileName =
                      'social-creative-${DateTime.now().millisecondsSinceEpoch}.png';
                  final result = await service.uploadFile(
                    fileName: fileName,
                    bytes: bytes,
                    type: 'image',
                  );
                  if (result == null) {
                    throw const _CreativeStudioException(
                      'Düzenlenen görsel yüklenemedi.',
                    );
                  }
                  final next = List<String>.from(data.mediaUrls);
                  if (next.isEmpty) {
                    next.add(result.src);
                  } else {
                    next[0] = result.src;
                  }
                  onMediaUrlsChanged(next);
                  if (context.mounted) {
                    AdminToast.show(
                      context,
                      message: 'Düzenlenen görsel paylaşım medyasına eklendi.',
                      tone: AdminToastTone.success,
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    AdminToast.show(
                      context,
                      message: error.toString(),
                      tone: AdminToastTone.error,
                    );
                  }
                } finally {
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

class _CreativeStudioException implements Exception {
  const _CreativeStudioException(this.message);

  final String message;

  @override
  String toString() => message;
}
