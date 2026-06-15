import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as youtube;

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/media_service.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
import '../../../../shared/widgets/admin_rich_text_editor.dart'
    show adminEmptyQuillDeltaJson, adminQuillDocumentFromJson;
import '../../../../shared/widgets/media_library_dialog.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

const _videoBlockStrongLine = Color(0xFFDDE5E8);
const _videoBlockSoftLine = Color(0xFFE8EEF1);
const _videoBlockMutedText = Color(0xFF5F6F78);
const _videoBlockUploadInk = Color(0xFF6D7B83);

class ArticleVideoBlockEntry {
  ArticleVideoBlockEntry()
    : titleController = TextEditingController(),
      sourceController = TextEditingController(),
      descriptionController = quill.QuillController(
        document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      );

  final TextEditingController titleController;
  final TextEditingController sourceController;
  final quill.QuillController descriptionController;
  String? mediaUrl;
  String videoThumbUrl = '';
  String videoPlatform = '';
  String videoPublishedAt = '';
  String videoAddedAt = '';
  var showOnHomepage = false;
  var extraSettingsExpanded = false;

  void dispose() {
    titleController.dispose();
    sourceController.dispose();
    descriptionController.dispose();
  }
}

class ArticleVideoBlockCard extends StatelessWidget {
  const ArticleVideoBlockCard({
    super.key,
    required this.blockTitleController,
    required this.sourceController,
    required this.descriptionController,
    required this.mediaUrl,
    required this.blockNumber,
    required this.showOnHomepage,
    required this.extraSettingsExpanded,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onVideoChanged,
    required this.onShowOnHomepageChanged,
    required this.onToggleExtraSettings,
    this.blockTitleKey = 'newsAdd.videoBlock',
    this.titleHintKey = 'newsAdd.imageBlockTitleHint',
    this.descriptionLabelKey = 'newsAdd.videoDescription',
    this.descriptionHintKey = 'newsAdd.videoDescriptionHint',
  });

  final TextEditingController blockTitleController;
  final TextEditingController sourceController;
  final quill.QuillController descriptionController;
  final String? mediaUrl;
  final int? blockNumber;
  final bool showOnHomepage;
  final bool extraSettingsExpanded;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<String?> onVideoChanged;
  final ValueChanged<bool> onShowOnHomepageChanged;
  final VoidCallback onToggleExtraSettings;
  final String blockTitleKey;
  final String titleHintKey;
  final String descriptionLabelKey;
  final String descriptionHintKey;

  Future<void> _pickVideo(BuildContext context) async {
    final selected = await showMediaLibraryDialog(context, type: 'video');
    if (selected == null) return;
    onVideoChanged(selected);
  }

  Future<void> _pickVideoUrl(BuildContext context) async {
    final selected = await showUrlVideoDialog(context);
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    onVideoChanged(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return _VideoSectionCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.deepOcean.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(AppRadius.value),
                        ),
                        child: const Icon(
                          Symbols.videocam_outlined,
                          color: AppColors.deepOcean,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.t(blockTitleKey),
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      _HomepageToggle(
                        value: showOnHomepage,
                        onChanged: onShowOnHomepageChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: _videoBlockSoftLine),
                  const SizedBox(height: 20),
                  const _VideoFieldLabel('newsAdd.imageBlockTitle'),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (blockNumber != null) ...[
                          _BlockNumberBadge(blockNumber!),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _VideoTextInputBox(
                            controller: blockTitleController,
                            hintTextKey: titleHintKey,
                            fontSize: 13,
                            bold: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 760;
                      final videoPanel = _VideoPanel(
                        mediaUrl: mediaUrl,
                        onPickVideo: () => _pickVideo(context),
                        onPickUrl: () => _pickVideoUrl(context),
                        onClear: () => onVideoChanged(null),
                      );
                      final descriptionPanel = _DescriptionPanel(
                        controller: descriptionController,
                        labelKey: descriptionLabelKey,
                        hintKey: descriptionHintKey,
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            videoPanel,
                            const SizedBox(height: 16),
                            descriptionPanel,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: videoPanel),
                          const SizedBox(width: 24),
                          Expanded(flex: 10, child: descriptionPanel),
                        ],
                      );
                    },
                  ),
                  _ExtraSettingsPanel(
                    expanded: extraSettingsExpanded,
                    sourceController: sourceController,
                    onToggle: onToggleExtraSettings,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _BlockActionRail(
              canMoveUp: canMoveUp,
              canMoveDown: canMoveDown,
              onDelete: onDelete,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoSectionCard extends StatelessWidget {
  const _VideoSectionCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _videoBlockStrongLine),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HomepageToggle extends StatelessWidget {
  const _HomepageToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniSwitch(value: value, onChanged: onChanged),
        const SizedBox(width: 10),
        Text(
          context.t('newsAdd.showOnHomepage'),
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 34,
          height: 18,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? AppColors.deepOcean : AppColors.softLine,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockActionRail extends StatelessWidget {
  const _BlockActionRail({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _videoBlockSoftLine)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _RailIconButton(
            icon: Symbols.keyboard_arrow_up,
            active: canMoveUp,
            onTap: onMoveUp,
          ),
          const SizedBox(height: 8),
          _RailIconButton(
            icon: Symbols.keyboard_arrow_down,
            active: canMoveDown,
            onTap: onMoveDown,
          ),
          const Spacer(),
          _RailIconButton(
            icon: Symbols.delete_outline,
            active: true,
            activeColor: AppColors.actionRed,
            onTap: onDelete,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RailIconButton extends StatelessWidget {
  const _RailIconButton({
    required this.icon,
    required this.active,
    required this.onTap,
    this.activeColor = AppColors.deepOcean,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? activeColor
        : AppColors.iconMuted.withValues(alpha: 0.38);
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: 0.16)
                  : Colors.transparent,
            ),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

class _BlockNumberBadge extends StatelessWidget {
  const _BlockNumberBadge(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.deepOcean,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _VideoPanel extends StatelessWidget {
  const _VideoPanel({
    required this.mediaUrl,
    required this.onPickVideo,
    required this.onPickUrl,
    required this.onClear,
  });

  final String? mediaUrl;
  final VoidCallback onPickVideo;
  final VoidCallback onPickUrl;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final selectedUrl = mediaUrl?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _VideoFieldLabel('newsAdd.videoPanel'),
        CustomPaint(
          painter: _DashedBorderPainter(
            color: _videoBlockStrongLine,
            radius: AppRadius.value,
          ),
          child: Container(
            height: 252,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: selectedUrl == null || selectedUrl.isEmpty
                ? _EmptyVideoPicker(
                    onPickVideo: onPickVideo,
                    onPickUrl: onPickUrl,
                  )
                : _SelectedVideoPreview(
                    mediaUrl: selectedUrl,
                    onEdit: onPickVideo,
                    onClear: onClear,
                  ),
          ),
        ),
      ],
    );
  }
}

class _EmptyVideoPicker extends StatelessWidget {
  const _EmptyVideoPicker({required this.onPickVideo, required this.onPickUrl});

  final VoidCallback onPickVideo;
  final VoidCallback onPickUrl;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPickVideo,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.deepOcean.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Symbols.add,
                  color: _videoBlockUploadInk,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.t('newsAdd.videoPickUpload'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 26),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPickUrl,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.value),
                      border: Border.all(color: _videoBlockStrongLine),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deepOcean.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Symbols.public,
                          size: 13,
                          color: AppColors.deepOcean,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.t('newsAdd.videoUrlYoutube'),
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
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

class _SelectedVideoPreview extends StatefulWidget {
  const _SelectedVideoPreview({
    required this.mediaUrl,
    required this.onEdit,
    required this.onClear,
  });

  final String mediaUrl;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  State<_SelectedVideoPreview> createState() => _SelectedVideoPreviewState();
}

class _SelectedVideoPreviewState extends State<_SelectedVideoPreview> {
  var _hover = false;
  var _playing = false;

  @override
  void didUpdateWidget(covariant _SelectedVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      _playing = false;
    }
  }

  void _startPlayback() {
    if (!_playing) setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    final youtube = _YoutubeVideoInfo.tryParse(widget.mediaUrl);
    final isDirectVideo =
        youtube == null && _isPlayableDirectVideo(widget.mediaUrl);
    final canPlay = youtube != null || isDirectVideo;
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.value),
              child: youtube == null
                  ? _DirectVideoPreview(
                      mediaUrl: widget.mediaUrl,
                      playing: _playing,
                      showCenterToggle: _hover && _playing,
                      onPlaybackChanged: (playing) {
                        if (_playing == playing) return;
                        setState(() => _playing = playing);
                      },
                    )
                  : _YoutubeVideoPreview(info: youtube, playing: _playing),
            ),
            if (!_playing)
              Center(
                child: _VideoPlayButton(
                  enabled: canPlay,
                  onTap: _startPlayback,
                ),
              ),
            if (_playing)
              Positioned(
                left: 12,
                top: 12,
                child: _VideoInfoStrip(
                  text: youtube == null
                      ? _fileNameFromUrl(widget.mediaUrl)
                      : 'YouTube',
                ),
              )
            else
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _VideoInfoStrip(
                  text: youtube == null
                      ? _fileNameFromUrl(widget.mediaUrl)
                      : 'YouTube',
                ),
              ),
            Positioned(
              top: 10,
              right: 10,
              child: IgnorePointer(
                ignoring: !_hover,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _hover ? 1 : 0,
                  child: Row(
                    children: [
                      _VideoPreviewActionButton(
                        icon: Symbols.edit_outlined,
                        onTap: widget.onEdit,
                      ),
                      const SizedBox(width: 8),
                      _VideoPreviewActionButton(
                        icon: Symbols.delete_outline,
                        color: AppColors.actionRed,
                        onTap: widget.onClear,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlayButton extends StatelessWidget {
  const _VideoPlayButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(
            Symbols.play_circle_fill_rounded,
            size: 58,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Color(0x66000000),
                blurRadius: 14,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectVideoPreview extends StatefulWidget {
  const _DirectVideoPreview({
    required this.mediaUrl,
    required this.playing,
    required this.showCenterToggle,
    required this.onPlaybackChanged,
  });

  final String mediaUrl;
  final bool playing;
  final bool showCenterToggle;
  final ValueChanged<bool> onPlaybackChanged;

  @override
  State<_DirectVideoPreview> createState() => _DirectVideoPreviewState();
}

class _DirectVideoPreviewState extends State<_DirectVideoPreview> {
  VideoPlayerController? _controller;
  bool? _lastControllerPlaying;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void didUpdateWidget(covariant _DirectVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      _disposeController();
      _failed = false;
      _loadVideo();
    } else if (oldWidget.playing != widget.playing) {
      _syncPlayback();
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
    controller?.removeListener(_handleControllerChanged);
    controller?.dispose();
  }

  Future<void> _loadVideo() async {
    final displayUrl = _resolveVideoUrl(widget.mediaUrl);
    if (_isImagePath(displayUrl) || !_isPlayableDirectVideo(widget.mediaUrl)) {
      return;
    }

    final uri = Uri.tryParse(displayUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted || _controller != controller) return;
      _lastControllerPlaying = controller.value.isPlaying;
      controller.addListener(_handleControllerChanged);
      setState(() {});
      _syncPlayback();
    } catch (_) {
      if (!mounted || _controller != controller) return;
      await controller.dispose();
      _controller = null;
      setState(() => _failed = true);
    }
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final playing = controller.value.isPlaying;
    if (_lastControllerPlaying == playing) return;
    _lastControllerPlaying = playing;
    widget.onPlaybackChanged(playing);
  }

  Future<void> _syncPlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.playing && !controller.value.isPlaying) {
      await controller.play();
    } else if (!widget.playing && controller.value.isPlaying) {
      await controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayUrl = _resolveVideoUrl(widget.mediaUrl);
    final isImageThumb = _isImagePath(displayUrl);
    if (isImageThumb) {
      return AdminCachedImage(
        url: displayUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        useOldImageOnUrlChange: true,
        errorWidget: _VideoPlaceholder(mediaUrl: widget.mediaUrl),
      );
    }

    final controller = _controller;
    if (!_failed && controller != null && controller.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _FittedVideo(controller: controller, fit: BoxFit.contain),
          if (widget.playing)
            Center(
              child: IgnorePointer(
                ignoring: !widget.showCenterToggle,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: widget.showCenterToggle ? 1 : 0,
                  child: _DirectCenterToggleButton(controller: controller),
                ),
              ),
            ),
          if (widget.playing)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _DirectVideoControls(controller: controller),
            ),
        ],
      );
    }

    return _failed
        ? const _PlayerErrorSurface()
        : _VideoPlaceholder(mediaUrl: widget.mediaUrl);
  }
}

class _DirectCenterToggleButton extends StatefulWidget {
  const _DirectCenterToggleButton({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_DirectCenterToggleButton> createState() =>
      _DirectCenterToggleButtonState();
}

class _DirectCenterToggleButtonState extends State<_DirectCenterToggleButton> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _DirectCenterToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _toggle() {
    final controller = widget.controller;
    if (!controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = widget.controller.value.isPlaying;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Icon(
          playing
              ? Symbols.pause_circle_filled_rounded
              : Symbols.play_circle_fill,
          size: 62,
          color: Colors.white,
          shadows: const [
            Shadow(
              color: Color(0x66000000),
              blurRadius: 16,
              offset: Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectVideoControls extends StatefulWidget {
  const _DirectVideoControls({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_DirectVideoControls> createState() => _DirectVideoControlsState();
}

class _DirectVideoControlsState extends State<_DirectVideoControls> {
  double _lastAudibleVolume = 1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _DirectVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _togglePlayback() {
    if (!widget.controller.value.isInitialized) return;
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
  }

  void _seekTo(double milliseconds) {
    widget.controller.seekTo(Duration(milliseconds: milliseconds.round()));
  }

  void _toggleMute() {
    final volume = widget.controller.value.volume;
    if (volume > 0) {
      _lastAudibleVolume = volume;
      widget.controller.setVolume(0);
      return;
    }
    widget.controller.setVolume(
      _lastAudibleVolume <= 0 ? 1 : _lastAudibleVolume,
    );
  }

  void _setVolume(double value) {
    final next = value.clamp(0, 1).toDouble();
    if (next > 0) _lastAudibleVolume = next;
    widget.controller.setVolume(next);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final initialized = value.isInitialized;
    final duration = initialized ? value.duration : Duration.zero;
    final position = initialized ? value.position : Duration.zero;
    final maxMs = duration.inMilliseconds
        .toDouble()
        .clamp(1, double.infinity)
        .toDouble();
    final currentMs = position.inMilliseconds
        .toDouble()
        .clamp(0, maxMs)
        .toDouble();
    final volume = value.volume.clamp(0, 1).toDouble();

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Row(
        children: [
          _PlayerIconButton(
            icon: initialized && value.isPlaying
                ? Symbols.pause_rounded
                : Symbols.play_arrow_rounded,
            onTap: _togglePlayback,
          ),
          const SizedBox(width: 6),
          _PlayerIconButton(
            icon: volume <= 0
                ? Symbols.volume_off_rounded
                : Symbols.volume_up_rounded,
            onTap: _toggleMute,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 54,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                activeTrackColor: Colors.white.withValues(alpha: 0.88),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.24),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.12),
              ),
              child: Slider(
                min: 0,
                max: 1,
                value: volume,
                onChanged: initialized ? _setVolume : null,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${_formatDuration(position)} / ${_formatDuration(duration)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.24),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.12),
              ),
              child: Slider(
                min: 0,
                max: maxMs,
                value: currentMs,
                onChanged: initialized ? _seekTo : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FittedVideo extends StatelessWidget {
  const _FittedVideo({required this.controller, required this.fit});

  final VideoPlayerController controller;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) {
      return VideoPlayer(controller);
    }

    return FittedBox(
      fit: fit,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _PlayerIconButton extends StatelessWidget {
  const _PlayerIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _PlayerErrorSurface extends StatelessWidget {
  const _PlayerErrorSurface();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.error_outline_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            _PlayerErrorText(),
          ],
        ),
      ),
    );
  }
}

class _PlayerErrorText extends StatelessWidget {
  const _PlayerErrorText();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t('media.videoPlaybackError'),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _YoutubeVideoPreview extends StatelessWidget {
  const _YoutubeVideoPreview({required this.info, required this.playing});

  final _YoutubeVideoInfo info;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    if (playing) return _YoutubeInlinePlayer(info: info);

    return _YoutubeThumbnail(
      primaryUrl: info.maxThumbnail,
      fallbackUrl: info.fallbackThumbnail,
    );
  }
}

class _YoutubeInlinePlayer extends StatefulWidget {
  const _YoutubeInlinePlayer({required this.info});

  final _YoutubeVideoInfo info;

  @override
  State<_YoutubeInlinePlayer> createState() => _YoutubeInlinePlayerState();
}

class _YoutubeInlinePlayerState extends State<_YoutubeInlinePlayer> {
  late youtube.YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController(widget.info.id);
  }

  @override
  void didUpdateWidget(covariant _YoutubeInlinePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.info.id != widget.info.id) {
      _controller.close();
      _controller = _createController(widget.info.id);
    }
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  youtube.YoutubePlayerController _createController(String id) {
    return youtube.YoutubePlayerController.fromVideoId(
      videoId: id,
      autoPlay: true,
      params: const youtube.YoutubePlayerParams(
        mute: true,
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
        playsInline: true,
        enableCaption: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return youtube.YoutubePlayer(controller: _controller);
  }
}

class _YoutubeThumbnail extends StatefulWidget {
  const _YoutubeThumbnail({
    required this.primaryUrl,
    required this.fallbackUrl,
  });

  final String primaryUrl;
  final String fallbackUrl;

  @override
  State<_YoutubeThumbnail> createState() => _YoutubeThumbnailState();
}

class _YoutubeThumbnailState extends State<_YoutubeThumbnail> {
  late String _url = widget.primaryUrl;
  var _usedFallback = false;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      useOldImageOnUrlChange: true,
      errorWidget: (_, _, _) {
        if (!_usedFallback) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _usedFallback = true;
              _url = widget.fallbackUrl;
            });
          });
        }
        return const _VideoFallbackSurface(label: 'YOUTUBE');
      },
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.mediaUrl});

  final String mediaUrl;

  @override
  Widget build(BuildContext context) {
    final extension = _extensionFromUrl(mediaUrl).toUpperCase();
    return _VideoFallbackSurface(
      label: extension.isEmpty ? 'VIDEO' : extension,
    );
  }
}

class _VideoFallbackSurface extends StatelessWidget {
  const _VideoFallbackSurface({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172535), Color(0xFF2A3B4B)],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Symbols.videocam_outlined,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoInfoStrip extends StatelessWidget {
  const _VideoInfoStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.deepOcean.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _VideoPreviewActionButton extends StatelessWidget {
  const _VideoPreviewActionButton({
    required this.icon,
    required this.onTap,
    this.color = AppColors.deepOcean,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _videoBlockStrongLine),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

class _YoutubeVideoInfo {
  const _YoutubeVideoInfo(this.id);

  final String id;

  String get maxThumbnail => 'https://img.youtube.com/vi/$id/maxresdefault.jpg';
  String get fallbackThumbnail =>
      'https://img.youtube.com/vi/$id/hqdefault.jpg';

  static _YoutubeVideoInfo? tryParse(String value) {
    final text = value.trim();
    final match = RegExp(
      r'^.*(?:youtu\.be\/|v\/|u\/\w\/|embed\/|watch\?v=|&v=|shorts\/)([^#&?]*).*',
      caseSensitive: false,
    ).firstMatch(text);
    final id = match?.group(1);
    if (id == null || id.length != 11) return null;
    return _YoutubeVideoInfo(id);
  }
}

String _resolveVideoUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return MediaService().resolveUrl(trimmed);
}

bool _isImagePath(String value) {
  final path = Uri.tryParse(value)?.path.toLowerCase() ?? value.toLowerCase();
  return path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.png') ||
      path.endsWith('.webp') ||
      path.endsWith('.gif');
}

bool _isPlayableDirectVideo(String value) {
  final resolved = _resolveVideoUrl(value);
  if (_isImagePath(resolved)) return false;
  final uri = Uri.tryParse(resolved);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
  final extension = _extensionFromUrl(resolved).toLowerCase();
  if (extension.isEmpty) return true;
  return const {'mp4', 'm4v', 'mov', 'webm', 'avi', 'mkv'}.contains(extension);
}

String _fileNameFromUrl(String value) {
  final path = Uri.tryParse(value)?.path ?? value;
  final name = path.split('/').where((part) => part.isNotEmpty).lastOrNull;
  return name == null || name.isEmpty ? 'Video' : Uri.decodeComponent(name);
}

String _extensionFromUrl(String value) {
  final path = Uri.tryParse(value)?.path ?? value;
  final fileName = path.split('/').last;
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1);
}

String _formatDuration(Duration duration) {
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

class _DescriptionPanel extends StatelessWidget {
  const _DescriptionPanel({
    required this.controller,
    required this.labelKey,
    required this.hintKey,
  });

  final quill.QuillController controller;
  final String labelKey;
  final String hintKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VideoFieldLabel(labelKey),
        _VideoRichTextEditor(
          controller: controller,
          placeholder: hintKey,
          bodyHeight: 172,
        ),
      ],
    );
  }
}

class _ExtraSettingsPanel extends StatelessWidget {
  const _ExtraSettingsPanel({
    required this.expanded,
    required this.sourceController,
    required this.onToggle,
  });

  final bool expanded;
  final TextEditingController sourceController;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _VideoFieldLabel('newsAdd.videoCredit'),
                          _VideoTextInputBox(
                            controller: sourceController,
                            hintTextKey: 'newsAdd.videoCreditHint',
                            fontSize: 13,
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: SizedBox(
                height: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t(
                        expanded
                            ? 'newsAdd.lessDetails'
                            : 'newsAdd.moreDetails',
                      ),
                      style: TextStyle(
                        color: _videoBlockMutedText.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Symbols.keyboard_arrow_up
                          : Symbols.keyboard_arrow_down,
                      size: 16,
                      color: _videoBlockMutedText.withValues(alpha: 0.72),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoRichTextEditor extends StatelessWidget {
  const _VideoRichTextEditor({
    required this.controller,
    required this.placeholder,
    required this.bodyHeight,
  });

  final quill.QuillController controller;
  final String placeholder;
  final double bodyHeight;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.value);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: _videoBlockStrongLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFBF7F1),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF8C6D53).withValues(alpha: 0.16),
                ),
              ),
            ),
            child: quill.QuillSimpleToolbar(
              controller: controller,
              config: const quill.QuillSimpleToolbarConfig(
                toolbarSize: 30,
                toolbarIconAlignment: WrapAlignment.start,
                toolbarIconCrossAlignment: WrapCrossAlignment.center,
                toolbarSectionSpacing: 4,
                toolbarRunSpacing: 2,
                sectionDividerSpace: 8,
                iconTheme: quill.QuillIconTheme(
                  iconButtonUnselectedData: quill.IconButtonData(
                    iconSize: 17,
                    padding: EdgeInsets.all(2),
                    visualDensity: VisualDensity.compact,
                    constraints: BoxConstraints.tightFor(width: 26, height: 26),
                    color: Color(0xFF8C7A6A),
                  ),
                  iconButtonSelectedData: quill.IconButtonData(
                    iconSize: 17,
                    padding: EdgeInsets.all(2),
                    visualDensity: VisualDensity.compact,
                    constraints: BoxConstraints.tightFor(width: 26, height: 26),
                    color: AppColors.deepOcean,
                  ),
                ),
                multiRowsDisplay: true,
                showFontFamily: false,
                showFontSize: false,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: true,
                showColorButton: true,
                showBackgroundColorButton: true,
                showHeaderStyle: true,
                showListNumbers: true,
                showListBullets: true,
                showListCheck: false,
                showQuote: true,
                showCodeBlock: true,
                showLink: true,
                showSubscript: true,
                showSuperscript: true,
                showUndo: false,
                showRedo: false,
                showSearchButton: false,
                showAlignmentButtons: false,
                showIndent: false,
                showClearFormat: false,
                showDirection: false,
              ),
            ),
          ),
          SizedBox(
            height: bodyHeight,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: quill.QuillEditor.basic(
                  controller: controller,
                  config: quill.QuillEditorConfig(
                    placeholder: context.t(placeholder),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoTextInputBox extends StatelessWidget {
  const _VideoTextInputBox({
    required this.controller,
    required this.hintTextKey,
    this.bold = false,
    this.fontSize = 14,
  });

  final TextEditingController controller;
  final String hintTextKey;
  final bool bold;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _videoBlockStrongLine),
      ),
      child: TextField(
        controller: controller,
        maxLines: 1,
        cursorColor: AppColors.deepOcean,
        style: TextStyle(
          color: AppColors.deepOcean,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: context.t(hintTextKey),
          hintStyle: TextStyle(
            color: AppColors.placeholder,
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
            letterSpacing: 0,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }
}

class _VideoFieldLabel extends StatelessWidget {
  const _VideoFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        context.t(text),
        style: const TextStyle(
          color: _videoBlockMutedText,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashed.addPath(metric.extractPath(distance, distance + 6), Offset.zero);
        distance += 12;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
