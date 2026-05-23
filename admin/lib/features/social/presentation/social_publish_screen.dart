import 'package:flutter/material.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../news/data/admin_news_repository.dart';
import 'social_platform_data.dart';
import 'widgets/social_platform_selector.dart';
import 'widgets/social_post_type_selector.dart';
import 'widgets/social_caption_editor.dart';
import 'widgets/social_media_picker.dart';
import 'widgets/social_hashtag_input.dart';
import 'widgets/social_news_source_picker.dart';
import 'widgets/social_preview_panel.dart';

/// Professional social media bulk publish screen.
class SocialPublishScreen extends StatefulWidget {
  const SocialPublishScreen({super.key, required this.newsRepository});

  final AdminNewsRepository newsRepository;

  @override
  State<SocialPublishScreen> createState() => _SocialPublishScreenState();
}

class _SocialPublishScreenState extends State<SocialPublishScreen>
    with SingleTickerProviderStateMixin {
  final _captionController = TextEditingController();

  SocialPublishData _data = const SocialPublishData(
    selectedPlatforms: {SocialPlatform.instagram, SocialPlatform.facebook},
  );

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _updateData(SocialPublishData Function(SocialPublishData d) updater) {
    setState(() => _data = updater(_data));
  }

  /// Compute available post types from selected platforms.
  List<SocialPostType> get _availableTypes {
    if (_data.selectedPlatforms.isEmpty) return [SocialPostType.feed];
    final sets = _data.selectedPlatforms
        .map((p) => platformInfoFor(p).supportedTypes.toSet());
    var intersection = sets.first;
    for (final s in sets.skip(1)) {
      intersection = intersection.intersection(s);
    }
    final result = intersection.toList();
    if (result.isEmpty) return [SocialPostType.feed];
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value * 2),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(context, isCompact),

                // Content
                Expanded(
                  child: isCompact
                      ? _buildCompactLayout(context)
                      : _buildSplitLayout(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isCompact) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.actionRed.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.value * 2),
            ),
            child: const Icon(
              Icons.send_rounded,
              size: 18,
              color: AppColors.actionRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('social.publish.title'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepOcean,
                    letterSpacing: -0.2,
                  ),
                ),
                if (!isCompact) ...[
                  const SizedBox(height: 1),
                  Text(
                    context.t('social.publish.subtitle'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.support,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Schedule button
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.schedule_rounded, size: 16),
            label: isCompact
                ? const SizedBox.shrink()
                : Text(context.t('social.publish.schedule')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepOcean,
              side: const BorderSide(color: AppColors.line),
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 14),
              minimumSize: const Size(0, 36),
              maximumSize: const Size(double.infinity, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value * 2),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'PateezInter',
                letterSpacing: 0,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Publish button
          FilledButton.icon(
            onPressed: _data.selectedPlatforms.isEmpty ? null : () {},
            icon: const Icon(Icons.send_rounded, size: 16),
            label: isCompact
                ? const SizedBox.shrink()
                : Text(context.t('social.publish.publishNow')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              disabledBackgroundColor:
                  AppColors.actionRed.withValues(alpha: 0.4),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 18),
              minimumSize: const Size(0, 36),
              maximumSize: const Size(double.infinity, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value * 2),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'PateezInter',
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Editor panel
        Expanded(
          flex: 55,
          child: _buildEditorPanel(context),
        ),

        // Divider
        Container(
          width: 1,
          color: AppColors.line,
        ),

        // Preview panel
        Expanded(
          flex: 45,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SocialPreviewPanel(
              selectedPlatforms: _data.selectedPlatforms,
              data: _data,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: TabBar(
              labelColor: AppColors.deepOcean,
              unselectedLabelColor: AppColors.support,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'PateezInter',
                letterSpacing: 0,
              ),
              indicatorColor: AppColors.actionRed,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(text: context.t('social.publish.tabEditor')),
                Tab(text: context.t('social.publish.tabPreview')),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildEditorPanel(context),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SocialPreviewPanel(
                    selectedPlatforms: _data.selectedPlatforms,
                    data: _data,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorPanel(BuildContext context) {
    final availableTypes = _availableTypes;
    // Ensure current type is still valid.
    if (!availableTypes.contains(_data.postType)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateData((d) => d.copyWith(postType: availableTypes.first));
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform selector
          SocialPlatformSelector(
            selected: _data.selectedPlatforms,
            onChanged: (platforms) =>
                _updateData((d) => d.copyWith(selectedPlatforms: platforms)),
          ),

          const SizedBox(height: 22),

          // Post type selector
          SocialPostTypeSelector(
            current: _data.postType,
            available: availableTypes,
            onChanged: (type) =>
                _updateData((d) => d.copyWith(postType: type)),
          ),

          if (availableTypes.length > 1) const SizedBox(height: 22),

          // News source
          SocialNewsSourcePicker(
            newsRepository: widget.newsRepository,
            selectedLink: _data.newsLink,
            manualLink: _data.manualLink,
            onNewsSelected: ({
              required String title,
              required String imageUrl,
              required String link,
              required String summary,
              required String keywords,
              required String category,
              required String type,
            }) {
              // Auto-fill caption with summary if caption is empty
              if (summary.isNotEmpty && _captionController.text.trim().isEmpty) {
                _captionController.text = summary;
              }

              // Auto-fill hashtags from keywords (comma-separated)
              List<String> parsedTags = _data.hashtags;
              if (keywords.isNotEmpty && _data.hashtags.isEmpty) {
                parsedTags = keywords
                    .split(RegExp(r'[,;،]'))
                    .map((k) => k.trim().replaceAll('#', '').replaceAll(' ', '_'))
                    .where((k) => k.isNotEmpty)
                    .toList();
              }

              // Auto-fill media with news thumbnail
              List<String> mediaList = _data.mediaUrls;
              if (imageUrl.isNotEmpty && _data.mediaUrls.isEmpty) {
                mediaList = [imageUrl];
              }

              _updateData((d) => d.copyWith(
                    newsTitle: title,
                    newsImageUrl: imageUrl,
                    newsLink: link,
                    newsSummary: summary,
                    newsKeywords: keywords,
                    newsCategory: category,
                    newsType: type,
                    caption: _captionController.text,
                    hashtags: parsedTags,
                    mediaUrls: mediaList,
                  ));
            },
            onManualLinkChanged: (link) =>
                _updateData((d) => d.copyWith(manualLink: link)),
          ),

          const SizedBox(height: 22),

          // Caption editor
          SocialCaptionEditor(
            controller: _captionController,
            selectedPlatforms: _data.selectedPlatforms,
            onChanged: (text) =>
                _updateData((d) => d.copyWith(caption: text)),
          ),

          const SizedBox(height: 22),

          // Media picker
          SocialMediaPicker(
            mediaUrls: _data.mediaUrls,
            onPickMedia: () {
              _showMediaUrlDialog(context);
            },
            onClearMedia: () =>
                _updateData((d) => d.copyWith(mediaUrls: [])),
            onRemoveMedia: (index) {
              final urls = List<String>.from(_data.mediaUrls);
              if (index < urls.length) {
                urls.removeAt(index);
                _updateData((d) => d.copyWith(mediaUrls: urls));
              }
            },
          ),

          const SizedBox(height: 22),

          // Hashtags
          SocialHashtagInput(
            hashtags: _data.hashtags,
            onChanged: (tags) =>
                _updateData((d) => d.copyWith(hashtags: tags)),
          ),

          const SizedBox(height: 30),

          // Summary info
          _buildSummary(context),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    if (_data.selectedPlatforms.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.deepOcean.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppRadius.value * 2),
        border: Border.all(
          color: AppColors.deepOcean.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.deepOcean.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t(
                'social.publish.summaryInfo',
                values: {
                  'count': _data.selectedPlatforms.length,
                  'type': context.t(postTypeKey(_data.postType)),
                },
              ),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.inkSoft.withValues(alpha: 0.8),
                height: 1.4,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMediaUrlDialog(BuildContext context) async {
    final urlController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.t('social.publish.mediaUrlTitle'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.deepOcean,
          ),
        ),
        content: TextField(
          controller: urlController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'https://',
            hintStyle: const TextStyle(color: AppColors.placeholder),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.value * 2),
            ),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.value * 3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              context.t('social.publish.cancel'),
              style: const TextStyle(color: AppColors.support),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(urlController.text),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.actionRed,
            ),
            child: Text(
              context.t('social.publish.add'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    urlController.dispose();

    if (result != null && result.trim().isNotEmpty) {
      final urls = List<String>.from(_data.mediaUrls)..add(result.trim());
      _updateData((d) => d.copyWith(mediaUrls: urls));
    }
  }
}
