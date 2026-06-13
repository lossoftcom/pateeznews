import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as youtube;

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/media_service.dart';
import '../../../../shared/widgets/admin_rich_text_editor.dart'
    show adminEmptyQuillDeltaJson, adminQuillDocumentFromJson;
import '../../../../shared/widgets/media_library_dialog.dart';

const _audioBlockStrongLine = Color(0xFFDDE5E8);
const _audioBlockSoftLine = Color(0xFFE8EEF1);
const _audioBlockMutedText = Color(0xFF5F6F78);
const _audioBlockUploadInk = Color(0xFF6D7B83);

class ArticleAudioBlockEntry {
  ArticleAudioBlockEntry()
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
  var showOnHomepage = false;
  var extraSettingsExpanded = false;

  void dispose() {
    titleController.dispose();
    sourceController.dispose();
    descriptionController.dispose();
  }
}

class ArticleAudioBlockCard extends StatelessWidget {
  const ArticleAudioBlockCard({
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
    required this.onAudioChanged,
    required this.onShowOnHomepageChanged,
    required this.onToggleExtraSettings,
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
  final ValueChanged<String?> onAudioChanged;
  final ValueChanged<bool> onShowOnHomepageChanged;
  final VoidCallback onToggleExtraSettings;

  Future<void> _pickAudio(BuildContext context) async {
    final selected = await showMediaLibraryDialog(context, type: 'audio');
    if (selected == null || selected.trim().isEmpty) return;
    onAudioChanged(selected.trim());
  }

  Future<void> _pickAudioUrl(BuildContext context) async {
    final selected = await showUrlAudioDialog(context);
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    onAudioChanged(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return _AudioSectionCard(
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
                          Icons.mic_none_rounded,
                          color: AppColors.deepOcean,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.t('newsAdd.audioBlock'),
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
                  Container(height: 1, color: _audioBlockSoftLine),
                  const SizedBox(height: 20),
                  const _AudioFieldLabel('newsAdd.imageBlockTitle'),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (blockNumber != null) ...[
                          _BlockNumberBadge(blockNumber!),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _AudioTextInputBox(
                            controller: blockTitleController,
                            hintTextKey: 'newsAdd.imageBlockTitleHint',
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
                      final audioPanel = _AudioPanel(
                        mediaUrl: mediaUrl,
                        onPickAudio: () => _pickAudio(context),
                        onPickUrl: () => _pickAudioUrl(context),
                        onClear: () => onAudioChanged(null),
                      );
                      final descriptionPanel = _DescriptionPanel(
                        controller: descriptionController,
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            audioPanel,
                            const SizedBox(height: 16),
                            descriptionPanel,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: audioPanel),
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

class _AudioSectionCard extends StatelessWidget {
  const _AudioSectionCard({required this.child, this.padding});

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
        border: Border.all(color: _audioBlockStrongLine),
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
        border: Border(right: BorderSide(color: _audioBlockSoftLine)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _RailIconButton(
            icon: Icons.keyboard_arrow_up,
            active: canMoveUp,
            onTap: onMoveUp,
          ),
          const SizedBox(height: 8),
          _RailIconButton(
            icon: Icons.keyboard_arrow_down,
            active: canMoveDown,
            onTap: onMoveDown,
          ),
          const Spacer(),
          _RailIconButton(
            icon: Icons.delete_outline,
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

class _AudioPanel extends StatelessWidget {
  const _AudioPanel({
    required this.mediaUrl,
    required this.onPickAudio,
    required this.onPickUrl,
    required this.onClear,
  });

  final String? mediaUrl;
  final VoidCallback onPickAudio;
  final VoidCallback onPickUrl;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final selectedUrl = mediaUrl?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AudioFieldLabel('newsAdd.audioPanel'),
        CustomPaint(
          painter: _DashedBorderPainter(
            color: _audioBlockStrongLine,
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
                ? _EmptyAudioPicker(
                    onPickAudio: onPickAudio,
                    onPickUrl: onPickUrl,
                  )
                : _SelectedAudioPreview(
                    mediaUrl: selectedUrl,
                    onPickAudio: onPickAudio,
                    onClear: onClear,
                  ),
          ),
        ),
      ],
    );
  }
}

class _EmptyAudioPicker extends StatelessWidget {
  const _EmptyAudioPicker({required this.onPickAudio, required this.onPickUrl});

  final VoidCallback onPickAudio;
  final VoidCallback onPickUrl;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPickAudio,
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
                  Icons.add,
                  color: _audioBlockUploadInk,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.t('newsAdd.audioPickUpload'),
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
                      border: Border.all(color: _audioBlockStrongLine),
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
                          Icons.public,
                          size: 13,
                          color: AppColors.deepOcean,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.t('newsAdd.audioUrlYoutube'),
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

class _SelectedAudioPreview extends StatefulWidget {
  const _SelectedAudioPreview({
    required this.mediaUrl,
    required this.onPickAudio,
    required this.onClear,
  });

  final String mediaUrl;
  final VoidCallback onPickAudio;
  final VoidCallback onClear;

  @override
  State<_SelectedAudioPreview> createState() => _SelectedAudioPreviewState();
}

class _SelectedAudioPreviewState extends State<_SelectedAudioPreview> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 310),
                child: _AudioPlayerCard(mediaUrl: widget.mediaUrl),
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
                      _AudioPreviewActionButton(
                        icon: Icons.edit_outlined,
                        onTap: widget.onPickAudio,
                      ),
                      const SizedBox(width: 8),
                      _AudioPreviewActionButton(
                        icon: Icons.delete_outline,
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

class _AudioPlayerCard extends StatefulWidget {
  const _AudioPlayerCard({required this.mediaUrl});

  final String mediaUrl;

  @override
  State<_AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<_AudioPlayerCard> {
  VideoPlayerController? _controller;
  var _failed = false;
  double _lastAudibleVolume = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AudioPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
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
    controller?.removeListener(_refresh);
    controller?.dispose();
  }

  Future<void> _load() async {
    if (_YoutubeAudioInfo.tryParse(widget.mediaUrl) != null) return;

    final url = _resolveAudioUrl(widget.mediaUrl);
    final uri = Uri.tryParse(url);
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

  void _seekTo(double milliseconds) {
    _controller?.seekTo(Duration(milliseconds: milliseconds.round()));
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

  @override
  Widget build(BuildContext context) {
    final youtubeAudio = _YoutubeAudioInfo.tryParse(widget.mediaUrl);
    if (youtubeAudio != null) {
      return _YoutubeAudioCard(info: youtubeAudio);
    }

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
      height: 98,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _audioBlockStrongLine),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: _failed
          ? _AudioErrorSurface()
          : Row(
              children: [
                _AudioPlayButton(
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
                                  _formatDuration(position),
                                  style: const TextStyle(
                                    color: AppColors.deepOcean,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDuration(duration),
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
                                inactiveTrackColor: _audioBlockSoftLine,
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
                _AudioIconButton(
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

class _YoutubeAudioCard extends StatefulWidget {
  const _YoutubeAudioCard({required this.info});

  final _YoutubeAudioInfo info;

  @override
  State<_YoutubeAudioCard> createState() => _YoutubeAudioCardState();
}

class _YoutubeAudioCardState extends State<_YoutubeAudioCard> {
  var _playing = false;

  @override
  void didUpdateWidget(covariant _YoutubeAudioCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.info.id != widget.info.id) {
      _playing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 158,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _audioBlockStrongLine),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _playing
              ? _YoutubeAudioInlinePlayer(info: widget.info)
              : _YoutubeAudioThumbnail(info: widget.info),
          if (!_playing)
            Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _playing = true),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 54,
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
              ),
            ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.deepOcean.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.info.isMusic
                        ? Icons.music_note_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.info.isMusic ? 'YouTube Music' : 'YouTube',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YoutubeAudioInlinePlayer extends StatefulWidget {
  const _YoutubeAudioInlinePlayer({required this.info});

  final _YoutubeAudioInfo info;

  @override
  State<_YoutubeAudioInlinePlayer> createState() =>
      _YoutubeAudioInlinePlayerState();
}

class _YoutubeAudioInlinePlayerState extends State<_YoutubeAudioInlinePlayer> {
  late youtube.YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController(widget.info.id);
  }

  @override
  void didUpdateWidget(covariant _YoutubeAudioInlinePlayer oldWidget) {
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
        mute: false,
        showControls: true,
        showFullscreenButton: false,
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

class _YoutubeAudioThumbnail extends StatefulWidget {
  const _YoutubeAudioThumbnail({required this.info});

  final _YoutubeAudioInfo info;

  @override
  State<_YoutubeAudioThumbnail> createState() => _YoutubeAudioThumbnailState();
}

class _YoutubeAudioThumbnailState extends State<_YoutubeAudioThumbnail> {
  late String _url = widget.info.maxThumbnail;
  var _usedFallback = false;

  @override
  void didUpdateWidget(covariant _YoutubeAudioThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.info.id != widget.info.id) {
      _url = widget.info.maxThumbnail;
      _usedFallback = false;
    }
  }

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
              _url = widget.info.fallbackThumbnail;
            });
          });
        }
        return const _AudioYoutubeFallbackSurface();
      },
    );
  }
}

class _AudioYoutubeFallbackSurface extends StatelessWidget {
  const _AudioYoutubeFallbackSurface();

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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'YOUTUBE',
                style: TextStyle(
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

class _AudioPlayButton extends StatelessWidget {
  const _AudioPlayButton({
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

class _AudioIconButton extends StatelessWidget {
  const _AudioIconButton({
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
            color: enabled ? _audioBlockMutedText : AppColors.placeholder,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _AudioErrorSurface extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('media.audioPlaybackError'),
        style: const TextStyle(
          color: AppColors.actionRed,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AudioPreviewActionButton extends StatelessWidget {
  const _AudioPreviewActionButton({
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
            border: Border.all(color: _audioBlockStrongLine),
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

class _DescriptionPanel extends StatelessWidget {
  const _DescriptionPanel({required this.controller});

  final quill.QuillController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AudioFieldLabel('newsAdd.audioDescription'),
        _AudioRichTextEditor(
          controller: controller,
          placeholder: 'newsAdd.audioDescriptionHint',
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
                      child: _AudioTextInputBox(
                        controller: sourceController,
                        hintTextKey: 'newsAdd.audioCreditHint',
                        fontSize: 13,
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
                        color: _audioBlockMutedText.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: _audioBlockMutedText.withValues(alpha: 0.72),
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

class _AudioRichTextEditor extends StatelessWidget {
  const _AudioRichTextEditor({
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
        border: Border.all(color: _audioBlockStrongLine),
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

class _AudioTextInputBox extends StatelessWidget {
  const _AudioTextInputBox({
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
        border: Border.all(color: _audioBlockStrongLine),
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

class _AudioFieldLabel extends StatelessWidget {
  const _AudioFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        context.t(text),
        style: const TextStyle(
          color: _audioBlockMutedText,
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

String _resolveAudioUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return MediaService().resolveUrl(trimmed);
}

class _YoutubeAudioInfo {
  const _YoutubeAudioInfo({required this.id, required this.isMusic});

  final String id;
  final bool isMusic;

  String get maxThumbnail => 'https://img.youtube.com/vi/$id/maxresdefault.jpg';
  String get fallbackThumbnail =>
      'https://img.youtube.com/vi/$id/hqdefault.jpg';

  static _YoutubeAudioInfo? tryParse(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);
    if (uri != null && uri.host.isNotEmpty) {
      final host = uri.host.toLowerCase().replaceFirst('www.', '');
      final isYoutubeHost =
          host == 'youtu.be' ||
          host == 'youtube-nocookie.com' ||
          host.endsWith('youtube.com');
      if (isYoutubeHost) {
        final fromQuery = uri.queryParameters['v'];
        if (fromQuery != null && fromQuery.isNotEmpty) {
          final id = _cleanYoutubeAudioId(fromQuery);
          if (id != null) {
            return _YoutubeAudioInfo(
              id: id,
              isMusic: host == 'music.youtube.com',
            );
          }
        }

        if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
          final id = _cleanYoutubeAudioId(uri.pathSegments.first);
          if (id != null) return _YoutubeAudioInfo(id: id, isMusic: false);
        }

        if (uri.pathSegments.length >= 2 &&
            const {
              'embed',
              'shorts',
              'live',
            }.contains(uri.pathSegments.first)) {
          final id = _cleanYoutubeAudioId(uri.pathSegments[1]);
          if (id != null) {
            return _YoutubeAudioInfo(
              id: id,
              isMusic: host == 'music.youtube.com',
            );
          }
        }
      }
    }

    final match = RegExp(
      r'^.*(?:youtu\.be\/|v\/|u\/\w\/|embed\/|watch\?v=|&v=|music\.youtube\.com\/watch\?v=)([^#&?]*).*',
      caseSensitive: false,
    ).firstMatch(text);
    final id = _cleanYoutubeAudioId(match?.group(1));
    if (id == null) return null;
    return _YoutubeAudioInfo(
      id: id,
      isMusic: text.toLowerCase().contains('music.youtube.com'),
    );
  }
}

String? _cleanYoutubeAudioId(String? value) {
  if (value == null) return null;
  final clean = value.trim();
  if (clean.length != 11) return null;
  return clean;
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
