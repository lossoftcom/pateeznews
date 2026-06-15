import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/admin_social_repository.dart';
import '../social_platform_data.dart';
import '../previews/instagram_preview.dart';
import '../previews/facebook_preview.dart';
import '../previews/twitter_preview.dart';
import '../previews/linkedin_preview.dart';
import '../previews/tiktok_preview.dart';
import '../previews/youtube_preview.dart';
import '../previews/pinterest_preview.dart';
import '../previews/reddit_preview.dart';
import '../previews/threads_preview.dart';
import '../previews/bluesky_preview.dart';
import '../previews/mastodon_preview.dart';
import '../previews/google_business_preview.dart';
import '../previews/discord_preview.dart';
import '../previews/slack_preview.dart';
import 'social_brand_logo.dart';
import 'social_media_preview.dart';
import 'social_post_type_selector.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

/// Right-side preview panel with platform tab bar.
class SocialPreviewPanel extends StatefulWidget {
  const SocialPreviewPanel({
    super.key,
    required this.selectedPlatforms,
    required this.data,
    this.connectedAccounts = const [],
    this.selectedConnectedAccountIds = const {},
    this.loading = false,
    this.onAccountChanged,
    this.onPostTypeChanged,
  });

  final Set<SocialPlatform> selectedPlatforms;
  final SocialPublishData data;
  final List<AdminSocialConnectedAccount> connectedAccounts;
  final Map<SocialPlatform, int> selectedConnectedAccountIds;
  final bool loading;
  final void Function(SocialPlatform platform, int accountId)? onAccountChanged;
  final ValueChanged<SocialPostType>? onPostTypeChanged;

  @override
  State<SocialPreviewPanel> createState() => _SocialPreviewPanelState();
}

class _SocialPreviewPanelState extends State<SocialPreviewPanel> {
  final _tabScrollController = ScrollController();
  SocialPlatform? _activeTab;
  var _showTabBack = false;
  var _showTabForward = false;

  @override
  void initState() {
    super.initState();
    _tabScrollController.addListener(_syncTabButtons);
  }

  @override
  void didUpdateWidget(SocialPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset tab if current is no longer selected
    if (_activeTab != null && !widget.selectedPlatforms.contains(_activeTab)) {
      _activeTab = widget.selectedPlatforms.isNotEmpty
          ? widget.selectedPlatforms.first
          : null;
    }
    // Set default tab
    if (_activeTab == null && widget.selectedPlatforms.isNotEmpty) {
      _activeTab = widget.selectedPlatforms.first;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTabButtons());
  }

  @override
  void dispose() {
    _tabScrollController.removeListener(_syncTabButtons);
    _tabScrollController.dispose();
    super.dispose();
  }

  void _syncTabButtons() {
    if (!mounted || !_tabScrollController.hasClients) return;
    final position = _tabScrollController.position;
    final showBack = position.pixels > 1;
    final showForward = position.maxScrollExtent - position.pixels > 1;
    if (showBack == _showTabBack && showForward == _showTabForward) return;
    setState(() {
      _showTabBack = showBack;
      _showTabForward = showForward;
    });
  }

  void _scrollTabs(double direction) {
    if (!_tabScrollController.hasClients) return;
    final position = _tabScrollController.position;
    final target = (position.pixels + (direction * 168))
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _tabScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  List<SocialPostType> _availableTypesFor(SocialPlatform platform) {
    return platformInfoFor(platform).supportedTypes;
  }

  SocialPostType _effectivePostTypeFor(SocialPlatform platform) {
    final availableTypes = _availableTypesFor(platform);
    if (availableTypes.contains(widget.data.postType)) {
      return widget.data.postType;
    }
    return availableTypes.isNotEmpty
        ? availableTypes.first
        : SocialPostType.feed;
  }

  void _syncPostTypeFor(SocialPlatform platform) {
    final effectiveType = _effectivePostTypeFor(platform);
    if (effectiveType == widget.data.postType) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onPostTypeChanged?.call(effectiveType);
    });
  }

  void _activateTab(SocialPlatform platform) {
    setState(() => _activeTab = platform);
    final effectiveType = _effectivePostTypeFor(platform);
    if (effectiveType != widget.data.postType) {
      widget.onPostTypeChanged?.call(effectiveType);
    }
  }

  List<AdminSocialConnectedAccount> _accountsFor(SocialPlatform platform) {
    return widget.connectedAccounts
        .where((account) => account.platform == platform)
        .toList(growable: false);
  }

  AdminSocialConnectedAccount? _selectedAccountFor(SocialPlatform platform) {
    final accounts = _accountsFor(platform);
    if (accounts.isEmpty) return null;
    final selectedId = widget.selectedConnectedAccountIds[platform];
    for (final account in accounts) {
      if (account.id == selectedId) return account;
    }
    return accounts.first;
  }

  _PreviewProfile _profileFor(SocialPlatform platform) {
    final account = _selectedAccountFor(platform);
    final name = account?.resolvedDisplayName.trim();
    final username = account?.resolvedUsername.trim();
    return _PreviewProfile(
      name: name == null || name.isEmpty ? 'Pateeznews' : name,
      username: username == null || username.isEmpty ? 'pateeznews' : username,
      avatarUrl: account?.avatarUrl.trim() ?? '',
      verified:
          platform == SocialPlatform.twitter &&
          (account?.isTwitterPremium ?? false),
    );
  }

  /// Önizleme kartının avatar başlığında, ismin yanında gösterilecek "hesap
  /// değiştir" aşağı oku — yalnızca o platformda 2+ bağlı hesap varsa görünür.
  /// Tıklanınca hesaplar açılır, seçim mevcut [onAccountChanged] ile uygulanır.
  Widget? _previewAccountAction(SocialPlatform platform) {
    final accounts = _accountsFor(platform);
    if (accounts.length < 2 || widget.onAccountChanged == null) return null;
    final selected = _selectedAccountFor(platform) ?? accounts.first;
    final info = platformInfoFor(platform);
    return PopupMenuButton<int>(
      tooltip: 'Hesap değiştir',
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      onSelected: (id) => widget.onAccountChanged?.call(platform, id),
      itemBuilder: (context) {
        return accounts
            .map(
              (account) => PopupMenuItem<int>(
                value: account.id,
                child: SizedBox(
                  width: 260,
                  child: _AccountMenuRow(
                    account: account,
                    info: info,
                    selected: account.id == selected.id,
                  ),
                ),
              ),
            )
            .toList(growable: false);
      },
      child: const Padding(
        padding: EdgeInsets.only(left: 3),
        child: Icon(
          Symbols.keyboard_arrow_down_rounded,
          size: 18,
          color: Color(0xFF8E8E8E),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platforms = widget.selectedPlatforms.toList();

    if (platforms.isEmpty && widget.loading) {
      return _loadingState();
    }

    if (platforms.isEmpty) {
      return _emptyState();
    }

    _activeTab ??= platforms.first;
    final activePlatform = _activeTab!;
    _syncPostTypeFor(activePlatform);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTabButtons());

    return Column(
      children: [
        // Tab bar
        _buildTabBar(platforms),

        // Selected account switcher
        _buildAccountSelector(activePlatform),

        // Platform-specific post type tabs
        _buildPostTypeSelector(activePlatform),

        // Preview content
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
              border: Border(
                left: BorderSide(color: AppColors.line),
                right: BorderSide(color: AppColors.line),
                bottom: BorderSide(color: AppColors.line),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactHeight = constraints.maxHeight < 560;
                final padding = compactHeight ? 12.0 : 20.0;
                return Padding(
                  padding: EdgeInsets.all(padding),
                  child: _ResponsivePreviewFit(
                    child: _buildPreviewWithFormat(activePlatform),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(List<SocialPlatform> platforms) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          if (_showTabBack)
            _TabScrollButton(
              icon: Symbols.chevron_left_rounded,
              onTap: () => _scrollTabs(-1),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minTabWidth = constraints.maxWidth > 8
                    ? constraints.maxWidth - 8
                    : 0.0;
                return ClipRect(
                  child: SingleChildScrollView(
                    controller: _tabScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: minTabWidth),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: platforms.map(_buildTab).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_showTabForward)
            _TabScrollButton(
              icon: Symbols.chevron_right,
              onTap: () => _scrollTabs(1),
            ),
        ],
      ),
    );
  }

  Widget _buildTab(SocialPlatform platform) {
    final info = platformInfoFor(platform);
    final active = platform == _activeTab;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _activateTab(platform),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? info.color.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
              border: active
                  ? Border.all(color: info.color.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SocialBrandLogo(
                  info: info,
                  size: 16,
                  iconSize: 16,
                  active: active,
                  showBackground: false,
                ),
                const SizedBox(width: 6),
                Text(
                  info.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? info.color : AppColors.inkSoft,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSelector(SocialPlatform platform) {
    final accounts = _accountsFor(platform);
    if (accounts.isEmpty) return const SizedBox.shrink();

    final selected = _selectedAccountFor(platform) ?? accounts.first;
    final info = platformInfoFor(platform);
    final canSwitch = accounts.length > 1 && widget.onAccountChanged != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: AppColors.line),
          right: BorderSide(color: AppColors.line),
          bottom: BorderSide(color: AppColors.line),
        ),
      ),
      child: Row(
        children: [
          SocialBrandLogo(info: info, size: 26, iconSize: 15),
          const SizedBox(width: 9),
          Expanded(
            child: _AccountSummary(account: selected, info: info),
          ),
          const SizedBox(width: 10),
          if (canSwitch)
            PopupMenuButton<int>(
              tooltip: 'Hesap değiştir',
              position: PopupMenuPosition.under,
              onSelected: (id) => widget.onAccountChanged?.call(platform, id),
              itemBuilder: (context) {
                return accounts
                    .map(
                      (account) => PopupMenuItem<int>(
                        value: account.id,
                        child: SizedBox(
                          width: 260,
                          child: _AccountMenuRow(
                            account: account,
                            info: info,
                            selected: account.id == selected.id,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false);
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Değiştir',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepOcean,
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Symbols.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.inkSoft,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            _AccountTierPill(account: selected, info: info),
        ],
      ),
    );
  }

  Widget _buildPostTypeSelector(SocialPlatform platform) {
    final availableTypes = _availableTypesFor(platform);
    if (availableTypes.length <= 1) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: AppColors.line),
          right: BorderSide(color: AppColors.line),
          bottom: BorderSide(color: AppColors.line),
        ),
      ),
      child: SocialPostTypeSelector(
        current: _effectivePostTypeFor(platform),
        available: availableTypes,
        onChanged: (type) => widget.onPostTypeChanged?.call(type),
      ),
    );
  }

  Widget _buildPreview(SocialPlatform platform) {
    final d = widget.data;
    final caption = d.displayCaption;
    final image = _previewMediaUrl(d.effectiveImage);
    final link = d.effectiveLink;
    final title = d.newsTitle;
    final profile = _profileFor(platform);

    return switch (platform) {
      SocialPlatform.instagram => InstagramPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        profileUsername: profile.username,
        avatarUrl: profile.avatarUrl,
        accountAction: _previewAccountAction(platform),
      ),
      SocialPlatform.facebook => FacebookPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        profileUsername: profile.username,
        avatarUrl: profile.avatarUrl,
        accountAction: _previewAccountAction(platform),
      ),
      SocialPlatform.twitter => TwitterPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        profileUsername: profile.username,
        avatarUrl: profile.avatarUrl,
        verified: profile.verified,
        accountAction: _previewAccountAction(platform),
      ),
      SocialPlatform.linkedin => LinkedinPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        accountAction: _previewAccountAction(platform),
      ),
      SocialPlatform.tiktok => TiktokPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        accountAction: _previewAccountAction(platform),
      ),
      SocialPlatform.youtube => YoutubePreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        accountAction: _previewAccountAction(platform),
      ),
      SocialPlatform.pinterest => PinterestPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        accountAction: _previewAccountAction(platform),
      ),
      SocialPlatform.reddit => RedditPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        accountAction: _previewAccountAction(platform),
      ),
      SocialPlatform.threads => ThreadsPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        accountAction: _previewAccountAction(platform),
      ),
      SocialPlatform.bluesky => BlueskyPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        accountAction: _previewAccountAction(platform),
      ),
      SocialPlatform.mastodon => MastodonPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        accountAction: _previewAccountAction(platform),
      ),
      SocialPlatform.googleBusiness => GoogleBusinessPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        accountAction: _previewAccountAction(platform),
      ),
      SocialPlatform.discord => DiscordPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        accountAction: _previewAccountAction(platform),
      ),
      SocialPlatform.slack => SlackPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
        profileName: profile.name,
        accountAction: _previewAccountAction(platform),
      ),
    };
  }

  /// Wraps the preview in an appropriate frame based on post type.
  Widget _buildPreviewWithFormat(SocialPlatform platform) {
    final postType = _effectivePostTypeFor(platform);
    final isVertical =
        postType == SocialPostType.story ||
        postType == SocialPostType.reels ||
        postType == SocialPostType.shortVideo;

    if (isVertical) {
      return _buildStoryPreview(platform, postType);
    }

    // Feed / Thread: regular preview
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: _buildPreview(platform),
    );
  }

  /// Vertical phone-frame for story/reels preview.
  Widget _buildStoryPreview(SocialPlatform platform, SocialPostType type) {
    final d = widget.data;
    final info = platformInfoFor(platform);
    final image = _previewMediaUrl(d.effectiveImage);
    final hasImage = image.isNotEmpty;
    final profile = _profileFor(platform);

    return Column(
      children: [
        // Phone frame
        Container(
          width: 260,
          height: 462, // ~9:16
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade800, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image or gradient
                if (hasImage)
                  SocialMediaPreview(
                    url: image,
                    fit: BoxFit.contain,
                    memCacheWidth: 1080,
                    errorWidget: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            info.color.withValues(alpha: 0.8),
                            info.color.withValues(alpha: 0.4),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          info.color.withValues(alpha: 0.8),
                          info.color.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Symbols.add_photo_alternate_outlined,
                        size: 48,
                        color: Colors.white54,
                      ),
                    ),
                  ),

                // Top bar (profile)
                Positioned(
                  top: 16,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          color: info.color,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _AccountAvatar(
                          name: profile.name,
                          avatarUrl: profile.avatarUrl,
                          color: info.color,
                          size: 32,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          profile.username,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Icon(
                        Symbols.more_horiz,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),

                // Bottom overlay with caption
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 40, 14, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (d.displayCaption.isNotEmpty)
                          Text(
                            d.displayCaption,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.4,
                              shadows: [
                                Shadow(
                                  blurRadius: 4,
                                  color: Colors.black.withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                        if (type == SocialPostType.reels ||
                            type == SocialPostType.shortVideo) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Symbols.music_note_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Orijinal ses - ${profile.username}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Right side actions (reels / tiktok style)
                if (type == SocialPostType.reels ||
                    type == SocialPostType.shortVideo)
                  Positioned(
                    right: 10,
                    bottom: 80,
                    child: Column(
                      children: [
                        _storyAction(Symbols.favorite_border_rounded, '1.2K'),
                        _storyAction(
                          Symbols.chat_bubble_outline_rounded,
                          '234',
                        ),
                        _storyAction(Symbols.send_outlined, ''),
                        _storyAction(Symbols.bookmark_border_rounded, ''),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _storyAction(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _loadingState() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value * 2),
        border: Border.all(color: AppColors.line),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.actionRed,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value * 2),
        border: Border.all(color: AppColors.line),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.deepOcean.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Symbols.preview_rounded,
                  size: 28,
                  color: AppColors.iconMuted,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Önizleme',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepOcean,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Gönderinizin nasıl görüneceğini görmek için\nbir platform seçin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.support,
                  height: 1.5,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewProfile {
  const _PreviewProfile({
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.verified,
  });

  final String name;
  final String username;
  final String avatarUrl;
  final bool verified;
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({required this.account, required this.info});

  final AdminSocialConnectedAccount account;
  final SocialPlatformInfo info;

  @override
  Widget build(BuildContext context) {
    final subtitle = _accountSubtitle(account);
    return Row(
      children: [
        _AccountAvatar(
          name: account.resolvedDisplayName,
          avatarUrl: account.avatarUrl,
          color: info.color,
          size: 30,
          fontSize: 12,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                account.resolvedDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepOcean,
                  letterSpacing: 0,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.support,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountMenuRow extends StatelessWidget {
  const _AccountMenuRow({
    required this.account,
    required this.info,
    required this.selected,
  });

  final AdminSocialConnectedAccount account;
  final SocialPlatformInfo info;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AccountAvatar(
          name: account.resolvedDisplayName,
          avatarUrl: account.avatarUrl,
          color: info.color,
          size: 32,
          fontSize: 12,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                account.resolvedDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepOcean,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _accountSubtitle(account),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.support,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 8),
          const Icon(
            Symbols.check_rounded,
            size: 17,
            color: AppColors.actionRed,
          ),
        ],
      ],
    );
  }
}

class _AccountTierPill extends StatelessWidget {
  const _AccountTierPill({required this.account, required this.info});

  final AdminSocialConnectedAccount account;
  final SocialPlatformInfo info;

  @override
  Widget build(BuildContext context) {
    final tier = account.platform == SocialPlatform.twitter
        ? account.twitterTierLabel
        : '';
    final text = tier.isEmpty ? 'Seçili' : tier;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
        border: Border.all(color: info.color.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: info.color,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({
    required this.name,
    required this.avatarUrl,
    required this.color,
    required this.size,
    required this.fontSize,
  });

  final String name;
  final String avatarUrl;
  final Color color;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fallback = _AvatarFallback(
      name: name,
      color: color,
      size: size,
      fontSize: fontSize,
    );
    if (avatarUrl.trim().isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        avatarUrl.trim(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.name,
    required this.color,
    required this.size,
    required this.fontSize,
  });

  final String name;
  final Color color;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'P' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

String _accountSubtitle(AdminSocialConnectedAccount account) {
  final handle = account.resolvedUsername.trim();
  final channel = account.channelName.trim().replaceFirst(RegExp(r'^@'), '');
  final parts = <String>[
    if (handle.isNotEmpty) '@$handle',
    if (channel.isNotEmpty && channel != handle) channel,
    if (account.platform == SocialPlatform.twitter &&
        account.twitterTierLabel.isNotEmpty)
      account.twitterTierLabel,
  ];
  return parts.join(' · ');
}

String _previewMediaUrl(String value) {
  return socialMediaDisplayUrl(value);
}

class _ResponsivePreviewFit extends StatelessWidget {
  const _ResponsivePreviewFit({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

class _TabScrollButton extends StatelessWidget {
  const _TabScrollButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 40,
      child: Center(
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.value * 1.25),
            side: const BorderSide(color: AppColors.line),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.value * 1.25),
            child: SizedBox(
              width: 26,
              height: 26,
              child: Icon(icon, size: 16, color: AppColors.inkSoft),
            ),
          ),
        ),
      ),
    );
  }
}
