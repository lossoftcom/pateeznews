import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/symbol_icon.dart';

class ContentSettingsScreen extends StatefulWidget {
  const ContentSettingsScreen({super.key});

  @override
  State<ContentSettingsScreen> createState() => _ContentSettingsScreenState();
}

class _ContentSettingsScreenState extends State<ContentSettingsScreen> {
  final _paginationController = TextEditingController(text: '16');
  final _popularLimitController = TextEditingController(text: '5');
  final _relatedLimitController = TextEditingController(text: '6');
  final _maxImageSizeController = TextEditingController(text: '20');
  final _maxVideoSizeController = TextEditingController(text: '50');
  final _maxAudioSizeController = TextEditingController(text: '20');
  final _maxFileSizeController = TextEditingController(text: '50');
  final _featuredDurationController = TextEditingController(text: '10');
  final _featuredLimitController = TextEditingController(text: '15');
  final _autoDeleteDaysController = TextEditingController(text: '30');

  var _selectedTab = _ContentSettingsTab.general;
  var _showFeaturedSection = true;
  var _commentSystem = true;
  var _commentApprovalSystem = true;
  var _emojiReactions = true;
  var _showLatestPosts = true;
  var _bulkPostUpload = true;
  var _deleteImagesAlongPost = false;
  var _audioDownloadButton = true;
  var _showPostAuthor = true;
  var _showPostDate = true;
  var _showPostViewCount = true;
  var _requireNewPostApproval = true;
  var _requireEditedPostApproval = true;
  var _redirectRssPosts = false;
  var _autoPostDeletion = false;
  var _postUrlStructure = _ContentSettingOptions.slugUrls;
  var _imageFileFormat = 'WEBP';
  var _featuredContentSource = _ContentSettingOptions.manualSelection;
  var _featuredSortingLogic = _ContentSettingOptions.sliderOrder;
  var _autoDeletePosts = _ContentSettingOptions.deleteAllPosts;
  var _postFormats = {
    for (final key in _ContentSettingOptions.postFormatKeys) key: true,
  };

  @override
  void dispose() {
    _paginationController.dispose();
    _popularLimitController.dispose();
    _relatedLimitController.dispose();
    _maxImageSizeController.dispose();
    _maxVideoSizeController.dispose();
    _maxAudioSizeController.dispose();
    _maxFileSizeController.dispose();
    _featuredDurationController.dispose();
    _featuredLimitController.dispose();
    _autoDeleteDaysController.dispose();
    super.dispose();
  }

  void _showSavedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('contentSettings.saveSuccess'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            28,
            horizontalPadding,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ContentHeader(title: context.t('contentSettings.title')),
              const SizedBox(height: 22),
              _ContentSettingsGrid(
                left: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MainContentSettingsCard(
                      selectedTab: _selectedTab,
                      onTabChanged: (tab) => setState(() => _selectedTab = tab),
                      child: switch (_selectedTab) {
                        _ContentSettingsTab.general => _GeneralTab(
                          showFeaturedSection: _showFeaturedSection,
                          commentSystem: _commentSystem,
                          commentApprovalSystem: _commentApprovalSystem,
                          emojiReactions: _emojiReactions,
                          showLatestPosts: _showLatestPosts,
                          paginationController: _paginationController,
                          onShowFeaturedSectionChanged: (value) =>
                              setState(() => _showFeaturedSection = value),
                          onCommentSystemChanged: (value) =>
                              setState(() => _commentSystem = value),
                          onCommentApprovalSystemChanged: (value) =>
                              setState(() => _commentApprovalSystem = value),
                          onEmojiReactionsChanged: (value) =>
                              setState(() => _emojiReactions = value),
                          onShowLatestPostsChanged: (value) =>
                              setState(() => _showLatestPosts = value),
                          onSave: _showSavedMessage,
                        ),
                        _ContentSettingsTab.posts => _PostsTab(
                          postUrlStructure: _postUrlStructure,
                          bulkPostUpload: _bulkPostUpload,
                          deleteImagesAlongPost: _deleteImagesAlongPost,
                          audioDownloadButton: _audioDownloadButton,
                          showPostAuthor: _showPostAuthor,
                          showPostDate: _showPostDate,
                          showPostViewCount: _showPostViewCount,
                          requireNewPostApproval: _requireNewPostApproval,
                          requireEditedPostApproval: _requireEditedPostApproval,
                          redirectRssPosts: _redirectRssPosts,
                          popularLimitController: _popularLimitController,
                          relatedLimitController: _relatedLimitController,
                          onPostUrlStructureChanged: (value) {
                            if (value == null) return;
                            setState(() => _postUrlStructure = value);
                          },
                          onBulkPostUploadChanged: (value) =>
                              setState(() => _bulkPostUpload = value),
                          onDeleteImagesAlongPostChanged: (value) =>
                              setState(() => _deleteImagesAlongPost = value),
                          onAudioDownloadButtonChanged: (value) =>
                              setState(() => _audioDownloadButton = value),
                          onShowPostAuthorChanged: (value) =>
                              setState(() => _showPostAuthor = value),
                          onShowPostDateChanged: (value) =>
                              setState(() => _showPostDate = value),
                          onShowPostViewCountChanged: (value) =>
                              setState(() => _showPostViewCount = value),
                          onRequireNewPostApprovalChanged: (value) =>
                              setState(() => _requireNewPostApproval = value),
                          onRequireEditedPostApprovalChanged: (value) =>
                              setState(
                                () => _requireEditedPostApproval = value,
                              ),
                          onRedirectRssPostsChanged: (value) =>
                              setState(() => _redirectRssPosts = value),
                          onSave: _showSavedMessage,
                        ),
                        _ContentSettingsTab.postFormats => _PostFormatsTab(
                          values: _postFormats,
                          onChanged: (key, value) => setState(
                            () => _postFormats = {..._postFormats, key: value},
                          ),
                          onSave: _showSavedMessage,
                        ),
                        _ContentSettingsTab.fileUpload => _FileUploadTab(
                          imageFileFormat: _imageFileFormat,
                          maxImageSizeController: _maxImageSizeController,
                          maxVideoSizeController: _maxVideoSizeController,
                          maxAudioSizeController: _maxAudioSizeController,
                          maxFileSizeController: _maxFileSizeController,
                          onImageFileFormatChanged: (value) {
                            if (value == null) return;
                            setState(() => _imageFileFormat = value);
                          },
                          onSave: _showSavedMessage,
                        ),
                      },
                    ),
                    const SizedBox(height: 18),
                    _FeaturedContentCard(
                      contentSource: _featuredContentSource,
                      sortingLogic: _featuredSortingLogic,
                      durationController: _featuredDurationController,
                      limitController: _featuredLimitController,
                      onContentSourceChanged: (value) {
                        if (value == null) return;
                        setState(() => _featuredContentSource = value);
                      },
                      onSortingLogicChanged: (value) {
                        if (value == null) return;
                        setState(() => _featuredSortingLogic = value);
                      },
                      onSave: _showSavedMessage,
                    ),
                  ],
                ),
                right: _AutoPostDeletionCard(
                  enabled: _autoPostDeletion,
                  daysController: _autoDeleteDaysController,
                  postsValue: _autoDeletePosts,
                  onEnabledChanged: (value) =>
                      setState(() => _autoPostDeletion = value),
                  onPostsChanged: (value) {
                    if (value == null) return;
                    setState(() => _autoDeletePosts = value);
                  },
                  onSave: _showSavedMessage,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _ContentSettingsGrid extends StatelessWidget {
  const _ContentSettingsGrid({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1120) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 18), right],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 13, child: left),
            const SizedBox(width: 22),
            Expanded(flex: 8, child: right),
          ],
        );
      },
    );
  }
}

class _MainContentSettingsCard extends StatelessWidget {
  const _MainContentSettingsCard({
    required this.selectedTab,
    required this.onTabChanged,
    required this.child,
  });

  final _ContentSettingsTab selectedTab;
  final ValueChanged<_ContentSettingsTab> onTabChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _ContentCard(
      minHeight: 464,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ContentTabs(selected: selectedTab, onSelected: onTabChanged),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.child, this.title, this.minHeight});

  final String? title;
  final Widget child;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: minHeight == null
          ? null
          : BoxConstraints(minHeight: minHeight!),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            _ContentCardTitle(title!),
            const SizedBox(height: 26),
          ],
          child,
        ],
      ),
    );
  }
}

class _ContentCardTitle extends StatelessWidget {
  const _ContentCardTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t(title),
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _ContentTabs extends StatelessWidget {
  const _ContentTabs({required this.selected, required this.onSelected});

  final _ContentSettingsTab selected;
  final ValueChanged<_ContentSettingsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tab in _ContentSettingsTab.values)
          _ContentTabButton(
            label: tab.labelKey,
            selected: selected == tab,
            onTap: () => onSelected(tab),
          ),
      ],
    );
  }
}

class _ContentTabButton extends StatelessWidget {
  const _ContentTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: onTap,
        style:
            TextButton.styleFrom(
              backgroundColor: selected ? AppColors.actionRed : Colors.white,
              foregroundColor: selected ? Colors.white : AppColors.deepOcean,
              side: BorderSide(
                color: selected
                    ? AppColors.actionRed
                    : AppColors.line.withValues(alpha: 0.88),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Text(context.t(label)),
      ),
    );
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab({
    required this.showFeaturedSection,
    required this.commentSystem,
    required this.commentApprovalSystem,
    required this.emojiReactions,
    required this.showLatestPosts,
    required this.paginationController,
    required this.onShowFeaturedSectionChanged,
    required this.onCommentSystemChanged,
    required this.onCommentApprovalSystemChanged,
    required this.onEmojiReactionsChanged,
    required this.onShowLatestPostsChanged,
    required this.onSave,
  });

  final bool showFeaturedSection;
  final bool commentSystem;
  final bool commentApprovalSystem;
  final bool emojiReactions;
  final bool showLatestPosts;
  final TextEditingController paginationController;
  final ValueChanged<bool> onShowFeaturedSectionChanged;
  final ValueChanged<bool> onCommentSystemChanged;
  final ValueChanged<bool> onCommentApprovalSystemChanged;
  final ValueChanged<bool> onEmojiReactionsChanged;
  final ValueChanged<bool> onShowLatestPostsChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SwitchLine(
          label: 'contentSettings.general.showFeaturedSection',
          value: showFeaturedSection,
          valueLabel: 'contentSettings.value.yes',
          onChanged: onShowFeaturedSectionChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.general.commentSystem',
          value: commentSystem,
          valueLabel: 'contentSettings.value.enabled',
          onChanged: onCommentSystemChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.general.commentApprovalSystem',
          value: commentApprovalSystem,
          valueLabel: 'contentSettings.value.enabled',
          onChanged: onCommentApprovalSystemChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.general.emojiReactions',
          value: emojiReactions,
          valueLabel: 'contentSettings.value.enabled',
          onChanged: onEmojiReactionsChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.general.showLatestPosts',
          value: showLatestPosts,
          valueLabel: 'contentSettings.value.yes',
          onChanged: onShowLatestPostsChanged,
        ),
        _InputLine(
          label: 'contentSettings.general.pagination',
          controller: paginationController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        _SaveRow(onPressed: onSave),
      ],
    );
  }
}

class _PostsTab extends StatelessWidget {
  const _PostsTab({
    required this.postUrlStructure,
    required this.bulkPostUpload,
    required this.deleteImagesAlongPost,
    required this.audioDownloadButton,
    required this.showPostAuthor,
    required this.showPostDate,
    required this.showPostViewCount,
    required this.requireNewPostApproval,
    required this.requireEditedPostApproval,
    required this.redirectRssPosts,
    required this.popularLimitController,
    required this.relatedLimitController,
    required this.onPostUrlStructureChanged,
    required this.onBulkPostUploadChanged,
    required this.onDeleteImagesAlongPostChanged,
    required this.onAudioDownloadButtonChanged,
    required this.onShowPostAuthorChanged,
    required this.onShowPostDateChanged,
    required this.onShowPostViewCountChanged,
    required this.onRequireNewPostApprovalChanged,
    required this.onRequireEditedPostApprovalChanged,
    required this.onRedirectRssPostsChanged,
    required this.onSave,
  });

  final String postUrlStructure;
  final bool bulkPostUpload;
  final bool deleteImagesAlongPost;
  final bool audioDownloadButton;
  final bool showPostAuthor;
  final bool showPostDate;
  final bool showPostViewCount;
  final bool requireNewPostApproval;
  final bool requireEditedPostApproval;
  final bool redirectRssPosts;
  final TextEditingController popularLimitController;
  final TextEditingController relatedLimitController;
  final ValueChanged<String?> onPostUrlStructureChanged;
  final ValueChanged<bool> onBulkPostUploadChanged;
  final ValueChanged<bool> onDeleteImagesAlongPostChanged;
  final ValueChanged<bool> onAudioDownloadButtonChanged;
  final ValueChanged<bool> onShowPostAuthorChanged;
  final ValueChanged<bool> onShowPostDateChanged;
  final ValueChanged<bool> onShowPostViewCountChanged;
  final ValueChanged<bool> onRequireNewPostApprovalChanged;
  final ValueChanged<bool> onRequireEditedPostApprovalChanged;
  final ValueChanged<bool> onRedirectRssPostsChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectLine(
          label: 'contentSettings.posts.urlStructure',
          helper: 'contentSettings.posts.urlStructureHelp',
          value: postUrlStructure,
          options: _ContentSettingOptions.postUrlOptions,
          onChanged: onPostUrlStructureChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.bulkUpload',
          value: bulkPostUpload,
          valueLabel: 'contentSettings.value.enabled',
          onChanged: onBulkPostUploadChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.deleteImages',
          value: deleteImagesAlongPost,
          valueLabel: 'contentSettings.value.enabled',
          onChanged: onDeleteImagesAlongPostChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.audioDownload',
          value: audioDownloadButton,
          valueLabel: 'contentSettings.value.enabled',
          onChanged: onAudioDownloadButtonChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.showAuthor',
          value: showPostAuthor,
          valueLabel: 'contentSettings.value.yes',
          onChanged: onShowPostAuthorChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.showDate',
          value: showPostDate,
          valueLabel: 'contentSettings.value.yes',
          onChanged: onShowPostDateChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.showViewCount',
          value: showPostViewCount,
          valueLabel: 'contentSettings.value.yes',
          onChanged: onShowPostViewCountChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.newApproval',
          value: requireNewPostApproval,
          valueLabel: 'contentSettings.value.yes',
          onChanged: onRequireNewPostApprovalChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.editedApproval',
          value: requireEditedPostApproval,
          valueLabel: 'contentSettings.value.yes',
          onChanged: onRequireEditedPostApprovalChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.redirectRss',
          value: redirectRssPosts,
          valueLabel: 'contentSettings.value.yes',
          onChanged: onRedirectRssPostsChanged,
        ),
        _InputLine(
          label: 'contentSettings.posts.popularLimit',
          controller: popularLimitController,
          keyboardType: TextInputType.number,
        ),
        _InputLine(
          label: 'contentSettings.posts.relatedLimit',
          controller: relatedLimitController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        _SaveRow(onPressed: onSave),
      ],
    );
  }
}

class _PostFormatsTab extends StatelessWidget {
  const _PostFormatsTab({
    required this.values,
    required this.onChanged,
    required this.onSave,
  });

  final Map<String, bool> values;
  final void Function(String key, bool value) onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final key in _ContentSettingOptions.postFormatKeys)
          _SwitchLine(
            label: key,
            value: values[key] ?? false,
            valueLabel: 'contentSettings.value.enabled',
            onChanged: (value) => onChanged(key, value),
          ),
        const SizedBox(height: 8),
        _SaveRow(onPressed: onSave),
      ],
    );
  }
}

class _FileUploadTab extends StatelessWidget {
  const _FileUploadTab({
    required this.imageFileFormat,
    required this.maxImageSizeController,
    required this.maxVideoSizeController,
    required this.maxAudioSizeController,
    required this.maxFileSizeController,
    required this.onImageFileFormatChanged,
    required this.onSave,
  });

  final String imageFileFormat;
  final TextEditingController maxImageSizeController;
  final TextEditingController maxVideoSizeController;
  final TextEditingController maxAudioSizeController;
  final TextEditingController maxFileSizeController;
  final ValueChanged<String?> onImageFileFormatChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectLine(
          label: 'contentSettings.file.imageFormat',
          value: imageFileFormat,
          options: _ContentSettingOptions.imageFormats,
          onChanged: onImageFileFormatChanged,
          isRequired: true,
          translateOptions: false,
        ),
        const _TagsLine(
          label: 'contentSettings.file.allowedExtensions',
          helper: 'contentSettings.file.allowedExtensionsHelp',
          tags: ['jpg', 'png', 'pdf', 'ppt', 'doc'],
        ),
        _UnitInputLine(
          label: 'contentSettings.file.maxImageSize',
          controller: maxImageSizeController,
        ),
        _UnitInputLine(
          label: 'contentSettings.file.maxVideoSize',
          controller: maxVideoSizeController,
        ),
        _UnitInputLine(
          label: 'contentSettings.file.maxAudioSize',
          controller: maxAudioSizeController,
        ),
        _UnitInputLine(
          label: 'contentSettings.file.maxFileSize',
          controller: maxFileSizeController,
        ),
        const SizedBox(height: 8),
        _SaveRow(onPressed: onSave),
      ],
    );
  }
}

class _FeaturedContentCard extends StatelessWidget {
  const _FeaturedContentCard({
    required this.contentSource,
    required this.sortingLogic,
    required this.durationController,
    required this.limitController,
    required this.onContentSourceChanged,
    required this.onSortingLogicChanged,
    required this.onSave,
  });

  final String contentSource;
  final String sortingLogic;
  final TextEditingController durationController;
  final TextEditingController limitController;
  final ValueChanged<String?> onContentSourceChanged;
  final ValueChanged<String?> onSortingLogicChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _ContentCard(
      title: 'contentSettings.featured.title',
      minHeight: 318,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _ContentTabButton(
              label: 'contentSettings.featured.mainSlider',
              selected: true,
              onTap: () {},
            ),
          ),
          const SizedBox(height: 20),
          _FullSelectField(
            label: 'contentSettings.featured.contentSource',
            value: contentSource,
            options: _ContentSettingOptions.contentSourceOptions,
            onChanged: onContentSourceChanged,
          ),
          const SizedBox(height: 18),
          _FullSelectField(
            label: 'contentSettings.featured.sortingLogic',
            value: sortingLogic,
            options: _ContentSettingOptions.sortingOptions,
            onChanged: onSortingLogicChanged,
          ),
          const SizedBox(height: 18),
          _TwoFieldRow(
            children: [
              _FullTextField(
                label: 'contentSettings.featured.displayDuration',
                controller: durationController,
                keyboardType: TextInputType.number,
              ),
              _FullTextField(
                label: 'contentSettings.featured.displayLimit',
                controller: limitController,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SaveRow(onPressed: onSave),
        ],
      ),
    );
  }
}

class _AutoPostDeletionCard extends StatelessWidget {
  const _AutoPostDeletionCard({
    required this.enabled,
    required this.daysController,
    required this.postsValue,
    required this.onEnabledChanged,
    required this.onPostsChanged,
    required this.onSave,
  });

  final bool enabled;
  final TextEditingController daysController;
  final String postsValue;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String?> onPostsChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _ContentCard(
      title: 'contentSettings.autoDelete.title',
      minHeight: 318,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InlineSwitchControl(
            label: 'contentSettings.autoDelete.status',
            value: enabled,
            valueLabel: 'contentSettings.value.enable',
            onChanged: onEnabledChanged,
          ),
          const SizedBox(height: 18),
          _FullTextField(
            label: 'contentSettings.autoDelete.days',
            helper: 'contentSettings.autoDelete.daysHelp',
            controller: daysController,
            keyboardType: TextInputType.number,
            isRequired: true,
          ),
          const SizedBox(height: 18),
          _FullSelectField(
            label: 'contentSettings.autoDelete.posts',
            value: postsValue,
            options: _ContentSettingOptions.autoDeletePostOptions,
            onChanged: onPostsChanged,
            isRequired: true,
          ),
          const SizedBox(height: 20),
          _SaveRow(onPressed: onSave),
        ],
      ),
    );
  }
}

class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final String valueLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ContentLine(
      label: label,
      control: _InlineSwitchControl(
        value: value,
        valueLabel: valueLabel,
        onChanged: onChanged,
      ),
    );
  }
}

class _InputLine extends StatelessWidget {
  const _InputLine({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return _ContentLine(
      label: label,
      control: _ContentTextField(
        controller: controller,
        keyboardType: keyboardType,
      ),
    );
  }
}

class _UnitInputLine extends StatelessWidget {
  const _UnitInputLine({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _ContentLine(
      label: label,
      isRequired: true,
      control: _UnitTextField(controller: controller),
    );
  }
}

class _SelectLine extends StatelessWidget {
  const _SelectLine({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.helper,
    this.isRequired = false,
    this.translateOptions = true,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String? helper;
  final bool isRequired;
  final bool translateOptions;

  @override
  Widget build(BuildContext context) {
    return _ContentLine(
      label: label,
      helper: helper,
      isRequired: isRequired,
      control: _ContentSelectField(
        value: value,
        options: options,
        onChanged: onChanged,
        translateOptions: translateOptions,
      ),
    );
  }
}

class _TagsLine extends StatelessWidget {
  const _TagsLine({required this.label, required this.tags, this.helper});

  final String label;
  final List<String> tags;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return _ContentLine(
      label: label,
      helper: helper,
      isRequired: true,
      control: _TagsField(tags: tags),
    );
  }
}

class _ContentLine extends StatelessWidget {
  const _ContentLine({
    required this.label,
    required this.control,
    this.helper,
    this.isRequired = false,
  });

  final String label;
  final Widget control;
  final String? helper;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel(label: label, isRequired: isRequired),
              if (helper != null) ...[
                const SizedBox(height: 5),
                Text(
                  context.t(helper!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.placeholder,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          );

          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [labelColumn, const SizedBox(height: 8), control],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 4, child: labelColumn),
              const SizedBox(width: 18),
              Expanded(flex: 6, child: control),
            ],
          );
        },
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.isRequired = false});

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            context.t(label),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.actionRed,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineSwitchControl extends StatelessWidget {
  const _InlineSwitchControl({
    required this.value,
    required this.valueLabel,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final String valueLabel;
  final ValueChanged<bool> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            context.t(label!),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 18),
        ],
        _ContentSwitch(value: value, onChanged: onChanged),
        const SizedBox(width: 8),
        Text(
          context.t(valueLabel),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.placeholder,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ContentSwitch extends StatelessWidget {
  const _ContentSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 42,
            height: 24,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? AppColors.actionRed : AppColors.softLine,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: value
                    ? AppColors.actionRed
                    : AppColors.line.withValues(alpha: 0.9),
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: value
                    ? const SymbolIcon(
                        Symbols.check,
                        color: AppColors.actionRed,
                        size: 12,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentTextField extends StatelessWidget {
  const _ContentTextField({required this.controller, this.keyboardType});

  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textAlignVertical: TextAlignVertical.center,
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        decoration: _contentInputDecoration(context),
      ),
    );
  }
}

class _UnitTextField extends StatelessWidget {
  const _UnitTextField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(right: BorderSide(color: AppColors.line)),
            ),
            child: Text(
              context.t('contentSettings.file.unitMb'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlignVertical: TextAlignVertical.center,
              mouseCursor: SystemMouseCursors.text,
              cursorColor: AppColors.support,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
              decoration: _contentInputDecoration(context).copyWith(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentSelectField extends StatelessWidget {
  const _ContentSelectField({
    required this.value,
    required this.options,
    required this.onChanged,
    this.translateOptions = true,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool translateOptions;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: 42,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            borderRadius: BorderRadius.circular(AppRadius.value),
            dropdownColor: Colors.white,
            focusColor: Colors.transparent,
            mouseCursor: SystemMouseCursors.click,
            dropdownMenuItemMouseCursor: SystemMouseCursors.click,
            icon: const SymbolIcon(
              Symbols.keyboard_arrow_down,
              color: AppColors.iconMuted,
              size: 18,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            items: [
              for (final option in options)
                DropdownMenuItem(
                  value: option,
                  child: Text(
                    translateOptions ? context.t(option) : option,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _TagsField extends StatelessWidget {
  const _TagsField({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final tag in tags)
            Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(color: AppColors.softLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tag,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const SymbolIcon(
                    Symbols.close,
                    color: AppColors.iconMuted,
                    size: 13,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FullSelectField extends StatelessWidget {
  const _FullSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.isRequired = false,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label: label, isRequired: isRequired),
        const SizedBox(height: 8),
        _ContentSelectField(
          value: value,
          options: options,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FullTextField extends StatelessWidget {
  const _FullTextField({
    required this.label,
    required this.controller,
    this.helper,
    this.keyboardType,
    this.isRequired = false,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;
  final TextInputType? keyboardType;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label: label, isRequired: isRequired),
        const SizedBox(height: 8),
        _ContentTextField(controller: controller, keyboardType: keyboardType),
        if (helper != null) ...[
          const SizedBox(height: 7),
          Text(
            context.t(helper!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.placeholder,
              fontWeight: FontWeight.w600,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _TwoFieldRow extends StatelessWidget {
  const _TwoFieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(height: 18),
                children[index],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(width: 16),
              Expanded(child: children[index]),
            ],
          ],
        );
      },
    );
  }
}

class _SaveRow extends StatelessWidget {
  const _SaveRow({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 38,
        child: TextButton(
          onPressed: onPressed,
          style:
              TextButton.styleFrom(
                backgroundColor: AppColors.actionRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ).copyWith(
                mouseCursor: const WidgetStatePropertyAll(
                  SystemMouseCursors.click,
                ),
              ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SymbolIcon(Symbols.check, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(context.t('contentSettings.saveChanges')),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _contentInputDecoration(BuildContext context) {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: BorderSide(color: AppColors.deepOcean.withValues(alpha: 0.4)),
    ),
  );
}

enum _ContentSettingsTab {
  general('contentSettings.tab.general'),
  posts('contentSettings.tab.posts'),
  postFormats('contentSettings.tab.postFormats'),
  fileUpload('contentSettings.tab.fileUpload');

  const _ContentSettingsTab(this.labelKey);

  final String labelKey;
}

class _ContentSettingOptions {
  const _ContentSettingOptions._();

  static const slugUrls = 'contentSettings.option.slugUrls';
  static const idUrls = 'contentSettings.option.idUrls';
  static const manualSelection = 'contentSettings.option.manualSelection';
  static const latestPosts = 'contentSettings.option.latestPosts';
  static const sliderOrder = 'contentSettings.option.sliderOrder';
  static const publishDate = 'contentSettings.option.publishDate';
  static const deleteAllPosts = 'contentSettings.option.deleteAllPosts';
  static const deleteDraftPosts = 'contentSettings.option.deleteDraftPosts';

  static const postUrlOptions = [slugUrls, idUrls];
  static const contentSourceOptions = [manualSelection, latestPosts];
  static const sortingOptions = [sliderOrder, publishDate];
  static const autoDeletePostOptions = [deleteAllPosts, deleteDraftPosts];
  static const imageFormats = ['WEBP', 'JPEG', 'PNG'];
  static const postFormatKeys = [
    'contentSettings.format.article',
    'contentSettings.format.gallery',
    'contentSettings.format.sortedList',
    'contentSettings.format.tableOfContents',
    'contentSettings.format.video',
    'contentSettings.format.audio',
    'contentSettings.format.triviaQuiz',
    'contentSettings.format.personalityQuiz',
    'contentSettings.format.poll',
    'contentSettings.format.recipe',
    'contentSettings.format.event',
  ];
}
