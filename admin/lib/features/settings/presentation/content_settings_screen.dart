import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../features/auth/data/admin_auth_models.dart';
import '../../../features/settings/data/admin_content_settings_repository.dart';
import '../../../shared/widgets/symbol_icon.dart';

class ContentSettingsScreen extends StatefulWidget {
  const ContentSettingsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminContentSettingsRepository(),
    this.initialSettings,
    this.onGeneralSettingsChanged,
    this.onPostSettingsChanged,
    this.onPostFormatSettingsChanged,
    this.onUploadSettingsChanged,
    this.onFeaturedSettingsChanged,
    this.onTrashCleanupSettingsChanged,
  });

  final AdminSession session;
  final AdminContentSettingsRepository repository;
  final ContentSettingsSnapshot? initialSettings;
  final ValueChanged<ContentGeneralSettingsData>? onGeneralSettingsChanged;
  final ValueChanged<ContentPostSettingsData>? onPostSettingsChanged;
  final ValueChanged<ContentPostFormatSettingsData>?
  onPostFormatSettingsChanged;
  final ValueChanged<ContentUploadSettingsData>? onUploadSettingsChanged;
  final ValueChanged<ContentFeaturedSettingsData>? onFeaturedSettingsChanged;
  final ValueChanged<ContentTrashCleanupSettingsData>?
  onTrashCleanupSettingsChanged;

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
  final _allowedExtensionsController = TextEditingController(
    text: contentUploadDefaultExtensions.join(', '),
  );
  final _featuredLimitController = TextEditingController(text: '15');
  final _autoDeleteDaysController = TextEditingController(text: '30');

  var _selectedTab = _ContentSettingsTab.general;
  var _showFeaturedSection = true;
  var _commentSystem = true;
  var _commentApprovalSystem = true;
  var _emojiReactions = true;
  var _generalLoading = true;
  var _generalSaving = false;
  var _postSettingsLoading = true;
  var _postSettingsSaving = false;
  var _postFormatsLoading = true;
  var _postFormatsSaving = false;
  var _fileUploadLoading = true;
  var _fileUploadSaving = false;
  var _featuredLoading = true;
  var _featuredSaving = false;
  var _trashCleanupLoading = true;
  var _trashCleanupSaving = false;
  String? _loadedLanguageCode;
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
  var _featuredShowNewsInfo = false;
  var _autoDeletePosts = _ContentSettingOptions.deleteAllPosts;
  var _postFormats = {
    for (final key in _ContentSettingOptions.postFormatKeys) key: true,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = _normalizeLanguageCode(
      AdminLocalizationScope.maybeOf(context)?.code ?? 'tr',
    );
    if (_loadedLanguageCode == languageCode) return;
    _loadedLanguageCode = languageCode;
    final initialSettings = widget.initialSettings;
    if (initialSettings != null &&
        initialSettings.languageCode == languageCode) {
      _applySnapshot(initialSettings);
      return;
    }
    unawaited(_loadGeneralSettings(languageCode));
    unawaited(_loadPostSettings(languageCode));
    unawaited(_loadPostFormatSettings(languageCode));
    unawaited(_loadUploadSettings(languageCode));
    unawaited(_loadFeaturedSettings(languageCode));
    unawaited(_loadTrashCleanupSettings(languageCode));
  }

  @override
  void didUpdateWidget(covariant ContentSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initialSettings = widget.initialSettings;
    if (oldWidget.initialSettings == initialSettings ||
        initialSettings == null ||
        initialSettings.languageCode != _loadedLanguageCode) {
      return;
    }
    _applySnapshot(initialSettings);
  }

  @override
  void dispose() {
    _paginationController.dispose();
    _popularLimitController.dispose();
    _relatedLimitController.dispose();
    _maxImageSizeController.dispose();
    _maxVideoSizeController.dispose();
    _maxAudioSizeController.dispose();
    _maxFileSizeController.dispose();
    _allowedExtensionsController.dispose();
    _featuredLimitController.dispose();
    _autoDeleteDaysController.dispose();
    super.dispose();
  }

  void _showSavedMessage() {
    AdminToast.show(
      context,
      message: context.t('contentSettings.saveSuccess'),
      tone: AdminToastTone.success,
    );
  }

  void _showErrorMessage(Object error) {
    AdminToast.show(
      context,
      message: error.toString(),
      tone: AdminToastTone.error,
    );
  }

  void _applySnapshot(ContentSettingsSnapshot settings) {
    _applyGeneralSettings(settings.general);
    _applyPostSettings(settings.posts);
    _applyPostFormatSettings(settings.postFormats);
    _applyUploadSettings(settings.upload);
    _applyFeaturedSettings(settings.featured);
    _applyTrashCleanupSettings(settings.trashCleanup);
    _generalLoading = false;
    _postSettingsLoading = false;
    _postFormatsLoading = false;
    _fileUploadLoading = false;
    _featuredLoading = false;
    _trashCleanupLoading = false;
  }

  void _applyGeneralSettings(ContentGeneralSettingsData settings) {
    _showFeaturedSection = settings.showFeaturedSection;
    _commentSystem = settings.commentSystem;
    _commentApprovalSystem = settings.commentApprovalSystem;
    _emojiReactions = settings.emojiReactions;
    _paginationController.text = settings.homePageSize.toString();
  }

  void _applyPostSettings(ContentPostSettingsData settings) {
    _postUrlStructure = _postUrlStructureOption(settings.postUrlStructure);
    _bulkPostUpload = settings.bulkPostUpload;
    _deleteImagesAlongPost = settings.deleteMediaWithPost;
    _audioDownloadButton = settings.audioDownloadButton;
    _showPostAuthor = settings.showPostAuthor;
    _showPostDate = settings.showPostDate;
    _showPostViewCount = settings.showPostViewCount;
    _requireNewPostApproval = settings.requireNewPostApproval;
    _requireEditedPostApproval = settings.requireEditedPostApproval;
    _redirectRssPosts = settings.redirectRssPosts;
    _popularLimitController.text = settings.popularPostLimit.toString();
    _relatedLimitController.text = settings.relatedPostLimit.toString();
  }

  void _applyPostFormatSettings(ContentPostFormatSettingsData settings) {
    _postFormats = {
      for (final key in _ContentSettingOptions.postFormatKeys)
        key: settings.enabledFormats.contains(key),
    };
  }

  void _applyUploadSettings(ContentUploadSettingsData settings) {
    _imageFileFormat = settings.imageFileFormat;
    _allowedExtensionsController.text = _formatExtensionsInput(
      settings.allowedExtensions,
    );
    _maxImageSizeController.text = settings.maxImageSizeMb.toString();
    _maxVideoSizeController.text = settings.maxVideoSizeMb.toString();
    _maxAudioSizeController.text = settings.maxAudioSizeMb.toString();
    _maxFileSizeController.text = settings.maxFileSizeMb.toString();
  }

  void _applyFeaturedSettings(ContentFeaturedSettingsData settings) {
    _featuredContentSource = _featuredSourceOption(settings.contentSource);
    _featuredSortingLogic = _featuredSortingOption(settings.sortingLogic);
    _featuredShowNewsInfo = settings.showNewsInfo;
    _featuredLimitController.text = settings.displayLimit.toString();
  }

  void _applyTrashCleanupSettings(ContentTrashCleanupSettingsData settings) {
    _autoPostDeletion = settings.enabled;
    _autoDeleteDaysController.text = settings.days.toString();
    _autoDeletePosts = _trashScopeOption(settings.scope);
  }

  Future<void> _loadGeneralSettings(String languageCode) async {
    setState(() => _generalLoading = true);
    try {
      final settings = await widget.repository.fetchGeneralSettings(
        languageCode,
      );
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() {
        _applyGeneralSettings(settings);
        _generalLoading = false;
      });
      widget.onGeneralSettingsChanged?.call(settings);
    } catch (error) {
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() => _generalLoading = false);
      _showErrorMessage(error);
    }
  }

  Future<void> _saveGeneralSettings() async {
    if (_generalSaving) return;
    final languageCode =
        _loadedLanguageCode ??
        AdminLocalizationScope.maybeOf(context)?.code ??
        'tr';
    final pageSize = _normalizePageSize(_paginationController.text);
    setState(() {
      _generalSaving = true;
      _paginationController.text = pageSize.toString();
    });
    try {
      final saved = await widget.repository.saveGeneralSettings(
        session: widget.session,
        settings: ContentGeneralSettingsData(
          languageCode: languageCode,
          showFeaturedSection: _showFeaturedSection,
          commentSystem: _commentSystem,
          commentApprovalSystem: _commentApprovalSystem,
          emojiReactions: _emojiReactions,
          homePageSize: pageSize,
        ),
      );
      if (!mounted) return;
      setState(() {
        _applyGeneralSettings(saved);
        _generalSaving = false;
      });
      widget.onGeneralSettingsChanged?.call(saved);
      _showSavedMessage();
    } catch (error) {
      if (!mounted) return;
      setState(() => _generalSaving = false);
      _showErrorMessage(error);
    }
  }

  Future<void> _loadPostSettings(String languageCode) async {
    setState(() => _postSettingsLoading = true);
    try {
      final settings = await widget.repository.fetchPostSettings(languageCode);
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() {
        _applyPostSettings(settings);
        _postSettingsLoading = false;
      });
      widget.onPostSettingsChanged?.call(settings);
    } catch (error) {
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() => _postSettingsLoading = false);
      _showErrorMessage(error);
    }
  }

  Future<void> _savePostSettings() async {
    if (_postSettingsSaving) return;
    final languageCode =
        _loadedLanguageCode ??
        AdminLocalizationScope.maybeOf(context)?.code ??
        'tr';
    final popularLimit = _normalizeContentLimit(
      _popularLimitController.text,
      fallback: 5,
    );
    final relatedLimit = _normalizeContentLimit(
      _relatedLimitController.text,
      fallback: 6,
    );
    setState(() {
      _postSettingsSaving = true;
      _popularLimitController.text = popularLimit.toString();
      _relatedLimitController.text = relatedLimit.toString();
    });
    try {
      final saved = await widget.repository.savePostSettings(
        session: widget.session,
        settings: ContentPostSettingsData(
          languageCode: languageCode,
          postUrlStructure: _postUrlStructureValue(_postUrlStructure),
          bulkPostUpload: _bulkPostUpload,
          deleteMediaWithPost: _deleteImagesAlongPost,
          audioDownloadButton: _audioDownloadButton,
          showPostAuthor: _showPostAuthor,
          showPostDate: _showPostDate,
          showPostViewCount: _showPostViewCount,
          requireNewPostApproval: _requireNewPostApproval,
          requireEditedPostApproval: _requireEditedPostApproval,
          redirectRssPosts: _redirectRssPosts,
          popularPostLimit: popularLimit,
          relatedPostLimit: relatedLimit,
        ),
      );
      if (!mounted) return;
      setState(() {
        _applyPostSettings(saved);
        _postSettingsSaving = false;
      });
      widget.onPostSettingsChanged?.call(saved);
      _showSavedMessage();
    } catch (error) {
      if (!mounted) return;
      setState(() => _postSettingsSaving = false);
      _showErrorMessage(error);
    }
  }

  Future<void> _loadPostFormatSettings(String languageCode) async {
    setState(() => _postFormatsLoading = true);
    try {
      final settings = await widget.repository.fetchPostFormatSettings(
        languageCode,
      );
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() {
        _applyPostFormatSettings(settings);
        _postFormatsLoading = false;
      });
      widget.onPostFormatSettingsChanged?.call(settings);
    } catch (error) {
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() => _postFormatsLoading = false);
      _showErrorMessage(error);
    }
  }

  Future<void> _savePostFormatSettings() async {
    if (_postFormatsSaving) return;
    final languageCode =
        _loadedLanguageCode ??
        AdminLocalizationScope.maybeOf(context)?.code ??
        'tr';
    final enabledFormats = _postFormats.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toSet();
    setState(() => _postFormatsSaving = true);
    try {
      final saved = await widget.repository.savePostFormatSettings(
        session: widget.session,
        settings: ContentPostFormatSettingsData(
          languageCode: languageCode,
          enabledFormats: enabledFormats,
        ),
      );
      if (!mounted) return;
      setState(() {
        _applyPostFormatSettings(saved);
        _postFormatsSaving = false;
      });
      widget.onPostFormatSettingsChanged?.call(saved);
      _showSavedMessage();
    } catch (error) {
      if (!mounted) return;
      setState(() => _postFormatsSaving = false);
      _showErrorMessage(error);
    }
  }

  Future<void> _loadUploadSettings(String languageCode) async {
    setState(() => _fileUploadLoading = true);
    try {
      final settings = await widget.repository.fetchUploadSettings(
        languageCode,
      );
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() {
        _applyUploadSettings(settings);
        _fileUploadLoading = false;
      });
      widget.onUploadSettingsChanged?.call(settings);
    } catch (error) {
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() => _fileUploadLoading = false);
      _showErrorMessage(error);
    }
  }

  Future<void> _saveUploadSettings() async {
    if (_fileUploadSaving) return;
    final languageCode =
        _loadedLanguageCode ??
        AdminLocalizationScope.maybeOf(context)?.code ??
        'tr';
    final extensions = _parseExtensionsInput(_allowedExtensionsController.text);
    final maxImage = _normalizeMegabyteLimit(_maxImageSizeController.text, 20);
    final maxVideo = _normalizeMegabyteLimit(_maxVideoSizeController.text, 50);
    final maxAudio = _normalizeMegabyteLimit(_maxAudioSizeController.text, 20);
    final maxFile = _normalizeMegabyteLimit(_maxFileSizeController.text, 50);
    setState(() {
      _fileUploadSaving = true;
      _allowedExtensionsController.text = _formatExtensionsInput(extensions);
      _maxImageSizeController.text = maxImage.toString();
      _maxVideoSizeController.text = maxVideo.toString();
      _maxAudioSizeController.text = maxAudio.toString();
      _maxFileSizeController.text = maxFile.toString();
    });
    try {
      final saved = await widget.repository.saveUploadSettings(
        session: widget.session,
        settings: ContentUploadSettingsData(
          languageCode: languageCode,
          imageFileFormat: _imageFileFormat,
          allowedExtensions: extensions,
          maxImageSizeMb: maxImage,
          maxVideoSizeMb: maxVideo,
          maxAudioSizeMb: maxAudio,
          maxFileSizeMb: maxFile,
        ),
      );
      if (!mounted) return;
      setState(() {
        _applyUploadSettings(saved);
        _fileUploadSaving = false;
      });
      widget.onUploadSettingsChanged?.call(saved);
      _showSavedMessage();
    } catch (error) {
      if (!mounted) return;
      setState(() => _fileUploadSaving = false);
      _showErrorMessage(error);
    }
  }

  Future<void> _loadFeaturedSettings(String languageCode) async {
    setState(() => _featuredLoading = true);
    try {
      final settings = await widget.repository.fetchFeaturedSettings(
        languageCode,
      );
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() {
        _applyFeaturedSettings(settings);
        _featuredLoading = false;
      });
      widget.onFeaturedSettingsChanged?.call(settings);
    } catch (error) {
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() => _featuredLoading = false);
      _showErrorMessage(error);
    }
  }

  Future<void> _saveFeaturedSettings() async {
    if (_featuredSaving) return;
    final languageCode =
        _loadedLanguageCode ??
        AdminLocalizationScope.maybeOf(context)?.code ??
        'tr';
    final displayLimit = _normalizeFeaturedLimit(_featuredLimitController.text);
    setState(() {
      _featuredSaving = true;
      _featuredLimitController.text = displayLimit.toString();
    });
    try {
      final saved = await widget.repository.saveFeaturedSettings(
        session: widget.session,
        settings: ContentFeaturedSettingsData(
          languageCode: languageCode,
          contentSource: _featuredSourceValue(_featuredContentSource),
          sortingLogic: _featuredSortingValue(_featuredSortingLogic),
          displayLimit: displayLimit,
          showNewsInfo: _featuredShowNewsInfo,
        ),
      );
      if (!mounted) return;
      setState(() {
        _applyFeaturedSettings(saved);
        _featuredSaving = false;
      });
      widget.onFeaturedSettingsChanged?.call(saved);
      _showSavedMessage();
    } catch (error) {
      if (!mounted) return;
      setState(() => _featuredSaving = false);
      _showErrorMessage(error);
    }
  }

  Future<void> _loadTrashCleanupSettings(String languageCode) async {
    setState(() => _trashCleanupLoading = true);
    try {
      final settings = await widget.repository.fetchTrashCleanupSettings(
        languageCode,
      );
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() {
        _applyTrashCleanupSettings(settings);
        _trashCleanupLoading = false;
      });
      widget.onTrashCleanupSettingsChanged?.call(settings);
    } catch (error) {
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() => _trashCleanupLoading = false);
      _showErrorMessage(error);
    }
  }

  Future<void> _saveTrashCleanupSettings() async {
    if (_trashCleanupSaving) return;
    final languageCode =
        _loadedLanguageCode ??
        AdminLocalizationScope.maybeOf(context)?.code ??
        'tr';
    final days = _normalizeTrashDays(_autoDeleteDaysController.text);
    setState(() {
      _trashCleanupSaving = true;
      _autoDeleteDaysController.text = days.toString();
    });
    try {
      final saved = await widget.repository.saveTrashCleanupSettings(
        session: widget.session,
        settings: ContentTrashCleanupSettingsData(
          languageCode: languageCode,
          enabled: _autoPostDeletion,
          days: days,
          scope: _trashScopeValue(_autoDeletePosts),
        ),
      );
      if (!mounted) return;
      setState(() {
        _applyTrashCleanupSettings(saved);
        _trashCleanupSaving = false;
      });
      widget.onTrashCleanupSettingsChanged?.call(saved);
      _showSavedMessage();
    } catch (error) {
      if (!mounted) return;
      setState(() => _trashCleanupSaving = false);
      _showErrorMessage(error);
    }
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
                          loading: _generalLoading,
                          saving: _generalSaving,
                          paginationController: _paginationController,
                          onShowFeaturedSectionChanged: (value) =>
                              setState(() => _showFeaturedSection = value),
                          onCommentSystemChanged: (value) =>
                              setState(() => _commentSystem = value),
                          onCommentApprovalSystemChanged: (value) =>
                              setState(() => _commentApprovalSystem = value),
                          onEmojiReactionsChanged: (value) =>
                              setState(() => _emojiReactions = value),
                          onSave: _saveGeneralSettings,
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
                          loading: _postSettingsLoading,
                          saving: _postSettingsSaving,
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
                          onSave: _savePostSettings,
                        ),
                        _ContentSettingsTab.postFormats => _PostFormatsTab(
                          values: _postFormats,
                          loading: _postFormatsLoading,
                          saving: _postFormatsSaving,
                          onChanged: (key, value) => setState(
                            () => _postFormats = {..._postFormats, key: value},
                          ),
                          onSave: _savePostFormatSettings,
                        ),
                        _ContentSettingsTab.fileUpload => _FileUploadTab(
                          imageFileFormat: _imageFileFormat,
                          loading: _fileUploadLoading,
                          saving: _fileUploadSaving,
                          allowedExtensionsController:
                              _allowedExtensionsController,
                          maxImageSizeController: _maxImageSizeController,
                          maxVideoSizeController: _maxVideoSizeController,
                          maxAudioSizeController: _maxAudioSizeController,
                          maxFileSizeController: _maxFileSizeController,
                          onImageFileFormatChanged: (value) {
                            if (value == null) return;
                            setState(() => _imageFileFormat = value);
                          },
                          onSave: _saveUploadSettings,
                        ),
                      },
                    ),
                    const SizedBox(height: 18),
                    _FeaturedContentCard(
                      contentSource: _featuredContentSource,
                      sortingLogic: _featuredSortingLogic,
                      showNewsInfo: _featuredShowNewsInfo,
                      loading: _featuredLoading,
                      saving: _featuredSaving,
                      limitController: _featuredLimitController,
                      onContentSourceChanged: (value) {
                        if (value == null) return;
                        setState(() => _featuredContentSource = value);
                      },
                      onSortingLogicChanged: (value) {
                        if (value == null) return;
                        setState(() => _featuredSortingLogic = value);
                      },
                      onShowNewsInfoChanged: (value) {
                        setState(() => _featuredShowNewsInfo = value);
                      },
                      onSave: _saveFeaturedSettings,
                    ),
                  ],
                ),
                right: _AutoPostDeletionCard(
                  enabled: _autoPostDeletion,
                  loading: _trashCleanupLoading,
                  saving: _trashCleanupSaving,
                  daysController: _autoDeleteDaysController,
                  postsValue: _autoDeletePosts,
                  onEnabledChanged: (value) =>
                      setState(() => _autoPostDeletion = value),
                  onPostsChanged: (value) {
                    if (value == null) return;
                    setState(() => _autoDeletePosts = value);
                  },
                  onSave: _saveTrashCleanupSettings,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

int _normalizePageSize(String value) {
  final parsed = int.tryParse(value.trim());
  return (parsed ?? 16).clamp(1, 50).toInt();
}

int _normalizeMegabyteLimit(String value, int fallback) {
  final parsed = int.tryParse(value.trim());
  return (parsed ?? fallback).clamp(1, 1024).toInt();
}

int _normalizeFeaturedLimit(String value) {
  final parsed = int.tryParse(value.trim());
  return (parsed ?? 15).clamp(1, 50).toInt();
}

int _normalizeContentLimit(String value, {required int fallback}) {
  final parsed = int.tryParse(value.trim());
  return (parsed ?? fallback).clamp(1, 50).toInt();
}

int _normalizeTrashDays(String value) {
  final parsed = int.tryParse(value.trim());
  return (parsed ?? 30).clamp(1, 365).toInt();
}

String _postUrlStructureValue(String option) {
  return option == _ContentSettingOptions.idUrls ? 'id' : 'slug';
}

String _postUrlStructureOption(String value) {
  return value == 'id'
      ? _ContentSettingOptions.idUrls
      : _ContentSettingOptions.slugUrls;
}

String _featuredSourceValue(String option) {
  return option == _ContentSettingOptions.latestPosts ? 'latest' : 'manual';
}

String _featuredSourceOption(String value) {
  return value == 'latest'
      ? _ContentSettingOptions.latestPosts
      : _ContentSettingOptions.manualSelection;
}

String _featuredSortingValue(String option) {
  return option == _ContentSettingOptions.publishDate
      ? 'publish_date'
      : 'slider_order';
}

String _featuredSortingOption(String value) {
  return value == 'publish_date'
      ? _ContentSettingOptions.publishDate
      : _ContentSettingOptions.sliderOrder;
}

String _trashScopeValue(String option) {
  return option == _ContentSettingOptions.deleteDraftPosts ? 'draft' : 'all';
}

String _trashScopeOption(String value) {
  return value == 'draft'
      ? _ContentSettingOptions.deleteDraftPosts
      : _ContentSettingOptions.deleteAllPosts;
}

String _normalizeLanguageCode(String value) {
  final code = value.trim().toLowerCase().replaceAll('_', '-');
  return code.isEmpty ? 'tr' : code;
}

Set<String> _parseExtensionsInput(String value) {
  final parsed = value
      .split(RegExp(r'[\s,;]+'))
      .map(
        (item) => item.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), ''),
      )
      .where((item) => item.isNotEmpty)
      .toSet();
  return parsed.isEmpty ? {...contentUploadDefaultExtensions} : parsed;
}

String _formatExtensionsInput(Set<String> values) {
  final sorted =
      values
          .map(
            (item) =>
                item.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), ''),
          )
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return sorted.join(', ');
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
    required this.loading,
    required this.saving,
    required this.paginationController,
    required this.onShowFeaturedSectionChanged,
    required this.onCommentSystemChanged,
    required this.onCommentApprovalSystemChanged,
    required this.onEmojiReactionsChanged,
    required this.onSave,
  });

  final bool showFeaturedSection;
  final bool commentSystem;
  final bool commentApprovalSystem;
  final bool emojiReactions;
  final bool loading;
  final bool saving;
  final TextEditingController paginationController;
  final ValueChanged<bool> onShowFeaturedSectionChanged;
  final ValueChanged<bool> onCommentSystemChanged;
  final ValueChanged<bool> onCommentApprovalSystemChanged;
  final ValueChanged<bool> onEmojiReactionsChanged;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _SettingsLoadingPanel(height: 248);
    }

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
        _InputLine(
          label: 'contentSettings.general.pagination',
          controller: paginationController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        _SaveRow(onPressed: saving ? null : () => unawaited(onSave())),
      ],
    );
  }
}

class _SettingsLoadingPanel extends StatelessWidget {
  const _SettingsLoadingPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
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
    required this.loading,
    required this.saving,
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
  final bool loading;
  final bool saving;
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
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _SettingsLoadingPanel(height: 420);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectLine(
          label: 'contentSettings.posts.urlStructure',
          helper: 'contentSettings.posts.urlStructureHelp',
          value: postUrlStructure,
          options: _ContentSettingOptions.postUrlOptions,
          onChanged: saving ? (_) {} : onPostUrlStructureChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.bulkUpload',
          value: bulkPostUpload,
          valueLabel: 'contentSettings.value.enabled',
          onChanged: saving ? (_) {} : onBulkPostUploadChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.deleteImages',
          value: deleteImagesAlongPost,
          valueLabel: 'contentSettings.value.enabled',
          onChanged: saving ? (_) {} : onDeleteImagesAlongPostChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.audioDownload',
          value: audioDownloadButton,
          valueLabel: 'contentSettings.value.enabled',
          onChanged: saving ? (_) {} : onAudioDownloadButtonChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.showAuthor',
          value: showPostAuthor,
          valueLabel: 'contentSettings.value.yes',
          onChanged: saving ? (_) {} : onShowPostAuthorChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.showDate',
          value: showPostDate,
          valueLabel: 'contentSettings.value.yes',
          onChanged: saving ? (_) {} : onShowPostDateChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.showViewCount',
          value: showPostViewCount,
          valueLabel: 'contentSettings.value.yes',
          onChanged: saving ? (_) {} : onShowPostViewCountChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.newApproval',
          value: requireNewPostApproval,
          valueLabel: 'contentSettings.value.yes',
          onChanged: saving ? (_) {} : onRequireNewPostApprovalChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.editedApproval',
          value: requireEditedPostApproval,
          valueLabel: 'contentSettings.value.yes',
          onChanged: saving ? (_) {} : onRequireEditedPostApprovalChanged,
        ),
        _SwitchLine(
          label: 'contentSettings.posts.redirectRss',
          value: redirectRssPosts,
          valueLabel: 'contentSettings.value.yes',
          onChanged: saving ? (_) {} : onRedirectRssPostsChanged,
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
        _SaveRow(onPressed: saving ? null : () => unawaited(onSave())),
      ],
    );
  }
}

class _PostFormatsTab extends StatelessWidget {
  const _PostFormatsTab({
    required this.values,
    required this.loading,
    required this.saving,
    required this.onChanged,
    required this.onSave,
  });

  final Map<String, bool> values;
  final bool loading;
  final bool saving;
  final void Function(String key, bool value) onChanged;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _SettingsLoadingPanel(height: 270);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final key in _ContentSettingOptions.postFormatKeys)
          _SwitchLine(
            label: _ContentSettingOptions.postFormatLabels[key] ?? key,
            value: values[key] ?? false,
            valueLabel: 'contentSettings.value.enabled',
            onChanged: saving ? (_) {} : (value) => onChanged(key, value),
          ),
        const SizedBox(height: 8),
        _SaveRow(onPressed: saving ? null : () => unawaited(onSave())),
      ],
    );
  }
}

class _FileUploadTab extends StatelessWidget {
  const _FileUploadTab({
    required this.imageFileFormat,
    required this.loading,
    required this.saving,
    required this.allowedExtensionsController,
    required this.maxImageSizeController,
    required this.maxVideoSizeController,
    required this.maxAudioSizeController,
    required this.maxFileSizeController,
    required this.onImageFileFormatChanged,
    required this.onSave,
  });

  final String imageFileFormat;
  final bool loading;
  final bool saving;
  final TextEditingController allowedExtensionsController;
  final TextEditingController maxImageSizeController;
  final TextEditingController maxVideoSizeController;
  final TextEditingController maxAudioSizeController;
  final TextEditingController maxFileSizeController;
  final ValueChanged<String?> onImageFileFormatChanged;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _SettingsLoadingPanel(height: 300);

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
        _ExtensionsInputLine(
          label: 'contentSettings.file.allowedExtensions',
          helper: 'contentSettings.file.allowedExtensionsHelp',
          controller: allowedExtensionsController,
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
        _SaveRow(onPressed: saving ? null : () => unawaited(onSave())),
      ],
    );
  }
}

class _FeaturedContentCard extends StatelessWidget {
  const _FeaturedContentCard({
    required this.contentSource,
    required this.sortingLogic,
    required this.showNewsInfo,
    required this.loading,
    required this.saving,
    required this.limitController,
    required this.onContentSourceChanged,
    required this.onSortingLogicChanged,
    required this.onShowNewsInfoChanged,
    required this.onSave,
  });

  final String contentSource;
  final String sortingLogic;
  final bool showNewsInfo;
  final bool loading;
  final bool saving;
  final TextEditingController limitController;
  final ValueChanged<String?> onContentSourceChanged;
  final ValueChanged<String?> onSortingLogicChanged;
  final ValueChanged<bool> onShowNewsInfoChanged;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return _ContentCard(
      title: 'contentSettings.featured.title',
      minHeight: 358,
      child: loading
          ? const _SettingsLoadingPanel(height: 260)
          : Column(
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
                _SwitchLine(
                  label: 'contentSettings.featured.showNewsInfo',
                  value: showNewsInfo,
                  valueLabel: 'contentSettings.value.yes',
                  onChanged: onShowNewsInfoChanged,
                ),
                _FullTextField(
                  label: 'contentSettings.featured.displayLimit',
                  controller: limitController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                _SaveRow(onPressed: saving ? null : () => unawaited(onSave())),
              ],
            ),
    );
  }
}

class _AutoPostDeletionCard extends StatelessWidget {
  const _AutoPostDeletionCard({
    required this.enabled,
    required this.loading,
    required this.saving,
    required this.daysController,
    required this.postsValue,
    required this.onEnabledChanged,
    required this.onPostsChanged,
    required this.onSave,
  });

  final bool enabled;
  final bool loading;
  final bool saving;
  final TextEditingController daysController;
  final String postsValue;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String?> onPostsChanged;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return _ContentCard(
      title: 'contentSettings.autoDelete.title',
      minHeight: 318,
      child: loading
          ? const _SettingsLoadingPanel(height: 220)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InlineSwitchControl(
                  label: 'contentSettings.autoDelete.status',
                  value: enabled,
                  valueLabel: 'contentSettings.value.enable',
                  onChanged: saving ? (_) {} : onEnabledChanged,
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
                  onChanged: saving ? (_) {} : onPostsChanged,
                  isRequired: true,
                ),
                const SizedBox(height: 20),
                _SaveRow(onPressed: saving ? null : () => unawaited(onSave())),
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

class _ExtensionsInputLine extends StatelessWidget {
  const _ExtensionsInputLine({
    required this.label,
    required this.controller,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return _ContentLine(
      label: label,
      helper: helper,
      isRequired: true,
      control: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ContentTextField(controller: controller),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return _TagsField(
                tags: _parseExtensionsInput(controller.text).toList()..sort(),
              );
            },
          ),
        ],
      ),
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

class _SaveRow extends StatelessWidget {
  const _SaveRow({required this.onPressed});

  final VoidCallback? onPressed;

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
  static const postFormatKeys = contentPostFormatKeys;
  static const postFormatLabels = {
    'article': 'newsAdd.tab.article',
    'opinion': 'newsAdd.tab.opinion',
    'quiz': 'newsAdd.tab.quiz',
    'poll': 'newsAdd.tab.poll',
    'video': 'newsAdd.tab.video',
    'contents': 'newsAdd.tab.contents',
    'recipe': 'newsAdd.tab.recipe',
    'event': 'newsAdd.tab.event',
  };
}
