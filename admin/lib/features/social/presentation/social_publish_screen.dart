import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../auth/data/admin_auth_models.dart';
import '../../news/data/admin_news_repository.dart';
import '../data/admin_social_repository.dart';
import 'social_platform_data.dart';
import 'widgets/social_caption_editor.dart';
import 'widgets/social_creative_studio.dart';
import 'widgets/social_media_picker.dart';
import 'widgets/social_hashtag_input.dart';
import 'widgets/social_news_source_picker.dart';
import 'widgets/social_platform_options_panel.dart';
import 'widgets/social_preview_panel.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/media_library_dialog.dart';

/// Professional social media bulk publish screen.
class SocialPublishScreen extends StatefulWidget {
  const SocialPublishScreen({
    super.key,
    required this.session,
    required this.newsRepository,
    required this.socialRepository,
  });

  final AdminSession session;
  final AdminNewsRepository newsRepository;
  final AdminSocialRepository socialRepository;

  @override
  State<SocialPublishScreen> createState() => _SocialPublishScreenState();
}

class _SocialPublishScreenState extends State<SocialPublishScreen>
    with SingleTickerProviderStateMixin {
  final _captionController = TextEditingController();
  var _submitting = false;
  var _loadingConnectedAccounts = true;
  var _connectedAccounts = <AdminSocialConnectedAccount>[];

  SocialPublishData _data = const SocialPublishData();

  @override
  void initState() {
    super.initState();
    unawaited(_loadConnectedAccounts());
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _updateData(SocialPublishData Function(SocialPublishData d) updater) {
    setState(() => _data = updater(_data));
  }

  Future<void> _loadConnectedAccounts() async {
    try {
      final accounts = await widget.socialRepository.fetchConnectedAccounts(
        widget.session,
      );
      final connectedAccounts = _connectedAccountsFrom(accounts);
      final selectedAccountIds = _defaultSelectedAccountIdsFrom(
        connectedAccounts,
      );
      if (!mounted) return;
      setState(() {
        _loadingConnectedAccounts = false;
        _connectedAccounts = connectedAccounts;
        final connectedPlatforms = _platformsFromAccounts(connectedAccounts);
        final postType = _effectivePostTypeForPlatforms(
          _data.postType,
          connectedPlatforms,
        );
        _data = _data.copyWith(
          selectedPlatforms: _platformsSupportingPostType(
            connectedPlatforms,
            postType,
          ),
          selectedConnectedAccountIds: selectedAccountIds,
          postType: postType,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingConnectedAccounts = false;
        _connectedAccounts = const <AdminSocialConnectedAccount>[];
        _data = _data.copyWith(
          selectedPlatforms: const <SocialPlatform>{},
          selectedConnectedAccountIds: const <SocialPlatform, int>{},
        );
      });
    }
  }

  List<AdminSocialConnectedAccount> _connectedAccountsFrom(
    Iterable<AdminSocialConnectedAccount> accounts,
  ) {
    final connected = <AdminSocialConnectedAccount>[];
    for (final account in accounts) {
      final status = account.status.trim().toLowerCase();
      if (status.isNotEmpty && status != 'connected') continue;
      connected.add(account);
    }
    return connected;
  }

  Set<SocialPlatform> _platformsFromAccounts(
    Iterable<AdminSocialConnectedAccount> accounts,
  ) {
    final connected = accounts.map((account) => account.platform).toSet();
    return {
      for (final info in socialPlatforms)
        if (connected.contains(info.platform)) info.platform,
    };
  }

  Map<SocialPlatform, int> _defaultSelectedAccountIdsFrom(
    Iterable<AdminSocialConnectedAccount> accounts,
  ) {
    final selected = <SocialPlatform, int>{};
    for (final info in socialPlatforms) {
      for (final account in accounts) {
        if (account.platform != info.platform) continue;
        selected[info.platform] = account.id;
        break;
      }
    }
    return selected;
  }

  AdminSocialConnectedAccount? _selectedConnectedAccountFor(
    SocialPlatform platform,
  ) {
    final selectedId = _data.selectedConnectedAccountIds[platform];
    for (final account in _connectedAccounts) {
      if (account.platform == platform && account.id == selectedId) {
        return account;
      }
    }
    for (final account in _connectedAccounts) {
      if (account.platform == platform) return account;
    }
    return null;
  }

  Map<SocialPlatform, int> _captionLimitsByPlatform() {
    return {
      for (final platform in _data.selectedPlatforms)
        platform: platform == SocialPlatform.twitter
            ? (_selectedConnectedAccountFor(
                    platform,
                  )?.effectiveTwitterCharLimit ??
                  platformInfoFor(platform).charLimit)
            : platformInfoFor(platform).charLimit,
    };
  }

  void _selectConnectedAccount(SocialPlatform platform, int accountId) {
    final next = Map<SocialPlatform, int>.from(
      _data.selectedConnectedAccountIds,
    );
    next[platform] = accountId;
    _updateData((d) => d.copyWith(selectedConnectedAccountIds: next));
  }

  List<SocialPostType> _availablePostTypesForPlatforms(
    Set<SocialPlatform> platforms,
  ) {
    final supported = <SocialPostType>{
      for (final platform in platforms)
        ...platformInfoFor(platform).supportedTypes,
    };
    return [
      for (final type in SocialPostType.values)
        if (supported.contains(type)) type,
    ];
  }

  SocialPostType _effectivePostTypeForPlatforms(
    SocialPostType current,
    Set<SocialPlatform> platforms,
  ) {
    final available = _availablePostTypesForPlatforms(platforms);
    if (available.contains(current)) return current;
    return available.isNotEmpty ? available.first : SocialPostType.feed;
  }

  Set<SocialPlatform> _platformsSupportingPostType(
    Set<SocialPlatform> platforms,
    SocialPostType type,
  ) {
    return {
      for (final platform in platforms)
        if (platformInfoFor(platform).supportedTypes.contains(type)) platform,
    };
  }

  void _changePostType(SocialPostType type) {
    final connectedPlatforms = _platformsFromAccounts(_connectedAccounts);
    if (!_availablePostTypesForPlatforms(connectedPlatforms).contains(type)) {
      return;
    }

    final nextPlatforms = _platformsSupportingPostType(
      connectedPlatforms,
      type,
    );
    if (nextPlatforms.isEmpty) return;

    final nextSelectedIds = <SocialPlatform, int>{};
    for (final platform in nextPlatforms) {
      final account = _selectedConnectedAccountFor(platform);
      if (account != null) nextSelectedIds[platform] = account.id;
    }

    _updateData(
      (d) => d.copyWith(
        postType: type,
        selectedPlatforms: nextPlatforms,
        selectedConnectedAccountIds: nextSelectedIds,
      ),
    );
  }

  Future<void> _openCreativeEditor() {
    return showSocialCreativeEditor(
      context,
      data: _data,
      onMediaUrlsChanged: _replaceMediaUrls,
    );
  }

  Future<void> _showPlatformOptions() async {
    final options = await showSocialPlatformOptionsDialog(context, data: _data);
    if (options == null || !mounted) return;
    _updateData((d) => d.copyWith(platformOptions: options));
  }

  int? _primarySocialAccountIdForPublish() {
    for (final info in socialPlatforms) {
      if (!_data.selectedPlatforms.contains(info.platform)) continue;
      final account = _selectedConnectedAccountFor(info.platform);
      if (account != null) return account.socialAccountId;
    }
    return null;
  }

  Future<void> _submitPost({DateTime? scheduledAt}) async {
    if (_data.selectedPlatforms.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await widget.socialRepository.publishPost(
        widget.session,
        socialAccountId: _primarySocialAccountIdForPublish(),
        data: _data.copyWith(caption: _captionController.text),
        scheduledAt: scheduledAt,
      );
      if (!mounted) return;
      AdminToast.show(
        context,
        message: context.t(
          scheduledAt == null
              ? 'social.publish.publishSuccess'
              : 'social.publish.scheduleSuccess',
          values: {
            'id': result.bundlePostId.isEmpty ? result.id : result.bundlePostId,
          },
        ),
        tone: AdminToastTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      AdminToast.show(
        context,
        message: error.toString(),
        tone: AdminToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _schedulePost() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    if (time == null || !mounted) return;
    await _submitPost(
      scheduledAt: DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
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
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.actionRed.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.value * 2),
            ),
            child: const Icon(
              Symbols.send_rounded,
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
            onPressed:
                _data.selectedPlatforms.isEmpty ||
                    _loadingConnectedAccounts ||
                    _submitting
                ? null
                : _schedulePost,
            icon: const Icon(Symbols.schedule_rounded, size: 16),
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
                fontFamily: 'PateezSans',
                letterSpacing: 0,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Publish button
          FilledButton.icon(
            onPressed:
                _data.selectedPlatforms.isEmpty ||
                    _loadingConnectedAccounts ||
                    _submitting
                ? null
                : () => _submitPost(),
            icon: const Icon(Symbols.send_rounded, size: 16),
            label: isCompact
                ? const SizedBox.shrink()
                : Text(context.t('social.publish.publishNow')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              disabledBackgroundColor: AppColors.actionRed.withValues(
                alpha: 0.4,
              ),
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
                fontFamily: 'PateezSans',
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
        Expanded(flex: 55, child: _buildEditorPanel(context)),

        // Divider
        Container(width: 1, color: AppColors.line),

        // Preview panel
        Expanded(
          flex: 45,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SocialPreviewPanel(
              selectedPlatforms: _data.selectedPlatforms,
              connectedAccounts: _connectedAccounts,
              selectedConnectedAccountIds: _data.selectedConnectedAccountIds,
              data: _data,
              loading: _loadingConnectedAccounts,
              onAccountChanged: _selectConnectedAccount,
              onPostTypeChanged: _changePostType,
              onEditCreative: _openCreativeEditor,
              onOpenPlatformOptions: _showPlatformOptions,
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
                fontFamily: 'PateezSans',
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
                    connectedAccounts: _connectedAccounts,
                    selectedConnectedAccountIds:
                        _data.selectedConnectedAccountIds,
                    data: _data,
                    loading: _loadingConnectedAccounts,
                    onAccountChanged: _selectConnectedAccount,
                    onPostTypeChanged: _changePostType,
                    onEditCreative: _openCreativeEditor,
                    onOpenPlatformOptions: _showPlatformOptions,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // News source
          SocialNewsSourcePicker(
            newsRepository: widget.newsRepository,
            selectedLink: _data.newsLink,
            manualLink: _data.manualLink,
            onNewsSelected:
                ({
                  required String title,
                  required String imageUrl,
                  required String link,
                  required String summary,
                  required String keywords,
                  required String category,
                  required String type,
                }) {
                  final nextCaption = summary.trim().isNotEmpty
                      ? summary.trim()
                      : title.trim();
                  _captionController.text = nextCaption;

                  final parsedTags = keywords.trim().isEmpty
                      ? <String>[]
                      : keywords
                            .split(RegExp(r'[,;،]'))
                            .map(
                              (k) => k
                                  .trim()
                                  .replaceAll('#', '')
                                  .replaceAll(' ', '_'),
                            )
                            .where((k) => k.isNotEmpty)
                            .toList();

                  final mediaList = imageUrl.trim().isEmpty
                      ? <String>[]
                      : <String>[imageUrl.trim()];

                  _updateData(
                    (d) => d.copyWith(
                      newsTitle: title,
                      newsImageUrl: imageUrl.trim(),
                      newsLink: link,
                      manualLink: '',
                      newsSummary: summary,
                      newsKeywords: keywords,
                      newsCategory: category,
                      newsType: type,
                      caption: _captionController.text,
                      hashtags: parsedTags,
                      mediaUrls: mediaList,
                    ),
                  );
                },
            onManualLinkChanged: (link) =>
                _updateData((d) => d.copyWith(manualLink: link)),
          ),

          const SizedBox(height: 22),

          // Caption editor
          SocialCaptionEditor(
            controller: _captionController,
            selectedPlatforms: _data.selectedPlatforms,
            platformCharLimits: _captionLimitsByPlatform(),
            onChanged: (text) => _updateData((d) => d.copyWith(caption: text)),
          ),

          const SizedBox(height: 22),

          // Media picker
          SocialMediaPicker(
            mediaUrls: _data.mediaUrls,
            onPickImage: _pickImageFromLibrary,
            onPickImageUrl: _pickImageFromUrl,
            onPickVideo: _pickVideoFromLibrary,
            onPickVideoUrl: _pickVideoFromUrl,
            onClearMedia: () => _updateData((d) => d.copyWith(mediaUrls: [])),
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
            onChanged: (tags) => _updateData((d) => d.copyWith(hashtags: tags)),
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
        border: Border.all(color: AppColors.deepOcean.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(
            Symbols.info_outline_rounded,
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

  Future<void> _pickImageFromLibrary() async {
    final selected = await showMediaLibraryDialog(context);
    if (selected == null || !mounted) return;
    _appendMediaUrl(selected);
  }

  Future<void> _pickImageFromUrl() async {
    final selected = await showUrlImageDialog(context);
    if (selected == null || !mounted) return;
    _appendMediaUrl(selected);
  }

  Future<void> _pickVideoFromLibrary() async {
    final selected = await showMediaLibraryDialog(context, type: 'video');
    if (selected == null || !mounted) return;
    _appendMediaUrl(selected);
  }

  Future<void> _pickVideoFromUrl() async {
    final selected = await showUrlVideoDialog(context);
    if (selected == null || !mounted) return;
    _appendMediaUrl(selected);
  }

  void _appendMediaUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final urls = List<String>.from(_data.mediaUrls)..add(trimmed);
    _updateData((d) => d.copyWith(mediaUrls: urls));
  }

  void _replaceMediaUrls(List<String> urls) {
    _updateData((d) => d.copyWith(mediaUrls: urls));
  }
}
