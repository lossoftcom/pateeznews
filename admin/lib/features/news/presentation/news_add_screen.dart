import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_news_ai_repository.dart';
import '../data/admin_news_source_reader.dart';
import '../data/admin_news_repository.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/data/media_service.dart';
import '../../../shared/widgets/admin_rich_text_editor.dart'
    show
        adminEmptyQuillDeltaJson,
        adminQuillDocumentFromJson,
        adminQuillHtml,
        adminSetQuillHtml;
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/media_library_dialog.dart';
import '../../../shared/widgets/symbol_icon.dart';
import 'news_models.dart';
import 'widgets/article_audio_block.dart';
import 'widgets/article_before_after_block.dart';
import 'widgets/article_event_block.dart';
import 'widgets/article_file_block.dart';
import 'widgets/article_flipcard_block.dart';
import 'widgets/article_iframe_block.dart';
import 'widgets/article_image_block.dart';
import 'widgets/article_quote_block.dart';
import 'widgets/article_recipe_block.dart';
import 'widgets/article_review_block.dart';
import 'widgets/article_social_block.dart';
import 'widgets/article_slider_image_block.dart';
import 'widgets/article_table_of_contents_block.dart';
import 'widgets/article_text_block.dart';
import 'widgets/article_vs_block.dart';
import 'widgets/article_video_block.dart';
import 'widgets/poll_question_block.dart';
import 'widgets/quiz_question_block.dart';
import 'widgets/quiz_result_block.dart';

enum NewsAddFormatTab { article, quiz, poll, video, contents, recipe, event }

enum NewsAddQuizSubTab { personality, trivia, checklist }

enum NewsAddQuizSort { asc, desc, hide }

const _newsAddStrongLine = Color(0xFFDDE5E8);
const _newsAddSoftLine = Color(0xFFE8EEF1);
const _newsAddTabMuted = Color(0xFF5F6F78);
const _newsAddUploadInk = Color(0xFF6D7B83);
const _newsAddActionHeight = 42.0;
const _newsAddCoverVisualHeight = 160.0;
const _newsAddAutoSubCategoryAliases = <NewsAddFormatTab, List<String>>{
  NewsAddFormatTab.quiz: ['test', 'testler', 'quiz', 'quizzes'],
  NewsAddFormatTab.poll: ['anket', 'anketler', 'poll', 'polls'],
  NewsAddFormatTab.video: ['video', 'videolar', 'videos'],
};
const _allowedAiSchemaTypes = {
  'NewsArticle',
  'ReportageNewsArticle',
  'OpinionNewsArticle',
  'AnalysisNewsArticle',
  'Article',
  'Quiz',
  'VideoObject',
  'Recipe',
  'Event',
};
const _editorDirtyIgnoredKeys = {
  'id',
  'type',
  'orderNumber',
  'allowMultiple',
  'answerCount',
  'pollColumns',
  'quizType',
  'showResults',
};
const _schemaTypeOptions = [
  _SchemaTypeOption('NewsArticle', 'newsAdd.schemaType.newsArticle'),
  _SchemaTypeOption(
    'ReportageNewsArticle',
    'newsAdd.schemaType.reportageNewsArticle',
  ),
  _SchemaTypeOption(
    'OpinionNewsArticle',
    'newsAdd.schemaType.opinionNewsArticle',
  ),
  _SchemaTypeOption(
    'AnalysisNewsArticle',
    'newsAdd.schemaType.analysisNewsArticle',
  ),
  _SchemaTypeOption('Article', 'newsAdd.schemaType.article'),
  _SchemaTypeOption('Quiz', 'newsAdd.schemaType.quiz'),
  _SchemaTypeOption('VideoObject', 'newsAdd.schemaType.videoObject'),
  _SchemaTypeOption('Recipe', 'newsAdd.schemaType.recipe'),
  _SchemaTypeOption('Event', 'newsAdd.schemaType.event'),
];

String _normalizeNewsAddCategoryLabel(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool _isHiddenNewsAddSubCategory(AdminNewsEditorCategory category) {
  return _normalizeNewsAddCategoryLabel(category.label).startsWith('haftanin ');
}

const _recipeDifficultyValues = {'easy', 'medium', 'hard'};

String _normalizeRecipeDifficulty(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return '';
  if (_recipeDifficultyValues.contains(normalized)) return normalized;
  if (normalized.contains('easy') ||
      normalized.contains('beginner') ||
      normalized.contains('simple') ||
      normalized.contains('kolay')) {
    return 'easy';
  }
  if (normalized.contains('medium') ||
      normalized.contains('intermediate') ||
      normalized.contains('moderate') ||
      normalized.contains('orta')) {
    return 'medium';
  }
  if (normalized.contains('hard') ||
      normalized.contains('advanced') ||
      normalized.contains('difficult') ||
      normalized.contains('challenging') ||
      normalized.contains('zor')) {
    return 'hard';
  }
  return '';
}

class _SchemaTypeOption {
  const _SchemaTypeOption(this.value, this.labelKey);

  final String value;
  final String labelKey;
}

class NewsAddScreen extends StatefulWidget {
  const NewsAddScreen({
    super.key,
    required this.session,
    required this.repository,
    this.profile,
    this.postId,
    this.aiRepository,
    this.onBackToNews,
  });

  final AdminSession session;
  final AdminProfile? profile;
  final AdminNewsRepository repository;
  final AdminNewsAiRepository? aiRepository;
  final String? postId;
  final VoidCallback? onBackToNews;

  @override
  State<NewsAddScreen> createState() => _NewsAddScreenState();
}

class _NewsAddScreenState extends State<NewsAddScreen> {
  // ── Top-level state ───────────────────────────────────────────────────────
  var _activeTab = NewsAddFormatTab.article;
  var _articleSort = _Sort.asc;
  var _videoSort = _Sort.asc;
  var _quizSubTab = NewsAddQuizSubTab.personality;
  var _quizSort = NewsAddQuizSort.asc;
  var _pollSort = NewsAddQuizSort.asc;
  var _mansetSlider = false;
  var _pinToTop = false;
  var _factCheck = false;
  var _pollAllowMulti = false;
  var _pollShowResults = true;

  // ── Controllers ───────────────────────────────────────────────────────────
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _seoTitleController = TextEditingController();
  final _slugController = TextEditingController();
  final _metaDescriptionController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _publishAtController = TextEditingController();
  final _quizEndDateController = TextEditingController();
  final _coverAltController = TextEditingController();
  final _articleBlocks = <Object>[ArticleTextBlockEntry()];
  final _quizResults = <QuizResultBlockEntry>[QuizResultBlockEntry()];
  final _quizQuestions = <QuizQuestionBlockEntry>[QuizQuestionBlockEntry()];
  final _pollQuestions = <PollQuestionBlockEntry>[PollQuestionBlockEntry()];
  final _videoBlocks = <Object>[ArticleVideoBlockEntry()];
  final _tocBlock = TocBlockEntry();
  final _recipeBlock = RecipeBlockEntry();
  final _recipeVideoBlock = ArticleVideoBlockEntry();
  final _eventBlock = EventBlockEntry();
  final _eventContentBlocks = <Object>[];

  // ── Misc state ────────────────────────────────────────────────────────────
  var _schemaType = 'NewsArticle';
  var _languageCode = 'tr';
  var _mainCategory = 'Niğde';
  String? _subCategory;
  String? _thirdCategory;
  String? _autoSubCategory;
  String? _coverImageUrl;
  final _keywords = <String>[];
  final _focusKeywordsController = TextEditingController();
  final _faqEntries = <_FaqEntry>[];
  final _entryIds = Expando<String>('news-editor-entry-id');
  var _idSequence = 0;
  var _loading = true;
  var _saving = false;
  var _hydrating = false;
  String? _loadError;
  String? _editingPostId;
  String? _loadedPublisherId;
  String _lastAutoSlug = '';
  String _lastAutoSeoTitle = '';
  String _lastAutoSeoDescription = '';
  Map<String, Object?> _loadedCardData = const {};
  AdminNewsEditorBootstrap _bootstrap = const AdminNewsEditorBootstrap(
    languages: [],
    categories: [],
    publishers: [],
  );
  late final AdminNewsAiRepository _aiRepository;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _aiRepository = widget.aiRepository ?? const GeminiAdminNewsAiRepository();
    _editingPostId = widget.postId;
    _titleController.addListener(_handleTitleChanged);
    _summaryController.addListener(_handleSummaryChanged);
    unawaited(_loadEditor());
  }

  @override
  void didUpdateWidget(covariant NewsAddScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId ||
        oldWidget.repository != widget.repository) {
      _editingPostId = widget.postId;
      unawaited(_loadEditor());
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_handleTitleChanged);
    _summaryController.removeListener(_handleSummaryChanged);
    _titleController.dispose();
    _summaryController.dispose();
    _seoTitleController.dispose();
    _slugController.dispose();
    _metaDescriptionController.dispose();
    _keywordsController.dispose();
    _publishAtController.dispose();
    _quizEndDateController.dispose();
    _coverAltController.dispose();
    _focusKeywordsController.dispose();
    for (final block in _articleBlocks) {
      _disposeContentBlock(block);
    }
    for (final result in _quizResults) {
      result.dispose();
    }
    for (final question in _quizQuestions) {
      question.dispose();
    }
    for (final question in _pollQuestions) {
      question.dispose();
    }
    for (final block in _videoBlocks) {
      _disposeContentBlock(block);
    }
    _tocBlock.dispose();
    _recipeBlock.dispose();
    _recipeVideoBlock.dispose();
    _eventBlock.dispose();
    for (final block in _eventContentBlocks) {
      _disposeContentBlock(block);
    }
    super.dispose();
  }

  void _disposeContentBlock(Object block) {
    if (block is ArticleTextBlockEntry) block.dispose();
    if (block is ArticleImageBlockEntry) block.dispose();
    if (block is ArticleSliderImageBlockEntry) block.dispose();
    if (block is ArticleVideoBlockEntry) block.dispose();
    if (block is ArticleAudioBlockEntry) block.dispose();
    if (block is ArticleFileBlockEntry) block.dispose();
    if (block is ArticleSocialBlockEntry) block.dispose();
    if (block is ArticleFlipcardBlockEntry) block.dispose();
    if (block is ArticleBeforeAfterBlockEntry) block.dispose();
    if (block is ArticleVsBlockEntry) block.dispose();
    if (block is ArticleReviewBlockEntry) block.dispose();
    if (block is ArticleQuoteBlockEntry) block.dispose();
    if (block is ArticleIframeBlockEntry) block.dispose();
    if (block is PollQuestionBlockEntry) block.dispose();
  }

  Future<void> _loadEditor() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final bootstrapFuture = widget.repository.fetchEditorBootstrap();
      final postId = widget.postId?.trim();
      final postFuture = postId == null || postId.isEmpty
          ? null
          : widget.repository.fetchEditorPost(postId);
      final bootstrap = await bootstrapFuture;
      final post = postFuture == null ? null : await postFuture;
      if (!mounted) return;
      _hydrating = true;
      setState(() {
        _bootstrap = bootstrap;
        _resetEditorState();
        _applyBootstrapDefaults();
        if (post != null) {
          _applyEditorPost(post);
        }
        _loading = false;
      });
      _hydrating = false;
    } catch (error) {
      if (!mounted) return;
      _hydrating = false;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  void _resetEditorState() {
    _activeTab = NewsAddFormatTab.article;
    _articleSort = _Sort.asc;
    _videoSort = _Sort.asc;
    _quizSubTab = NewsAddQuizSubTab.personality;
    _quizSort = NewsAddQuizSort.asc;
    _pollSort = NewsAddQuizSort.asc;
    _mansetSlider = false;
    _pinToTop = false;
    _factCheck = false;
    _pollAllowMulti = false;
    _pollShowResults = true;
    _schemaType = 'NewsArticle';
    _languageCode = 'tr';
    _mainCategory = 'Niğde';
    _subCategory = null;
    _thirdCategory = null;
    _autoSubCategory = null;
    _coverImageUrl = null;
    _editingPostId = widget.postId;
    _loadedPublisherId = null;
    _loadedCardData = const {};
    _lastAutoSlug = '';
    _lastAutoSeoTitle = '';
    _lastAutoSeoDescription = '';
    _clearController(_titleController);
    _clearController(_summaryController);
    _clearController(_seoTitleController);
    _clearController(_slugController);
    _clearController(_metaDescriptionController);
    _clearController(_keywordsController);
    _clearController(_publishAtController);
    _clearController(_quizEndDateController);
    _clearController(_coverAltController);
    _keywords.clear();
    _focusKeywordsController.clear();
    for (final entry in _faqEntries) {
      entry.dispose();
    }
    _faqEntries.clear();
    _replaceContentBlocks(_articleBlocks, [ArticleTextBlockEntry()]);
    _replaceContentBlocks(_videoBlocks, [ArticleVideoBlockEntry()]);
    _replaceQuizResults([QuizResultBlockEntry()]);
    _replaceQuizQuestions([QuizQuestionBlockEntry()]);
    _replacePollQuestions([PollQuestionBlockEntry()]);
    _resetTocBlock();
    _resetRecipeBlock();
    _resetVideoBlock(_recipeVideoBlock);
    _resetEventBlock();
    _replaceContentBlocks(_eventContentBlocks, const []);
  }

  void _applyBootstrapDefaults() {
    if (_bootstrap.languages.any((item) => item.code == _languageCode)) {
      return;
    }
    if (_bootstrap.languages.isNotEmpty) {
      _languageCode = _bootstrap.languages.first.code;
    }
    final roots = _rootCategoriesForLanguage(_languageCode);
    if (roots.isNotEmpty) {
      _mainCategory = roots.first.label;
      _subCategory = null;
      _thirdCategory = null;
      _autoSubCategory = null;
    }
  }

  void _applyEditorPost(AdminNewsEditorPost post) {
    _editingPostId = post.id;
    _loadedPublisherId = post.publisherId;
    _loadedCardData = post.cardData;
    _setControllerText(_titleController, post.title);
    _setControllerText(_summaryController, post.summary);
    _setControllerText(_seoTitleController, post.seoTitle);
    _setControllerText(_slugController, post.slug);
    _setControllerText(_metaDescriptionController, post.seoDescription);
    _setControllerText(_coverAltController, post.thumbnailAlt);
    _schemaType = post.schemaType.isEmpty ? 'NewsArticle' : post.schemaType;
    _languageCode = post.languageCode.isEmpty ? 'tr' : post.languageCode;
    _pinToTop = post.isPinned;
    _mansetSlider = post.showInManset;
    _factCheck = post.factChecked;
    _coverImageUrl = post.thumbnailUrl.trim().isEmpty
        ? null
        : post.thumbnailUrl;
    _setControllerText(
      _publishAtController,
      post.publishedAt == null ? '' : _formatEditorDate(post.publishedAt!),
    );
    _keywords
      ..clear()
      ..addAll(
        post.keywords
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
    _hydrateFaq(post.faqData);
    _applyCategorySelection(post.category);
    _hydrateItems(post.type, post.items);
    _lastAutoSlug = _slugify(_titleController.text);
    _lastAutoSeoTitle = _titleController.text.trim().length > 60
        ? _titleController.text.trim().substring(0, 60)
        : _titleController.text.trim();
    _lastAutoSeoDescription = _summaryController.text.trim().length > 160
        ? _summaryController.text.trim().substring(0, 160)
        : _summaryController.text.trim();
  }

  void _applyCategorySelection(String category) {
    _autoSubCategory = null;
    final label = category.trim();
    final roots = _rootCategoriesForLanguage(_languageCode);
    if (label.isEmpty) {
      if (roots.isNotEmpty) _mainCategory = roots.first.label;
      _subCategory = null;
      _thirdCategory = null;
      return;
    }
    final byLabel = {
      for (final item in _categoriesForLanguage(_languageCode))
        item.label: item,
    };
    final selected = byLabel[label];
    if (selected == null || selected.parentId.isEmpty) {
      _mainCategory = label;
      _subCategory = null;
      _thirdCategory = null;
      return;
    }
    final parent = _categoryById(selected.parentId);
    final grandParent = parent == null || parent.parentId.isEmpty
        ? null
        : _categoryById(parent.parentId);
    if (grandParent != null) {
      _mainCategory = grandParent.label;
      _subCategory = parent?.label;
      _thirdCategory = selected.label;
    } else {
      _mainCategory = parent?.label ?? label;
      _subCategory = selected.label;
      _thirdCategory = null;
    }
  }

  List<AdminNewsEditorCategory> _categoriesForLanguage(String languageCode) {
    final exact = _bootstrap.categories
        .where(
          (item) =>
              item.languageCode.isEmpty || item.languageCode == languageCode,
        )
        .toList();
    exact.sort((a, b) {
      final order = a.orderIndex.compareTo(b.orderIndex);
      return order == 0 ? a.label.compareTo(b.label) : order;
    });
    return exact;
  }

  List<AdminNewsEditorCategory> _rootCategoriesForLanguage(
    String languageCode,
  ) {
    return _categoriesForLanguage(languageCode)
        .where(
          (item) =>
              item.parentId.isEmpty || _categoryById(item.parentId) == null,
        )
        .toList();
  }

  List<AdminNewsEditorCategory> _childrenOfCategory(String? label) {
    if (label == null || label.trim().isEmpty) return const [];
    AdminNewsEditorCategory? parent;
    for (final item in _categoriesForLanguage(_languageCode)) {
      if (item.label == label) {
        parent = item;
        break;
      }
    }
    if (parent == null) return const [];
    final parentId = parent.id;
    return _categoriesForLanguage(_languageCode)
        .where(
          (item) =>
              item.parentId == parentId && !_isHiddenNewsAddSubCategory(item),
        )
        .toList();
  }

  AdminNewsEditorCategory? _defaultSubCategoryForTab(NewsAddFormatTab tab) {
    final aliases = _newsAddAutoSubCategoryAliases[tab];
    if (aliases == null) return null;
    final normalizedAliases = aliases
        .map(_normalizeNewsAddCategoryLabel)
        .toSet();
    for (final category in _childrenOfCategory(_mainCategory)) {
      if (normalizedAliases.contains(
        _normalizeNewsAddCategoryLabel(category.label),
      )) {
        return category;
      }
    }
    return null;
  }

  bool _isCurrentTabDefaultSubCategory(String value) {
    final autoSubCategory = _autoSubCategory?.trim();
    if (autoSubCategory == null || autoSubCategory.isEmpty) return false;
    return _normalizeNewsAddCategoryLabel(value) ==
        _normalizeNewsAddCategoryLabel(autoSubCategory);
  }

  AdminNewsEditorCategory? _categoryById(String id) {
    for (final item in _bootstrap.categories) {
      if (item.id == id) return item;
    }
    return null;
  }

  String get _selectedCategory {
    final third = _thirdCategory?.trim();
    if (third != null && third.isNotEmpty) return third;
    final sub = _subCategory?.trim();
    if (sub != null && sub.isNotEmpty) return sub;
    return _mainCategory.trim();
  }

  void _replaceContentBlocks(List<Object> target, List<Object> next) {
    for (final block in target) {
      _disposeContentBlock(block);
    }
    target
      ..clear()
      ..addAll(next);
  }

  void _replaceQuizResults(List<QuizResultBlockEntry> next) {
    for (final entry in _quizResults) {
      entry.dispose();
    }
    _quizResults
      ..clear()
      ..addAll(next);
  }

  void _replaceQuizQuestions(List<QuizQuestionBlockEntry> next) {
    for (final entry in _quizQuestions) {
      entry.dispose();
    }
    _quizQuestions
      ..clear()
      ..addAll(next);
  }

  void _replacePollQuestions(List<PollQuestionBlockEntry> next) {
    for (final entry in _pollQuestions) {
      entry.dispose();
    }
    _pollQuestions
      ..clear()
      ..addAll(next);
  }

  void _resetTocBlock() {
    _tocBlock.level1Style = 'none';
    _tocBlock.level2Style = 'none';
    _tocBlock.level3Style = 'none';
    _tocBlock.showLevel1InText = false;
    _tocBlock.showLevel2InText = false;
    _tocBlock.showLevel3InText = false;
    for (final item in _tocBlock.items) {
      item.dispose();
    }
    _tocBlock.items
      ..clear()
      ..add(TocItemEntry());
  }

  void _resetRecipeBlock() {
    _recipeBlock.difficulty = '';
    _clearController(_recipeBlock.prepTimeController);
    _clearController(_recipeBlock.cookTimeController);
    _clearController(_recipeBlock.servingController);
    for (final item in _recipeBlock.ingredients) {
      item.dispose();
    }
    for (final item in _recipeBlock.nutrition) {
      item.dispose();
    }
    for (final item in _recipeBlock.directions) {
      item.dispose();
    }
    _recipeBlock.ingredients
      ..clear()
      ..add(RecipeIngredientEntry());
    _recipeBlock.nutrition
      ..clear()
      ..add(RecipeNutritionEntry());
    _recipeBlock.directions
      ..clear()
      ..add(RecipeDirectionEntry());
  }

  void _resetVideoBlock(ArticleVideoBlockEntry block) {
    _clearController(block.titleController);
    _clearController(block.sourceController);
    adminSetQuillHtml(block.descriptionController, '');
    block.mediaUrl = null;
    block.showOnHomepage = false;
    block.extraSettingsExpanded = false;
  }

  void _resetEventBlock() {
    _eventBlock.registrationType = 'none';
    for (final controller in [
      _eventBlock.startDateTimeController,
      _eventBlock.endDateTimeController,
      _eventBlock.organizerController,
      _eventBlock.venueNameController,
      _eventBlock.addressController,
      _eventBlock.latitudeController,
      _eventBlock.longitudeController,
      _eventBlock.ticketUrlController,
      _eventBlock.ticketPriceController,
      _eventBlock.capacityController,
      _eventBlock.scheduleTitleController,
      _eventBlock.highlightsTitleController,
      _eventBlock.speakersTitleController,
    ]) {
      _clearController(controller);
    }
    for (final item in _eventBlock.schedule) {
      item.dispose();
    }
    for (final item in _eventBlock.highlights) {
      item.dispose();
    }
    for (final item in _eventBlock.speakers) {
      item.dispose();
    }
    _eventBlock.schedule
      ..clear()
      ..add(EventScheduleEntry());
    _eventBlock.highlights
      ..clear()
      ..add(EventHighlightEntry());
    _eventBlock.speakers
      ..clear()
      ..add(EventSpeakerEntry());
  }

  void _clearController(TextEditingController controller) {
    controller.value = const TextEditingValue();
  }

  void _setControllerText(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _handleTitleChanged() {
    if (_hydrating) return;
    final title = _titleController.text.trim();
    final nextSlug = _slugify(title);
    if (_slugController.text.trim().isEmpty ||
        _slugController.text.trim() == _lastAutoSlug) {
      _setControllerText(_slugController, nextSlug);
    }
    _lastAutoSlug = nextSlug;
    final nextSeoTitle = title.length > 60 ? title.substring(0, 60) : title;
    if (_seoTitleController.text.trim().isEmpty ||
        _seoTitleController.text.trim() == _lastAutoSeoTitle) {
      _setControllerText(_seoTitleController, nextSeoTitle);
    }
    _lastAutoSeoTitle = nextSeoTitle;
    if (_summaryController.text.trim().isEmpty &&
        (_metaDescriptionController.text.trim().isEmpty ||
            _metaDescriptionController.text.trim() ==
                _lastAutoSeoDescription)) {
      final nextDescription = title.length > 160
          ? title.substring(0, 160)
          : title;
      _setControllerText(_metaDescriptionController, nextDescription);
      _lastAutoSeoDescription = nextDescription;
    }
  }

  void _handleSummaryChanged() {
    if (_hydrating) return;
    final summary = _summaryController.text.trim();
    final nextDescription = summary.length > 160
        ? summary.substring(0, 160)
        : summary;
    if (_metaDescriptionController.text.trim().isEmpty ||
        _metaDescriptionController.text.trim() == _lastAutoSeoDescription) {
      _setControllerText(_metaDescriptionController, nextDescription);
    }
    _lastAutoSeoDescription = nextDescription;
  }

  void _hydrateFaq(List<Map<String, Object?>> faqData) {
    for (final entry in _faqEntries) {
      entry.dispose();
    }
    _faqEntries
      ..clear()
      ..addAll([
        for (final row in faqData)
          if (_text(row['q']).isNotEmpty || _text(row['a']).isNotEmpty)
            _FaqEntry()
              ..question.text = _text(row['q'])
              ..answer.text = _text(row['a']),
      ]);
  }

  void _hydrateItems(String postType, List<Map<String, Object?>> rawItems) {
    final items = rawItems
        .where((item) => _text(item['type']) != 'faq')
        .toList(growable: false);
    _activeTab = _tabFromPostType(postType);
    switch (_activeTab) {
      case NewsAddFormatTab.article:
        final blocks = items.map(_blockFromItem).whereType<Object>().toList();
        _replaceContentBlocks(
          _articleBlocks,
          blocks.isEmpty ? [ArticleTextBlockEntry()] : blocks,
        );
      case NewsAddFormatTab.video:
        final blocks = items.map(_blockFromItem).whereType<Object>().toList();
        _replaceContentBlocks(
          _videoBlocks,
          blocks.isEmpty ? [ArticleVideoBlockEntry()] : blocks,
        );
      case NewsAddFormatTab.poll:
        final polls = items
            .where((item) => _text(item['type']) == 'poll')
            .map(_pollFromItem)
            .toList();
        _replacePollQuestions(
          polls.isEmpty ? [PollQuestionBlockEntry()] : polls,
        );
      case NewsAddFormatTab.quiz:
        final quizItem = items
            .where((item) => _text(item['type']) == 'quiz')
            .cast<Map<String, Object?>?>()
            .firstWhere((item) => item != null, orElse: () => null);
        _hydrateQuizItem(quizItem ?? const {});
      case NewsAddFormatTab.contents:
        final tocItem = items
            .where((item) => _text(item['type']) == 'toc')
            .cast<Map<String, Object?>?>()
            .firstWhere((item) => item != null, orElse: () => null);
        _hydrateTocItem(tocItem ?? const {});
      case NewsAddFormatTab.recipe:
        for (final item in items) {
          final type = _text(item['type']);
          if (type == 'recipe') _hydrateRecipeItem(item);
          if (type == 'video') _hydrateVideoBlock(_recipeVideoBlock, item);
        }
      case NewsAddFormatTab.event:
        final eventItem = items
            .where((item) => _text(item['type']) == 'event')
            .cast<Map<String, Object?>?>()
            .firstWhere((item) => item != null, orElse: () => null);
        if (eventItem != null) _hydrateEventItem(eventItem);
        final blocks = items
            .where((item) => _text(item['type']) != 'event')
            .map(_blockFromItem)
            .whereType<Object>()
            .toList();
        _replaceContentBlocks(_eventContentBlocks, blocks);
    }
  }

  NewsAddFormatTab _tabFromPostType(String type) {
    return switch (type.trim().toLowerCase()) {
      'quiz' => NewsAddFormatTab.quiz,
      'poll' => NewsAddFormatTab.poll,
      'video' => NewsAddFormatTab.video,
      'contents' || 'table of contents' || 'toc' => NewsAddFormatTab.contents,
      'recipe' => NewsAddFormatTab.recipe,
      'event' => NewsAddFormatTab.event,
      _ => NewsAddFormatTab.article,
    };
  }

  Object? _blockFromItem(Map<String, Object?> item) {
    final type = _text(item['type']);
    switch (type) {
      case 'text':
        final block = ArticleTextBlockEntry();
        _hydrateCommonBlock(block, item);
        adminSetQuillHtml(block.editorController, _text(item['description']));
        return block;
      case 'image':
        final block = ArticleImageBlockEntry();
        _hydrateCommonBlock(block, item);
        adminSetQuillHtml(block.captionController, _text(item['description']));
        block.imageUrl = _nullableText(item['mediaUrl']);
        block.altTextController.text = _text(item['altText']);
        block.showOnHomepage = _bool(item['showOnHomepage']);
        return block;
      case 'slider':
        final block = ArticleSliderImageBlockEntry();
        _hydrateCommonBlock(block, item);
        adminSetQuillHtml(block.captionController, _text(item['description']));
        block.imageUrls.addAll(_stringList(item['mediaUrls']));
        block.showOnHomepage = _bool(item['showOnHomepage']);
        return block;
      case 'video':
        final block = ArticleVideoBlockEntry();
        _hydrateVideoBlock(block, item);
        return block;
      case 'audio':
        final block = ArticleAudioBlockEntry();
        _hydrateCommonBlock(block, item);
        adminSetQuillHtml(
          block.descriptionController,
          _text(item['description']),
        );
        block.mediaUrl = _nullableText(item['mediaUrl']);
        block.showOnHomepage = _bool(item['showOnHomepage']);
        return block;
      case 'file':
        final block = ArticleFileBlockEntry();
        _hydrateCommonBlock(block, item);
        adminSetQuillHtml(
          block.descriptionController,
          _text(item['description']),
        );
        block.mediaUrl = _nullableText(item['mediaUrl']);
        block.showOnHomepage = _bool(item['showOnHomepage']);
        return block;
      case 'social':
        final block = ArticleSocialBlockEntry();
        _hydrateCommonBlock(block, item);
        block.embedController.text = _text(item['mediaUrl']);
        adminSetQuillHtml(block.contentController, _text(item['description']));
        block.showOnHomepage = _bool(item['showOnHomepage']);
        return block;
      case 'flipcard':
        final block = ArticleFlipcardBlockEntry();
        _hydrateCommonBlock(block, item);
        final data = _map(item['flipData']);
        block.frontImageUrl = _nullableText(data['frontImage']);
        block.backImageUrl = _nullableText(data['backImage']);
        block.frontTitleController.text = _text(data['frontTitle']);
        block.backTitleController.text = _text(data['backTitle']);
        block.frontLinkController.text = _text(data['frontLink']);
        block.backLinkController.text = _text(data['backLink']);
        adminSetQuillHtml(
          block.frontDescriptionController,
          _text(data['frontDescription']),
        );
        adminSetQuillHtml(
          block.backDescriptionController,
          _text(data['backDescription']),
        );
        adminSetQuillHtml(
          block.descriptionController,
          _text(item['description']),
        );
        block.showOnHomepage = _bool(item['showOnHomepage']);
        return block;
      case 'beforeafter':
        final block = ArticleBeforeAfterBlockEntry(
          beforeLabel: context.t('newsAdd.beforeAfterBeforeDefault'),
          afterLabel: context.t('newsAdd.beforeAfterAfterDefault'),
        );
        _hydrateCommonBlock(block, item);
        final data = _map(item['beforeAfterData']);
        block.beforeImageUrl = _nullableText(data['beforeImage']);
        block.afterImageUrl = _nullableText(data['afterImage']);
        block.beforeLabelController.text = _text(data['beforeLabel']);
        block.afterLabelController.text = _text(data['afterLabel']);
        adminSetQuillHtml(
          block.descriptionController,
          _text(item['description']),
        );
        block.showOnHomepage = _bool(item['showOnHomepage']);
        return block;
      case 'poll':
        return _pollFromItem(item);
      case 'vs':
        final options = _mapList(item['options']);
        final block = ArticleVsBlockEntry(
          leftLabel: options.isNotEmpty
              ? _text(options[0]['text'])
              : context.t('newsAdd.vsLeftDefault'),
          rightLabel: options.length > 1
              ? _text(options[1]['text'])
              : context.t('newsAdd.vsRightDefault'),
        );
        _hydrateCommonBlock(block, item);
        adminSetQuillHtml(
          block.descriptionController,
          _text(item['description']),
        );
        block.mainImageUrl = _nullableText(item['mediaUrl']);
        block.showOnHomepage = _bool(item['showOnHomepage']);
        for (
          var index = 0;
          index < options.length && index < block.options.length;
          index++
        ) {
          _setEntryId(
            block.options[index],
            preferred: _text(options[index]['id']),
          );
          block.options[index].textController.text = _text(
            options[index]['text'],
          );
          block.options[index].votesController.text = _int(
            options[index]['votes'],
          ).toString();
          block.options[index].imageUrl = _nullableText(
            options[index]['image'],
          );
        }
        return block;
      case 'review':
        final data = _map(item['reviewData']);
        final block = ArticleReviewBlockEntry(
          designLabel: context.t('newsAdd.reviewCriterionDesign'),
          performanceLabel: context.t('newsAdd.reviewCriterionPerformance'),
        );
        _setEntryId(block, preferred: _text(item['id']));
        block.productNameController.text = _text(data['productName']);
        block.sourceController.text = _text(item['source']);
        block.imageUrl = _nullableText(data['productImage']);
        adminSetQuillHtml(block.verdictController, _text(data['verdict']));
        _replaceReviewTexts(block.pros, _stringList(data['pros']));
        _replaceReviewTexts(block.cons, _stringList(data['cons']));
        _replaceReviewCriteria(block.criteria, _mapList(data['breakdown']));
        block.showOnHomepage = _bool(item['showOnHomepage']);
        return block;
      case 'quote':
        final block = ArticleQuoteBlockEntry();
        _setEntryId(block, preferred: _text(item['id']));
        block.authorController.text = _text(item['title']);
        block.sourceController.text = _text(item['source']);
        adminSetQuillHtml(block.quoteController, _text(item['description']));
        block.showOnHomepage = _bool(item['showOnHomepage']);
        return block;
      case 'iframe':
        final block = ArticleIframeBlockEntry();
        _setEntryId(block, preferred: _text(item['id']));
        block.titleController.text = _text(item['title']);
        block.embedController.text = _text(item['mediaUrl']).isNotEmpty
            ? _text(item['mediaUrl'])
            : _text(item['description']);
        block.sourceController.text = _text(item['source']);
        block.showOnHomepage = _bool(item['showOnHomepage']);
        return block;
    }
    return null;
  }

  void _hydrateCommonBlock(Object block, Map<String, Object?> item) {
    _setEntryId(block, preferred: _text(item['id']));
    if (block is ArticleTextBlockEntry) {
      block.titleController.text = _text(item['title']);
      block.sourceController.text = _text(item['source']);
    } else if (block is ArticleImageBlockEntry) {
      block.titleController.text = _text(item['title']);
      block.sourceController.text = _text(item['source']);
    } else if (block is ArticleSliderImageBlockEntry) {
      block.titleController.text = _text(item['title']);
      block.sourceController.text = _text(item['source']);
    } else if (block is ArticleVideoBlockEntry) {
      block.titleController.text = _text(item['title']);
      block.sourceController.text = _text(item['source']);
    } else if (block is ArticleAudioBlockEntry) {
      block.titleController.text = _text(item['title']);
      block.sourceController.text = _text(item['source']);
    } else if (block is ArticleFileBlockEntry) {
      block.titleController.text = _text(item['title']);
      block.sourceController.text = _text(item['source']);
    } else if (block is ArticleSocialBlockEntry) {
      block.titleController.text = _text(item['title']);
      block.sourceController.text = _text(item['source']);
    } else if (block is ArticleFlipcardBlockEntry) {
      block.titleController.text = _text(item['title']);
      block.sourceController.text = _text(item['source']);
    } else if (block is ArticleBeforeAfterBlockEntry) {
      block.titleController.text = _text(item['title']);
      block.sourceController.text = _text(item['source']);
    } else if (block is ArticleVsBlockEntry) {
      block.titleController.text = _text(item['title']);
      block.sourceController.text = _text(item['source']);
    }
  }

  void _hydrateVideoBlock(
    ArticleVideoBlockEntry block,
    Map<String, Object?> item,
  ) {
    _hydrateCommonBlock(block, item);
    adminSetQuillHtml(block.descriptionController, _text(item['description']));
    block.mediaUrl = _nullableText(item['mediaUrl']);
    block.showOnHomepage = _bool(item['showOnHomepage']);
  }

  PollQuestionBlockEntry _pollFromItem(Map<String, Object?> item) {
    final block = PollQuestionBlockEntry(answerCount: 0);
    _hydrateCommonBlock(block, item);
    block.titleController.text = _text(item['title']);
    block.sourceController.text = _text(item['source']);
    adminSetQuillHtml(block.descriptionController, _text(item['description']));
    block.imageUrl = _nullableText(item['mediaUrl']);
    block.showOnHomepage = _bool(item['showOnHomepage']);
    block.layout = _pollLayoutFromColumns(
      _int(item['pollColumns']),
      _bool(item['isImagePoll']),
    );
    final options = _mapList(item['options']);
    block.answers.clear();
    for (final option in options) {
      final answer = PollQuestionAnswerEntry();
      _setEntryId(answer, preferred: _text(option['id']));
      answer.answerController.text = _text(option['text']);
      answer.votesController.text = _int(option['votes']).toString();
      answer.imageUrl = _nullableText(option['image']);
      block.answers.add(answer);
    }
    if (block.answers.isEmpty) block.ensureAnswerCount(2);
    return block;
  }

  void _hydrateQuizItem(Map<String, Object?> item) {
    _setEntryId(item, preferred: _text(item['id']));
    final data = _map(item['quizData']);
    _quizSubTab = switch (_text(data['quizType'])) {
      'trivia' => NewsAddQuizSubTab.trivia,
      'checklist' => NewsAddQuizSubTab.checklist,
      _ => NewsAddQuizSubTab.personality,
    };
    _quizSort = _quizSortFromText(_text(data['questionSorting']));
    _pollAllowMulti = _bool(data['allowMultiple']);
    _pollShowResults = data['showResults'] != false;
    _quizEndDateController.text = _text(data['endDate']);
    final results = <QuizResultBlockEntry>[];
    for (final row in _mapList(data['results'])) {
      final entry = QuizResultBlockEntry();
      _setEntryId(entry, preferred: _text(row['id']));
      entry.titleController.text = _text(row['title']);
      entry.imageUrl = _nullableText(row['image']);
      entry.minScoreController.text = _scoreText(row['minScore']);
      entry.maxScoreController.text = _scoreText(row['maxScore']);
      final answerCount = _optionalInt(row['answerCount']);
      if (entry.minScoreController.text.isEmpty && answerCount != null) {
        entry.minScoreController.text = answerCount.toString();
      }
      if (entry.maxScoreController.text.isEmpty && answerCount != null) {
        entry.maxScoreController.text = answerCount.toString();
      }
      adminSetQuillHtml(entry.descriptionController, _text(row['description']));
      results.add(entry);
    }
    _replaceQuizResults(results.isEmpty ? [QuizResultBlockEntry()] : results);
    final questions = <QuizQuestionBlockEntry>[];
    for (final row in _mapList(data['questions'])) {
      final entry = QuizQuestionBlockEntry(answerCount: 0);
      _setEntryId(entry, preferred: _text(row['id']));
      entry.titleController.text = _text(row['title']);
      entry.imageUrl = _nullableText(row['image']);
      entry.layout = _quizLayoutFromText(_text(row['layout']));
      adminSetQuillHtml(entry.descriptionController, _text(row['description']));
      entry.answers.clear();
      for (final answerRow in _mapList(row['answers'])) {
        final answer = QuizQuestionAnswerEntry();
        _setEntryId(answer, preferred: _text(answerRow['id']));
        answer.answerController.text = _text(answerRow['text']);
        answer.imageUrl = _nullableText(answerRow['image']);
        answer.resultId = _nullableText(answerRow['resultId']);
        answer.isCorrect = _bool(answerRow['isCorrect']);
        answer.explanationController.text = _firstNonEmpty([
          _text(answerRow['explanation']),
          _text(answerRow['correctExplanation']),
        ]);
        entry.answers.add(answer);
      }
      if (entry.answers.isEmpty) entry.ensureAnswerCount(2);
      questions.add(entry);
    }
    _replaceQuizQuestions(
      questions.isEmpty ? [QuizQuestionBlockEntry()] : questions,
    );
  }

  void _hydrateTocItem(Map<String, Object?> item) {
    _setEntryId(_tocBlock, preferred: _text(item['id']));
    final data = _map(item['tocData']);
    final styles = _map(data['linkListStyle']);
    _tocBlock.level1Style = _text(styles['level1']).isEmpty
        ? 'none'
        : _text(styles['level1']);
    _tocBlock.level2Style = _text(styles['level2']).isEmpty
        ? 'none'
        : _text(styles['level2']);
    _tocBlock.level3Style = _text(styles['level3']).isEmpty
        ? 'none'
        : _text(styles['level3']);
    final show = _map(data['showInText']);
    _tocBlock.showLevel1InText = _bool(show['level1']);
    _tocBlock.showLevel2InText = _bool(show['level2']);
    _tocBlock.showLevel3InText = _bool(show['level3']);
    for (final entry in _tocBlock.items) {
      entry.dispose();
    }
    _tocBlock.items.clear();
    for (final row in _mapList(data['items'])) {
      final entry = TocItemEntry();
      _setEntryId(entry, preferred: _text(row['id']));
      entry.titleController.text = _text(row['title']);
      entry.parentLinkController.text = _text(row['parentId']);
      entry.imageDescriptionController.text = _text(row['imageDescription']);
      entry.imageUrl = _nullableText(row['image']);
      adminSetQuillHtml(entry.contentController, _text(row['content']));
      _tocBlock.items.add(entry);
    }
    if (_tocBlock.items.isEmpty) _tocBlock.items.add(TocItemEntry());
  }

  void _hydrateRecipeItem(Map<String, Object?> item) {
    _setEntryId(_recipeBlock, preferred: _text(item['id']));
    final data = _map(item['recipeData']);
    _recipeBlock.prepTimeController.text = _text(data['prepTime']);
    _recipeBlock.cookTimeController.text = _text(data['cookTime']);
    _recipeBlock.servingController.text = _text(data['serving']);
    _recipeBlock.difficulty = _normalizeRecipeDifficulty(
      _text(data['difficulty']),
    );
    for (final entry in _recipeBlock.ingredients) {
      entry.dispose();
    }
    _recipeBlock.ingredients
      ..clear()
      ..addAll([
        for (final row in _mapList(data['ingredients']))
          RecipeIngredientEntry()..textController.text = _text(row['text']),
      ]);
    if (_recipeBlock.ingredients.isEmpty) {
      _recipeBlock.ingredients.add(RecipeIngredientEntry());
    }
    for (final entry in _recipeBlock.nutrition) {
      entry.dispose();
    }
    _recipeBlock.nutrition
      ..clear()
      ..addAll([
        for (final row in _mapList(data['nutrition']))
          RecipeNutritionEntry()
            ..labelController.text = _text(row['label'])
            ..valueController.text = _text(row['value']),
      ]);
    if (_recipeBlock.nutrition.isEmpty) {
      _recipeBlock.nutrition.add(RecipeNutritionEntry());
    }
    for (final entry in _recipeBlock.directions) {
      entry.dispose();
    }
    _recipeBlock.directions.clear();
    for (final row in _mapList(data['directions'])) {
      final entry = RecipeDirectionEntry();
      _setEntryId(entry, preferred: _text(row['id']));
      entry.titleController.text = _text(row['title']);
      entry.imageDescriptionController.text = _text(row['imageDescription']);
      entry.imageUrl = _nullableText(row['image']);
      adminSetQuillHtml(entry.contentController, _text(row['content']));
      _recipeBlock.directions.add(entry);
    }
    if (_recipeBlock.directions.isEmpty) {
      _recipeBlock.directions.add(RecipeDirectionEntry());
    }
  }

  void _hydrateRecipeVideoBlockFromRecipeItem(Map<String, Object?> item) {
    final data = _map(item['recipeData']);
    final title = _firstNonEmpty([
      _text(data['videoTitle']),
      _text(data['videoName']),
      _text(data['videoHeading']),
    ]);
    final description = _firstNonEmpty([
      _text(data['videoDescriptionHtml']),
      _text(data['videoDescription']),
    ]);
    final videoUrl = _firstNonEmpty([
      _text(data['videoUrl']),
      _text(data['videoURL']),
      _text(data['youtubeUrl']),
      _text(data['youtubeURL']),
      _text(item['mediaUrl']),
    ]);
    if (title.isEmpty && description.isEmpty && videoUrl.isEmpty) return;

    if (title.isNotEmpty) {
      _recipeVideoBlock.titleController.text = title;
    }
    if (description.isNotEmpty) {
      adminSetQuillHtml(_recipeVideoBlock.descriptionController, description);
    }
    if (videoUrl.isNotEmpty) {
      _recipeVideoBlock.mediaUrl = videoUrl;
    }
  }

  void _hydrateEventItem(Map<String, Object?> item) {
    _setEntryId(_eventBlock, preferred: _text(item['id']));
    final data = _map(item['eventData']);
    _eventBlock.startDateTimeController.text = _text(data['startDateTime']);
    _eventBlock.endDateTimeController.text = _text(data['endDateTime']);
    _eventBlock.organizerController.text = _text(data['organizer']);
    _eventBlock.venueNameController.text = _text(data['venueName']);
    _eventBlock.addressController.text = _text(data['address']);
    _eventBlock.latitudeController.text = _text(data['latitude']);
    _eventBlock.longitudeController.text = _text(data['longitude']);
    _eventBlock.registrationType = _text(data['registrationType']).isEmpty
        ? 'none'
        : _text(data['registrationType']);
    _eventBlock.ticketUrlController.text = _text(data['ticketUrl']);
    _eventBlock.ticketPriceController.text = _text(data['ticketPrice']);
    _eventBlock.capacityController.text = _text(data['capacity']);
    _eventBlock.scheduleTitleController.text = _text(data['scheduleTitle']);
    _eventBlock.highlightsTitleController.text = _text(data['highlightsTitle']);
    _eventBlock.speakersTitleController.text = _text(data['speakersTitle']);
    for (final entry in _eventBlock.schedule) {
      entry.dispose();
    }
    _eventBlock.schedule.clear();
    for (final row in _mapList(data['schedule'])) {
      final entry = EventScheduleEntry();
      _setEntryId(entry, preferred: _text(row['id']));
      entry.dateController.text = _text(row['date']);
      entry.timeController.text = _text(row['time']);
      entry.titleController.text = _text(row['title']);
      entry.descriptionController.text = _text(row['description']);
      entry.imageDescriptionController.text = _text(row['imageDescription']);
      entry.imageUrl = _nullableText(row['image']);
      _eventBlock.schedule.add(entry);
    }
    if (_eventBlock.schedule.isEmpty) {
      _eventBlock.schedule.add(EventScheduleEntry());
    }
    for (final entry in _eventBlock.highlights) {
      entry.dispose();
    }
    _eventBlock.highlights
      ..clear()
      ..addAll([
        for (final row in _mapList(data['highlights']))
          EventHighlightEntry()
            ..labelController.text = _text(row['label'])
            ..valueController.text = _text(row['value']),
      ]);
    if (_eventBlock.highlights.isEmpty) {
      _eventBlock.highlights.add(EventHighlightEntry());
    }
    for (final entry in _eventBlock.speakers) {
      entry.dispose();
    }
    _eventBlock.speakers.clear();
    for (final row in _mapList(data['speakers'])) {
      final entry = EventSpeakerEntry();
      _setEntryId(entry, preferred: _text(row['id']));
      entry.nameController.text = _text(row['name']);
      entry.roleController.text = _text(row['role']);
      entry.imageDescriptionController.text = _text(row['imageDescription']);
      entry.imageUrl = _nullableText(row['image']);
      adminSetQuillHtml(entry.bioController, _text(row['bio']));
      _eventBlock.speakers.add(entry);
    }
    if (_eventBlock.speakers.isEmpty) {
      _eventBlock.speakers.add(EventSpeakerEntry());
    }
  }

  Future<void> _handleSave(String status) async {
    if (_saving) return;
    final validationError = _validationError();
    if (validationError != null) {
      _showEditorMessage(validationError, isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (_pinToTop) {
        final pinnedCount = await widget.repository.countPinnedPosts(
          excludingPostId: _editingPostId,
        );
        if (pinnedCount >= 2) {
          throw const AdminNewsException('En fazla 2 haber sabitlenebilir.');
        }
      }
      final saved = await widget.repository.saveEditorPost(
        postId: _editingPostId,
        payload: AdminNewsEditorSavePayload(values: _buildPostValues(status)),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (_editingPostId == null || _editingPostId!.isEmpty) {
          _resetEditorState();
          _applyBootstrapDefaults();
        } else {
          _editingPostId = saved.id;
          _loadedCardData = saved.cardData;
          _loadedPublisherId = saved.publisherId;
        }
      });
      _showEditorMessage(
        status == 'draft'
            ? context.t('newsAdd.savedDraft')
            : context.t('newsAdd.savedPublished'),
      );
      widget.onBackToNews?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showEditorMessage(error.toString(), isError: true);
    }
  }

  String? _validationError() {
    if (_titleController.text.trim().isEmpty) {
      return context.t('newsAdd.errorTitleRequired');
    }
    if (_summaryController.text.trim().isEmpty) {
      return context.t('newsAdd.errorSummaryRequired');
    }
    if (_selectedCategory.trim().isEmpty) {
      return context.t('newsAdd.errorCategoryRequired');
    }
    return null;
  }

  Future<void> _handleClearEditor() async {
    if (_saving) return;
    if (_hasEditorInputData) {
      final confirmed = await showAppConfirmationDialog(
        context,
        title: context.t('newsAdd.clearConfirmTitle'),
        message: context.t('newsAdd.clearConfirmMessage'),
        cancelLabel: context.t('common.cancel'),
        confirmLabel: context.t('newsAdd.clear'),
        danger: true,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _resetEditorState();
      _applyBootstrapDefaults();
    });
    _showEditorMessage(context.t('newsAdd.cleared'));
  }

  bool get _hasEditorInputData {
    final controllers = [
      _titleController,
      _summaryController,
      _seoTitleController,
      _slugController,
      _metaDescriptionController,
      _keywordsController,
      _publishAtController,
      _quizEndDateController,
      _coverAltController,
      _focusKeywordsController,
    ];
    if (controllers.any((controller) => controller.text.trim().isNotEmpty)) {
      return true;
    }
    if ((_coverImageUrl?.trim().isNotEmpty ?? false) ||
        _keywords.isNotEmpty ||
        _faqDataForStorage().isNotEmpty) {
      return true;
    }
    final hasAnswerSettingsChanged =
        (_activeTab == NewsAddFormatTab.quiz ||
            _activeTab == NewsAddFormatTab.poll) &&
        (_pollAllowMulti || !_pollShowResults);
    if (_mansetSlider ||
        _pinToTop ||
        _factCheck ||
        hasAnswerSettingsChanged ||
        _schemaType != _defaultSchemaTypeForActiveTab) {
      return true;
    }
    final subCategory = _subCategory?.trim() ?? '';
    final hasManualSubCategory =
        subCategory.isNotEmpty && !_isCurrentTabDefaultSubCategory(subCategory);
    if (_languageCode != _resetDefaultLanguageCode ||
        _mainCategory.trim() != _resetDefaultMainCategory.trim() ||
        hasManualSubCategory ||
        (_thirdCategory?.trim().isNotEmpty ?? false)) {
      return true;
    }
    return _hasActiveTabContentInputData;
  }

  String get _defaultSchemaTypeForActiveTab {
    return _defaultSchemaTypeForTab(_activeTab);
  }

  String _defaultSchemaTypeForTab(NewsAddFormatTab tab) {
    return switch (tab) {
      NewsAddFormatTab.quiz => 'Quiz',
      NewsAddFormatTab.video => 'VideoObject',
      NewsAddFormatTab.recipe => 'Recipe',
      NewsAddFormatTab.event => 'Event',
      _ => 'NewsArticle',
    };
  }

  String get _resetDefaultLanguageCode {
    if (_bootstrap.languages.any((item) => item.code == 'tr')) return 'tr';
    return _bootstrap.languages.isEmpty
        ? 'tr'
        : _bootstrap.languages.first.code;
  }

  String get _resetDefaultMainCategory {
    final languageCode = _resetDefaultLanguageCode;
    if (languageCode == 'tr') return 'Niğde';
    final roots = _rootCategoriesForLanguage(languageCode);
    return roots.isEmpty ? 'Niğde' : roots.first.label;
  }

  bool _hasMeaningfulEditorValue(Object? value, {String? key}) {
    if (key != null && _editorDirtyIgnoredKeys.contains(key)) return false;
    if (value == null) return false;
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return false;
      return !_isDefaultEditorValue(key, text);
    }
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is Map) {
      for (final entry in value.entries) {
        if (_hasMeaningfulEditorValue(entry.value, key: entry.key.toString())) {
          return true;
        }
      }
      return false;
    }
    if (value is Iterable) {
      for (final item in value) {
        if (_hasMeaningfulEditorValue(item)) return true;
      }
      return false;
    }
    return false;
  }

  bool _isDefaultEditorValue(String? key, String value) {
    return switch (key) {
      'layout' => value == 'list',
      'level1' || 'level2' || 'level3' => value == 'none',
      'questionSorting' => value == 'asc',
      'registrationType' => value == 'none',
      'title' => value == 'Table of Contents',
      _ => false,
    };
  }

  bool get _hasActiveTabContentInputData {
    return switch (_activeTab) {
      NewsAddFormatTab.poll => _pollQuestions.any(_hasPollQuestionInputData),
      NewsAddFormatTab.contents => _hasTocInputData,
      NewsAddFormatTab.recipe => _hasRecipeInputData,
      NewsAddFormatTab.event => _hasEventInputData,
      _ => _itemsForStorage().any((item) => _hasMeaningfulEditorValue(item)),
    };
  }

  bool _hasPollQuestionInputData(PollQuestionBlockEntry block) {
    if (_hasTextInput(block.titleController) ||
        _hasTextInput(block.sourceController) ||
        _hasRichTextInput(block.descriptionController) ||
        _hasStringInput(block.imageUrl) ||
        block.showOnHomepage) {
      return true;
    }
    return block.answers.any((answer) {
      return _hasTextInput(answer.answerController) ||
          _hasStringInput(answer.imageUrl) ||
          _int(answer.votesController.text) > 0;
    });
  }

  bool get _hasTocInputData {
    if (_tocBlock.level1Style != 'none' ||
        _tocBlock.level2Style != 'none' ||
        _tocBlock.level3Style != 'none' ||
        _tocBlock.showLevel1InText ||
        _tocBlock.showLevel2InText ||
        _tocBlock.showLevel3InText) {
      return true;
    }
    return _tocBlock.items.any((item) {
      return _hasTextInput(item.titleController) ||
          _hasTextInput(item.parentLinkController) ||
          _hasStringInput(item.imageUrl) ||
          _hasTextInput(item.imageDescriptionController) ||
          _hasRichTextInput(item.contentController);
    });
  }

  bool get _hasRecipeInputData {
    if (_hasTextInput(_recipeBlock.prepTimeController) ||
        _hasTextInput(_recipeBlock.cookTimeController) ||
        _hasTextInput(_recipeBlock.servingController) ||
        _hasStringInput(_recipeBlock.difficulty)) {
      return true;
    }
    if (_recipeBlock.ingredients.any(
      (item) => _hasTextInput(item.textController),
    )) {
      return true;
    }
    if (_recipeBlock.nutrition.any(
      (item) =>
          _hasTextInput(item.labelController) ||
          _hasTextInput(item.valueController),
    )) {
      return true;
    }
    if (_recipeBlock.directions.any((item) {
      return _hasTextInput(item.titleController) ||
          _hasStringInput(item.imageUrl) ||
          _hasTextInput(item.imageDescriptionController) ||
          _hasRichTextInput(item.contentController);
    })) {
      return true;
    }
    return _hasMeaningfulEditorValue(
      _serializeVideoBlock(_recipeVideoBlock, 2),
    );
  }

  bool get _hasEventInputData {
    if (_hasTextInput(_eventBlock.startDateTimeController) ||
        _hasTextInput(_eventBlock.endDateTimeController) ||
        _hasTextInput(_eventBlock.organizerController) ||
        _hasTextInput(_eventBlock.venueNameController) ||
        _hasTextInput(_eventBlock.addressController) ||
        _hasTextInput(_eventBlock.latitudeController) ||
        _hasTextInput(_eventBlock.longitudeController) ||
        _hasTextInput(_eventBlock.ticketUrlController) ||
        _hasTextInput(_eventBlock.ticketPriceController) ||
        _hasTextInput(_eventBlock.capacityController) ||
        _hasTextInput(_eventBlock.scheduleTitleController) ||
        _hasTextInput(_eventBlock.highlightsTitleController) ||
        _hasTextInput(_eventBlock.speakersTitleController) ||
        _eventBlock.registrationType != 'none') {
      return true;
    }
    if (_eventBlock.schedule.any((item) {
      return _hasTextInput(item.dateController) ||
          _hasTextInput(item.timeController) ||
          _hasTextInput(item.titleController) ||
          _hasTextInput(item.descriptionController) ||
          _hasStringInput(item.imageUrl) ||
          _hasTextInput(item.imageDescriptionController);
    })) {
      return true;
    }
    if (_eventBlock.highlights.any((item) {
      return _hasTextInput(item.labelController) ||
          _hasTextInput(item.valueController);
    })) {
      return true;
    }
    if (_eventBlock.speakers.any((item) {
      return _hasTextInput(item.nameController) ||
          _hasTextInput(item.roleController) ||
          _hasStringInput(item.imageUrl) ||
          _hasTextInput(item.imageDescriptionController) ||
          _hasRichTextInput(item.bioController);
    })) {
      return true;
    }
    return _serializeContentBlocks(
      _eventContentBlocks,
      _Sort.asc,
      offset: 1,
    ).any(_hasMeaningfulEditorValue);
  }

  bool _hasTextInput(TextEditingController controller) {
    return controller.text.trim().isNotEmpty;
  }

  bool _hasRichTextInput(quill.QuillController controller) {
    return controller.document.toPlainText().trim().isNotEmpty;
  }

  bool _hasStringInput(String? value) {
    return value?.trim().isNotEmpty ?? false;
  }

  Map<String, Object?> _buildPostValues(String status) {
    final items = _itemsForStorage();
    final faqData = _faqDataForStorage();
    final itemsWithFaq = [
      ...items,
      if (faqData.isNotEmpty)
        {
          'id': 'faq-schema-block',
          'type': 'faq',
          'title': 'FAQ',
          'description': '',
          'faqData': faqData,
        },
    ];
    final publishAt = status == 'published'
        ? (_parseEditorDate(_publishAtController.text) ?? DateTime.now())
              .toUtc()
              .toIso8601String()
        : null;
    return {
      'title': _titleController.text.trim(),
      'summary': _summaryController.text.trim(),
      'category': _selectedCategory,
      'thumbnail_url': _coverImageUrl?.trim() ?? '',
      'thumbnail_alt': _coverAltController.text.trim(),
      'seo_title': _seoTitleController.text.trim(),
      'seo_description': _metaDescriptionController.text.trim(),
      'keywords': _keywords.join(', '),
      'slug': _slugController.text.trim().isEmpty
          ? _slugify(_titleController.text)
          : _slugController.text.trim(),
      'fact_checked': _factCheck,
      'schema_type': _schemaType,
      'faq_data': faqData,
      'items': itemsWithFaq,
      'card_data': _buildCardData(items),
      'published_at': publishAt,
      'status': status,
      'language_code': _languageCode,
      'publisher_id': (_loadedPublisherId?.trim().isNotEmpty ?? false)
          ? _loadedPublisherId
          : widget.session.user.id,
      'is_pinned': _pinToTop,
      'show_in_manset': _mansetSlider,
      'type': _postTypeForActiveTab,
    };
  }

  String get _postTypeForActiveTab {
    return switch (_activeTab) {
      NewsAddFormatTab.contents => 'contents',
      NewsAddFormatTab.article => 'article',
      NewsAddFormatTab.quiz => 'quiz',
      NewsAddFormatTab.poll => 'poll',
      NewsAddFormatTab.video => 'video',
      NewsAddFormatTab.recipe => 'recipe',
      NewsAddFormatTab.event => 'event',
    };
  }

  List<Map<String, Object?>> _itemsForStorage() {
    final items = switch (_activeTab) {
      NewsAddFormatTab.article => _serializeContentBlocks(
        _articleBlocks,
        _articleSort,
      ),
      NewsAddFormatTab.video => _serializeContentBlocks(
        _videoBlocks,
        _videoSort,
      ),
      NewsAddFormatTab.poll => _serializePollBlocks(),
      NewsAddFormatTab.quiz => [_serializeQuizItem()],
      NewsAddFormatTab.contents => [_serializeTocItem()],
      NewsAddFormatTab.recipe => [
        _serializeRecipeItem(),
        _serializeVideoBlock(_recipeVideoBlock, 2),
      ],
      NewsAddFormatTab.event => [
        _serializeEventItem(),
        ..._serializeContentBlocks(_eventContentBlocks, _Sort.asc, offset: 1),
      ],
    };
    return [
      for (var index = 0; index < items.length; index++)
        {...items[index], 'orderNumber': index + 1},
    ];
  }

  List<Map<String, Object?>> _serializeContentBlocks(
    List<Object> blocks,
    _Sort sort, {
    int offset = 0,
  }) {
    final ordered = switch (sort) {
      _Sort.asc || _Sort.hide => blocks,
      _Sort.desc => blocks.reversed.toList(),
    };
    return [
      for (var index = 0; index < ordered.length; index++)
        if (_serializeContentBlock(ordered[index], index + 1 + offset) != null)
          _serializeContentBlock(ordered[index], index + 1 + offset)!,
    ];
  }

  Map<String, Object?>? _serializeContentBlock(Object block, int orderNumber) {
    if (block is ArticleTextBlockEntry) {
      return _baseItem(
        block,
        'text',
        orderNumber,
        title: block.titleController.text,
        description: adminQuillHtml(block.editorController),
        source: block.sourceController.text,
      );
    }
    if (block is ArticleImageBlockEntry) {
      return {
        ..._baseItem(
          block,
          'image',
          orderNumber,
          title: block.titleController.text,
          description: adminQuillHtml(block.captionController),
          source: block.sourceController.text,
          showOnHomepage: block.showOnHomepage,
        ),
        'mediaUrl': block.imageUrl ?? '',
        'altText': block.altTextController.text.trim(),
      };
    }
    if (block is ArticleSliderImageBlockEntry) {
      return {
        ..._baseItem(
          block,
          'slider',
          orderNumber,
          title: block.titleController.text,
          description: adminQuillHtml(block.captionController),
          source: block.sourceController.text,
          showOnHomepage: block.showOnHomepage,
        ),
        'mediaUrls': block.imageUrls,
      };
    }
    if (block is ArticleVideoBlockEntry) {
      return _serializeVideoBlock(block, orderNumber);
    }
    if (block is ArticleAudioBlockEntry) {
      return {
        ..._baseItem(
          block,
          'audio',
          orderNumber,
          title: block.titleController.text,
          description: adminQuillHtml(block.descriptionController),
          source: block.sourceController.text,
          showOnHomepage: block.showOnHomepage,
        ),
        'mediaUrl': block.mediaUrl ?? '',
      };
    }
    if (block is ArticleFileBlockEntry) {
      return {
        ..._baseItem(
          block,
          'file',
          orderNumber,
          title: block.titleController.text,
          description: adminQuillHtml(block.descriptionController),
          source: block.sourceController.text,
          showOnHomepage: block.showOnHomepage,
        ),
        'mediaUrl': block.mediaUrl ?? '',
      };
    }
    if (block is ArticleSocialBlockEntry) {
      return {
        ..._baseItem(
          block,
          'social',
          orderNumber,
          title: block.titleController.text,
          description: adminQuillHtml(block.contentController),
          source: block.sourceController.text,
          showOnHomepage: block.showOnHomepage,
        ),
        'mediaUrl': block.embedController.text.trim(),
      };
    }
    if (block is ArticleFlipcardBlockEntry) {
      return {
        ..._baseItem(
          block,
          'flipcard',
          orderNumber,
          title: block.titleController.text,
          description: adminQuillHtml(block.descriptionController),
          source: block.sourceController.text,
          showOnHomepage: block.showOnHomepage,
        ),
        'flipData': {
          'frontImage': block.frontImageUrl ?? '',
          'frontTitle': block.frontTitleController.text.trim(),
          'frontDescription': adminQuillHtml(block.frontDescriptionController),
          'frontLink': block.frontLinkController.text.trim(),
          'backImage': block.backImageUrl ?? '',
          'backTitle': block.backTitleController.text.trim(),
          'backDescription': adminQuillHtml(block.backDescriptionController),
          'backLink': block.backLinkController.text.trim(),
        },
      };
    }
    if (block is ArticleBeforeAfterBlockEntry) {
      return {
        ..._baseItem(
          block,
          'beforeafter',
          orderNumber,
          title: block.titleController.text,
          description: adminQuillHtml(block.descriptionController),
          source: block.sourceController.text,
          showOnHomepage: block.showOnHomepage,
        ),
        'beforeAfterData': {
          'beforeImage': block.beforeImageUrl ?? '',
          'afterImage': block.afterImageUrl ?? '',
          'beforeLabel': block.beforeLabelController.text.trim(),
          'afterLabel': block.afterLabelController.text.trim(),
        },
      };
    }
    if (block is PollQuestionBlockEntry) {
      return _serializePollBlock(block, orderNumber);
    }
    if (block is ArticleVsBlockEntry) {
      return {
        ..._baseItem(
          block,
          'vs',
          orderNumber,
          title: block.titleController.text,
          description: adminQuillHtml(block.descriptionController),
          source: block.sourceController.text,
          showOnHomepage: block.showOnHomepage,
        ),
        'mediaUrl': block.mainImageUrl ?? '',
        'options': [
          for (final option in block.options.take(2))
            {
              'id': _entryId(option),
              'text': option.textController.text.trim(),
              'image': option.imageUrl ?? '',
              'votes': _int(option.votesController.text),
            },
        ],
      };
    }
    if (block is ArticleReviewBlockEntry) {
      return {
        ..._baseItem(
          block,
          'review',
          orderNumber,
          title: block.productNameController.text,
          description: '',
          source: block.sourceController.text,
          showOnHomepage: block.showOnHomepage,
        ),
        'reviewData': {
          'productName': block.productNameController.text.trim(),
          'productImage': block.imageUrl ?? '',
          'score': block.score,
          'pros': [for (final item in block.pros) item.controller.text.trim()],
          'cons': [for (final item in block.cons) item.controller.text.trim()],
          'breakdown': [
            for (final item in block.criteria)
              {'label': item.labelController.text.trim(), 'score': item.score},
          ],
          'verdict': adminQuillHtml(block.verdictController),
        },
      };
    }
    if (block is ArticleQuoteBlockEntry) {
      return _baseItem(
        block,
        'quote',
        orderNumber,
        title: block.authorController.text,
        description: adminQuillHtml(block.quoteController),
        source: block.sourceController.text,
        showOnHomepage: block.showOnHomepage,
      );
    }
    if (block is ArticleIframeBlockEntry) {
      return {
        ..._baseItem(
          block,
          'iframe',
          orderNumber,
          title: block.titleController.text,
          description: '',
          source: block.sourceController.text,
          showOnHomepage: block.showOnHomepage,
        ),
        'mediaUrl': block.embedController.text.trim(),
      };
    }
    return null;
  }

  Map<String, Object?> _serializeVideoBlock(
    ArticleVideoBlockEntry block,
    int orderNumber,
  ) {
    return {
      ..._baseItem(
        block,
        'video',
        orderNumber,
        title: block.titleController.text,
        description: adminQuillHtml(block.descriptionController),
        source: block.sourceController.text,
        showOnHomepage: block.showOnHomepage,
      ),
      'mediaUrl': block.mediaUrl ?? '',
    };
  }

  List<Map<String, Object?>> _serializePollBlocks() {
    final ordered = switch (_pollSort) {
      NewsAddQuizSort.asc || NewsAddQuizSort.hide => _pollQuestions,
      NewsAddQuizSort.desc => _pollQuestions.reversed.toList(),
    };
    return [
      for (var index = 0; index < ordered.length; index++)
        _serializePollBlock(ordered[index], index + 1),
    ];
  }

  Map<String, Object?> _serializePollBlock(
    PollQuestionBlockEntry block,
    int orderNumber,
  ) {
    return {
      ..._baseItem(
        block,
        'poll',
        orderNumber,
        title: block.titleController.text,
        description: adminQuillHtml(block.descriptionController),
        source: block.sourceController.text,
        showOnHomepage: block.showOnHomepage,
      ),
      'mediaUrl': block.imageUrl ?? '',
      'isImagePoll': block.layout != PollQuestionAnswerLayout.list,
      'pollColumns': block.layout == PollQuestionAnswerLayout.grid3 ? 3 : 2,
      'options': [
        for (final answer in block.answers)
          {
            'id': _entryId(answer),
            'text': answer.answerController.text.trim(),
            'image': answer.imageUrl ?? '',
            'votes': _int(answer.votesController.text),
          },
      ],
    };
  }

  Map<String, Object?> _serializeQuizItem() {
    return {
      ..._baseItem(
        _quizQuestions,
        'quiz',
        1,
        title: _titleController.text,
        description: _summaryController.text,
      ),
      'quizData': {
        'quizType': _quizSubTab.name,
        'results': [
          for (final result in _quizResults) _serializeQuizResult(result),
        ],
        'questions': [
          for (final question in _quizQuestions)
            {
              'id': _entryId(question),
              'title': question.titleController.text.trim(),
              'image': question.imageUrl ?? '',
              'description': adminQuillHtml(question.descriptionController),
              'layout': _quizLayoutText(question.layout),
              'answers': [
                for (final answer in question.answers)
                  _serializeQuizAnswer(answer),
              ],
            },
        ],
        'questionSorting': _quizSortText(_quizSort),
        'allowMultiple': _pollAllowMulti,
        'showResults': _pollShowResults,
        'endDate': _quizEndDateController.text.trim(),
      },
    };
  }

  Map<String, Object?> _serializeQuizResult(QuizResultBlockEntry result) {
    final row = <String, Object?>{
      'id': _entryId(result),
      'title': result.titleController.text.trim(),
      'image': result.imageUrl ?? '',
      'description': adminQuillHtml(result.descriptionController),
    };
    final minScore = _optionalInt(result.minScoreController.text);
    final maxScore = _optionalInt(result.maxScoreController.text);
    if (minScore != null) row['minScore'] = minScore;
    if (maxScore != null) row['maxScore'] = maxScore;
    return row;
  }

  Map<String, Object?> _serializeQuizAnswer(QuizQuestionAnswerEntry answer) {
    final row = <String, Object?>{
      'id': _entryId(answer),
      'text': answer.answerController.text.trim(),
      'image': answer.imageUrl ?? '',
      'resultId': answer.resultId ?? '',
      'isCorrect': answer.isCorrect,
    };
    final explanation = answer.explanationController.text.trim();
    if (explanation.isNotEmpty) row['explanation'] = explanation;
    return row;
  }

  Map<String, Object?> _serializeTocItem() {
    return {
      ..._baseItem(
        _tocBlock,
        'toc',
        1,
        title: 'Table of Contents',
        description: '',
      ),
      'tocData': {
        'linkListStyle': {
          'level1': _tocBlock.level1Style,
          'level2': _tocBlock.level2Style,
          'level3': _tocBlock.level3Style,
        },
        'showInText': {
          'level1': _tocBlock.showLevel1InText,
          'level2': _tocBlock.showLevel2InText,
          'level3': _tocBlock.showLevel3InText,
        },
        'items': [
          for (var index = 0; index < _tocBlock.items.length; index++)
            {
              'id': _entryId(_tocBlock.items[index]),
              'title': _tocBlock.items[index].titleController.text.trim(),
              'parentId': _tocBlock.items[index].parentLinkController.text
                  .trim(),
              'image': _tocBlock.items[index].imageUrl ?? '',
              'imageDescription': _tocBlock
                  .items[index]
                  .imageDescriptionController
                  .text
                  .trim(),
              'content': adminQuillHtml(
                _tocBlock.items[index].contentController,
              ),
              'orderNumber': index + 1,
            },
        ],
      },
    };
  }

  Map<String, Object?> _serializeRecipeItem() {
    return {
      ..._baseItem(
        _recipeBlock,
        'recipe',
        1,
        title: _titleController.text,
        description: _summaryController.text,
      ),
      'recipeData': {
        'prepTime': _recipeBlock.prepTimeController.text.trim(),
        'cookTime': _recipeBlock.cookTimeController.text.trim(),
        'serving': _recipeBlock.servingController.text.trim(),
        'difficulty': _recipeBlock.difficulty,
        'ingredients': [
          for (final item in _recipeBlock.ingredients)
            {'text': item.textController.text.trim()},
        ],
        'nutrition': [
          for (final item in _recipeBlock.nutrition)
            {
              'label': item.labelController.text.trim(),
              'value': item.valueController.text.trim(),
            },
        ],
        'directions': [
          for (var index = 0; index < _recipeBlock.directions.length; index++)
            {
              'id': _entryId(_recipeBlock.directions[index]),
              'title': _recipeBlock.directions[index].titleController.text
                  .trim(),
              'content': adminQuillHtml(
                _recipeBlock.directions[index].contentController,
              ),
              'image': _recipeBlock.directions[index].imageUrl ?? '',
              'imageDescription': _recipeBlock
                  .directions[index]
                  .imageDescriptionController
                  .text
                  .trim(),
              'orderNumber': index + 1,
            },
        ],
      },
    };
  }

  Map<String, Object?> _serializeEventItem() {
    return {
      ..._baseItem(
        _eventBlock,
        'event',
        1,
        title: _titleController.text,
        description: _summaryController.text,
      ),
      'eventData': {
        'startDateTime': _eventBlock.startDateTimeController.text.trim(),
        'endDateTime': _eventBlock.endDateTimeController.text.trim(),
        'organizer': _eventBlock.organizerController.text.trim(),
        'venueName': _eventBlock.venueNameController.text.trim(),
        'address': _eventBlock.addressController.text.trim(),
        'latitude': _eventBlock.latitudeController.text.trim(),
        'longitude': _eventBlock.longitudeController.text.trim(),
        'registrationType': _eventBlock.registrationType,
        'ticketUrl': _eventBlock.ticketUrlController.text.trim(),
        'ticketPrice': _eventBlock.ticketPriceController.text.trim(),
        'capacity': _eventBlock.capacityController.text.trim(),
        'scheduleTitle': _eventBlock.scheduleTitleController.text.trim(),
        'highlightsTitle': _eventBlock.highlightsTitleController.text.trim(),
        'speakersTitle': _eventBlock.speakersTitleController.text.trim(),
        'schedule': [
          for (final item in _eventBlock.schedule)
            {
              'id': _entryId(item),
              'date': item.dateController.text.trim(),
              'time': item.timeController.text.trim(),
              'title': item.titleController.text.trim(),
              'description': item.descriptionController.text.trim(),
              'image': item.imageUrl ?? '',
              'imageDescription': item.imageDescriptionController.text.trim(),
            },
        ],
        'highlights': [
          for (final item in _eventBlock.highlights)
            {
              'label': item.labelController.text.trim(),
              'value': item.valueController.text.trim(),
            },
        ],
        'speakers': [
          for (final item in _eventBlock.speakers)
            {
              'id': _entryId(item),
              'name': item.nameController.text.trim(),
              'role': item.roleController.text.trim(),
              'bio': adminQuillHtml(item.bioController),
              'image': item.imageUrl ?? '',
              'imageDescription': item.imageDescriptionController.text.trim(),
            },
        ],
      },
    };
  }

  Map<String, Object?> _baseItem(
    Object owner,
    String type,
    int orderNumber, {
    required String title,
    required String description,
    String source = '',
    bool showOnHomepage = false,
  }) {
    return {
      'id': _entryId(owner),
      'type': type,
      'title': title.trim(),
      'description': description,
      'source': source.trim(),
      'showOnHomepage': showOnHomepage,
      'orderNumber': orderNumber,
    };
  }

  List<Map<String, Object?>> _faqDataForStorage() {
    return [
      for (final entry in _faqEntries)
        if (entry.question.text.trim().isNotEmpty ||
            entry.answer.text.trim().isNotEmpty)
          {'q': entry.question.text.trim(), 'a': entry.answer.text.trim()},
    ];
  }

  Map<String, Object?> _buildCardData(List<Map<String, Object?>> items) {
    final cardData = Map<String, Object?>.from(_loadedCardData);
    for (final key in [
      'type',
      'mediaUrl',
      'mediaList',
      'thumbnail',
      'thumbnailAlt',
      'flipData',
      'beforeAfterData',
      'reviewData',
      'options',
      'isImagePoll',
      'pollColumns',
      'totalVotes',
      'blockTitle',
      'blockDescription',
      'paragraphData',
    ]) {
      cardData.remove(key);
    }
    Map<String, Object?>? featured = items
        .where((item) => item['showOnHomepage'] == true)
        .cast<Map<String, Object?>?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (featured == null && _activeTab == NewsAddFormatTab.video) {
      featured = items
          .where((item) => _text(item['type']) == 'video')
          .cast<Map<String, Object?>?>()
          .firstWhere((item) => item != null, orElse: () => null);
    }
    if (featured == null && _activeTab == NewsAddFormatTab.poll) {
      featured = items
          .where((item) => _text(item['type']) == 'poll')
          .cast<Map<String, Object?>?>()
          .firstWhere((item) => item != null, orElse: () => null);
    }
    if (featured == null && _activeTab == NewsAddFormatTab.article) {
      featured = items
          .where((item) => _text(item['type']) == 'quote')
          .cast<Map<String, Object?>?>()
          .firstWhere((item) => item != null, orElse: () => null);
    }
    if (featured == null) return cardData;
    final type = _text(featured['type']);
    cardData['type'] = switch (type) {
      'slider' => 'gallery',
      'social' || 'iframe' => 'embed',
      'flipcard' => 'flip_card',
      'beforeafter' => 'before_after',
      'quote' => 'paragraph',
      _ => type,
    };
    if (type == 'video' ||
        type == 'audio' ||
        type == 'social' ||
        type == 'iframe') {
      cardData['mediaUrl'] = _text(featured['mediaUrl']);
    } else if (type == 'slider') {
      cardData['mediaList'] = _stringList(featured['mediaUrls']);
    } else if (type == 'image') {
      cardData['thumbnail'] = _text(featured['mediaUrl']);
      cardData['thumbnailAlt'] = _text(featured['altText']);
    } else if (type == 'flipcard') {
      cardData['flipData'] = featured['flipData'];
    } else if (type == 'beforeafter') {
      cardData['beforeAfterData'] = featured['beforeAfterData'];
    } else if (type == 'review') {
      cardData['reviewData'] = featured['reviewData'];
    } else if (type == 'poll' || type == 'vs') {
      cardData['thumbnail'] = _text(featured['mediaUrl']);
      cardData['options'] = featured['options'];
      cardData['isImagePoll'] = featured['isImagePoll'];
      cardData['pollColumns'] = featured['pollColumns'];
      cardData['blockTitle'] = _text(featured['title']);
      cardData['blockDescription'] = _text(featured['description']);
    } else if (type == 'quote') {
      cardData['paragraphData'] = {
        'items': [_text(featured['description'])],
        'quoteAuthor': _text(featured['title']),
      };
    }
    return cardData;
  }

  String _entryId(Object owner) {
    final existing = _entryIds[owner];
    if (existing != null && existing.isNotEmpty) return existing;
    return _setEntryId(owner);
  }

  String _setEntryId(Object owner, {String? preferred}) {
    final value = (preferred?.trim().isNotEmpty ?? false)
        ? preferred!.trim()
        : 'flutter-${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';
    _entryIds[owner] = value;
    return value;
  }

  String _text(Object? value) => value?.toString() ?? '';

  String? _nullableText(Object? value) {
    final text = _text(value).trim();
    return text.isEmpty ? null : text;
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _optionalInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  String _scoreText(Object? value) {
    final number = _optionalInt(value);
    return number == null ? '' : number.toString();
  }

  bool _bool(Object? value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry(key.toString(), nestedValue),
      );
    }
    return const {};
  }

  List<Map<String, Object?>> _mapList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map)
          item.map((key, nestedValue) => MapEntry(key.toString(), nestedValue)),
    ];
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item != null && item.toString().trim().isNotEmpty)
          item.toString().trim(),
    ];
  }

  String _slugify(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return slug.length > 50 ? slug.substring(0, 50) : slug;
  }

  String _formatEditorDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  DateTime? _parseEditorDate(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;
    final match = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})\s+(\d{1,2}):(\d{2})$',
    ).firstMatch(raw);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
    );
  }

  NewsAddQuizSort _quizSortFromText(String value) {
    return switch (value) {
      'desc' => NewsAddQuizSort.desc,
      'hidden' || 'hide' => NewsAddQuizSort.hide,
      _ => NewsAddQuizSort.asc,
    };
  }

  String _quizSortText(NewsAddQuizSort value) {
    return switch (value) {
      NewsAddQuizSort.desc => 'desc',
      NewsAddQuizSort.hide => 'hidden',
      NewsAddQuizSort.asc => 'asc',
    };
  }

  QuizQuestionAnswerLayout _quizLayoutFromText(String value) {
    return switch (value) {
      'grid2' => QuizQuestionAnswerLayout.grid2,
      'grid3' => QuizQuestionAnswerLayout.grid3,
      _ => QuizQuestionAnswerLayout.list,
    };
  }

  String _quizLayoutText(QuizQuestionAnswerLayout value) {
    return switch (value) {
      QuizQuestionAnswerLayout.grid2 => 'grid2',
      QuizQuestionAnswerLayout.grid3 => 'grid3',
      QuizQuestionAnswerLayout.list => 'list',
    };
  }

  PollQuestionAnswerLayout _pollLayoutFromColumns(int columns, bool imagePoll) {
    if (!imagePoll) return PollQuestionAnswerLayout.list;
    return columns == 3
        ? PollQuestionAnswerLayout.grid3
        : PollQuestionAnswerLayout.grid2;
  }

  void _replaceReviewTexts(
    List<ArticleReviewTextEntry> target,
    List<String> values,
  ) {
    for (final item in target) {
      item.dispose();
    }
    target
      ..clear()
      ..addAll(
        values.isEmpty
            ? [ArticleReviewTextEntry()]
            : values.map(ArticleReviewTextEntry.new),
      );
  }

  void _replaceReviewCriteria(
    List<ArticleReviewCriterionEntry> target,
    List<Map<String, Object?>> values,
  ) {
    for (final item in target) {
      item.dispose();
    }
    target
      ..clear()
      ..addAll([
        for (final row in values)
          ArticleReviewCriterionEntry(
            label: _text(row['label']),
            score: _int(row['score']),
          ),
      ]);
    if (target.isEmpty) {
      target.add(ArticleReviewCriterionEntry(label: '', score: 80));
    }
  }

  void _showEditorMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.actionRed : AppColors.deepOcean,
      ),
    );
  }

  // ── Handlers ──────────────────────────────────────────────────────────────
  void _handleAddFaq() {
    setState(() {
      _faqEntries.add(_FaqEntry());
    });
  }

  void _handleRemoveFaq(_FaqEntry entry) {
    setState(() {
      entry.dispose();
      _faqEntries.remove(entry);
    });
  }

  void _handleKeywordSubmitted(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return;
    setState(() {
      if (!_keywords.contains(raw)) {
        _keywords.add(raw);
      }
      _focusKeywordsController.clear();
    });
  }

  void _handleRemoveKeyword(String value) {
    setState(() => _keywords.remove(value));
  }

  void _handleAddArticleTextBlock() {
    setState(() {
      _articleBlocks.add(ArticleTextBlockEntry());
    });
  }

  void _handleAddArticleImageBlock() {
    setState(() {
      _articleBlocks.add(ArticleImageBlockEntry());
    });
  }

  void _handleAddArticleSliderImageBlock() {
    setState(() {
      _articleBlocks.add(ArticleSliderImageBlockEntry());
    });
  }

  void _handleAddArticleVideoBlock() {
    setState(() {
      _articleBlocks.add(ArticleVideoBlockEntry());
    });
  }

  void _handleAddArticleAudioBlock() {
    setState(() {
      _articleBlocks.add(ArticleAudioBlockEntry());
    });
  }

  void _handleAddArticleFileBlock() {
    setState(() {
      _articleBlocks.add(ArticleFileBlockEntry());
    });
  }

  void _handleAddArticleSocialBlock() {
    setState(() {
      _articleBlocks.add(ArticleSocialBlockEntry());
    });
  }

  void _handleAddArticleFlipcardBlock() {
    setState(() {
      _articleBlocks.add(ArticleFlipcardBlockEntry());
    });
  }

  void _handleAddArticleBeforeAfterBlock() {
    setState(() {
      _articleBlocks.add(
        ArticleBeforeAfterBlockEntry(
          beforeLabel: context.t('newsAdd.beforeAfterBeforeDefault'),
          afterLabel: context.t('newsAdd.beforeAfterAfterDefault'),
        ),
      );
    });
  }

  void _handleAddArticlePollBlock() {
    setState(() {
      _articleBlocks.add(PollQuestionBlockEntry());
    });
  }

  void _handleAddArticleVsBlock() {
    setState(() {
      _articleBlocks.add(
        ArticleVsBlockEntry(
          leftLabel: context.t('newsAdd.vsLeftDefault'),
          rightLabel: context.t('newsAdd.vsRightDefault'),
        ),
      );
    });
  }

  void _handleAddArticleReviewBlock() {
    setState(() {
      _articleBlocks.add(
        ArticleReviewBlockEntry(
          designLabel: context.t('newsAdd.reviewCriterionDesign'),
          performanceLabel: context.t('newsAdd.reviewCriterionPerformance'),
        ),
      );
    });
  }

  void _handleAddArticleQuoteBlock() {
    setState(() {
      _articleBlocks.add(ArticleQuoteBlockEntry());
    });
  }

  void _handleAddArticleIframeBlock() {
    setState(() {
      _articleBlocks.add(ArticleIframeBlockEntry());
    });
  }

  void _handleAddVideoContentBlock(Object block) {
    setState(() {
      _videoBlocks.add(block);
    });
  }

  void _handleFormatTabChanged(NewsAddFormatTab tab) {
    unawaited(_confirmFormatTabChange(tab));
  }

  Future<void> _confirmFormatTabChange(NewsAddFormatTab tab) async {
    if (_saving || tab == _activeTab) return;
    if (_hasEditorInputData) {
      final confirmed = await showAppConfirmationDialog(
        context,
        title: context.t('newsAdd.tabSwitchConfirmTitle'),
        message: context.t('newsAdd.tabSwitchConfirmMessage'),
        cancelLabel: context.t('common.cancel'),
        confirmLabel: context.t('newsAdd.tabSwitchConfirmAction'),
        danger: true,
      );
      if (!confirmed || !mounted) return;
      setState(() {
        _resetEditorState();
        _applyBootstrapDefaults();
        _applyFormatTab(tab);
      });
      return;
    }
    setState(() => _applyFormatTab(tab));
  }

  void _applyFormatTab(NewsAddFormatTab tab) {
    final currentAutoSubCategory = _autoSubCategory?.trim();
    final hasCurrentAutoSubCategory =
        currentAutoSubCategory != null &&
        currentAutoSubCategory.isNotEmpty &&
        _subCategory != null &&
        _normalizeNewsAddCategoryLabel(_subCategory!) ==
            _normalizeNewsAddCategoryLabel(currentAutoSubCategory);
    _activeTab = tab;
    _schemaType = _defaultSchemaTypeForTab(tab);
    final defaultSubCategory = _defaultSubCategoryForTab(tab);
    if (defaultSubCategory != null) {
      _subCategory = defaultSubCategory.label;
      _thirdCategory = null;
      _autoSubCategory = defaultSubCategory.label;
    } else if (hasCurrentAutoSubCategory) {
      _subCategory = null;
      _thirdCategory = null;
      _autoSubCategory = null;
    } else {
      _autoSubCategory = null;
    }
  }

  void _handleTocStyleChanged(int level, String value) {
    if (!tocListStyleOptions.contains(value)) return;
    setState(() {
      _tocBlock.setStyleForLevel(level, value);
    });
  }

  void _handleTocShowStyleChanged(int level, bool value) {
    setState(() {
      _tocBlock.setShowStyleForLevel(level, value);
    });
  }

  void _handleAddTocItem() {
    setState(() {
      _tocBlock.items.add(TocItemEntry());
    });
  }

  void _handleRemoveTocItem(TocItemEntry item) {
    if (_tocBlock.items.length <= 1) return;
    setState(() {
      _tocBlock.items.remove(item);
      item.dispose();
    });
  }

  void _handleMoveTocItem(TocItemEntry item, int delta) {
    final fromIndex = _tocBlock.items.indexOf(item);
    final toIndex = fromIndex + delta;
    if (fromIndex < 0 || toIndex < 0 || toIndex >= _tocBlock.items.length) {
      return;
    }
    setState(() {
      _tocBlock.items[fromIndex] = _tocBlock.items[toIndex];
      _tocBlock.items[toIndex] = item;
    });
  }

  void _handleToggleTocItemCollapsed(TocItemEntry item) {
    setState(() {
      item.collapsed = !item.collapsed;
    });
  }

  void _handleTocItemImageChanged(TocItemEntry item, String? imageUrl) {
    setState(() {
      item.imageUrl = imageUrl;
    });
  }

  void _handleRecipeDifficultyChanged(String value) {
    setState(() {
      _recipeBlock.difficulty = _normalizeRecipeDifficulty(value);
    });
  }

  void _handleAddRecipeIngredient() {
    setState(() {
      _recipeBlock.ingredients.add(RecipeIngredientEntry());
    });
  }

  void _handleRemoveRecipeIngredient(RecipeIngredientEntry entry) {
    if (_recipeBlock.ingredients.length <= 1) return;
    setState(() {
      _recipeBlock.ingredients.remove(entry);
      entry.dispose();
    });
  }

  void _handleAddRecipeNutrition() {
    setState(() {
      _recipeBlock.nutrition.add(RecipeNutritionEntry());
    });
  }

  void _handleRemoveRecipeNutrition(RecipeNutritionEntry entry) {
    if (_recipeBlock.nutrition.length <= 1) return;
    setState(() {
      _recipeBlock.nutrition.remove(entry);
      entry.dispose();
    });
  }

  void _handleAddRecipeDirection() {
    setState(() {
      _recipeBlock.directions.add(RecipeDirectionEntry());
    });
  }

  void _handleRemoveRecipeDirection(RecipeDirectionEntry direction) {
    if (_recipeBlock.directions.length <= 1) return;
    setState(() {
      _recipeBlock.directions.remove(direction);
      direction.dispose();
    });
  }

  void _handleMoveRecipeDirection(RecipeDirectionEntry direction, int delta) {
    final fromIndex = _recipeBlock.directions.indexOf(direction);
    final toIndex = fromIndex + delta;
    if (fromIndex < 0 ||
        toIndex < 0 ||
        toIndex >= _recipeBlock.directions.length) {
      return;
    }
    setState(() {
      _recipeBlock.directions[fromIndex] = _recipeBlock.directions[toIndex];
      _recipeBlock.directions[toIndex] = direction;
    });
  }

  void _handleToggleRecipeDirectionCollapsed(RecipeDirectionEntry direction) {
    setState(() {
      direction.collapsed = !direction.collapsed;
    });
  }

  void _handleRecipeDirectionImageChanged(
    RecipeDirectionEntry direction,
    String? imageUrl,
  ) {
    setState(() {
      direction.imageUrl = imageUrl;
    });
  }

  void _handleClearRecipeVideoBlock() {
    setState(() {
      _recipeVideoBlock.mediaUrl = null;
      _recipeVideoBlock.titleController.clear();
      _recipeVideoBlock.sourceController.clear();
    });
  }

  void _handleEventRegistrationTypeChanged(String value) {
    if (!eventRegistrationTypeOptions.contains(value)) return;
    setState(() {
      _eventBlock.registrationType = value;
    });
  }

  void _handleAddEventSchedule() {
    setState(() {
      _eventBlock.schedule.add(EventScheduleEntry());
    });
  }

  void _handleRemoveEventSchedule(EventScheduleEntry entry) {
    if (_eventBlock.schedule.length <= 1) return;
    setState(() {
      _eventBlock.schedule.remove(entry);
      entry.dispose();
    });
  }

  void _handleEventScheduleImageChanged(
    EventScheduleEntry entry,
    String? imageUrl,
  ) {
    setState(() {
      entry.imageUrl = imageUrl;
    });
  }

  void _handleAddEventHighlight() {
    setState(() {
      _eventBlock.highlights.add(EventHighlightEntry());
    });
  }

  void _handleRemoveEventHighlight(EventHighlightEntry entry) {
    if (_eventBlock.highlights.length <= 1) return;
    setState(() {
      _eventBlock.highlights.remove(entry);
      entry.dispose();
    });
  }

  void _handleAddEventSpeaker() {
    setState(() {
      _eventBlock.speakers.add(EventSpeakerEntry());
    });
  }

  void _handleRemoveEventSpeaker(EventSpeakerEntry speaker) {
    if (_eventBlock.speakers.length <= 1) return;
    setState(() {
      _eventBlock.speakers.remove(speaker);
      speaker.dispose();
    });
  }

  void _handleMoveEventSpeaker(EventSpeakerEntry speaker, int delta) {
    final fromIndex = _eventBlock.speakers.indexOf(speaker);
    final toIndex = fromIndex + delta;
    if (fromIndex < 0 ||
        toIndex < 0 ||
        toIndex >= _eventBlock.speakers.length) {
      return;
    }
    setState(() {
      _eventBlock.speakers[fromIndex] = _eventBlock.speakers[toIndex];
      _eventBlock.speakers[toIndex] = speaker;
    });
  }

  void _handleToggleEventSpeakerCollapsed(EventSpeakerEntry speaker) {
    setState(() {
      speaker.collapsed = !speaker.collapsed;
    });
  }

  void _handleEventSpeakerImageChanged(
    EventSpeakerEntry speaker,
    String? imageUrl,
  ) {
    setState(() {
      speaker.imageUrl = imageUrl;
    });
  }

  void _handleAddEventContentBlock(Object block) {
    setState(() {
      _eventContentBlocks.add(block);
    });
  }

  bool _canRemoveContentBlock(List<Object> blocks, Object block) {
    if (!identical(blocks, _articleBlocks)) return true;
    if (block is! ArticleTextBlockEntry) return true;
    return blocks.whereType<ArticleTextBlockEntry>().length > 1;
  }

  void _handleRemoveContentBlock(List<Object> blocks, Object block) {
    if (!_canRemoveContentBlock(blocks, block)) return;
    setState(() {
      blocks.remove(block);
      _disposeContentBlock(block);
    });
  }

  void _handleMoveContentBlock(
    List<Object> blocks,
    Object block,
    int visibleDelta,
    _Sort sort,
  ) {
    final visibleBlocks = switch (sort) {
      _Sort.asc || _Sort.hide => blocks,
      _Sort.desc => blocks.reversed.toList(),
    };
    final fromVisibleIndex = visibleBlocks.indexOf(block);
    final toVisibleIndex = fromVisibleIndex + visibleDelta;
    if (fromVisibleIndex < 0 ||
        toVisibleIndex < 0 ||
        toVisibleIndex >= visibleBlocks.length) {
      return;
    }

    final target = visibleBlocks[toVisibleIndex];
    final fromActualIndex = blocks.indexOf(block);
    final toActualIndex = blocks.indexOf(target);
    if (fromActualIndex < 0 || toActualIndex < 0) return;

    setState(() {
      blocks[fromActualIndex] = target;
      blocks[toActualIndex] = block;
    });
  }

  void _handleToggleArticleTextBlockSettings(ArticleTextBlockEntry block) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleToggleArticleImageBlockSettings(ArticleImageBlockEntry block) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleToggleArticleSliderImageBlockSettings(
    ArticleSliderImageBlockEntry block,
  ) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleToggleArticleVideoBlockSettings(ArticleVideoBlockEntry block) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleToggleArticleAudioBlockSettings(ArticleAudioBlockEntry block) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleToggleArticleFileBlockSettings(ArticleFileBlockEntry block) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleToggleArticleSocialBlockSettings(ArticleSocialBlockEntry block) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleToggleArticleFlipcardBlockSettings(
    ArticleFlipcardBlockEntry block,
  ) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleToggleArticleBeforeAfterBlockSettings(
    ArticleBeforeAfterBlockEntry block,
  ) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleToggleArticleVsBlockSettings(ArticleVsBlockEntry block) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleToggleArticleReviewBlockSettings(ArticleReviewBlockEntry block) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleToggleArticleQuoteBlockSettings(ArticleQuoteBlockEntry block) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleToggleArticleIframeBlockSettings(ArticleIframeBlockEntry block) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleArticleImageChanged(
    ArticleImageBlockEntry block,
    String? imageUrl,
  ) {
    setState(() {
      block.imageUrl = imageUrl;
    });
  }

  void _handleArticleImageHomeChanged(
    ArticleImageBlockEntry block,
    bool value,
  ) {
    setState(() {
      block.showOnHomepage = value;
    });
  }

  void _handleArticleSliderImagesAdded(
    ArticleSliderImageBlockEntry block,
    List<String> imageUrls,
  ) {
    setState(() {
      for (final imageUrl in imageUrls) {
        final normalized = imageUrl.trim();
        if (normalized.isEmpty || block.imageUrls.contains(normalized)) {
          continue;
        }
        block.imageUrls.add(normalized);
      }
    });
  }

  void _handleArticleSliderImageReplaced(
    ArticleSliderImageBlockEntry block,
    int index,
    String imageUrl,
  ) {
    if (index < 0 || index >= block.imageUrls.length) return;
    setState(() {
      block.imageUrls[index] = imageUrl;
    });
  }

  void _handleArticleSliderImageRemoved(
    ArticleSliderImageBlockEntry block,
    int index,
  ) {
    if (index < 0 || index >= block.imageUrls.length) return;
    setState(() {
      block.imageUrls.removeAt(index);
    });
  }

  void _handleArticleSliderImageHomeChanged(
    ArticleSliderImageBlockEntry block,
    bool value,
  ) {
    setState(() {
      block.showOnHomepage = value;
    });
  }

  void _handleArticleVideoHomeChanged(
    ArticleVideoBlockEntry block,
    bool value,
  ) {
    setState(() {
      block.showOnHomepage = value;
    });
  }

  void _handleArticleVideoChanged(
    ArticleVideoBlockEntry block,
    String? videoUrl,
  ) {
    setState(() {
      block.mediaUrl = videoUrl;
    });
  }

  void _handleArticleAudioHomeChanged(
    ArticleAudioBlockEntry block,
    bool value,
  ) {
    setState(() {
      block.showOnHomepage = value;
    });
  }

  void _handleArticleAudioChanged(
    ArticleAudioBlockEntry block,
    String? audioUrl,
  ) {
    setState(() {
      block.mediaUrl = audioUrl;
    });
  }

  void _handleArticleFileHomeChanged(ArticleFileBlockEntry block, bool value) {
    setState(() {
      block.showOnHomepage = value;
    });
  }

  void _handleArticleFileChanged(ArticleFileBlockEntry block, String? fileUrl) {
    setState(() {
      block.mediaUrl = fileUrl;
    });
  }

  void _handleArticleSocialHomeChanged(
    ArticleSocialBlockEntry block,
    bool value,
  ) {
    setState(() {
      block.showOnHomepage = value;
    });
  }

  void _handleArticleFlipcardHomeChanged(
    ArticleFlipcardBlockEntry block,
    bool value,
  ) {
    setState(() {
      block.showOnHomepage = value;
    });
  }

  void _handleArticleFlipcardFrontImageChanged(
    ArticleFlipcardBlockEntry block,
    String? imageUrl,
  ) {
    setState(() {
      block.frontImageUrl = imageUrl;
    });
  }

  void _handleArticleFlipcardBackImageChanged(
    ArticleFlipcardBlockEntry block,
    String? imageUrl,
  ) {
    setState(() {
      block.backImageUrl = imageUrl;
    });
  }

  void _handleArticleBeforeAfterHomeChanged(
    ArticleBeforeAfterBlockEntry block,
    bool value,
  ) {
    setState(() {
      block.showOnHomepage = value;
    });
  }

  void _handleArticleBeforeAfterBeforeImageChanged(
    ArticleBeforeAfterBlockEntry block,
    String? imageUrl,
  ) {
    setState(() {
      block.beforeImageUrl = imageUrl;
    });
  }

  void _handleArticleBeforeAfterAfterImageChanged(
    ArticleBeforeAfterBlockEntry block,
    String? imageUrl,
  ) {
    setState(() {
      block.afterImageUrl = imageUrl;
    });
  }

  void _handleArticleVsHomeChanged(ArticleVsBlockEntry block, bool value) {
    setState(() {
      block.showOnHomepage = value;
    });
  }

  void _handleArticleVsMainImageChanged(
    ArticleVsBlockEntry block,
    String? imageUrl,
  ) {
    setState(() {
      block.mainImageUrl = imageUrl;
    });
  }

  void _handleArticleVsOptionImageChanged(
    ArticleVsBlockEntry block,
    int index,
    String? imageUrl,
  ) {
    if (index < 0 || index >= block.options.length) return;
    setState(() {
      block.options[index].imageUrl = imageUrl;
    });
  }

  void _handleArticleReviewImageChanged(
    ArticleReviewBlockEntry block,
    String? imageUrl,
  ) {
    setState(() {
      block.imageUrl = imageUrl;
    });
  }

  void _handleArticleReviewHomeChanged(
    ArticleReviewBlockEntry block,
    bool value,
  ) {
    setState(() {
      block.showOnHomepage = value;
    });
  }

  void _handleArticleReviewProsAdd(ArticleReviewBlockEntry block) {
    setState(() {
      block.pros.add(ArticleReviewTextEntry());
    });
  }

  void _handleArticleReviewProsRemove(
    ArticleReviewBlockEntry block,
    int index,
  ) {
    if (index < 0 || index >= block.pros.length) return;
    setState(() {
      final removed = block.pros.removeAt(index);
      removed.dispose();
    });
  }

  void _handleArticleReviewConsAdd(ArticleReviewBlockEntry block) {
    setState(() {
      block.cons.add(ArticleReviewTextEntry());
    });
  }

  void _handleArticleReviewConsRemove(
    ArticleReviewBlockEntry block,
    int index,
  ) {
    if (index < 0 || index >= block.cons.length) return;
    setState(() {
      final removed = block.cons.removeAt(index);
      removed.dispose();
    });
  }

  void _handleArticleReviewCriterionAdd(ArticleReviewBlockEntry block) {
    setState(() {
      block.criteria.add(ArticleReviewCriterionEntry(label: ''));
    });
  }

  void _handleArticleReviewCriterionRemove(
    ArticleReviewBlockEntry block,
    int index,
  ) {
    if (index < 0 || index >= block.criteria.length) return;
    setState(() {
      final removed = block.criteria.removeAt(index);
      removed.dispose();
    });
  }

  void _handleArticleReviewCriterionScoreChanged(
    ArticleReviewBlockEntry block,
    int index,
    int score,
  ) {
    if (index < 0 || index >= block.criteria.length) return;
    setState(() {
      block.criteria[index].score = score.clamp(0, 100).toInt();
    });
  }

  void _handleArticleQuoteHomeChanged(
    ArticleQuoteBlockEntry block,
    bool value,
  ) {
    setState(() {
      block.showOnHomepage = value;
    });
  }

  void _handleArticleIframeHomeChanged(
    ArticleIframeBlockEntry block,
    bool value,
  ) {
    setState(() {
      block.showOnHomepage = value;
    });
  }

  List<QuizResultBlockEntry> get _visibleQuizResults => switch (_quizSort) {
    NewsAddQuizSort.asc || NewsAddQuizSort.hide => _quizResults,
    NewsAddQuizSort.desc => _quizResults.reversed.toList(),
  };

  List<QuizQuestionBlockEntry> get _visibleQuizQuestions => switch (_quizSort) {
    NewsAddQuizSort.asc || NewsAddQuizSort.hide => _quizQuestions,
    NewsAddQuizSort.desc => _quizQuestions.reversed.toList(),
  };

  List<PollQuestionBlockEntry> get _visiblePollQuestions => switch (_pollSort) {
    NewsAddQuizSort.asc || NewsAddQuizSort.hide => _pollQuestions,
    NewsAddQuizSort.desc => _pollQuestions.reversed.toList(),
  };

  QuizQuestionType get _quizQuestionType => switch (_quizSubTab) {
    NewsAddQuizSubTab.personality => QuizQuestionType.personality,
    NewsAddQuizSubTab.trivia => QuizQuestionType.trivia,
    NewsAddQuizSubTab.checklist => QuizQuestionType.checklist,
  };

  String _quizResultId(QuizResultBlockEntry block) => _entryId(block);

  List<QuizQuestionResultOption> get _quizResultOptions {
    return [
      for (var index = 0; index < _quizResults.length; index++)
        QuizQuestionResultOption(
          id: _quizResultId(_quizResults[index]),
          label: _quizResults[index].titleController.text.trim().isEmpty
              ? '${context.t('newsAdd.quiz.resultTitle')} ${index + 1}'
              : _quizResults[index].titleController.text.trim(),
        ),
    ];
  }

  void _handleAddQuizResult() {
    setState(() {
      _quizResults.add(QuizResultBlockEntry());
    });
  }

  void _handleRemoveQuizResult(QuizResultBlockEntry block) {
    final resultId = _quizResultId(block);
    setState(() {
      _quizResults.remove(block);
      for (final question in _quizQuestions) {
        for (final answer in question.answers) {
          if (answer.resultId == resultId) answer.resultId = null;
        }
      }
      block.dispose();
    });
  }

  void _handleMoveQuizResult(QuizResultBlockEntry block, int visibleDelta) {
    final visibleResults = _visibleQuizResults;
    final fromVisibleIndex = visibleResults.indexOf(block);
    final toVisibleIndex = fromVisibleIndex + visibleDelta;
    if (fromVisibleIndex < 0 ||
        toVisibleIndex < 0 ||
        toVisibleIndex >= visibleResults.length) {
      return;
    }

    final target = visibleResults[toVisibleIndex];
    final fromActualIndex = _quizResults.indexOf(block);
    final toActualIndex = _quizResults.indexOf(target);
    if (fromActualIndex < 0 || toActualIndex < 0) return;

    setState(() {
      _quizResults[fromActualIndex] = target;
      _quizResults[toActualIndex] = block;
    });
  }

  void _handleQuizResultImageChanged(
    QuizResultBlockEntry block,
    String? imageUrl,
  ) {
    setState(() {
      block.imageUrl = imageUrl;
    });
  }

  void _handleQuizQuestionLayoutChanged(
    QuizQuestionBlockEntry block,
    QuizQuestionAnswerLayout value,
  ) {
    if (!_quizQuestions.contains(block)) return;
    setState(() {
      block.layout = value;
      if (value == QuizQuestionAnswerLayout.grid3) {
        block.ensureAnswerCount(3);
      }
    });
  }

  void _handleAddQuizQuestion() {
    setState(() {
      _quizQuestions.add(QuizQuestionBlockEntry());
    });
  }

  void _handleRemoveQuizQuestion(QuizQuestionBlockEntry block) {
    setState(() {
      _quizQuestions.remove(block);
      block.dispose();
    });
  }

  void _handleMoveQuizQuestion(QuizQuestionBlockEntry block, int visibleDelta) {
    final visibleQuestions = _visibleQuizQuestions;
    final fromVisibleIndex = visibleQuestions.indexOf(block);
    final toVisibleIndex = fromVisibleIndex + visibleDelta;
    if (fromVisibleIndex < 0 ||
        toVisibleIndex < 0 ||
        toVisibleIndex >= visibleQuestions.length) {
      return;
    }

    final target = visibleQuestions[toVisibleIndex];
    final fromActualIndex = _quizQuestions.indexOf(block);
    final toActualIndex = _quizQuestions.indexOf(target);
    if (fromActualIndex < 0 || toActualIndex < 0) return;

    setState(() {
      _quizQuestions[fromActualIndex] = target;
      _quizQuestions[toActualIndex] = block;
    });
  }

  void _handleQuizQuestionImageChanged(
    QuizQuestionBlockEntry block,
    String? imageUrl,
  ) {
    setState(() {
      block.imageUrl = imageUrl;
    });
  }

  void _handleAddQuizAnswer(QuizQuestionBlockEntry block) {
    setState(() {
      block.answers.add(QuizQuestionAnswerEntry());
    });
  }

  void _handleRemoveQuizAnswer(
    QuizQuestionBlockEntry block,
    QuizQuestionAnswerEntry answer,
  ) {
    if (!block.answers.contains(answer) || block.answers.length <= 1) return;
    setState(() {
      block.answers.remove(answer);
      answer.dispose();
    });
  }

  void _handleQuizAnswerImageChanged(
    QuizQuestionBlockEntry block,
    QuizQuestionAnswerEntry answer,
    String? imageUrl,
  ) {
    if (!block.answers.contains(answer)) return;
    setState(() {
      answer.imageUrl = imageUrl;
    });
  }

  void _handleQuizAnswerResultChanged(
    QuizQuestionBlockEntry block,
    QuizQuestionAnswerEntry answer,
    String? resultId,
  ) {
    if (!block.answers.contains(answer)) return;
    setState(() {
      answer.resultId = resultId;
    });
  }

  void _handleQuizAnswerCorrectChanged(
    QuizQuestionBlockEntry block,
    QuizQuestionAnswerEntry answer,
    bool isCorrect,
  ) {
    if (!block.answers.contains(answer)) return;
    setState(() {
      answer.isCorrect = isCorrect;
    });
  }

  void _handlePollQuestionLayoutChanged(
    PollQuestionBlockEntry block,
    PollQuestionAnswerLayout value,
  ) {
    if (!_pollQuestions.contains(block)) return;
    _handleContentPollQuestionLayoutChanged(block, value);
  }

  void _handleContentPollQuestionLayoutChanged(
    PollQuestionBlockEntry block,
    PollQuestionAnswerLayout value,
  ) {
    setState(() {
      block.layout = value;
      if (value == PollQuestionAnswerLayout.grid3) {
        block.ensureAnswerCount(3);
      }
    });
  }

  void _handleAddPollQuestion() {
    setState(() {
      _pollQuestions.add(PollQuestionBlockEntry());
    });
  }

  void _handleRemovePollQuestion(PollQuestionBlockEntry block) {
    setState(() {
      _pollQuestions.remove(block);
      block.dispose();
    });
  }

  void _handleMovePollQuestion(PollQuestionBlockEntry block, int visibleDelta) {
    final visibleQuestions = _visiblePollQuestions;
    final fromVisibleIndex = visibleQuestions.indexOf(block);
    final toVisibleIndex = fromVisibleIndex + visibleDelta;
    if (fromVisibleIndex < 0 ||
        toVisibleIndex < 0 ||
        toVisibleIndex >= visibleQuestions.length) {
      return;
    }

    final target = visibleQuestions[toVisibleIndex];
    final fromActualIndex = _pollQuestions.indexOf(block);
    final toActualIndex = _pollQuestions.indexOf(target);
    if (fromActualIndex < 0 || toActualIndex < 0) return;

    setState(() {
      _pollQuestions[fromActualIndex] = target;
      _pollQuestions[toActualIndex] = block;
    });
  }

  void _handlePollQuestionImageChanged(
    PollQuestionBlockEntry block,
    String? imageUrl,
  ) {
    setState(() {
      block.imageUrl = imageUrl;
    });
  }

  void _handlePollQuestionHomeChanged(
    PollQuestionBlockEntry block,
    bool value,
  ) {
    setState(() {
      block.showOnHomepage = value;
    });
  }

  void _handleTogglePollQuestionSettings(PollQuestionBlockEntry block) {
    setState(() {
      block.extraSettingsExpanded = !block.extraSettingsExpanded;
    });
  }

  void _handleAddPollAnswer(PollQuestionBlockEntry block) {
    setState(() {
      block.answers.add(PollQuestionAnswerEntry());
    });
  }

  void _handleRemovePollAnswer(
    PollQuestionBlockEntry block,
    PollQuestionAnswerEntry answer,
  ) {
    if (!block.answers.contains(answer) || block.answers.length <= 1) return;
    setState(() {
      block.answers.remove(answer);
      answer.dispose();
    });
  }

  void _handlePollAnswerImageChanged(
    PollQuestionBlockEntry block,
    PollQuestionAnswerEntry answer,
    String? imageUrl,
  ) {
    if (!block.answers.contains(answer)) return;
    setState(() {
      answer.imageUrl = imageUrl;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.deepOcean,
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: _NewsAddStatusCard(
          message: _loadError!,
          onRetry: () => unawaited(_loadEditor()),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1180;
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;

        return AbsorbPointer(
          absorbing: _saving,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              24,
              horizontalPadding,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  onBack: widget.onBackToNews,
                  onClear: () => unawaited(_handleClearEditor()),
                  onNewsTap: widget.onBackToNews,
                ),
                const SizedBox(height: 18),
                if (isCompact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMainColumn(context),
                      const SizedBox(height: 20),
                      _buildSidebar(context),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildMainColumn(context)),
                      const SizedBox(width: 20),
                      SizedBox(width: 360, child: _buildSidebar(context)),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Main column ───────────────────────────────────────────────────────────
  Widget _buildMainColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContentInfoCard(
          activeTab: _activeTab,
          onTabChanged: _handleFormatTabChanged,
          titleController: _titleController,
          summaryController: _summaryController,
          seoTitleController: _seoTitleController,
          slugController: _slugController,
          metaDescriptionController: _metaDescriptionController,
          focusKeywordsController: _focusKeywordsController,
          schemaType: _schemaType,
          keywords: _keywords,
          mansetSlider: _mansetSlider,
          pinToTop: _pinToTop,
          onMansetChanged: (value) => setState(() => _mansetSlider = value),
          onPinChanged: (value) => setState(() => _pinToTop = value),
          onSchemaChanged: (value) =>
              setState(() => _schemaType = value ?? 'NewsArticle'),
          onKeywordSubmitted: _handleKeywordSubmitted,
          onKeywordRemoved: _handleRemoveKeyword,
          faqEntries: _faqEntries,
          onAddFaq: _handleAddFaq,
          onRemoveFaq: _handleRemoveFaq,
          onAiGenerate: _openAiContentGenerator,
        ),
        const SizedBox(height: 20),
        ..._buildTabBody(),
      ],
    );
  }

  Future<void> _openAiContentGenerator() async {
    final initialContent = _currentAiContentSeed();
    final targetTab = _activeTab;
    final result = await showDialog<_AiContentGeneratorResult>(
      context: context,
      barrierColor: AppColors.deepOcean.withValues(alpha: 0.58),
      builder: (dialogContext) {
        return _AiContentGeneratorDialog(
          languageCode: _languageCode,
          category: _selectedCategory,
          formatType: _postTypeForActiveTab,
          formatSubtype: _aiFormatSubtypeForActiveTab,
          initialTopic: initialContent,
          initialNotes: '',
          revisionMode: initialContent.trim().isNotEmpty,
          onGenerate: _aiRepository.generateDraft,
        );
      },
    );
    if (result == null || !mounted) return;
    _applyAiDraft(
      result.draft,
      targetTab,
      sourceImage: result.sourceImage,
      eventImages: result.eventImages,
    );
    _showEditorMessage(context.t('newsAdd.aiModal.generated'));
  }

  String get _aiFormatSubtypeForActiveTab {
    return switch (_activeTab) {
      NewsAddFormatTab.quiz => _quizSubTab.name,
      _ => '',
    };
  }

  String _currentAiContentSeed() {
    final lines = <String>[];

    void addField(String label, String value) {
      final text = value.trim();
      if (text.isEmpty) return;
      lines.add('$label: $text');
    }

    addField('Haber başlığı', _titleController.text);
    addField('Kısa özet', _summaryController.text);
    addField('SEO başlık', _seoTitleController.text);
    addField('URL uzantısı', _slugController.text);
    addField('Meta açıklama', _metaDescriptionController.text);
    if (_keywords.isNotEmpty) {
      addField('Odak anahtar kelimeler', _keywords.join(', '));
    }

    final items = _itemsForStorage()
        .where(_hasUsefulAiContentSeedItem)
        .toList(growable: false);
    if (items.isNotEmpty) {
      lines.add('Haber içerik blokları:');
      for (final item in items) {
        final type = _text(item['type']);
        final title = _text(item['title']);
        final description = _text(item['description']);
        final source = _text(item['source']);
        lines.add('---');
        addField('Blok tipi', type);
        addField('Blok başlığı', title);
        addField('Blok metni', description);
        addField('Blok kaynağı', source);
        addField('Medya URL', _text(item['mediaUrl']));
        addField('Alt metin', _text(item['altText']));
        final options = item['options'];
        if (options is List && options.isNotEmpty) {
          addField(
            'Seçenekler',
            options
                .map(
                  (option) =>
                      option is Map ? _text(option['text']) : _text(option),
                )
                .where((option) => option.isNotEmpty)
                .join(', '),
          );
        }
        _appendStructuredAiSeedItem(item, addField);
      }
    }

    final faqData = _faqDataForStorage();
    if (faqData.isNotEmpty) {
      lines.add('FAQ:');
      for (final item in faqData) {
        addField('Soru', _text(item['q']));
        addField('Cevap', _text(item['a']));
      }
    }

    if (lines.isNotEmpty) {
      addField('Schema.org türü', _schemaType);
    }

    return lines.join('\n').trim();
  }

  void _appendStructuredAiSeedItem(
    Map<String, Object?> item,
    void Function(String label, String value) addField,
  ) {
    final type = _text(item['type']);
    if (type == 'quiz') {
      final data = _map(item['quizData']);
      addField('Quiz tipi', _text(data['quizType']));
      final results = _mapList(data['results']);
      if (results.isNotEmpty) {
        addField(
          'Quiz sonuçları',
          results
              .map((row) {
                final title = _text(row['title']);
                final minScore = _scoreText(row['minScore']);
                final maxScore = _scoreText(row['maxScore']);
                final range = minScore.isNotEmpty || maxScore.isNotEmpty
                    ? ' ($minScore-$maxScore doğru)'
                    : '';
                return '$title$range';
              })
              .join(', '),
        );
      }
      for (final row in _mapList(data['questions'])) {
        addField('Quiz sorusu', _text(row['title']));
        final answers = _mapList(row['answers'])
            .map((answer) => _text(answer['text']))
            .where((answer) => answer.trim().isNotEmpty)
            .join(', ');
        addField('Quiz cevapları', answers);
        final explanations = _mapList(row['answers'])
            .where((answer) => _bool(answer['isCorrect']))
            .map((answer) => _text(answer['explanation']))
            .where((text) => text.trim().isNotEmpty)
            .join(' | ');
        addField('Doğru cevap açıklaması', explanations);
      }
      return;
    }
    if (type == 'poll') {
      addField('Anket sorusu', _text(item['title']));
      addField(
        'Anket açıklaması',
        _plainTextFromAiHtml(_text(item['description'])),
      );
      final answers = _mapList(item['options'])
          .map((answer) => _text(answer['text']))
          .where((answer) => answer.trim().isNotEmpty)
          .join(', ');
      addField('Anket cevapları', answers);
      return;
    }
    if (type == 'toc') {
      final data = _map(item['tocData']);
      final styles = _map(data['linkListStyle']);
      addField('İçindekiler seviye 1 stili', _text(styles['level1']));
      addField('İçindekiler seviye 2 stili', _text(styles['level2']));
      addField('İçindekiler seviye 3 stili', _text(styles['level3']));
      for (final row in _mapList(data['items'])) {
        addField('İçindekiler id', _text(row['id']));
        addField('İçindekiler başlığı', _text(row['title']));
        addField('İçindekiler üst bağlantı', _text(row['parentId']));
        addField('İçindekiler metni', _text(row['content']));
      }
      return;
    }
    if (type == 'recipe') {
      final data = _map(item['recipeData']);
      addField('Hazırlık süresi', _text(data['prepTime']));
      addField('Pişirme süresi', _text(data['cookTime']));
      addField('Porsiyon', _text(data['serving']));
      addField('Zorluk', _text(data['difficulty']));
      addField(
        'Malzemeler',
        _mapList(data['ingredients'])
            .map((row) => _text(row['text']))
            .where((text) => text.trim().isNotEmpty)
            .join(', '),
      );
      for (final row in _mapList(data['directions'])) {
        addField('Tarif adımı', _text(row['title']));
        addField('Tarif adımı metni', _text(row['content']));
      }
      return;
    }
    if (type == 'event') {
      final data = _map(item['eventData']);
      addField('Etkinlik başlangıcı', _text(data['startDateTime']));
      addField('Etkinlik bitişi', _text(data['endDateTime']));
      addField('Organizatör', _text(data['organizer']));
      addField('Mekan', _text(data['venueName']));
      addField('Adres', _text(data['address']));
      for (final row in _mapList(data['schedule'])) {
        addField('Etkinlik programı', _text(row['title']));
        addField('Program açıklaması', _text(row['description']));
      }
      for (final row in _mapList(data['speakers'])) {
        addField('Konuşmacı', _text(row['name']));
        addField('Konuşmacı rolü', _text(row['role']));
      }
    }
  }

  bool _hasUsefulAiContentSeedItem(Map<String, Object?> item) {
    if (_text(item['type']) == 'toc') {
      return _hasUsefulTocAiContentSeedItem(item);
    }
    if (_text(item['type']) == 'poll') {
      return _hasUsefulPollAiContentSeedItem(item);
    }
    return _text(item['title']).isNotEmpty ||
        _text(item['description']).isNotEmpty ||
        _text(item['source']).isNotEmpty ||
        _text(item['mediaUrl']).isNotEmpty ||
        _text(item['altText']).isNotEmpty;
  }

  bool _hasUsefulTocAiContentSeedItem(Map<String, Object?> item) {
    final data = _map(item['tocData']);
    for (final row in _mapList(data['items'])) {
      if (_text(row['title']).isNotEmpty ||
          _text(row['parentId']).isNotEmpty ||
          _text(row['image']).isNotEmpty ||
          _text(row['imageDescription']).isNotEmpty ||
          _plainTextFromAiHtml(_text(row['content'])).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _hasUsefulPollAiContentSeedItem(Map<String, Object?> item) {
    if (_text(item['title']).isNotEmpty ||
        _plainTextFromAiHtml(_text(item['description'])).isNotEmpty ||
        _text(item['source']).isNotEmpty ||
        _text(item['mediaUrl']).isNotEmpty) {
      return true;
    }
    for (final option in _mapList(item['options'])) {
      if (_text(option['text']).isNotEmpty ||
          _text(option['image']).isNotEmpty ||
          _int(option['votes']) > 0) {
        return true;
      }
    }
    return false;
  }

  void _applyAiDraft(
    AdminNewsAiDraft draft,
    NewsAddFormatTab targetTab, {
    _AiSelectedSourceImage? sourceImage,
    List<_AiSelectedSourceImage> eventImages = const [],
  }) {
    if (targetTab != NewsAddFormatTab.article) {
      _applyAiDraftToStructuredTab(
        draft,
        targetTab,
        sourceImage: sourceImage,
        eventImages: eventImages,
      );
      return;
    }
    final blocks = _contentBlocksFromAiDraft(draft, sourceImage: sourceImage);
    _hydrating = true;
    setState(() {
      _activeTab = NewsAddFormatTab.article;
      _applyAiDraftCommonFields(draft);
      if (blocks.isNotEmpty) {
        _replaceContentBlocks(_articleBlocks, blocks);
      }
      _syncAiAutoMarkers();
    });
    _hydrating = false;
  }

  void _applyAiDraftToStructuredTab(
    AdminNewsAiDraft draft,
    NewsAddFormatTab targetTab, {
    _AiSelectedSourceImage? sourceImage,
    List<_AiSelectedSourceImage> eventImages = const [],
  }) {
    final item = targetTab == NewsAddFormatTab.poll
        ? null
        : _tabStorageItemFromAiDraft(draft, targetTab);
    final pollItems = targetTab == NewsAddFormatTab.poll
        ? _pollStorageItemsFromAiDraft(draft)
        : const <Map<String, Object?>>[];
    _hydrating = true;
    setState(() {
      _activeTab = targetTab;
      _applyAiDraftCommonFields(draft);
      final coverSourceImage =
          sourceImage ?? (eventImages.isNotEmpty ? eventImages.first : null);
      if (coverSourceImage != null) {
        _applySelectedSourceImageToCover(draft, coverSourceImage);
      }
      switch (targetTab) {
        case NewsAddFormatTab.quiz:
          if (item != null) {
            _hydrateQuizItem(item);
          }
        case NewsAddFormatTab.poll:
          final blocks = pollItems.map(_pollFromItem).toList();
          _replacePollQuestions(
            blocks.isEmpty ? [PollQuestionBlockEntry()] : blocks,
          );
        case NewsAddFormatTab.video:
          final blocks = <Object>[];
          if (item != null) {
            final block = ArticleVideoBlockEntry();
            _hydrateVideoBlock(block, item);
            blocks.add(block);
          }
          for (final aiItem in draft.items) {
            final block = _contentBlockFromAiItem(aiItem);
            if (block != null) blocks.add(block);
          }
          if (blocks.isNotEmpty) {
            _replaceContentBlocks(_videoBlocks, blocks);
          }
        case NewsAddFormatTab.contents:
          if (item != null) {
            _hydrateTocItem(item);
          }
        case NewsAddFormatTab.recipe:
          if (item != null) {
            _hydrateRecipeItem(item);
            _hydrateRecipeVideoBlockFromRecipeItem(item);
          }
        case NewsAddFormatTab.event:
          if (item != null) {
            _hydrateEventItem(item);
          }
          _applySelectedEventImagesToEventBlocks(draft, eventImages);
        case NewsAddFormatTab.article:
          break;
      }
      _syncAiAutoMarkers();
    });
    _hydrating = false;
  }

  void _applySelectedEventImagesToEventBlocks(
    AdminNewsAiDraft draft,
    List<_AiSelectedSourceImage> eventImages,
  ) {
    final images = <_AiSelectedSourceImage>[];
    final seen = <String>{};
    for (final image in eventImages) {
      final mediaSrc = image.mediaSrc.trim();
      if (mediaSrc.isEmpty || !seen.add(mediaSrc)) continue;
      images.add(image);
      if (images.length >= 5) break;
    }
    if (images.isEmpty) return;
    final existing = <String>{
      for (final block in _eventContentBlocks)
        if (block is ArticleImageBlockEntry)
          if ((block.imageUrl ?? '').trim().isNotEmpty) block.imageUrl!.trim(),
      for (final block in _eventContentBlocks)
        if (block is ArticleSliderImageBlockEntry)
          for (final imageUrl in block.imageUrls)
            if (imageUrl.trim().isNotEmpty) imageUrl.trim(),
    };
    final freshImages = [
      for (final image in images)
        if (!existing.contains(image.mediaSrc.trim())) image,
    ];
    if (freshImages.isEmpty) return;

    if (freshImages.length == 1) {
      final block = ArticleImageBlockEntry();
      _fillSelectedSourceImageBlock(block, draft, freshImages.first);
      _eventContentBlocks.insert(0, block);
      return;
    }

    final block = ArticleSliderImageBlockEntry();
    block.titleController.text = _firstNonEmpty([
      draft.title,
      context.t('newsAdd.aiModal.eventImages'),
    ]);
    block.sourceController.text = freshImages
        .map((image) => image.originalUrl)
        .where((url) => url.trim().isNotEmpty)
        .join('\n');
    block.imageUrls.addAll(freshImages.map((image) => image.mediaSrc));
    _eventContentBlocks.insert(0, block);
  }

  void _applySelectedSourceImageToCover(
    AdminNewsAiDraft draft,
    _AiSelectedSourceImage sourceImage,
  ) {
    if ((_coverImageUrl?.trim().isNotEmpty ?? false)) return;
    _coverImageUrl = sourceImage.mediaSrc;
    if (_coverAltController.text.trim().isEmpty) {
      _coverAltController.text = _firstNonEmpty([
        sourceImage.altText,
        draft.title,
      ]);
    }
  }

  void _applyAiDraftCommonFields(AdminNewsAiDraft draft) {
    if (draft.title.isNotEmpty) {
      _setControllerText(_titleController, draft.title);
    }
    if (draft.summary.isNotEmpty) {
      _setControllerText(_summaryController, draft.summary);
    }
    if (draft.seoTitle.isNotEmpty) {
      _setControllerText(_seoTitleController, draft.seoTitle);
    }
    final normalizedSlug = _slugify(
      draft.slug.isNotEmpty ? draft.slug : draft.title,
    );
    if (normalizedSlug.isNotEmpty) {
      _setControllerText(_slugController, normalizedSlug);
    }
    if (draft.metaDescription.isNotEmpty) {
      _setControllerText(
        _metaDescriptionController,
        draft.metaDescription.length > 170
            ? draft.metaDescription.substring(0, 170)
            : draft.metaDescription,
      );
    }
    if (_allowedAiSchemaTypes.contains(draft.schemaType)) {
      _schemaType = draft.schemaType;
    }
    if (draft.keywords.isNotEmpty) {
      _keywords
        ..clear()
        ..addAll(draft.keywords.take(14));
    }
    if (draft.faqEntries.isNotEmpty) {
      for (final entry in _faqEntries) {
        entry.dispose();
      }
      _faqEntries
        ..clear()
        ..addAll([
          for (final item in draft.faqEntries)
            _FaqEntry()
              ..question.text = item.question
              ..answer.text = item.answer,
        ]);
    }
  }

  void _syncAiAutoMarkers() {
    _lastAutoSlug = _slugController.text.trim();
    _lastAutoSeoTitle = _seoTitleController.text.trim();
    _lastAutoSeoDescription = _metaDescriptionController.text.trim();
  }

  Map<String, Object?>? _tabStorageItemFromAiDraft(
    AdminNewsAiDraft draft,
    NewsAddFormatTab targetTab,
  ) {
    final tabItem = draft.tabItem;
    if (tabItem.isEmpty) return null;
    final type = _storageTypeForAiTab(targetTab);
    final description = _firstNonEmpty([
      _text(tabItem['descriptionHtml']),
      draft.mainContentHtml,
      draft.summary,
    ]);
    final title = targetTab == NewsAddFormatTab.poll
        ? _firstNonEmpty([
            _text(tabItem['title']),
            _pollQuestionTitleFallback(description),
            draft.mainContentTitle,
            draft.title,
          ])
        : _firstNonEmpty([
            _text(tabItem['title']),
            draft.mainContentTitle,
            draft.title,
          ]);
    final item = <String, Object?>{
      'id': _firstNonEmpty([_text(tabItem['id']), 'ai-$type']),
      'type': type,
      'title': title,
      'description': description,
      'source': _text(tabItem['source']).trim(),
      'mediaUrl': _text(tabItem['mediaUrl']).trim(),
      'altText': _text(tabItem['altText']).trim(),
      'showOnHomepage': _bool(tabItem['showOnHomepage']),
      'orderNumber': 1,
    };

    switch (targetTab) {
      case NewsAddFormatTab.quiz:
        item['quizData'] = _map(tabItem['quizData']);
      case NewsAddFormatTab.poll:
        item['isImagePoll'] = _bool(tabItem['isImagePoll']);
        item['pollColumns'] = _int(tabItem['pollColumns']) == 3 ? 3 : 2;
        item['options'] = _aiPollOptions(tabItem['options']);
      case NewsAddFormatTab.contents:
        item['tocData'] = _map(tabItem['tocData']);
      case NewsAddFormatTab.recipe:
        item['recipeData'] = _map(tabItem['recipeData']);
      case NewsAddFormatTab.event:
        item['eventData'] = _map(tabItem['eventData']);
      case NewsAddFormatTab.video || NewsAddFormatTab.article:
        break;
    }
    return item;
  }

  List<Map<String, Object?>> _pollStorageItemsFromAiDraft(
    AdminNewsAiDraft draft,
  ) {
    final tabItem = draft.tabItem;
    if (tabItem.isEmpty) return const [];
    final pollData = _map(tabItem['pollData']);
    final questions = _mapList(pollData['questions']);
    if (questions.isEmpty) {
      final fallback = _tabStorageItemFromAiDraft(draft, NewsAddFormatTab.poll);
      return fallback == null ? const [] : [fallback];
    }

    final items = <Map<String, Object?>>[];
    for (var index = 0; index < questions.length; index++) {
      final item = _pollQuestionStorageItemFromAiDraft(
        draft,
        tabItem,
        questions[index],
        index,
      );
      if (_hasUsefulAiContentSeedItem(item) ||
          _mapList(item['options']).isNotEmpty) {
        items.add(item);
      }
    }
    if (items.isNotEmpty) return items;
    final fallback = _tabStorageItemFromAiDraft(draft, NewsAddFormatTab.poll);
    return fallback == null ? const [] : [fallback];
  }

  Map<String, Object?> _pollQuestionStorageItemFromAiDraft(
    AdminNewsAiDraft draft,
    Map<String, Object?> tabItem,
    Map<String, Object?> question,
    int index,
  ) {
    final rawDescription = _firstNonEmpty([
      _text(question['descriptionHtml']),
      _text(question['description']),
      if (index == 0) _text(tabItem['descriptionHtml']),
    ]);
    final title = _firstNonEmpty([
      _text(question['title']),
      _text(question['question']),
      _pollQuestionTitleFallback(rawDescription),
      if (index == 0) _text(tabItem['title']),
      draft.mainContentTitle,
      draft.title,
    ]);
    final questionColumns = _int(question['pollColumns']);
    final tabColumns = _int(tabItem['pollColumns']);
    final options = _aiPollOptionsForQuestion(
      _firstNonEmptyObject([
        question['options'],
        question['answers'],
        question['choices'],
      ]),
      index,
    );

    return {
      'id': _firstNonEmpty([
        _text(question['id']),
        'ai-poll-question-${index + 1}',
      ]),
      'type': 'poll',
      'title': title,
      'description': rawDescription,
      'source': _firstNonEmpty([
        _text(question['source']),
        _text(tabItem['source']),
      ]),
      'mediaUrl': _firstNonEmpty([
        _text(question['mediaUrl']),
        _text(question['image']),
        if (index == 0) _text(tabItem['mediaUrl']),
      ]),
      'altText': '',
      'showOnHomepage': question.containsKey('showOnHomepage')
          ? _bool(question['showOnHomepage'])
          : _bool(tabItem['showOnHomepage']),
      'orderNumber': index + 1,
      'isImagePoll': question.containsKey('isImagePoll')
          ? _bool(question['isImagePoll'])
          : _bool(tabItem['isImagePoll']),
      'pollColumns': questionColumns == 3
          ? 3
          : questionColumns == 2
          ? 2
          : tabColumns == 3
          ? 3
          : 2,
      'options': options,
    };
  }

  String _storageTypeForAiTab(NewsAddFormatTab tab) {
    return switch (tab) {
      NewsAddFormatTab.contents => 'toc',
      NewsAddFormatTab.article => 'article',
      NewsAddFormatTab.quiz => 'quiz',
      NewsAddFormatTab.poll => 'poll',
      NewsAddFormatTab.video => 'video',
      NewsAddFormatTab.recipe => 'recipe',
      NewsAddFormatTab.event => 'event',
    };
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final text = value.trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Object? _firstNonEmptyObject(List<Object?> values) {
    for (final value in values) {
      if (value is List && value.isNotEmpty) return value;
      if (value is Map && value.isNotEmpty) return value;
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  String _pollQuestionTitleFallback(String description) {
    final plain = _plainTextFromAiHtml(description);
    if (plain.isEmpty) return '';
    final questionMark = plain.indexOf('?');
    if (questionMark >= 0 && questionMark < 220) {
      return plain.substring(0, questionMark + 1).trim();
    }
    return plain.length > 180 ? plain.substring(0, 180).trim() : plain;
  }

  String _plainTextFromAiHtml(String value) {
    return value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'</p>|</h[1-6]>|</li>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<Map<String, Object?>> _aiPollOptions(Object? value) {
    if (value is! List) return const [];
    return [
      for (var index = 0; index < value.length && index < 6; index++)
        if (_aiPollOptionText(value[index]).isNotEmpty)
          {
            'id': 'ai-poll-option-${index + 1}',
            'text': _aiPollOptionText(value[index]),
            'image': value[index] is Map
                ? _text((value[index] as Map)['image']).trim()
                : '',
            'votes': value[index] is Map
                ? _int((value[index] as Map)['votes'])
                : 0,
          },
    ];
  }

  List<Map<String, Object?>> _aiPollOptionsForQuestion(
    Object? value,
    int questionIndex,
  ) {
    final options = _aiPollOptions(value);
    return [
      for (var index = 0; index < options.length; index++)
        {
          ...options[index],
          'id': 'ai-poll-q${questionIndex + 1}-option-${index + 1}',
        },
    ];
  }

  String _aiPollOptionText(Object? value) {
    if (value is Map) {
      return _firstNonEmpty([
        _text(value['text']),
        _text(value['label']),
        _text(value['title']),
        _text(value['value']),
      ]);
    }
    return _text(value).trim();
  }

  List<Object> _contentBlocksFromAiDraft(
    AdminNewsAiDraft draft, {
    _AiSelectedSourceImage? sourceImage,
  }) {
    final blocks = <Object>[];
    final sections = splitAdminNewsAiContentSections(
      title: draft.mainContentTitle,
      fallbackTitle: draft.title,
      html: draft.mainContentHtml,
    );
    for (final section in sections) {
      final block = ArticleTextBlockEntry();
      block.titleController.text = section.title;
      adminSetQuillHtml(block.editorController, section.html);
      blocks.add(block);
    }
    for (final item in draft.items) {
      final block = _contentBlockFromAiItem(item);
      if (block != null) blocks.add(block);
    }
    if (sourceImage != null) {
      _applySelectedSourceImageToBlocks(blocks, draft, sourceImage);
    }
    return blocks;
  }

  void _applySelectedSourceImageToBlocks(
    List<Object> blocks,
    AdminNewsAiDraft draft,
    _AiSelectedSourceImage sourceImage,
  ) {
    for (final block in blocks.whereType<ArticleImageBlockEntry>()) {
      if ((block.imageUrl ?? '').trim().isNotEmpty) continue;
      _fillSelectedSourceImageBlock(block, draft, sourceImage);
      return;
    }

    final block = ArticleImageBlockEntry();
    _fillSelectedSourceImageBlock(block, draft, sourceImage);
    final firstTextIndex = blocks.indexWhere(
      (item) => item is ArticleTextBlockEntry,
    );
    blocks.insert(
      firstTextIndex < 0 ? blocks.length : firstTextIndex + 1,
      block,
    );
  }

  void _fillSelectedSourceImageBlock(
    ArticleImageBlockEntry block,
    AdminNewsAiDraft draft,
    _AiSelectedSourceImage sourceImage,
  ) {
    block.imageUrl = sourceImage.mediaSrc;
    if (block.titleController.text.trim().isEmpty) {
      block.titleController.text = _firstNonEmpty([
        sourceImage.altText,
        draft.title,
      ]);
    }
    if (block.altTextController.text.trim().isEmpty) {
      block.altTextController.text = _firstNonEmpty([
        sourceImage.altText,
        draft.title,
      ]);
    }
    if (block.sourceController.text.trim().isEmpty) {
      block.sourceController.text = sourceImage.originalUrl;
    }
  }

  Object? _contentBlockFromAiItem(AdminNewsAiItem item) {
    switch (item.type) {
      case 'text':
        final block = ArticleTextBlockEntry();
        block.titleController.text = item.title;
        block.sourceController.text = item.source;
        adminSetQuillHtml(block.editorController, item.descriptionHtml);
        return block;
      case 'image':
        final block = ArticleImageBlockEntry();
        block.titleController.text = item.title;
        block.altTextController.text = item.altText;
        block.sourceController.text = item.source;
        adminSetQuillHtml(block.captionController, item.descriptionHtml);
        return block;
      case 'slider':
        final block = ArticleSliderImageBlockEntry();
        block.titleController.text = item.title;
        block.sourceController.text = item.source;
        adminSetQuillHtml(block.captionController, item.descriptionHtml);
        return block;
      case 'video':
        final block = ArticleVideoBlockEntry();
        block.titleController.text = item.title;
        block.sourceController.text = item.source;
        adminSetQuillHtml(block.descriptionController, item.descriptionHtml);
        return block;
      case 'audio':
        final block = ArticleAudioBlockEntry();
        block.titleController.text = item.title;
        block.sourceController.text = item.source;
        adminSetQuillHtml(block.descriptionController, item.descriptionHtml);
        return block;
      case 'file':
        final block = ArticleFileBlockEntry();
        block.titleController.text = item.title;
        block.sourceController.text = item.source;
        adminSetQuillHtml(block.descriptionController, item.descriptionHtml);
        return block;
      case 'social':
        final block = ArticleSocialBlockEntry();
        block.titleController.text = item.title;
        block.sourceController.text = item.source;
        adminSetQuillHtml(block.contentController, item.descriptionHtml);
        return block;
      case 'flipcard':
        final block = ArticleFlipcardBlockEntry();
        block.titleController.text = item.title;
        block.frontTitleController.text = item.frontTitle;
        block.backTitleController.text = item.backTitle;
        block.sourceController.text = item.source;
        adminSetQuillHtml(block.descriptionController, item.descriptionHtml);
        adminSetQuillHtml(
          block.frontDescriptionController,
          item.frontDescriptionHtml,
        );
        adminSetQuillHtml(
          block.backDescriptionController,
          item.backDescriptionHtml,
        );
        return block;
      case 'beforeafter':
        final block = ArticleBeforeAfterBlockEntry(
          beforeLabel: item.beforeLabel.isEmpty
              ? context.t('newsAdd.beforeAfterBeforeDefault')
              : item.beforeLabel,
          afterLabel: item.afterLabel.isEmpty
              ? context.t('newsAdd.beforeAfterAfterDefault')
              : item.afterLabel,
        );
        block.titleController.text = item.title;
        block.sourceController.text = item.source;
        adminSetQuillHtml(block.descriptionController, item.descriptionHtml);
        return block;
      case 'poll':
        final answers = item.options.isEmpty
            ? const <String>[]
            : item.options.take(6).toList();
        final block = PollQuestionBlockEntry(
          answerCount: answers.isEmpty ? 2 : answers.length,
        );
        block.titleController.text = item.title;
        block.sourceController.text = item.source;
        adminSetQuillHtml(block.descriptionController, item.descriptionHtml);
        for (
          var index = 0;
          index < answers.length && index < block.answers.length;
          index++
        ) {
          block.answers[index].answerController.text = answers[index];
        }
        return block;
      case 'vs':
        final left = item.options.isNotEmpty
            ? item.options[0]
            : context.t('newsAdd.vsLeftDefault');
        final right = item.options.length > 1
            ? item.options[1]
            : context.t('newsAdd.vsRightDefault');
        final block = ArticleVsBlockEntry(leftLabel: left, rightLabel: right);
        block.titleController.text = item.title;
        block.sourceController.text = item.source;
        adminSetQuillHtml(block.descriptionController, item.descriptionHtml);
        return block;
      case 'review':
        final block = ArticleReviewBlockEntry(
          designLabel: context.t('newsAdd.reviewCriterionDesign'),
          performanceLabel: context.t('newsAdd.reviewCriterionPerformance'),
        );
        block.productNameController.text = item.title;
        block.sourceController.text = item.source;
        adminSetQuillHtml(block.verdictController, item.descriptionHtml);
        if (item.pros.isNotEmpty) _replaceReviewTexts(block.pros, item.pros);
        if (item.cons.isNotEmpty) _replaceReviewTexts(block.cons, item.cons);
        if (item.criteria.isNotEmpty) {
          _replaceReviewCriteria(block.criteria, [
            for (final criterion in item.criteria)
              {'label': criterion.label, 'score': criterion.score},
          ]);
        }
        return block;
      case 'quote':
        final block = ArticleQuoteBlockEntry();
        block.authorController.text = item.title;
        block.sourceController.text = item.source;
        adminSetQuillHtml(block.quoteController, item.descriptionHtml);
        return block;
      case 'iframe':
        final block = ArticleIframeBlockEntry();
        block.titleController.text = item.title;
        block.sourceController.text = item.source;
        return block;
    }
    return null;
  }

  List<Widget> _buildTabBody() {
    switch (_activeTab) {
      case NewsAddFormatTab.article:
        return _buildArticleTabBody();
      case NewsAddFormatTab.quiz:
        return _buildQuizTabBody();
      case NewsAddFormatTab.poll:
        return _buildPollTabBody();
      case NewsAddFormatTab.video:
        return _buildVideoTabBody();
      case NewsAddFormatTab.contents:
        return _buildContentsTabBody();
      case NewsAddFormatTab.recipe:
        return _buildRecipeTabBody();
      case NewsAddFormatTab.event:
        return _buildEventTabBody();
    }
  }

  // ── Tab: Article ──────────────────────────────────────────────────────────
  List<Widget> _buildArticleTabBody() {
    final blocks = switch (_articleSort) {
      _Sort.asc || _Sort.hide => _articleBlocks,
      _Sort.desc => _articleBlocks.reversed.toList(),
    };

    return [
      _SortControls(
        active: _articleSort,
        onChanged: (value) => setState(() => _articleSort = value),
      ),
      const SizedBox(height: 18),
      for (var i = 0; i < blocks.length; i++) ...[
        _buildArticleBlockCard(
          blocks[i],
          i,
          blocks.length,
          _articleBlocks,
          _articleSort,
        ),
        if (i != blocks.length - 1) const SizedBox(height: 16),
      ],
      const SizedBox(height: 22),
      _AddItemButtonsRow(
        onTextAdd: _handleAddArticleTextBlock,
        onImageAdd: _handleAddArticleImageBlock,
        onSliderImageAdd: _handleAddArticleSliderImageBlock,
        onVideoAdd: _handleAddArticleVideoBlock,
        onAudioAdd: _handleAddArticleAudioBlock,
        onFileAdd: _handleAddArticleFileBlock,
        onSocialAdd: _handleAddArticleSocialBlock,
        onFlipcardAdd: _handleAddArticleFlipcardBlock,
        onBeforeAfterAdd: _handleAddArticleBeforeAfterBlock,
        onPollAdd: _handleAddArticlePollBlock,
        onVsAdd: _handleAddArticleVsBlock,
        onReviewAdd: _handleAddArticleReviewBlock,
        onQuoteAdd: _handleAddArticleQuoteBlock,
        onIframeAdd: _handleAddArticleIframeBlock,
      ),
    ];
  }

  Widget _buildArticleBlockCard(
    Object block,
    int visibleIndex,
    int blockCount,
    List<Object> targetBlocks,
    _Sort activeSort,
  ) {
    final blockNumber = activeSort == _Sort.hide
        ? null
        : (activeSort == _Sort.desc
              ? blockCount - visibleIndex
              : visibleIndex + 1);
    final canMoveUp = blockCount > 1 && visibleIndex > 0;
    final canMoveDown = blockCount > 1 && visibleIndex < blockCount - 1;

    if (block is ArticleTextBlockEntry) {
      return ArticleTextBlockCard(
        blockTitleController: block.titleController,
        editorController: block.editorController,
        sourceController: block.sourceController,
        blockNumber: blockNumber,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canDelete: _canRemoveContentBlock(targetBlocks, block),
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onToggleExtraSettings: () =>
            _handleToggleArticleTextBlockSettings(block),
      );
    }

    if (block is ArticleImageBlockEntry) {
      return ArticleImageBlockCard(
        blockTitleController: block.titleController,
        captionController: block.captionController,
        altTextController: block.altTextController,
        sourceController: block.sourceController,
        blockNumber: blockNumber,
        imageUrl: block.imageUrl,
        showOnHomepage: block.showOnHomepage,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onImageChanged: (imageUrl) =>
            _handleArticleImageChanged(block, imageUrl),
        onShowOnHomepageChanged: (value) =>
            _handleArticleImageHomeChanged(block, value),
        onToggleExtraSettings: () =>
            _handleToggleArticleImageBlockSettings(block),
      );
    }

    if (block is ArticleSliderImageBlockEntry) {
      return ArticleSliderImageBlockCard(
        blockTitleController: block.titleController,
        sourceController: block.sourceController,
        captionController: block.captionController,
        blockNumber: blockNumber,
        imageUrls: block.imageUrls,
        showOnHomepage: block.showOnHomepage,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onImagesAdded: (imageUrls) =>
            _handleArticleSliderImagesAdded(block, imageUrls),
        onImageReplaced: (index, imageUrl) =>
            _handleArticleSliderImageReplaced(block, index, imageUrl),
        onImageRemoved: (index) =>
            _handleArticleSliderImageRemoved(block, index),
        onShowOnHomepageChanged: (value) =>
            _handleArticleSliderImageHomeChanged(block, value),
        onToggleExtraSettings: () =>
            _handleToggleArticleSliderImageBlockSettings(block),
      );
    }

    if (block is ArticleVideoBlockEntry) {
      return ArticleVideoBlockCard(
        blockTitleController: block.titleController,
        sourceController: block.sourceController,
        descriptionController: block.descriptionController,
        mediaUrl: block.mediaUrl,
        blockNumber: blockNumber,
        showOnHomepage: block.showOnHomepage,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onVideoChanged: (videoUrl) =>
            _handleArticleVideoChanged(block, videoUrl),
        onShowOnHomepageChanged: (value) =>
            _handleArticleVideoHomeChanged(block, value),
        onToggleExtraSettings: () =>
            _handleToggleArticleVideoBlockSettings(block),
      );
    }

    if (block is ArticleAudioBlockEntry) {
      return ArticleAudioBlockCard(
        blockTitleController: block.titleController,
        sourceController: block.sourceController,
        descriptionController: block.descriptionController,
        mediaUrl: block.mediaUrl,
        blockNumber: blockNumber,
        showOnHomepage: block.showOnHomepage,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onAudioChanged: (audioUrl) =>
            _handleArticleAudioChanged(block, audioUrl),
        onShowOnHomepageChanged: (value) =>
            _handleArticleAudioHomeChanged(block, value),
        onToggleExtraSettings: () =>
            _handleToggleArticleAudioBlockSettings(block),
      );
    }

    if (block is ArticleFileBlockEntry) {
      return ArticleFileBlockCard(
        blockTitleController: block.titleController,
        sourceController: block.sourceController,
        descriptionController: block.descriptionController,
        mediaUrl: block.mediaUrl,
        blockNumber: blockNumber,
        showOnHomepage: block.showOnHomepage,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onFileChanged: (fileUrl) => _handleArticleFileChanged(block, fileUrl),
        onShowOnHomepageChanged: (value) =>
            _handleArticleFileHomeChanged(block, value),
        onToggleExtraSettings: () =>
            _handleToggleArticleFileBlockSettings(block),
      );
    }

    if (block is ArticleSocialBlockEntry) {
      return ArticleSocialBlockCard(
        blockTitleController: block.titleController,
        embedController: block.embedController,
        sourceController: block.sourceController,
        contentController: block.contentController,
        blockNumber: blockNumber,
        showOnHomepage: block.showOnHomepage,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onShowOnHomepageChanged: (value) =>
            _handleArticleSocialHomeChanged(block, value),
        onToggleExtraSettings: () =>
            _handleToggleArticleSocialBlockSettings(block),
      );
    }

    if (block is ArticleFlipcardBlockEntry) {
      return ArticleFlipcardBlockCard(
        blockTitleController: block.titleController,
        frontTitleController: block.frontTitleController,
        frontLinkController: block.frontLinkController,
        frontDescriptionController: block.frontDescriptionController,
        backTitleController: block.backTitleController,
        backLinkController: block.backLinkController,
        backDescriptionController: block.backDescriptionController,
        sourceController: block.sourceController,
        descriptionController: block.descriptionController,
        frontImageUrl: block.frontImageUrl,
        backImageUrl: block.backImageUrl,
        blockNumber: blockNumber,
        showOnHomepage: block.showOnHomepage,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onFrontImageChanged: (imageUrl) =>
            _handleArticleFlipcardFrontImageChanged(block, imageUrl),
        onBackImageChanged: (imageUrl) =>
            _handleArticleFlipcardBackImageChanged(block, imageUrl),
        onShowOnHomepageChanged: (value) =>
            _handleArticleFlipcardHomeChanged(block, value),
        onToggleExtraSettings: () =>
            _handleToggleArticleFlipcardBlockSettings(block),
      );
    }

    if (block is ArticleBeforeAfterBlockEntry) {
      return ArticleBeforeAfterBlockCard(
        blockTitleController: block.titleController,
        beforeLabelController: block.beforeLabelController,
        afterLabelController: block.afterLabelController,
        sourceController: block.sourceController,
        descriptionController: block.descriptionController,
        beforeImageUrl: block.beforeImageUrl,
        afterImageUrl: block.afterImageUrl,
        blockNumber: blockNumber,
        showOnHomepage: block.showOnHomepage,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onBeforeImageChanged: (imageUrl) =>
            _handleArticleBeforeAfterBeforeImageChanged(block, imageUrl),
        onAfterImageChanged: (imageUrl) =>
            _handleArticleBeforeAfterAfterImageChanged(block, imageUrl),
        onShowOnHomepageChanged: (value) =>
            _handleArticleBeforeAfterHomeChanged(block, value),
        onToggleExtraSettings: () =>
            _handleToggleArticleBeforeAfterBlockSettings(block),
      );
    }

    if (block is ArticleVsBlockEntry) {
      return ArticleVsBlockCard(
        blockTitleController: block.titleController,
        sourceController: block.sourceController,
        descriptionController: block.descriptionController,
        options: block.options,
        mainImageUrl: block.mainImageUrl,
        blockNumber: blockNumber,
        showOnHomepage: block.showOnHomepage,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onMainImageChanged: (imageUrl) =>
            _handleArticleVsMainImageChanged(block, imageUrl),
        onOptionImageChanged: (index, imageUrl) =>
            _handleArticleVsOptionImageChanged(block, index, imageUrl),
        onShowOnHomepageChanged: (value) =>
            _handleArticleVsHomeChanged(block, value),
        onToggleExtraSettings: () => _handleToggleArticleVsBlockSettings(block),
      );
    }

    if (block is ArticleReviewBlockEntry) {
      return ArticleReviewBlockCard(
        productNameController: block.productNameController,
        sourceController: block.sourceController,
        verdictController: block.verdictController,
        pros: block.pros,
        cons: block.cons,
        criteria: block.criteria,
        imageUrl: block.imageUrl,
        score: block.score,
        blockNumber: blockNumber,
        showOnHomepage: block.showOnHomepage,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onImageChanged: (imageUrl) =>
            _handleArticleReviewImageChanged(block, imageUrl),
        onShowOnHomepageChanged: (value) =>
            _handleArticleReviewHomeChanged(block, value),
        onToggleExtraSettings: () =>
            _handleToggleArticleReviewBlockSettings(block),
        onProsAdd: () => _handleArticleReviewProsAdd(block),
        onProsRemove: (index) => _handleArticleReviewProsRemove(block, index),
        onConsAdd: () => _handleArticleReviewConsAdd(block),
        onConsRemove: (index) => _handleArticleReviewConsRemove(block, index),
        onCriterionAdd: () => _handleArticleReviewCriterionAdd(block),
        onCriterionRemove: (index) =>
            _handleArticleReviewCriterionRemove(block, index),
        onCriterionScoreChanged: (index, score) =>
            _handleArticleReviewCriterionScoreChanged(block, index, score),
      );
    }

    if (block is PollQuestionBlockEntry) {
      return PollQuestionBlockCard(
        titleController: block.titleController,
        descriptionController: block.descriptionController,
        sourceController: block.sourceController,
        answers: block.answers,
        blockNumber: blockNumber,
        imageUrl: block.imageUrl,
        layout: block.layout,
        showOnHomepage: block.showOnHomepage,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onLayoutChanged: (value) =>
            _handleContentPollQuestionLayoutChanged(block, value),
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onImageChanged: (imageUrl) =>
            _handlePollQuestionImageChanged(block, imageUrl),
        onShowOnHomepageChanged: (value) =>
            _handlePollQuestionHomeChanged(block, value),
        onToggleExtraSettings: () => _handleTogglePollQuestionSettings(block),
        onAnswerImageChanged: (answer, imageUrl) =>
            _handlePollAnswerImageChanged(block, answer, imageUrl),
        onRemoveAnswer: (answer) => _handleRemovePollAnswer(block, answer),
        onAddAnswer: () => _handleAddPollAnswer(block),
      );
    }

    if (block is ArticleQuoteBlockEntry) {
      return ArticleQuoteBlockCard(
        authorController: block.authorController,
        sourceController: block.sourceController,
        quoteController: block.quoteController,
        blockNumber: blockNumber,
        showOnHomepage: block.showOnHomepage,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onShowOnHomepageChanged: (value) =>
            _handleArticleQuoteHomeChanged(block, value),
        onToggleExtraSettings: () =>
            _handleToggleArticleQuoteBlockSettings(block),
      );
    }

    if (block is ArticleIframeBlockEntry) {
      return ArticleIframeBlockCard(
        titleController: block.titleController,
        embedController: block.embedController,
        sourceController: block.sourceController,
        blockNumber: blockNumber,
        showOnHomepage: block.showOnHomepage,
        extraSettingsExpanded: block.extraSettingsExpanded,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: () => _handleRemoveContentBlock(targetBlocks, block),
        onMoveUp: () =>
            _handleMoveContentBlock(targetBlocks, block, -1, activeSort),
        onMoveDown: () =>
            _handleMoveContentBlock(targetBlocks, block, 1, activeSort),
        onShowOnHomepageChanged: (value) =>
            _handleArticleIframeHomeChanged(block, value),
        onToggleExtraSettings: () =>
            _handleToggleArticleIframeBlockSettings(block),
      );
    }

    return const SizedBox.shrink();
  }

  // ── Tab: Quiz ─────────────────────────────────────────────────────────────
  List<Widget> _buildQuizTabBody() {
    final visibleResults = _visibleQuizResults;
    final resultCount = visibleResults.length;
    final visibleQuestions = _visibleQuizQuestions;
    final questionCount = visibleQuestions.length;
    final resultOptions = _quizResultOptions;

    return [
      _QuizSubTabsCard(
        subTab: _quizSubTab,
        onChanged: (value) => setState(() => _quizSubTab = value),
      ),
      const SizedBox(height: 18),
      for (var index = 0; index < visibleResults.length; index++) ...[
        QuizResultBlockCard(
          titleController: visibleResults[index].titleController,
          minScoreController: visibleResults[index].minScoreController,
          maxScoreController: visibleResults[index].maxScoreController,
          descriptionController: visibleResults[index].descriptionController,
          blockNumber: _quizSort == NewsAddQuizSort.hide
              ? null
              : (_quizSort == NewsAddQuizSort.desc
                    ? resultCount - index
                    : index + 1),
          imageUrl: visibleResults[index].imageUrl,
          showScoreRange: _quizQuestionType != QuizQuestionType.personality,
          canMoveUp: resultCount > 1 && index > 0,
          canMoveDown: resultCount > 1 && index < resultCount - 1,
          onDelete: () => _handleRemoveQuizResult(visibleResults[index]),
          onMoveUp: () => _handleMoveQuizResult(visibleResults[index], -1),
          onMoveDown: () => _handleMoveQuizResult(visibleResults[index], 1),
          onImageChanged: (imageUrl) =>
              _handleQuizResultImageChanged(visibleResults[index], imageUrl),
        ),
        const SizedBox(height: 16),
      ],
      _AddResultButton(onPressed: _handleAddQuizResult),
      const SizedBox(height: 20),
      _QuizSortToolbar(
        active: _quizSort,
        onChanged: (value) => setState(() => _quizSort = value),
      ),
      const SizedBox(height: 18),
      for (var index = 0; index < visibleQuestions.length; index++) ...[
        QuizQuestionBlockCard(
          titleController: visibleQuestions[index].titleController,
          descriptionController: visibleQuestions[index].descriptionController,
          answers: visibleQuestions[index].answers,
          blockNumber: _quizSort == NewsAddQuizSort.hide
              ? null
              : (_quizSort == NewsAddQuizSort.desc
                    ? questionCount - index
                    : index + 1),
          imageUrl: visibleQuestions[index].imageUrl,
          quizType: _quizQuestionType,
          resultOptions: resultOptions,
          layout: visibleQuestions[index].layout,
          endDateController: _quizEndDateController,
          allowMulti: _pollAllowMulti,
          showResults: _pollShowResults,
          canMoveUp: questionCount > 1 && index > 0,
          canMoveDown: questionCount > 1 && index < questionCount - 1,
          onLayoutChanged: (value) =>
              _handleQuizQuestionLayoutChanged(visibleQuestions[index], value),
          onAllowMultiChanged: (v) => setState(() => _pollAllowMulti = v),
          onShowResultsChanged: (v) => setState(() => _pollShowResults = v),
          onDelete: () => _handleRemoveQuizQuestion(visibleQuestions[index]),
          onMoveUp: () => _handleMoveQuizQuestion(visibleQuestions[index], -1),
          onMoveDown: () => _handleMoveQuizQuestion(visibleQuestions[index], 1),
          onImageChanged: (imageUrl) => _handleQuizQuestionImageChanged(
            visibleQuestions[index],
            imageUrl,
          ),
          onAnswerImageChanged: (answer, imageUrl) =>
              _handleQuizAnswerImageChanged(
                visibleQuestions[index],
                answer,
                imageUrl,
              ),
          onAnswerResultChanged: (answer, resultId) =>
              _handleQuizAnswerResultChanged(
                visibleQuestions[index],
                answer,
                resultId,
              ),
          onAnswerCorrectChanged: (answer, isCorrect) =>
              _handleQuizAnswerCorrectChanged(
                visibleQuestions[index],
                answer,
                isCorrect,
              ),
          onRemoveAnswer: (answer) =>
              _handleRemoveQuizAnswer(visibleQuestions[index], answer),
          onAddAnswer: () => _handleAddQuizAnswer(visibleQuestions[index]),
        ),
        const SizedBox(height: 16),
      ],
      _AddQuizQuestionButton(onPressed: _handleAddQuizQuestion),
    ];
  }

  // ── Tab: Poll ─────────────────────────────────────────────────────────────
  List<Widget> _buildPollTabBody() {
    final visibleQuestions = _visiblePollQuestions;
    final questionCount = visibleQuestions.length;

    return [
      _QuizSortToolbar(
        active: _pollSort,
        onChanged: (value) => setState(() => _pollSort = value),
      ),
      const SizedBox(height: 18),
      for (var index = 0; index < visibleQuestions.length; index++) ...[
        PollQuestionBlockCard(
          titleController: visibleQuestions[index].titleController,
          descriptionController: visibleQuestions[index].descriptionController,
          sourceController: visibleQuestions[index].sourceController,
          answers: visibleQuestions[index].answers,
          blockNumber: _pollSort == NewsAddQuizSort.hide
              ? null
              : (_pollSort == NewsAddQuizSort.desc
                    ? questionCount - index
                    : index + 1),
          imageUrl: visibleQuestions[index].imageUrl,
          layout: visibleQuestions[index].layout,
          showOnHomepage: visibleQuestions[index].showOnHomepage,
          extraSettingsExpanded: visibleQuestions[index].extraSettingsExpanded,
          canMoveUp: questionCount > 1 && index > 0,
          canMoveDown: questionCount > 1 && index < questionCount - 1,
          onLayoutChanged: (value) =>
              _handlePollQuestionLayoutChanged(visibleQuestions[index], value),
          onDelete: () => _handleRemovePollQuestion(visibleQuestions[index]),
          onMoveUp: () => _handleMovePollQuestion(visibleQuestions[index], -1),
          onMoveDown: () => _handleMovePollQuestion(visibleQuestions[index], 1),
          onImageChanged: (imageUrl) => _handlePollQuestionImageChanged(
            visibleQuestions[index],
            imageUrl,
          ),
          onShowOnHomepageChanged: (value) =>
              _handlePollQuestionHomeChanged(visibleQuestions[index], value),
          onToggleExtraSettings: () =>
              _handleTogglePollQuestionSettings(visibleQuestions[index]),
          onAnswerImageChanged: (answer, imageUrl) =>
              _handlePollAnswerImageChanged(
                visibleQuestions[index],
                answer,
                imageUrl,
              ),
          onRemoveAnswer: (answer) =>
              _handleRemovePollAnswer(visibleQuestions[index], answer),
          onAddAnswer: () => _handleAddPollAnswer(visibleQuestions[index]),
        ),
        const SizedBox(height: 16),
      ],
      PollQuestionAddButton(onPressed: _handleAddPollQuestion),
    ];
  }

  // ── Tab: Video ────────────────────────────────────────────────────────────
  List<Widget> _buildVideoTabBody() {
    final blocks = switch (_videoSort) {
      _Sort.asc || _Sort.hide => _videoBlocks,
      _Sort.desc => _videoBlocks.reversed.toList(),
    };

    return [
      _SortControls(
        active: _videoSort,
        onChanged: (value) => setState(() => _videoSort = value),
      ),
      const SizedBox(height: 18),
      for (var i = 0; i < blocks.length; i++) ...[
        _buildArticleBlockCard(
          blocks[i],
          i,
          blocks.length,
          _videoBlocks,
          _videoSort,
        ),
        if (i != blocks.length - 1) const SizedBox(height: 16),
      ],
      const SizedBox(height: 22),
      _AddItemButtonsRow(
        onTextAdd: () => _handleAddVideoContentBlock(ArticleTextBlockEntry()),
        onImageAdd: () => _handleAddVideoContentBlock(ArticleImageBlockEntry()),
        onSliderImageAdd: () =>
            _handleAddVideoContentBlock(ArticleSliderImageBlockEntry()),
        onVideoAdd: () => _handleAddVideoContentBlock(ArticleVideoBlockEntry()),
        onAudioAdd: () => _handleAddVideoContentBlock(ArticleAudioBlockEntry()),
        onFileAdd: () => _handleAddVideoContentBlock(ArticleFileBlockEntry()),
        onSocialAdd: () =>
            _handleAddVideoContentBlock(ArticleSocialBlockEntry()),
        onFlipcardAdd: () =>
            _handleAddVideoContentBlock(ArticleFlipcardBlockEntry()),
        onBeforeAfterAdd: () => _handleAddVideoContentBlock(
          ArticleBeforeAfterBlockEntry(
            beforeLabel: context.t('newsAdd.beforeAfterBeforeDefault'),
            afterLabel: context.t('newsAdd.beforeAfterAfterDefault'),
          ),
        ),
        onPollAdd: () => _handleAddVideoContentBlock(PollQuestionBlockEntry()),
        onVsAdd: () => _handleAddVideoContentBlock(
          ArticleVsBlockEntry(
            leftLabel: context.t('newsAdd.vsLeftDefault'),
            rightLabel: context.t('newsAdd.vsRightDefault'),
          ),
        ),
        onReviewAdd: () => _handleAddVideoContentBlock(
          ArticleReviewBlockEntry(
            designLabel: context.t('newsAdd.reviewCriterionDesign'),
            performanceLabel: context.t('newsAdd.reviewCriterionPerformance'),
          ),
        ),
        onQuoteAdd: () => _handleAddVideoContentBlock(ArticleQuoteBlockEntry()),
        onIframeAdd: () =>
            _handleAddVideoContentBlock(ArticleIframeBlockEntry()),
      ),
    ];
  }

  // ── Tab: Contents (TOC) ───────────────────────────────────────────────────
  List<Widget> _buildContentsTabBody() {
    return [
      ArticleTableOfContentsBlockCard(
        entry: _tocBlock,
        onStyleChanged: _handleTocStyleChanged,
        onShowStyleChanged: _handleTocShowStyleChanged,
        onAddItem: _handleAddTocItem,
        onRemoveItem: _handleRemoveTocItem,
        onMoveItem: _handleMoveTocItem,
        onToggleItemCollapsed: _handleToggleTocItemCollapsed,
        onItemImageChanged: _handleTocItemImageChanged,
      ),
    ];
  }

  // ── Tab: Recipe ───────────────────────────────────────────────────────────
  List<Widget> _buildRecipeTabBody() {
    return [
      ArticleRecipeSettingsCard(
        entry: _recipeBlock,
        onDifficultyChanged: _handleRecipeDifficultyChanged,
      ),
      const SizedBox(height: 18),
      ArticleVideoBlockCard(
        blockTitleController: _recipeVideoBlock.titleController,
        sourceController: _recipeVideoBlock.sourceController,
        descriptionController: _recipeVideoBlock.descriptionController,
        mediaUrl: _recipeVideoBlock.mediaUrl,
        blockNumber: 1,
        showOnHomepage: _recipeVideoBlock.showOnHomepage,
        extraSettingsExpanded: _recipeVideoBlock.extraSettingsExpanded,
        canMoveUp: false,
        canMoveDown: false,
        onDelete: _handleClearRecipeVideoBlock,
        onMoveUp: () {},
        onMoveDown: () {},
        onVideoChanged: (videoUrl) =>
            _handleArticleVideoChanged(_recipeVideoBlock, videoUrl),
        onShowOnHomepageChanged: (value) =>
            _handleArticleVideoHomeChanged(_recipeVideoBlock, value),
        onToggleExtraSettings: () =>
            _handleToggleArticleVideoBlockSettings(_recipeVideoBlock),
        blockTitleKey: 'newsAdd.recipe.foodVideo',
        titleHintKey: 'newsAdd.recipe.foodVideoTitleHint',
      ),
      const SizedBox(height: 18),
      ArticleRecipeDetailsCard(
        entry: _recipeBlock,
        onAddIngredient: _handleAddRecipeIngredient,
        onRemoveIngredient: _handleRemoveRecipeIngredient,
        onAddNutrition: _handleAddRecipeNutrition,
        onRemoveNutrition: _handleRemoveRecipeNutrition,
        onAddDirection: _handleAddRecipeDirection,
        onRemoveDirection: _handleRemoveRecipeDirection,
        onMoveDirection: _handleMoveRecipeDirection,
        onToggleDirectionCollapsed: _handleToggleRecipeDirectionCollapsed,
        onDirectionImageChanged: _handleRecipeDirectionImageChanged,
      ),
    ];
  }

  // ── Tab: Event ────────────────────────────────────────────────────────────
  List<Widget> _buildEventTabBody() {
    return [
      ArticleEventSettingsCard(
        entry: _eventBlock,
        onRegistrationTypeChanged: _handleEventRegistrationTypeChanged,
      ),
      const SizedBox(height: 18),
      ArticleEventSectionsCard(
        entry: _eventBlock,
        onAddSchedule: _handleAddEventSchedule,
        onRemoveSchedule: _handleRemoveEventSchedule,
        onScheduleImageChanged: _handleEventScheduleImageChanged,
        onAddHighlight: _handleAddEventHighlight,
        onRemoveHighlight: _handleRemoveEventHighlight,
        onAddSpeaker: _handleAddEventSpeaker,
        onRemoveSpeaker: _handleRemoveEventSpeaker,
        onMoveSpeaker: _handleMoveEventSpeaker,
        onToggleSpeakerCollapsed: _handleToggleEventSpeakerCollapsed,
        onSpeakerImageChanged: _handleEventSpeakerImageChanged,
      ),
      if (_eventContentBlocks.isNotEmpty) const SizedBox(height: 18),
      for (var i = 0; i < _eventContentBlocks.length; i++) ...[
        _buildArticleBlockCard(
          _eventContentBlocks[i],
          i,
          _eventContentBlocks.length,
          _eventContentBlocks,
          _Sort.asc,
        ),
        if (i != _eventContentBlocks.length - 1) const SizedBox(height: 16),
      ],
      const SizedBox(height: 22),
      _AddItemButtonsRow(
        onTextAdd: () => _handleAddEventContentBlock(ArticleTextBlockEntry()),
        onImageAdd: () => _handleAddEventContentBlock(ArticleImageBlockEntry()),
        onSliderImageAdd: () =>
            _handleAddEventContentBlock(ArticleSliderImageBlockEntry()),
        onVideoAdd: () => _handleAddEventContentBlock(ArticleVideoBlockEntry()),
        onAudioAdd: () => _handleAddEventContentBlock(ArticleAudioBlockEntry()),
        onFileAdd: () => _handleAddEventContentBlock(ArticleFileBlockEntry()),
        onSocialAdd: () =>
            _handleAddEventContentBlock(ArticleSocialBlockEntry()),
        onFlipcardAdd: () =>
            _handleAddEventContentBlock(ArticleFlipcardBlockEntry()),
        onBeforeAfterAdd: () => _handleAddEventContentBlock(
          ArticleBeforeAfterBlockEntry(
            beforeLabel: context.t('newsAdd.beforeAfterBeforeDefault'),
            afterLabel: context.t('newsAdd.beforeAfterAfterDefault'),
          ),
        ),
        onPollAdd: () => _handleAddEventContentBlock(PollQuestionBlockEntry()),
        onVsAdd: () => _handleAddEventContentBlock(
          ArticleVsBlockEntry(
            leftLabel: context.t('newsAdd.vsLeftDefault'),
            rightLabel: context.t('newsAdd.vsRightDefault'),
          ),
        ),
        onReviewAdd: () => _handleAddEventContentBlock(
          ArticleReviewBlockEntry(
            designLabel: context.t('newsAdd.reviewCriterionDesign'),
            performanceLabel: context.t('newsAdd.reviewCriterionPerformance'),
          ),
        ),
        onQuoteAdd: () => _handleAddEventContentBlock(ArticleQuoteBlockEntry()),
        onIframeAdd: () =>
            _handleAddEventContentBlock(ArticleIframeBlockEntry()),
      ),
    ];
  }

  // ── Sidebar ───────────────────────────────────────────────────────────────
  Widget _buildSidebar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CoverCard(
          imageUrl: _coverImageUrl,
          altController: _coverAltController,
          onImageChanged: (value) => setState(() => _coverImageUrl = value),
        ),
        const SizedBox(height: 18),
        _CategorySettingsCard(
          languageCode: _languageCode,
          mainCategory: _mainCategory,
          subCategory: _subCategory,
          thirdCategory: _thirdCategory,
          languages: _bootstrap.languages,
          mainCategories: _rootCategoriesForLanguage(_languageCode),
          subCategories: _childrenOfCategory(_mainCategory),
          thirdCategories: _childrenOfCategory(_subCategory),
          onLanguageChanged: (value) => setState(() {
            _languageCode = value ?? 'tr';
            final roots = _rootCategoriesForLanguage(_languageCode);
            _mainCategory = roots.isEmpty ? '' : roots.first.label;
            _subCategory = null;
            _thirdCategory = null;
            _autoSubCategory = null;
          }),
          onMainChanged: (value) => setState(() {
            _mainCategory = value ?? '';
            _subCategory = null;
            _thirdCategory = null;
            _autoSubCategory = null;
          }),
          onSubChanged: (value) => setState(() {
            _subCategory = value?.trim().isEmpty ?? true ? null : value;
            _thirdCategory = null;
            _autoSubCategory = null;
          }),
          onThirdChanged: (value) => setState(() {
            _thirdCategory = value?.trim().isEmpty ?? true ? null : value;
            _autoSubCategory = null;
          }),
        ),
        const SizedBox(height: 18),
        _PublishCard(
          factCheck: _factCheck,
          publishAtController: _publishAtController,
          saving: _saving,
          onFactCheckChanged: (value) => setState(() => _factCheck = value),
          onSaveDraft: () => unawaited(_handleSave('draft')),
          onPublish: () => unawaited(_handleSave('published')),
          onSchedule: () => unawaited(_handleSave('published')),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Reusable: card container, labels, inputs
// ──────────────────────────────────────────────────────────────────────────────

class _NewsAddStatusCard extends StatelessWidget {
  const _NewsAddStatusCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: AppColors.actionRed,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _PillButton(
            icon: Icons.refresh,
            label: 'newsAdd.retry',
            onTap: onRetry,
            background: AppColors.deepOcean,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.padding});

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
        border: Border.all(color: _newsAddStrongLine),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.iconColor = AppColors.actionRed,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _newsAddSoftLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t(title),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: _newsAddTabMuted),
            const SizedBox(width: 6),
          ],
          Text(
            context.t(text),
            style: const TextStyle(
              color: _newsAddTabMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextInputBox extends StatelessWidget {
  const _TextInputBox({
    required this.controller,
    required this.hintTextKey,
    this.maxLines = 1,
    this.minLines,
    this.bold = false,
    this.fontSize = 14,
  });

  final TextEditingController controller;
  final String hintTextKey;
  final int? maxLines;
  final int? minLines;
  final bool bold;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _newsAddStrongLine),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
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

class _ToggleSwitch extends StatelessWidget {
  const _ToggleSwitch({
    required this.value,
    required this.onChanged,
    this.activeColor = AppColors.actionRed,
    this.showCheckIcon = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final bool showCheckIcon;

  @override
  Widget build(BuildContext context) {
    final width = showCheckIcon ? 42.0 : 38.0;
    final height = showCheckIcon ? 24.0 : 22.0;
    final padding = showCheckIcon ? 3.0 : 2.5;
    final knobSize = showCheckIcon ? 18.0 : 15.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: width,
          height: height,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: value ? activeColor : AppColors.softLine,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: value
                  ? activeColor
                  : AppColors.line.withValues(alpha: 0.9),
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: knobSize,
              height: knobSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: showCheckIcon
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
              ),
              child: value && showCheckIcon
                  ? SymbolIcon(Symbols.check, color: activeColor, size: 12)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.background = AppColors.actionRed,
    this.foreground = Colors.white,
    this.height = 36,
    this.borderColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final double height;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.62,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: borderColor == null
                  ? null
                  : Border.all(color: borderColor!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 8),
                Text(
                  context.t(label),
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
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

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    this.leadingIcon,
  });

  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.any((item) => item.value == value)
        ? value
        : (items.isEmpty ? null : items.first.value);

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
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 14, color: AppColors.iconMuted),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: safeValue,
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
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'PateezSans',
                    letterSpacing: 0,
                  ),
                  items: items,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Header
// ──────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({this.onBack, this.onClear, this.onNewsTap});

  final VoidCallback? onBack;
  final VoidCallback? onClear;
  final VoidCallback? onNewsTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final titleGroup = Row(
            children: [
              if (onBack != null) ...[
                _BackButton(onTap: onBack!),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('newsAdd.title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t('newsAdd.subtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = _HeaderActions(
            onClear: onClear,
            onNewsTap: onNewsTap,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleGroup,
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: titleGroup),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({this.onClear, this.onNewsTap});

  final VoidCallback? onClear;
  final VoidCallback? onNewsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PillButton(
          icon: Icons.cleaning_services_outlined,
          label: 'newsAdd.clear',
          onTap: onClear,
          background: Colors.white,
          foreground: AppColors.inkSoft,
          borderColor: AppColors.line,
        ),
        const SizedBox(width: 10),
        _PillButton(
          icon: Icons.list_alt_outlined,
          label: 'newsAdd.newsList',
          onTap: onNewsTap,
          background: AppColors.deepOcean,
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line),
          ),
          child: const RotatedBox(
            quarterTurns: 2,
            child: SymbolIcon(
              Symbols.arrow_forward,
              color: AppColors.deepOcean,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Format Tabs strip (lives inside main content card)
// ──────────────────────────────────────────────────────────────────────────────

class _FormatTabsStrip extends StatelessWidget {
  const _FormatTabsStrip({required this.active, required this.onChanged});

  final NewsAddFormatTab active;
  final ValueChanged<NewsAddFormatTab> onChanged;

  static const _tabs = <_TabInfo>[
    _TabInfo(
      NewsAddFormatTab.article,
      Icons.description_outlined,
      'newsAdd.tab.article',
    ),
    _TabInfo(
      NewsAddFormatTab.quiz,
      Icons.fact_check_outlined,
      'newsAdd.tab.quiz',
    ),
    _TabInfo(
      NewsAddFormatTab.poll,
      Icons.bar_chart_outlined,
      'newsAdd.tab.poll',
    ),
    _TabInfo(
      NewsAddFormatTab.video,
      Icons.play_circle_outline,
      'newsAdd.tab.video',
    ),
    _TabInfo(
      NewsAddFormatTab.contents,
      Icons.format_list_numbered,
      'newsAdd.tab.contents',
    ),
    _TabInfo(
      NewsAddFormatTab.recipe,
      Icons.restaurant_outlined,
      'newsAdd.tab.recipe',
    ),
    _TabInfo(
      NewsAddFormatTab.event,
      Icons.calendar_today_outlined,
      'newsAdd.tab.event',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(AppRadius.value),
        topRight: Radius.circular(AppRadius.value),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _newsAddStrongLine)),
        ),
        height: 102,
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++) ...[
              Expanded(
                child: _FormatTabButton(
                  info: _tabs[i],
                  selected: _tabs[i].id == active,
                  onTap: () => onChanged(_tabs[i].id),
                ),
              ),
              if (i != _tabs.length - 1)
                Container(width: 1, color: _newsAddSoftLine),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabInfo {
  const _TabInfo(this.id, this.icon, this.label);
  final NewsAddFormatTab id;
  final IconData icon;
  final String label;
}

class _FormatTabButton extends StatelessWidget {
  const _FormatTabButton({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final _TabInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.deepOcean;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              color: selected ? const Color(0xFFF3F6F8) : Colors.transparent,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(info.icon, color: color, size: selected ? 25 : 24),
                    const SizedBox(height: 8),
                    Text(
                      context.t(info.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selected)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 2, color: AppColors.actionRed),
              ),
            if (selected)
              Positioned(
                bottom: 1,
                child: ClipPath(
                  clipper: _UpTriangleClipper(),
                  child: Container(
                    width: 18,
                    height: 9,
                    color: AppColors.actionRed,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ──────────────────────────────────────────────────────────────────────────────
// Dashed rectangle painter (for image/media upload areas)
// ──────────────────────────────────────────────────────────────────────────────

class DashedRect extends StatelessWidget {
  const DashedRect({
    super.key,
    required this.child,
    this.color = _newsAddStrongLine,
    this.strokeWidth = 1.25,
    this.dashWidth = 7,
    this.dashSpace = 4,
    this.radius = AppRadius.value,
  });

  final Widget child;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        dashSpace: dashSpace,
        radius: radius,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rect);
    final dashed = _dashPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, double dashLen, double spaceLen) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLen;
        dest.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + spaceLen;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashWidth != dashWidth ||
      old.dashSpace != dashSpace ||
      old.radius != radius;
}

// ──────────────────────────────────────────────────────────────────────────────
// Content Info card
// ──────────────────────────────────────────────────────────────────────────────

class _ContentInfoCard extends StatelessWidget {
  const _ContentInfoCard({
    required this.activeTab,
    required this.onTabChanged,
    required this.titleController,
    required this.summaryController,
    required this.seoTitleController,
    required this.slugController,
    required this.metaDescriptionController,
    required this.focusKeywordsController,
    required this.schemaType,
    required this.keywords,
    required this.mansetSlider,
    required this.pinToTop,
    required this.onMansetChanged,
    required this.onPinChanged,
    required this.onSchemaChanged,
    required this.onKeywordSubmitted,
    required this.onKeywordRemoved,
    required this.faqEntries,
    required this.onAddFaq,
    required this.onRemoveFaq,
    required this.onAiGenerate,
  });

  final NewsAddFormatTab activeTab;
  final ValueChanged<NewsAddFormatTab> onTabChanged;
  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController seoTitleController;
  final TextEditingController slugController;
  final TextEditingController metaDescriptionController;
  final TextEditingController focusKeywordsController;
  final String schemaType;
  final List<String> keywords;
  final bool mansetSlider;
  final bool pinToTop;
  final ValueChanged<bool> onMansetChanged;
  final ValueChanged<bool> onPinChanged;
  final ValueChanged<String?> onSchemaChanged;
  final ValueChanged<String> onKeywordSubmitted;
  final ValueChanged<String> onKeywordRemoved;
  final List<_FaqEntry> faqEntries;
  final VoidCallback onAddFaq;
  final ValueChanged<_FaqEntry> onRemoveFaq;
  final VoidCallback onAiGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _newsAddStrongLine),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FormatTabsStrip(active: activeTab, onChanged: onTabChanged),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  icon: Icons.description_outlined,
                  title: 'newsAdd.contentInfo',
                  trailing: _HeaderToggles(
                    mansetSlider: mansetSlider,
                    pinToTop: pinToTop,
                    onMansetChanged: onMansetChanged,
                    onPinChanged: onPinChanged,
                    onAiGenerate: onAiGenerate,
                  ),
                ),
                const SizedBox(height: 22),
                _FormBody(
                  titleController: titleController,
                  summaryController: summaryController,
                  seoTitleController: seoTitleController,
                  slugController: slugController,
                  metaDescriptionController: metaDescriptionController,
                  focusKeywordsController: focusKeywordsController,
                  schemaType: schemaType,
                  keywords: keywords,
                  onSchemaChanged: onSchemaChanged,
                  onKeywordSubmitted: onKeywordSubmitted,
                  onKeywordRemoved: onKeywordRemoved,
                  faqEntries: faqEntries,
                  onAddFaq: onAddFaq,
                  onRemoveFaq: onRemoveFaq,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.titleController,
    required this.summaryController,
    required this.seoTitleController,
    required this.slugController,
    required this.metaDescriptionController,
    required this.focusKeywordsController,
    required this.schemaType,
    required this.keywords,
    required this.onSchemaChanged,
    required this.onKeywordSubmitted,
    required this.onKeywordRemoved,
    required this.faqEntries,
    required this.onAddFaq,
    required this.onRemoveFaq,
  });

  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController seoTitleController;
  final TextEditingController slugController;
  final TextEditingController metaDescriptionController;
  final TextEditingController focusKeywordsController;
  final String schemaType;
  final List<String> keywords;
  final ValueChanged<String?> onSchemaChanged;
  final ValueChanged<String> onKeywordSubmitted;
  final ValueChanged<String> onKeywordRemoved;
  final List<_FaqEntry> faqEntries;
  final VoidCallback onAddFaq;
  final ValueChanged<_FaqEntry> onRemoveFaq;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('newsAdd.articleTitle'),
        _TextInputBox(
          controller: titleController,
          hintTextKey: 'newsAdd.articleTitleHint',
          bold: true,
          fontSize: 17,
        ),
        const SizedBox(height: 18),
        const _FieldLabel('newsAdd.summary'),
        _TextInputBox(
          controller: summaryController,
          hintTextKey: 'newsAdd.summaryHint',
          maxLines: 5,
          minLines: 3,
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          icon: Icons.settings_outlined,
          iconColor: AppColors.warmHorizon,
          title: 'newsAdd.seoAi',
          trailing: _GoogleAiReadyBadge(),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SeoTitleField(controller: seoTitleController),
                  const SizedBox(height: 16),
                  _SeoSlugField(controller: slugController),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _SeoTitleField(controller: seoTitleController)),
                const SizedBox(width: 18),
                Expanded(child: _SeoSlugField(controller: slugController)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const _FieldLabel('newsAdd.metaDescription'),
        _TextInputBox(
          controller: metaDescriptionController,
          hintTextKey: 'newsAdd.metaDescriptionHint',
          fontSize: 13,
        ),
        const SizedBox(height: 16),
        const _FieldLabel('newsAdd.schemaType'),
        _DropdownField(
          value: schemaType,
          items: [
            for (final option in _schemaTypeOptions)
              DropdownMenuItem(
                value: option.value,
                child: Text(context.t(option.labelKey)),
              ),
          ],
          onChanged: onSchemaChanged,
        ),
        const SizedBox(height: 16),
        const _FieldLabel('newsAdd.keywords'),
        _KeywordsInput(
          controller: focusKeywordsController,
          tags: keywords,
          onSubmitted: onKeywordSubmitted,
          onRemove: onKeywordRemoved,
        ),
        const SizedBox(height: 18),
        _FaqSection(
          entries: faqEntries,
          onAdd: onAddFaq,
          onRemove: onRemoveFaq,
        ),
      ],
    );
  }
}

class _HeaderToggles extends StatelessWidget {
  const _HeaderToggles({
    required this.mansetSlider,
    required this.pinToTop,
    required this.onMansetChanged,
    required this.onPinChanged,
    required this.onAiGenerate,
  });

  final bool mansetSlider;
  final bool pinToTop;
  final ValueChanged<bool> onMansetChanged;
  final ValueChanged<bool> onPinChanged;
  final VoidCallback onAiGenerate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 14,
      runSpacing: 10,
      children: [
        _NamedToggle(
          label: 'newsAdd.manset',
          value: mansetSlider,
          onChanged: onMansetChanged,
          activeColor: AppColors.actionRed,
          showCheckIcon: true,
        ),
        _NamedToggle(
          label: 'newsAdd.pin',
          value: pinToTop,
          onChanged: onPinChanged,
          activeColor: AppColors.warmHorizon,
          showCheckIcon: true,
        ),
        _AiButton(onTap: onAiGenerate),
      ],
    );
  }
}

class _NamedToggle extends StatelessWidget {
  const _NamedToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.activeColor,
    this.showCheckIcon = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final bool showCheckIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.t(label),
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 10),
        _ToggleSwitch(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
          showCheckIcon: showCheckIcon,
        ),
      ],
    );
  }
}

class _AiButton extends StatelessWidget {
  const _AiButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.deepOcean.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: AppColors.deepOcean.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: AppColors.deepOcean),
              const SizedBox(width: 6),
              Text(
                context.t('newsAdd.ai'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiContentGeneratorResult {
  const _AiContentGeneratorResult({
    required this.draft,
    this.sourceImage,
    this.eventImages = const <_AiSelectedSourceImage>[],
  });

  final AdminNewsAiDraft draft;
  final _AiSelectedSourceImage? sourceImage;
  final List<_AiSelectedSourceImage> eventImages;
}

class _AiSelectedSourceImage {
  const _AiSelectedSourceImage({
    required this.mediaSrc,
    required this.originalUrl,
    required this.altText,
  });

  final String mediaSrc;
  final String originalUrl;
  final String altText;
}

class _AiContentGeneratorDialog extends StatefulWidget {
  const _AiContentGeneratorDialog({
    required this.languageCode,
    required this.category,
    required this.formatType,
    required this.formatSubtype,
    required this.initialTopic,
    required this.initialNotes,
    required this.revisionMode,
    required this.onGenerate,
  });

  final String languageCode;
  final String category;
  final String formatType;
  final String formatSubtype;
  final String initialTopic;
  final String initialNotes;
  final bool revisionMode;
  final Future<AdminNewsAiDraft> Function(AdminNewsAiDraftRequest request)
  onGenerate;

  @override
  State<_AiContentGeneratorDialog> createState() =>
      _AiContentGeneratorDialogState();
}

class _AiContentGeneratorDialogState extends State<_AiContentGeneratorDialog> {
  late final TextEditingController _sourceUrlController;
  late final TextEditingController _topicController;
  late final TextEditingController _notesController;
  final _sourceReader = const AdminNewsSourceReader();
  final _mediaService = MediaService();

  var _tone = 'neutral';
  var _contentType = 'article';
  var _outputTarget = 'all';
  var _includeSeo = true;
  var _deepResearch = false;
  var _preserveSource = false;
  var _generating = false;
  var _readingSource = false;
  String? _generationError;
  String? _sourceUrlStatus;
  var _sourceUrlStatusIsError = false;
  AdminNewsSourceArticle? _sourceArticle;
  String? _sourceArticleUrl;
  _AiSelectedSourceImage? _selectedSourceImage;
  var _sourceImageUploading = false;
  double? _sourceImageUploadProgress;
  String? _sourceImageStatus;
  var _sourceImageStatusIsError = false;
  final _selectedEventImages = <_AiSelectedSourceImage>[];
  final _itemCounts = <String, int>{};

  bool get _usesInteractiveAiFormat {
    return widget.formatType == 'quiz' || widget.formatType == 'poll';
  }

  bool get _usesContentsAiFormat {
    final formatType = widget.formatType.trim().toLowerCase();
    return formatType == 'contents' ||
        formatType == 'toc' ||
        formatType == 'table of contents';
  }

  bool get _usesRecipeAiFormat {
    return widget.formatType.trim().toLowerCase() == 'recipe';
  }

  bool get _usesEventAiFormat {
    return widget.formatType.trim().toLowerCase() == 'event';
  }

  bool get _usesDeepResearchAiFormat {
    return _usesInteractiveAiFormat ||
        _usesRecipeAiFormat ||
        _usesEventAiFormat;
  }

  bool get _usesTabOwnedAiItems {
    return _usesInteractiveAiFormat ||
        _usesContentsAiFormat ||
        _usesRecipeAiFormat;
  }

  List<_AddBtn> get _aiItemOptions => const [
    _AddBtn('newsAdd.add.text', Icons.text_fields, Color(0xFF2C3E50)),
    _AddBtn('newsAdd.add.image', Icons.image_outlined, Color(0xFF1F8B3D)),
    _AddBtn(
      'newsAdd.add.slider',
      Icons.collections_outlined,
      Color(0xFF2E7D32),
    ),
    _AddBtn('newsAdd.add.video', Icons.play_circle_outline, Color(0xFFC0392B)),
    _AddBtn('newsAdd.add.audio', Icons.headphones_outlined, Color(0xFF8E44AD)),
    _AddBtn(
      'newsAdd.add.file',
      Icons.insert_drive_file_outlined,
      Color(0xFF7F8C8D),
    ),
    _AddBtn('newsAdd.add.social', Icons.share_outlined, Color(0xFF2980B9)),
    _AddBtn('newsAdd.add.flip', Icons.sync, Color(0xFFD35400)),
    _AddBtn(
      'newsAdd.add.beforeAfter',
      Icons.compare_outlined,
      Color(0xFF1F6FA8),
    ),
    _AddBtn('newsAdd.add.poll', Icons.bar_chart_outlined, Color(0xFF5B3FB0)),
    _AddBtn('newsAdd.add.vs', Icons.flash_on_outlined, Color(0xFFE91E63)),
    _AddBtn('newsAdd.add.review', Icons.star_outline, Color(0xFF16A085)),
    _AddBtn('newsAdd.add.quote', Icons.format_quote, Color(0xFF34495E)),
    _AddBtn('newsAdd.add.iframe', Icons.public, Color(0xFF3F51B5)),
  ];

  @override
  void initState() {
    super.initState();
    _sourceUrlController = TextEditingController();
    _sourceUrlController.addListener(_handleSourceUrlChanged);
    _topicController = TextEditingController(text: widget.initialTopic);
    _notesController = TextEditingController(text: widget.initialNotes);
    if (_usesInteractiveAiFormat) {
      _tone = 'entertaining';
    }
  }

  @override
  void dispose() {
    _sourceUrlController.removeListener(_handleSourceUrlChanged);
    _sourceUrlController.dispose();
    _topicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<AdminNewsSourceImage> get _currentSourceImages {
    final url = _sourceUrlController.text.trim();
    final article = _sourceArticle;
    if (article == null || _sourceArticleUrl != url) {
      return const <AdminNewsSourceImage>[];
    }
    return article.images;
  }

  void _handleSourceUrlChanged() {
    final articleUrl = _sourceArticleUrl;
    if (articleUrl == null || _sourceUrlController.text.trim() == articleUrl) {
      return;
    }
    setState(() {
      _sourceArticle = null;
      _sourceArticleUrl = null;
      _selectedSourceImage = null;
      _sourceImageStatus = null;
      _sourceImageStatusIsError = false;
      _sourceImageUploadProgress = null;
    });
  }

  Future<void> _handleGenerate() async {
    if (_generating || _readingSource || _sourceImageUploading) return;
    setState(() {
      _generating = true;
      _generationError = null;
    });
    try {
      final sourceArticle = await _readSourceUrlIfNeeded(fillFields: false);
      final draft = await widget.onGenerate(
        AdminNewsAiDraftRequest(
          languageCode: widget.languageCode,
          category: widget.category,
          tone: _tone,
          contentType: _contentType,
          outputTarget: _outputTarget,
          includeSeo: _includeSeo,
          topic: _topicForGenerate(sourceArticle),
          sourceNotes: _sourceNotesForGenerate(),
          itemCounts: _usesTabOwnedAiItems
              ? const <String, int>{}
              : _normalizedItemCounts(),
          deepResearch: _usesDeepResearchAiFormat && _deepResearch,
          preserveSource: _preserveSource,
          formatType: widget.formatType,
          formatSubtype: widget.formatSubtype,
          sourceImageUrls: _usesEventAiFormat
              ? [
                  for (final image in _selectedEventImages)
                    if (image.originalUrl.trim().isNotEmpty)
                      image.originalUrl.trim(),
                ]
              : const <String>[],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        _AiContentGeneratorResult(
          draft: draft,
          sourceImage: _selectedSourceImage,
          eventImages: _selectedEventImages.toList(growable: false),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _generationError = error.toString();
      });
    }
  }

  Future<void> _handleReadSourceUrl() async {
    if (_readingSource || _generating || _sourceImageUploading) return;
    try {
      await _readSourceUrlIfNeeded(fillFields: true, force: true);
    } catch (_) {
      // Status is already written by _readSourceUrlIfNeeded.
    }
  }

  Future<AdminNewsSourceArticle?> _readSourceUrlIfNeeded({
    required bool fillFields,
    bool force = false,
  }) async {
    final url = _sourceUrlController.text.trim();
    if (url.isEmpty) return null;
    if (!force && _sourceArticle != null && _sourceArticleUrl == url) {
      return _sourceArticle;
    }
    setState(() {
      _readingSource = true;
      _sourceUrlStatus = null;
      _sourceUrlStatusIsError = false;
      _selectedSourceImage = null;
      _sourceImageStatus = null;
      _sourceImageStatusIsError = false;
      _sourceImageUploadProgress = null;
    });
    try {
      final article = await _sourceReader.read(url);
      if (!mounted) return article;
      setState(() {
        _sourceArticle = article;
        _sourceArticleUrl = url;
        _sourceUrlStatus = context.t('newsAdd.aiModal.sourceUrlReady');
        _sourceUrlStatusIsError = false;
        if (fillFields) {
          _applySourceArticleToInputs(article);
        }
      });
      return article;
    } catch (error) {
      if (!mounted) rethrow;
      setState(() {
        _sourceUrlStatus = error.toString();
        _sourceUrlStatusIsError = true;
      });
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _readingSource = false);
      }
    }
  }

  void _applySourceArticleToInputs(AdminNewsSourceArticle article) {
    final currentContent = _topicController.text.trim();
    final sourceBlock = article.toPromptBlock(
      includeStructureHints: _usesContentsAiFormat,
    );
    if (currentContent.contains('Kaynak URL: ${article.url}')) return;
    _topicController.text = currentContent.isEmpty
        ? sourceBlock
        : '$currentContent\n\n$sourceBlock';
  }

  Future<void> _handleOpenSourceImages() async {
    final images = _currentSourceImages;
    if (images.isEmpty || _sourceImageUploading) return;
    final selected = await showDialog<AdminNewsSourceImage>(
      context: context,
      barrierColor: AppColors.deepOcean.withValues(alpha: 0.58),
      builder: (_) => _SourceImagesPickerDialog(
        images: images,
        selectedUrl: _selectedSourceImage?.originalUrl,
      ),
    );
    if (selected == null || !mounted) return;
    await _uploadSelectedSourceImage(selected);
  }

  Future<void> _handleOpenEventImages() async {
    if (_generating || _readingSource || _sourceImageUploading) return;
    final selected = await showMediaLibraryMultiDialog(
      context,
      mediaService: _mediaService,
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    final next = <_AiSelectedSourceImage>[];
    final seen = <String>{};
    for (final mediaSrc in [
      ..._selectedEventImages.map((image) => image.mediaSrc),
      ...selected,
    ]) {
      final normalized = mediaSrc.trim();
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      next.add(
        _AiSelectedSourceImage(
          mediaSrc: normalized,
          originalUrl: _mediaService.resolveUrl(normalized),
          altText: '',
        ),
      );
      if (next.length >= 5) break;
    }
    setState(() {
      _selectedEventImages
        ..clear()
        ..addAll(next);
    });
  }

  void _handleRemoveEventImage(_AiSelectedSourceImage image) {
    setState(() {
      _selectedEventImages.removeWhere(
        (item) => item.mediaSrc == image.mediaSrc,
      );
    });
  }

  Future<void> _uploadSelectedSourceImage(AdminNewsSourceImage image) async {
    if (_sourceImageUploading) return;
    setState(() {
      _sourceImageUploading = true;
      _sourceImageUploadProgress = 0;
      _sourceImageStatus = context.t('newsAdd.aiModal.sourceImageUploading');
      _sourceImageStatusIsError = false;
    });
    try {
      final result = await _mediaService.uploadRemoteImage(
        imageUrl: image.url,
        onTransferProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _sourceImageUploadProgress = progress.progress;
          });
        },
      );
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _sourceImageStatus = context.t('newsAdd.aiModal.sourceImageError');
          _sourceImageStatusIsError = true;
        });
        return;
      }
      setState(() {
        _selectedSourceImage = _AiSelectedSourceImage(
          mediaSrc: result.src,
          originalUrl: image.url,
          altText: image.alt,
        );
        _sourceImageStatus = context.t('newsAdd.aiModal.sourceImageReady');
        _sourceImageStatusIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sourceImageStatus =
            '${context.t('newsAdd.aiModal.sourceImageError')} $error';
        _sourceImageStatusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _sourceImageUploading = false;
          _sourceImageUploadProgress = null;
        });
      }
    }
  }

  String _topicForGenerate(AdminNewsSourceArticle? article) {
    final topic = _topicController.text.trim();
    if (article == null || topic.contains('Kaynak URL: ${article.url}')) {
      return topic;
    }
    final sourceBlock = article.toPromptBlock(
      includeStructureHints: _usesContentsAiFormat,
    );
    return topic.isEmpty ? sourceBlock : '$topic\n\n$sourceBlock';
  }

  String _sourceNotesForGenerate() {
    return _notesController.text.trim();
  }

  Map<String, int> _normalizedItemCounts() {
    return {
      for (final entry in _itemCounts.entries)
        if (_itemTypeForLabel(entry.key).isNotEmpty && entry.value > 0)
          _itemTypeForLabel(entry.key): entry.value,
    };
  }

  String _itemTypeForLabel(String label) {
    return switch (label) {
      'newsAdd.add.text' => 'text',
      'newsAdd.add.image' => 'image',
      'newsAdd.add.slider' => 'slider',
      'newsAdd.add.video' => 'video',
      'newsAdd.add.audio' => 'audio',
      'newsAdd.add.file' => 'file',
      'newsAdd.add.social' => 'social',
      'newsAdd.add.flip' => 'flipcard',
      'newsAdd.add.beforeAfter' => 'beforeafter',
      'newsAdd.add.poll' => 'poll',
      'newsAdd.add.vs' => 'vs',
      'newsAdd.add.review' => 'review',
      'newsAdd.add.quote' => 'quote',
      'newsAdd.add.iframe' => 'iframe',
      _ => '',
    };
  }

  void _addAiItem(_AddBtn item) {
    setState(() {
      _itemCounts[item.label] = (_itemCounts[item.label] ?? 0) + 1;
    });
  }

  void _removeAiItem(_AddBtn item) {
    setState(() {
      final next = (_itemCounts[item.label] ?? 0) - 1;
      if (next <= 0) {
        _itemCounts.remove(item.label);
      } else {
        _itemCounts[item.label] = next;
      }
    });
  }

  void _clearAiItems() {
    setState(_itemCounts.clear);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final horizontalInset = size.width < 720 ? 16.0 : 48.0;
    final verticalInset = size.height < 700 ? 16.0 : 42.0;
    final availableWidth = size.width - (horizontalInset * 2);
    final availableHeight = size.height - (verticalInset * 2);
    final preferredWidth = size.width < 1180
        ? availableWidth
        : (size.width * 0.76).clamp(1120.0, 1280.0).toDouble();
    final dialogWidth = preferredWidth.clamp(0.0, availableWidth).toDouble();
    final preferredHeight = size.height < 700
        ? availableHeight
        : (size.height * 0.76).clamp(620.0, 700.0).toDouble();
    final dialogHeight = preferredHeight.clamp(0.0, availableHeight).toDouble();

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight,
        ),
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: _newsAddStrongLine),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  children: [
                    _AiModalHeader(
                      onClose:
                          _generating || _readingSource || _sourceImageUploading
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final railLayout = constraints.maxWidth >= 980;
                            final railWidth = constraints.maxWidth < 1160
                                ? 420.0
                                : 460.0;
                            final dense = constraints.maxHeight < 560;
                            final form = _buildAiForm(
                              context,
                              !railLayout,
                              dense,
                            );
                            final showItemPlanner = !_usesTabOwnedAiItems;
                            final items = showItemPlanner
                                ? _AiModalItemPlanner(
                                    items: _aiItemOptions,
                                    counts: _itemCounts,
                                    enabled: !_generating,
                                    onAdd: _addAiItem,
                                    onRemove: _removeAiItem,
                                    onClear: _clearAiItems,
                                  )
                                : null;
                            final notes = _buildAiNotesPanel(context, dense);

                            if (!railLayout) {
                              return SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    form,
                                    SizedBox(height: dense ? 12 : 16),
                                    if (items != null) ...[
                                      items,
                                      SizedBox(height: dense ? 12 : 14),
                                    ],
                                    notes,
                                  ],
                                ),
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(child: form),
                                ),
                                const SizedBox(width: 22),
                                SizedBox(
                                  width: railWidth,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (items != null) ...[
                                          items,
                                          SizedBox(height: dense ? 12 : 14),
                                        ],
                                        notes,
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    if (_generationError != null)
                      _AiGenerationError(message: _generationError!),
                    _AiModalFooter(
                      generating: _generating,
                      revisionMode: widget.revisionMode,
                      onClose:
                          _generating || _readingSource || _sourceImageUploading
                          ? null
                          : () => Navigator.of(context).pop(),
                      onGenerate:
                          _generating || _readingSource || _sourceImageUploading
                          ? null
                          : () => unawaited(_handleGenerate()),
                    ),
                  ],
                ),
                if (_generating) const _AiGenerationOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectGrid(BuildContext context, bool compact) {
    final primaryContentTypeLabel = widget.formatType == 'video'
        ? 'newsAdd.aiModal.content.video'
        : _usesContentsAiFormat
        ? 'newsAdd.aiModal.content.contents'
        : _usesRecipeAiFormat
        ? 'newsAdd.aiModal.content.recipe'
        : _usesEventAiFormat
        ? 'newsAdd.aiModal.content.event'
        : 'newsAdd.aiModal.content.article';
    final tone = _AiGeneratorSelect(
      label: 'newsAdd.aiModal.tone',
      value: _tone,
      leadingIcon: Icons.record_voice_over_outlined,
      items: [
        DropdownMenuItem(
          value: 'neutral',
          child: Text(context.t('newsAdd.aiModal.tone.neutral')),
        ),
        DropdownMenuItem(
          value: 'professional',
          child: Text(context.t('newsAdd.aiModal.tone.professional')),
        ),
        DropdownMenuItem(
          value: 'entertaining',
          child: Text(context.t('newsAdd.aiModal.tone.entertaining')),
        ),
        DropdownMenuItem(
          value: 'local',
          child: Text(context.t('newsAdd.aiModal.tone.local')),
        ),
        DropdownMenuItem(
          value: 'critical',
          child: Text(context.t('newsAdd.aiModal.tone.critical')),
        ),
        DropdownMenuItem(
          value: 'formal',
          child: Text(context.t('newsAdd.aiModal.tone.formal')),
        ),
      ],
      onChanged: (value) => setState(() => _tone = value ?? _tone),
    );
    final contentType = _AiGeneratorSelect(
      label: 'newsAdd.aiModal.contentType',
      value: _contentType,
      leadingIcon: Icons.article_outlined,
      items: [
        DropdownMenuItem(
          value: 'article',
          child: Text(context.t(primaryContentTypeLabel)),
        ),
        DropdownMenuItem(
          value: 'breaking',
          child: Text(context.t('newsAdd.aiModal.content.breaking')),
        ),
        DropdownMenuItem(
          value: 'analysis',
          child: Text(context.t('newsAdd.aiModal.content.analysis')),
        ),
        DropdownMenuItem(
          value: 'interview',
          child: Text(context.t('newsAdd.aiModal.content.interview')),
        ),
      ],
      onChanged: (value) =>
          setState(() => _contentType = value ?? _contentType),
    );
    final outputTarget = _AiGeneratorSelect(
      label: 'newsAdd.aiModal.outputTarget',
      value: _outputTarget,
      leadingIcon: Icons.auto_fix_high_outlined,
      items: [
        DropdownMenuItem(
          value: 'all',
          child: Text(context.t('newsAdd.aiModal.output.all')),
        ),
        DropdownMenuItem(
          value: 'contentSeo',
          child: Text(context.t('newsAdd.aiModal.output.contentSeo')),
        ),
        DropdownMenuItem(
          value: 'seoOnly',
          child: Text(context.t('newsAdd.aiModal.output.seoOnly')),
        ),
        DropdownMenuItem(
          value: 'social',
          child: Text(context.t('newsAdd.aiModal.output.social')),
        ),
      ],
      onChanged: (value) =>
          setState(() => _outputTarget = value ?? _outputTarget),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tone,
          const SizedBox(height: 14),
          contentType,
          const SizedBox(height: 14),
          outputTarget,
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tone),
            const SizedBox(width: 18),
            Expanded(child: contentType),
          ],
        ),
        const SizedBox(height: 16),
        outputTarget,
      ],
    );
  }

  Widget _buildAiForm(BuildContext context, bool compact, bool dense) {
    final sourceImages = _currentSourceImages;
    final topicLines = _usesEventAiFormat
        ? (dense ? 7 : 8)
        : sourceImages.isNotEmpty
        ? (dense ? 8 : 9)
        : (dense ? 11 : 12);
    final topicInput = _TextInputBox(
      controller: _topicController,
      hintTextKey: 'newsAdd.aiModal.topicHint',
      minLines: topicLines,
      maxLines: topicLines,
      fontSize: 13.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSelectGrid(context, compact),
        SizedBox(height: dense ? 14 : 18),
        _AiSourceUrlField(
          controller: _sourceUrlController,
          enabled: !_generating,
          reading: _readingSource,
          status: _sourceUrlStatus,
          statusIsError: _sourceUrlStatusIsError,
          onRead: _generating || _readingSource
              ? null
              : () => unawaited(_handleReadSourceUrl()),
        ),
        SizedBox(height: dense ? 12 : 14),
        const _FieldLabel('newsAdd.aiModal.topic', icon: Icons.auto_awesome),
        if (_usesEventAiFormat)
          LayoutBuilder(
            builder: (context, constraints) {
              final canUseSidePanel = !compact && constraints.maxWidth >= 620;
              final eventImages = _EventAiImagePicker(
                images: _selectedEventImages,
                enabled: !_generating && !_readingSource,
                onPick: () => unawaited(_handleOpenEventImages()),
                onRemove: _handleRemoveEventImage,
              );
              if (!canUseSidePanel) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    topicInput,
                    const SizedBox(height: 10),
                    eventImages,
                  ],
                );
              }
              final panelWidth = (constraints.maxWidth * 0.28).clamp(
                204.0,
                232.0,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: topicInput),
                  const SizedBox(width: 12),
                  SizedBox(width: panelWidth, child: eventImages),
                ],
              );
            },
          )
        else if (sourceImages.isEmpty)
          topicInput
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final canUseSidePanel = !compact && constraints.maxWidth >= 620;
              final preview = _SourceImagePreview(
                images: sourceImages,
                selectedImage: _selectedSourceImage,
                uploading: _sourceImageUploading,
                uploadProgress: _sourceImageUploadProgress,
                status: _sourceImageStatus,
                statusIsError: _sourceImageStatusIsError,
                sidePanel: canUseSidePanel,
                onTap: _sourceImageUploading
                    ? null
                    : () => unawaited(_handleOpenSourceImages()),
              );
              if (!canUseSidePanel) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [topicInput, const SizedBox(height: 10), preview],
                );
              }
              final panelWidth = (constraints.maxWidth * 0.26).clamp(
                184.0,
                210.0,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: topicInput),
                  const SizedBox(width: 12),
                  SizedBox(width: panelWidth, child: preview),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildAiNotesPanel(BuildContext context, bool dense) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel(
          'newsAdd.aiModal.sourceNotes',
          icon: Icons.fact_check_outlined,
        ),
        _TextInputBox(
          controller: _notesController,
          hintTextKey: 'newsAdd.aiModal.sourceNotesHint',
          minLines: dense ? 3 : 4,
          maxLines: dense ? 3 : 4,
          fontSize: 13,
        ),
        SizedBox(height: dense ? 10 : 12),
        _AiModalOptions(
          includeSeo: _includeSeo,
          showDeepResearch: _usesDeepResearchAiFormat,
          deepResearch: _deepResearch,
          preserveSource: _preserveSource,
          onSeoChanged: (value) => setState(() => _includeSeo = value),
          onDeepResearchChanged: (value) =>
              setState(() => _deepResearch = value),
          onPreserveSourceChanged: (value) =>
              setState(() => _preserveSource = value),
        ),
      ],
    );
  }
}

class _AiModalHeader extends StatelessWidget {
  const _AiModalHeader({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 18, 20, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _newsAddSoftLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.actionRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 18,
              color: AppColors.actionRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.t('newsAdd.aiModal.title'),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          _GoogleAiReadyBadge(),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: onClose == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: onClose == null
                      ? AppColors.iconMuted.withValues(alpha: 0.45)
                      : AppColors.iconMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiGeneratorSelect extends StatelessWidget {
  const _AiGeneratorSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.leadingIcon,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label, icon: leadingIcon),
        _DropdownField(
          value: value,
          items: items,
          onChanged: onChanged,
          leadingIcon: leadingIcon,
        ),
      ],
    );
  }
}

class _AiSourceUrlField extends StatelessWidget {
  const _AiSourceUrlField({
    required this.controller,
    required this.enabled,
    required this.reading,
    required this.status,
    required this.statusIsError,
    required this.onRead,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool reading;
  final String? status;
  final bool statusIsError;
  final VoidCallback? onRead;

  @override
  Widget build(BuildContext context) {
    final statusText = status?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel(
          'newsAdd.aiModal.sourceUrl',
          icon: Icons.link_outlined,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final input = _buildInput(context);
            final button = _PillButton(
              icon: reading ? Icons.hourglass_empty : Icons.travel_explore,
              label: reading
                  ? 'newsAdd.aiModal.sourceUrlReading'
                  : 'newsAdd.aiModal.sourceUrlRead',
              onTap: onRead,
              background: AppColors.deepOcean,
              foreground: Colors.white,
              height: 42,
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  input,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: button),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: input),
                const SizedBox(width: 10),
                button,
              ],
            );
          },
        ),
        if (statusText.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            statusText,
            style: TextStyle(
              color: statusIsError
                  ? AppColors.actionRed
                  : const Color(0xFF1F8B3D),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInput(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: enabled ? Colors.white : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _newsAddStrongLine),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: 1,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        cursorColor: AppColors.deepOcean,
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: context.t('newsAdd.aiModal.sourceUrlHint'),
          hintStyle: const TextStyle(
            color: AppColors.placeholder,
            fontSize: 13,
            fontWeight: FontWeight.w400,
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
          disabledBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }
}

class _SourceImagePreview extends StatelessWidget {
  const _SourceImagePreview({
    required this.images,
    required this.selectedImage,
    required this.uploading,
    required this.uploadProgress,
    required this.status,
    required this.statusIsError,
    required this.onTap,
    this.sidePanel = false,
  });

  final List<AdminNewsSourceImage> images;
  final _AiSelectedSourceImage? selectedImage;
  final bool uploading;
  final double? uploadProgress;
  final String? status;
  final bool statusIsError;
  final VoidCallback? onTap;
  final bool sidePanel;

  @override
  Widget build(BuildContext context) {
    final previewUrl = selectedImage?.originalUrl ?? images.first.url;
    final statusText = status?.trim() ?? '';
    final enabled = onTap != null;
    final child = sidePanel
        ? _buildSidePanel(context, previewUrl, statusText)
        : _buildInlinePanel(context, previewUrl, statusText);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _newsAddStrongLine),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildInlinePanel(
    BuildContext context,
    String previewUrl,
    String statusText,
  ) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.value),
          child: SizedBox(
            width: 96,
            height: 62,
            child: Image.network(
              previewUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _SourceImageFallback(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SourceImagePreviewText(
            images: images,
            uploading: uploading,
            uploadProgress: uploadProgress,
            statusText: statusText,
            statusIsError: statusIsError,
          ),
        ),
        const SizedBox(width: 10),
        _SourceImagePreviewAction(selected: selectedImage != null),
      ],
    );
  }

  Widget _buildSidePanel(
    BuildContext context,
    String previewUrl,
    String statusText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.value),
          child: SizedBox(
            height: 58,
            child: Image.network(
              previewUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _SourceImageFallback(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SourceImagePreviewText(
          images: images,
          uploading: uploading,
          uploadProgress: uploadProgress,
          statusText: statusText,
          statusIsError: statusIsError,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: _SourceImagePreviewAction(
            selected: selectedImage != null,
            compact: true,
          ),
        ),
      ],
    );
  }
}

class _SourceImagePreviewText extends StatelessWidget {
  const _SourceImagePreviewText({
    required this.images,
    required this.uploading,
    required this.uploadProgress,
    required this.statusText,
    required this.statusIsError,
  });

  final List<AdminNewsSourceImage> images;
  final bool uploading;
  final double? uploadProgress;
  final String statusText;
  final bool statusIsError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(
              Icons.image_search_outlined,
              size: 15,
              color: AppColors.deepOcean,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                context.t('newsAdd.aiModal.sourceImages'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${images.length} ${context.t('newsAdd.aiModal.sourceImagesFound')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _newsAddTabMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        if (uploading) ...[
          const SizedBox(height: 7),
          LinearProgressIndicator(
            minHeight: 3,
            value: uploadProgress,
            color: AppColors.deepOcean,
            backgroundColor: _newsAddSoftLine,
          ),
        ] else if (statusText.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            statusText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: statusIsError
                  ? AppColors.actionRed
                  : const Color(0xFF1F8B3D),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _SourceImagePreviewAction extends StatelessWidget {
  const _SourceImagePreviewAction({
    required this.selected,
    this.compact = false,
  });

  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 34.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.deepOcean,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Icon(
        selected ? Icons.check : Icons.grid_view,
        color: Colors.white,
        size: compact ? 15 : 16,
      ),
    );
  }
}

class _EventAiImagePicker extends StatelessWidget {
  const _EventAiImagePicker({
    required this.images,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final List<_AiSelectedSourceImage> images;
  final bool enabled;
  final VoidCallback onPick;
  final ValueChanged<_AiSelectedSourceImage> onRemove;

  @override
  Widget build(BuildContext context) {
    final mediaService = MediaService();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _newsAddStrongLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.actionRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  size: 16,
                  color: AppColors.actionRed,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.t('newsAdd.aiModal.eventImages'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _EventAiImageCount(count: images.length),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            context.t('newsAdd.aiModal.eventImagesHint'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _newsAddTabMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.25,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          if (images.isEmpty)
            _EventAiEmptyImageBox(enabled: enabled, onTap: onPick)
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final image in images)
                  _EventAiImageThumb(
                    imageUrl: mediaService.resolveImageUrl(
                      image.mediaSrc,
                      width: 160,
                      quality: 85,
                    ),
                    enabled: enabled,
                    onRemove: () => onRemove(image),
                  ),
                if (images.length < 5)
                  _EventAiAddImageThumb(enabled: enabled, onTap: onPick),
              ],
            ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: _EventAiImageButton(enabled: enabled, onTap: onPick),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventAiImageCount extends StatelessWidget {
  const _EventAiImageCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: count > 0
            ? AppColors.deepOcean.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _newsAddSoftLine),
      ),
      child: Text(
        '$count/5',
        style: TextStyle(
          color: count > 0 ? AppColors.deepOcean : AppColors.iconMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _EventAiEmptyImageBox extends StatelessWidget {
  const _EventAiEmptyImageBox({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          height: 78,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: _newsAddStrongLine,
              style: BorderStyle.solid,
            ),
          ),
          child: _EventAiImageButton(enabled: enabled, onTap: onTap),
        ),
      ),
    );
  }
}

class _EventAiImageButton extends StatelessWidget {
  const _EventAiImageButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.62,
          child: Container(
            width: double.infinity,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.deepOcean,
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 15,
                  color: Colors.white,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    context.t('newsAdd.aiModal.eventImagesSelect'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
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

class _EventAiAddImageThumb extends StatelessWidget {
  const _EventAiAddImageThumb({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _newsAddStrongLine),
          ),
          child: Icon(
            Icons.add,
            size: 22,
            color: enabled ? AppColors.deepOcean : AppColors.iconMuted,
          ),
        ),
      ),
    );
  }
}

class _EventAiImageThumb extends StatelessWidget {
  const _EventAiImageThumb({
    required this.imageUrl,
    required this.enabled,
    required this.onRemove,
  });

  final String imageUrl;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.value),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _SourceImageFallback(),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: MouseRegion(
              cursor: enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: enabled ? onRemove : null,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.actionRed,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.close, size: 11, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceImagesPickerDialog extends StatefulWidget {
  const _SourceImagesPickerDialog({
    required this.images,
    required this.selectedUrl,
  });

  final List<AdminNewsSourceImage> images;
  final String? selectedUrl;

  @override
  State<_SourceImagesPickerDialog> createState() =>
      _SourceImagesPickerDialogState();
}

class _SourceImagesPickerDialogState extends State<_SourceImagesPickerDialog> {
  String? _selectedUrl;

  @override
  void initState() {
    super.initState();
    _selectedUrl = widget.selectedUrl?.trim().isNotEmpty == true
        ? widget.selectedUrl!.trim()
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.62).clamp(720.0, 980.0);
    final height = (size.height * 0.68).clamp(500.0, 680.0);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 42),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: _newsAddStrongLine),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _SourceImagesDialogHeader(onClose: () => Navigator.pop(context)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = (constraints.maxWidth / 170)
                        .floor()
                        .clamp(3, 5)
                        .toInt();
                    return GridView.builder(
                      itemCount: widget.images.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.08,
                      ),
                      itemBuilder: (context, index) {
                        final image = widget.images[index];
                        return _SourceImageTile(
                          image: image,
                          selected: image.url == _selectedUrl,
                          onTap: () => setState(() => _selectedUrl = image.url),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            _SourceImagesDialogFooter(
              onClose: () => Navigator.pop(context),
              onUse: _selectedUrl == null
                  ? null
                  : () {
                      final selected = widget.images.firstWhere(
                        (image) => image.url == _selectedUrl,
                      );
                      Navigator.pop(context, selected);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceImagesDialogHeader extends StatelessWidget {
  const _SourceImagesDialogHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _newsAddSoftLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.actionRed,
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.t('newsAdd.aiModal.sourceImagesDialogTitle'),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, size: 20, color: AppColors.iconMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceImagesDialogFooter extends StatelessWidget {
  const _SourceImagesDialogFooter({required this.onClose, required this.onUse});

  final VoidCallback onClose;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: _newsAddSoftLine)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _PillButton(
            icon: Icons.close,
            label: 'newsAdd.aiModal.close',
            onTap: onClose,
            background: Colors.white,
            foreground: AppColors.inkSoft,
            borderColor: _newsAddStrongLine,
            height: 38,
          ),
          const SizedBox(width: 10),
          _PillButton(
            icon: Icons.check_circle_outline,
            label: 'newsAdd.aiModal.sourceImageUse',
            onTap: onUse,
            background: AppColors.deepOcean,
            foreground: Colors.white,
            height: 38,
          ),
        ],
      ),
    );
  }
}

class _SourceImageTile extends StatelessWidget {
  const _SourceImageTile({
    required this.image,
    required this.selected,
    required this.onTap,
  });

  final AdminNewsSourceImage image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(image.url);
    final label = image.alt.trim().isNotEmpty
        ? image.alt.trim()
        : uri?.host ?? image.url;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected ? const Color(0xFF10B981) : _newsAddStrongLine,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      image.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _SourceImageFallback(),
                    ),
                    if (selected)
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(
                              AppRadius.value,
                            ),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _newsAddSoftLine)),
                ),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    letterSpacing: 0,
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

class _SourceImageFallback extends StatelessWidget {
  const _SourceImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        size: 24,
        color: AppColors.iconMuted,
      ),
    );
  }
}

class _AiModalOptions extends StatelessWidget {
  const _AiModalOptions({
    required this.includeSeo,
    required this.showDeepResearch,
    required this.deepResearch,
    required this.preserveSource,
    required this.onSeoChanged,
    required this.onDeepResearchChanged,
    required this.onPreserveSourceChanged,
  });

  final bool includeSeo;
  final bool showDeepResearch;
  final bool deepResearch;
  final bool preserveSource;
  final ValueChanged<bool> onSeoChanged;
  final ValueChanged<bool> onDeepResearchChanged;
  final ValueChanged<bool> onPreserveSourceChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _newsAddSoftLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = constraints.maxWidth < 420 ? 6.0 : 10.0;
          final fontSize = constraints.maxWidth < 420
              ? 11.0
              : constraints.maxWidth < 480
              ? 11.5
              : 12.0;
          final toggles = [
            _AiModalOptionToggle(
              label: 'newsAdd.aiModal.includeSeo',
              value: includeSeo,
              onChanged: onSeoChanged,
              activeColor: AppColors.deepOcean,
              fontSize: fontSize,
            ),
            _AiModalOptionToggle(
              label: 'newsAdd.aiModal.preserveSource',
              value: preserveSource,
              onChanged: onPreserveSourceChanged,
              activeColor: AppColors.deepOcean,
              fontSize: fontSize,
            ),
            if (showDeepResearch)
              _AiModalOptionToggle(
                label: 'newsAdd.aiModal.deepResearch',
                value: deepResearch,
                onChanged: onDeepResearchChanged,
                activeColor: AppColors.warmHorizon,
                fontSize: fontSize,
              ),
          ];

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var index = 0; index < toggles.length; index++) ...[
                if (index > 0) SizedBox(width: spacing),
                Expanded(child: toggles[index]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AiModalOptionToggle extends StatelessWidget {
  const _AiModalOptionToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.activeColor,
    required this.fontSize,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              context.t(label),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: AppColors.inkSoft,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _ToggleSwitch(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
          showCheckIcon: true,
        ),
      ],
    );
  }
}

class _AiModalItemPlanner extends StatelessWidget {
  const _AiModalItemPlanner({
    required this.items,
    required this.counts,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
  });

  final List<_AddBtn> items;
  final Map<String, int> counts;
  final bool enabled;
  final ValueChanged<_AddBtn> onAdd;
  final ValueChanged<_AddBtn> onRemove;
  final VoidCallback onClear;

  int get _totalCount =>
      counts.values.fold<int>(0, (total, count) => total + count);

  @override
  Widget build(BuildContext context) {
    final totalCount = _totalCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _newsAddStrongLine),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.deepOcean.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: const Icon(
                  Icons.add_box_outlined,
                  color: AppColors.deepOcean,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t('newsAdd.aiModal.items'),
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              _AiItemCounterBadge(totalCount: totalCount),
              if (totalCount > 0) ...[
                const SizedBox(width: 8),
                _AiItemClearButton(onTap: enabled ? onClear : null),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.t('newsAdd.aiModal.itemsHint'),
            style: const TextStyle(
              color: AppColors.iconMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 360;
              final itemWidth = twoColumns
                  ? ((constraints.maxWidth - 8) / 2)
                  : constraints.maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: itemWidth,
                      child: _AiItemChoiceChip(
                        item: item,
                        count: counts[item.label] ?? 0,
                        enabled: enabled,
                        onAdd: () => onAdd(item),
                        onRemove: () => onRemove(item),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AiItemCounterBadge extends StatelessWidget {
  const _AiItemCounterBadge({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: totalCount > 0
            ? AppColors.deepOcean.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(
          color: totalCount > 0
              ? AppColors.deepOcean.withValues(alpha: 0.16)
              : _newsAddSoftLine,
        ),
      ),
      child: Text(
        '${context.t('newsAdd.aiModal.totalItems')}: $totalCount',
        style: TextStyle(
          color: totalCount > 0 ? AppColors.deepOcean : AppColors.iconMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _AiItemClearButton extends StatelessWidget {
  const _AiItemClearButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.actionRed.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: AppColors.actionRed.withValues(alpha: 0.16),
            ),
          ),
          child: Text(
            context.t('newsAdd.aiModal.clearItems'),
            style: const TextStyle(
              color: AppColors.actionRed,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _AiItemChoiceChip extends StatelessWidget {
  const _AiItemChoiceChip({
    required this.item,
    required this.count,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final _AddBtn item;
  final int count;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final selected = count > 0;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onAdd : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          height: 28,
          padding: const EdgeInsets.only(left: 6, right: 6),
          decoration: BoxDecoration(
            color: selected
                ? item.color.withValues(alpha: 0.10)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected
                  ? item.color.withValues(alpha: 0.38)
                  : _newsAddSoftLine,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: Icon(item.icon, size: 11, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.t(item.label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Container(
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                  child: Text(
                    'x$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled ? onRemove : null,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.value),
                      border: Border.all(
                        color: item.color.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(Icons.remove, color: item.color, size: 12),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 6),
                Icon(Icons.add, color: item.color, size: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AiModalFooter extends StatelessWidget {
  const _AiModalFooter({
    required this.generating,
    required this.revisionMode,
    required this.onClose,
    required this.onGenerate,
  });

  final bool generating;
  final bool revisionMode;
  final VoidCallback? onClose;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: _newsAddSoftLine)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final actions = [
            _PillButton(
              icon: Icons.close,
              label: 'newsAdd.aiModal.close',
              onTap: onClose,
              background: Colors.white,
              foreground: AppColors.inkSoft,
              borderColor: _newsAddStrongLine,
              height: 38,
            ),
            _PillButton(
              icon: generating ? Icons.hourglass_empty : Icons.auto_awesome,
              label: generating
                  ? (revisionMode
                        ? 'newsAdd.aiModal.fixing'
                        : 'newsAdd.aiModal.generating')
                  : (revisionMode
                        ? 'newsAdd.aiModal.fix'
                        : 'newsAdd.aiModal.generate'),
              onTap: onGenerate,
              background: AppColors.deepOcean,
              foreground: Colors.white,
              height: 38,
            ),
          ];

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [actions[1], const SizedBox(height: 10), actions[0]],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [actions[0], const SizedBox(width: 10), actions[1]],
          );
        },
      ),
    );
  }
}

class _AiGenerationOverlay extends StatelessWidget {
  const _AiGenerationOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.white.withValues(alpha: 0.78),
        child: Center(
          child: Container(
            width: 340,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: _newsAddStrongLine),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepOcean.withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.deepOcean.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.deepOcean,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.t('newsAdd.aiModal.generating'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  context.t('newsAdd.aiModal.generatingHint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.iconMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    letterSpacing: 0.1,
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

class _AiGenerationError extends StatelessWidget {
  const _AiGenerationError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 12),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.actionRed),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.actionRed,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleAiReadyBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F5EC),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: const Color(0xFFB7E1C2)),
      ),
      child: Text(
        context.t('newsAdd.googleAiReady'),
        style: const TextStyle(
          color: Color(0xFF1F8B3D),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _SeoTitleField extends StatelessWidget {
  const _SeoTitleField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('newsAdd.seoTitle'),
        _TextInputBox(
          controller: controller,
          hintTextKey: 'newsAdd.seoTitleHint',
          fontSize: 13,
          bold: true,
        ),
      ],
    );
  }
}

class _SeoSlugField extends StatelessWidget {
  const _SeoSlugField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('newsAdd.slug'),
        _TextInputBox(
          controller: controller,
          hintTextKey: 'newsAdd.slugHint',
          fontSize: 13,
        ),
      ],
    );
  }
}

class _KeywordsInput extends StatelessWidget {
  const _KeywordsInput({
    required this.controller,
    required this.tags,
    required this.onSubmitted,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<String> tags;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _newsAddStrongLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tags.isNotEmpty) ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.deepOcean,
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onRemove(tag),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          TextField(
            controller: controller,
            cursorColor: AppColors.deepOcean,
            onSubmitted: onSubmitted,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: context.t('newsAdd.enterToAdd'),
              hintStyle: const TextStyle(
                color: AppColors.placeholder,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// FAQ
// ──────────────────────────────────────────────────────────────────────────────

class _FaqEntry {
  _FaqEntry()
    : question = TextEditingController(),
      answer = TextEditingController();

  final TextEditingController question;
  final TextEditingController answer;

  void dispose() {
    question.dispose();
    answer.dispose();
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_FaqEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<_FaqEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.softLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.format_list_bulleted,
                size: 16,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t('newsAdd.faqTitle'),
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              _PillButton(
                icon: Icons.add,
                label: 'newsAdd.addQuestion',
                onTap: onAdd,
                background: AppColors.deepOcean.withValues(alpha: 0.06),
                foreground: AppColors.deepOcean,
                borderColor: AppColors.deepOcean.withValues(alpha: 0.18),
                height: 30,
              ),
            ],
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (var i = 0; i < entries.length; i++) ...[
              _FaqRow(
                entry: entries[i],
                index: i + 1,
                onRemove: () => onRemove(entries[i]),
              ),
              if (i != entries.length - 1) const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({
    required this.entry,
    required this.index,
    required this.onRemove,
  });

  final _FaqEntry entry;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#$index',
                style: const TextStyle(
                  color: AppColors.support,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: const Icon(
                    Icons.close,
                    color: AppColors.support,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TextInputBox(
            controller: entry.question,
            hintTextKey: 'newsAdd.faqTitle',
            fontSize: 13,
            bold: true,
          ),
          const SizedBox(height: 8),
          _TextInputBox(
            controller: entry.answer,
            hintTextKey: 'newsAdd.contentHint',
            fontSize: 12.5,
            maxLines: 3,
            minLines: 2,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Article tab: sort controls + Metin Ekle block
// ──────────────────────────────────────────────────────────────────────────────

class _SortControls extends StatelessWidget {
  const _SortControls({required this.active, required this.onChanged});

  final _Sort active;
  final ValueChanged<_Sort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SortChip(
              icon: Icons.north,
              label: 'newsAdd.sortAsc',
              selected: active == _Sort.asc,
              onTap: () => onChanged(_Sort.asc),
            ),
            const SizedBox(width: 6),
            _SortChip(
              icon: Icons.south,
              label: 'newsAdd.sortDesc',
              selected: active == _Sort.desc,
              onTap: () => onChanged(_Sort.desc),
            ),
            const SizedBox(width: 6),
            _SortChip(
              icon: Icons.visibility_off_outlined,
              label: 'newsAdd.sortHide',
              selected: active == _Sort.hide,
              onTap: () => onChanged(_Sort.hide),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Sort { asc, desc, hide }

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: _newsAddActionHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.deepOcean : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
              Text(
                context.t(label),
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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

// ──────────────────────────────────────────────────────────────────────────────
// Add item buttons row (Makale tab)
// ──────────────────────────────────────────────────────────────────────────────

class _AddItemButtonsRow extends StatelessWidget {
  const _AddItemButtonsRow({
    required this.onTextAdd,
    required this.onImageAdd,
    required this.onSliderImageAdd,
    required this.onVideoAdd,
    required this.onAudioAdd,
    required this.onFileAdd,
    required this.onSocialAdd,
    required this.onFlipcardAdd,
    required this.onBeforeAfterAdd,
    required this.onPollAdd,
    required this.onVsAdd,
    required this.onReviewAdd,
    required this.onQuoteAdd,
    required this.onIframeAdd,
  });

  final VoidCallback onTextAdd;
  final VoidCallback onImageAdd;
  final VoidCallback onSliderImageAdd;
  final VoidCallback onVideoAdd;
  final VoidCallback onAudioAdd;
  final VoidCallback onFileAdd;
  final VoidCallback onSocialAdd;
  final VoidCallback onFlipcardAdd;
  final VoidCallback onBeforeAfterAdd;
  final VoidCallback onPollAdd;
  final VoidCallback onVsAdd;
  final VoidCallback onReviewAdd;
  final VoidCallback onQuoteAdd;
  final VoidCallback onIframeAdd;

  @override
  Widget build(BuildContext context) {
    final items = <_AddBtn>[
      const _AddBtn('newsAdd.add.text', Icons.text_fields, Color(0xFF2C3E50)),
      const _AddBtn(
        'newsAdd.add.image',
        Icons.image_outlined,
        Color(0xFF1F8B3D),
      ),
      const _AddBtn(
        'newsAdd.add.slider',
        Icons.collections_outlined,
        Color(0xFF2E7D32),
      ),
      const _AddBtn(
        'newsAdd.add.video',
        Icons.play_circle_outline,
        Color(0xFFC0392B),
      ),
      const _AddBtn(
        'newsAdd.add.audio',
        Icons.headphones_outlined,
        Color(0xFF8E44AD),
      ),
      const _AddBtn(
        'newsAdd.add.file',
        Icons.insert_drive_file_outlined,
        Color(0xFF7F8C8D),
      ),
      const _AddBtn(
        'newsAdd.add.social',
        Icons.share_outlined,
        Color(0xFF2980B9),
      ),
      const _AddBtn('newsAdd.add.flip', Icons.sync, Color(0xFFD35400)),
      const _AddBtn(
        'newsAdd.add.beforeAfter',
        Icons.compare_outlined,
        Color(0xFF1F6FA8),
      ),
      const _AddBtn(
        'newsAdd.add.poll',
        Icons.bar_chart_outlined,
        Color(0xFF5B3FB0),
      ),
      const _AddBtn(
        'newsAdd.add.vs',
        Icons.flash_on_outlined,
        Color(0xFFE91E63),
      ),
      const _AddBtn(
        'newsAdd.add.review',
        Icons.star_outline,
        Color(0xFF16A085),
      ),
      const _AddBtn('newsAdd.add.quote', Icons.format_quote, Color(0xFF34495E)),
      const _AddBtn('newsAdd.add.iframe', Icons.public, Color(0xFF3F51B5)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final item in items)
            _AddItemChip(
              icon: item.icon,
              label: item.label,
              color: item.color,
              onTap: switch (item.label) {
                'newsAdd.add.text' => onTextAdd,
                'newsAdd.add.image' => onImageAdd,
                'newsAdd.add.slider' => onSliderImageAdd,
                'newsAdd.add.video' => onVideoAdd,
                'newsAdd.add.audio' => onAudioAdd,
                'newsAdd.add.file' => onFileAdd,
                'newsAdd.add.social' => onSocialAdd,
                'newsAdd.add.flip' => onFlipcardAdd,
                'newsAdd.add.beforeAfter' => onBeforeAfterAdd,
                'newsAdd.add.poll' => onPollAdd,
                'newsAdd.add.vs' => onVsAdd,
                'newsAdd.add.review' => onReviewAdd,
                'newsAdd.add.quote' => onQuoteAdd,
                'newsAdd.add.iframe' => onIframeAdd,
                _ => null,
              },
            ),
        ],
      ),
    );
  }
}

class _AddBtn {
  const _AddBtn(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class _AddItemChip extends StatelessWidget {
  const _AddItemChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.20),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 15),
              const SizedBox(width: 8),
              Text(
                context.t(label),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Quiz tab pieces
// ──────────────────────────────────────────────────────────────────────────────

class _QuizSubTabsCard extends StatelessWidget {
  const _QuizSubTabsCard({required this.subTab, required this.onChanged});

  final NewsAddQuizSubTab subTab;
  final ValueChanged<NewsAddQuizSubTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = <_QuizTab>[
      const _QuizTab(
        NewsAddQuizSubTab.personality,
        Icons.person_outline,
        'newsAdd.quiz.tab.personality',
      ),
      const _QuizTab(
        NewsAddQuizSubTab.trivia,
        Icons.fact_check_outlined,
        'newsAdd.quiz.tab.trivia',
      ),
      const _QuizTab(
        NewsAddQuizSubTab.checklist,
        Icons.checklist_outlined,
        'newsAdd.quiz.tab.checklist',
      ),
    ];
    return Center(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: _newsAddStrongLine),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              _QuizTabChip(
                info: entries[i],
                selected: entries[i].id == subTab,
                onTap: () => onChanged(entries[i].id),
              ),
              if (i != entries.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizTab {
  const _QuizTab(this.id, this.icon, this.label);
  final NewsAddQuizSubTab id;
  final IconData icon;
  final String label;
}

class _QuizTabChip extends StatelessWidget {
  const _QuizTabChip({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final _QuizTab info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.deepOcean : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected ? AppColors.deepOcean : AppColors.softLine,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                info.icon,
                size: 14,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
              const SizedBox(width: 8),
              Text(
                context.t(info.label),
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.inkSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
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

class _ImageDropArea extends StatefulWidget {
  const _ImageDropArea({required this.label});
  final String label;

  @override
  State<_ImageDropArea> createState() => _ImageDropAreaState();
}

class _ImageDropAreaState extends State<_ImageDropArea> {
  String? _imageUrl;

  Future<void> _pickImage() async {
    final selected = await showMediaLibraryDialog(context);
    if (selected != null) setState(() => _imageUrl = selected);
  }

  Future<void> _pickUrl() async {
    final selected = await showUrlImageDialog(context);
    if (selected != null && selected.trim().isNotEmpty) {
      setState(() => _imageUrl = selected.trim());
    }
  }

  void _clearImage() => setState(() => _imageUrl = null);

  String _resolvedImageUrl(String value) {
    if (value.startsWith('http')) return value;
    return MediaService().resolveImageUrl(value, width: 720, quality: 90);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(widget.label),
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        DashedRect(
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: _imageUrl == null
                ? _QuizImageEmptyPicker(
                    onPickImage: _pickImage,
                    onPickUrl: _pickUrl,
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.network(
                          _resolvedImageUrl(_imageUrl!),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          cacheWidth: 720,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => _QuizImageEmptyPicker(
                            onPickImage: _pickImage,
                            onPickUrl: _pickUrl,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          children: [
                            _QuizImageActionBtn(
                              icon: Icons.edit_outlined,
                              color: AppColors.deepOcean,
                              onTap: _pickImage,
                            ),
                            const SizedBox(width: 8),
                            _QuizImageActionBtn(
                              icon: Icons.delete_outline,
                              color: AppColors.actionRed,
                              onTap: _clearImage,
                            ),
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
}

class _QuizImageEmptyPicker extends StatelessWidget {
  const _QuizImageEmptyPicker({
    required this.onPickImage,
    required this.onPickUrl,
  });

  final VoidCallback onPickImage;
  final VoidCallback onPickUrl;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPickImage,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, color: _newsAddUploadInk, size: 32),
              const SizedBox(height: 8),
              Text(
                context.t('newsAdd.imageSelect'),
                style: const TextStyle(
                  color: _newsAddUploadInk,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPickUrl,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.value),
                      border: Border.all(color: _newsAddStrongLine),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.public,
                          size: 13,
                          color: AppColors.deepOcean,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.t('newsAdd.addUrl'),
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
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

class _QuizImageActionBtn extends StatelessWidget {
  const _QuizImageActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _newsAddStrongLine),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
              ),
            ],
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _UploadStub extends StatelessWidget {
  const _UploadStub({this.onUrlTap});

  final VoidCallback? onUrlTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add, color: _newsAddUploadInk, size: 32),
        const SizedBox(height: 8),
        Text(
          context.t('newsAdd.imageSelect'),
          style: const TextStyle(
            color: _newsAddUploadInk,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        MouseRegion(
          cursor: onUrlTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onUrlTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(color: _newsAddStrongLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public, size: 13, color: AppColors.deepOcean),
                  const SizedBox(width: 6),
                  Text(
                    context.t('newsAdd.addUrl'),
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultDescriptionField extends StatefulWidget {
  const _ResultDescriptionField();

  @override
  State<_ResultDescriptionField> createState() =>
      _ResultDescriptionFieldState();
}

class _ResultDescriptionFieldState extends State<_ResultDescriptionField> {
  late final quill.QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController(
      document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppRadius.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('newsAdd.quiz.resultDescription'),
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius,
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: _newsAddStrongLine),
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
                  controller: _controller,
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
                        constraints: BoxConstraints.tightFor(
                          width: 26,
                          height: 26,
                        ),
                        color: Color(0xFF8C7A6A),
                      ),
                      iconButtonSelectedData: quill.IconButtonData(
                        iconSize: 17,
                        padding: EdgeInsets.all(2),
                        visualDensity: VisualDensity.compact,
                        constraints: BoxConstraints.tightFor(
                          width: 26,
                          height: 26,
                        ),
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
                height: 148,
                child: ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: quill.QuillEditor.basic(
                      controller: _controller,
                      config: quill.QuillEditorConfig(
                        placeholder: context.t(
                          'newsAdd.quiz.resultDescriptionHint',
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddResultButton extends StatelessWidget {
  const _AddResultButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: DashedRect(
            color: AppColors.actionRed.withValues(alpha: 0.22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.actionRed.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    color: AppColors.actionRed,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.t('newsAdd.quiz.addResult'),
                    style: const TextStyle(
                      color: AppColors.actionRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddQuizQuestionButton extends StatelessWidget {
  const _AddQuizQuestionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: DashedRect(
            color: AppColors.actionRed.withValues(alpha: 0.22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.actionRed.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    color: AppColors.actionRed,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.t('newsAdd.quiz.addQuestion'),
                    style: const TextStyle(
                      color: AppColors.actionRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizSortToolbar extends StatelessWidget {
  const _QuizSortToolbar({required this.active, required this.onChanged});

  final NewsAddQuizSort active;
  final ValueChanged<NewsAddQuizSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SortChip(
              icon: Icons.north,
              label: 'newsAdd.sortAsc',
              selected: active == NewsAddQuizSort.asc,
              onTap: () => onChanged(NewsAddQuizSort.asc),
            ),
            const SizedBox(width: 6),
            _SortChip(
              icon: Icons.south,
              label: 'newsAdd.sortDesc',
              selected: active == NewsAddQuizSort.desc,
              onTap: () => onChanged(NewsAddQuizSort.desc),
            ),
            const SizedBox(width: 6),
            _SortChip(
              icon: Icons.visibility_off_outlined,
              label: 'newsAdd.sortHide',
              selected: active == NewsAddQuizSort.hide,
              onTap: () => onChanged(NewsAddQuizSort.hide),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sidebar cards
// ──────────────────────────────────────────────────────────────────────────────

class _CoverCard extends StatefulWidget {
  const _CoverCard({
    required this.imageUrl,
    required this.altController,
    required this.onImageChanged,
  });

  final String? imageUrl;
  final TextEditingController altController;
  final ValueChanged<String?> onImageChanged;

  @override
  State<_CoverCard> createState() => _CoverCardState();
}

class _CoverCardState extends State<_CoverCard> {
  var _coverHover = false;

  Future<void> _openMediaLibrary() async {
    final selected = await showMediaLibraryDialog(context);
    if (selected != null && mounted) {
      widget.onImageChanged(selected);
    }
  }

  Future<void> _openUrlDialog() async {
    final url = await showUrlImageDialog(context);
    if (url != null && url.isNotEmpty && mounted) {
      widget.onImageChanged(url);
    }
  }

  Future<void> _openImageEditor() async {
    final current = widget.imageUrl;
    if (current == null) return;

    final mediaService = MediaService();
    final imageUrl = current.startsWith('http')
        ? current
        : mediaService.resolveUrl(current);
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
                  final result = await mediaService.uploadFile(
                    fileName:
                        'cover-edited-${DateTime.now().millisecondsSinceEpoch}.jpg',
                    bytes: bytes,
                    type: 'image',
                  );
                  if (result != null && mounted) {
                    widget.onImageChanged(result.src);
                    setState(() => _coverHover = false);
                  }
                  if (editorContext.mounted) {
                    editorClosing = true;
                    Navigator.of(editorContext).pop();
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
  }

  void _clearCoverImage() {
    widget.onImageChanged(null);
    setState(() => _coverHover = false);
  }

  String _resolvedCoverImageUrl(String value) {
    if (value.startsWith('http')) return value;
    return MediaService().resolveImageUrl(value, width: 720, quality: 90);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return _SectionCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14, left: 2),
            child: Text(
              context.t('newsAdd.cover'),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.35,
              ),
            ),
          ),
          GestureDetector(
            onTap: _openMediaLibrary,
            child: MouseRegion(
              onEnter: (_) => setState(() => _coverHover = true),
              onExit: (_) => setState(() => _coverHover = false),
              cursor: SystemMouseCursors.click,
              child: DashedRect(
                strokeWidth: 1.35,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasImage
                      ? Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.value,
                                ),
                                child: Image.network(
                                  _resolvedCoverImageUrl(imageUrl),
                                  width: double.infinity,
                                  cacheWidth: 720,
                                  fit: BoxFit.fitWidth,
                                  alignment: Alignment.topCenter,
                                  filterQuality: FilterQuality.high,
                                  isAntiAlias: true,
                                  gaplessPlayback: true,
                                  loadingBuilder: (_, child, loadingProgress) {
                                    if (loadingProgress == null) {
                                      return child;
                                    }
                                    return const SizedBox(
                                      height: _newsAddCoverVisualHeight,
                                      child: Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.deepOcean,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, _, _) => SizedBox(
                                    height: _newsAddCoverVisualHeight,
                                    child: _UploadStub(
                                      onUrlTap: _openUrlDialog,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_coverHover)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _CoverImageActionButton(
                                      icon: Icons.edit_outlined,
                                      color: AppColors.deepOcean,
                                      onTap: _openImageEditor,
                                    ),
                                    const SizedBox(width: 8),
                                    _CoverImageActionButton(
                                      icon: Icons.delete_outline_rounded,
                                      color: AppColors.actionRed,
                                      onTap: _clearCoverImage,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : SizedBox(
                          height: _newsAddCoverVisualHeight,
                          child: Center(
                            child: _UploadStub(onUrlTap: _openUrlDialog),
                          ),
                        ),
                ),
              ),
            ),
          ),
          if (hasImage) ...[
            const SizedBox(height: 14),
            _CoverAltTextPanel(controller: widget.altController),
          ],
        ],
      ),
    );
  }
}

class _CoverAltTextPanel extends StatelessWidget {
  const _CoverAltTextPanel({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _TextInputBox(
      controller: controller,
      hintTextKey: 'newsAdd.coverAltTextHint',
      fontSize: 12.5,
    );
  }
}

class _CoverImageActionButton extends StatelessWidget {
  const _CoverImageActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _newsAddStrongLine),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
              ),
            ],
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _CategorySettingsCard extends StatelessWidget {
  const _CategorySettingsCard({
    required this.languageCode,
    required this.mainCategory,
    required this.subCategory,
    required this.thirdCategory,
    required this.languages,
    required this.mainCategories,
    required this.subCategories,
    required this.thirdCategories,
    required this.onLanguageChanged,
    required this.onMainChanged,
    required this.onSubChanged,
    required this.onThirdChanged,
  });

  final String languageCode;
  final String mainCategory;
  final String? subCategory;
  final String? thirdCategory;
  final List<AdminNewsEditorLanguage> languages;
  final List<AdminNewsEditorCategory> mainCategories;
  final List<AdminNewsEditorCategory> subCategories;
  final List<AdminNewsEditorCategory> thirdCategories;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onMainChanged;
  final ValueChanged<String?> onSubChanged;
  final ValueChanged<String?> onThirdChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.t('newsAdd.categorySettings'),
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const Icon(
                  Icons.settings_outlined,
                  size: 14,
                  color: AppColors.iconMuted,
                ),
              ],
            ),
          ),
          const _FieldLabel('newsAdd.language', icon: Icons.language),
          _DropdownField(
            value: languageCode,
            leadingIcon: Icons.language,
            items: [
              for (final language in languages)
                DropdownMenuItem(
                  value: language.code,
                  child: Text(language.name),
                ),
            ],
            onChanged: onLanguageChanged,
          ),
          const SizedBox(height: 16),
          const _FieldLabel(
            'newsAdd.mainCategory',
            icon: Icons.category_outlined,
          ),
          _DropdownField(
            value: mainCategory,
            leadingIcon: Icons.category_outlined,
            items: [
              for (final category in mainCategories)
                DropdownMenuItem(
                  value: category.label,
                  child: Text(category.label),
                ),
            ],
            onChanged: onMainChanged,
          ),
          const SizedBox(height: 16),
          const _FieldLabel(
            'newsAdd.subCategory',
            icon: Icons.list_alt_outlined,
          ),
          _DropdownField(
            value: subCategory ?? '',
            leadingIcon: Icons.list_alt_outlined,
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(context.t('newsAdd.selectSubCategory')),
              ),
              for (final category in subCategories)
                DropdownMenuItem(
                  value: category.label,
                  child: Text(category.label),
                ),
            ],
            onChanged: onSubChanged,
          ),
          if (thirdCategories.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _FieldLabel(
              'newsAdd.thirdCategory',
              icon: Icons.list_alt_outlined,
            ),
            _DropdownField(
              value: thirdCategory ?? '',
              leadingIcon: Icons.list_alt_outlined,
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(context.t('newsAdd.selectSubCategory')),
                ),
                for (final category in thirdCategories)
                  DropdownMenuItem(
                    value: category.label,
                    child: Text(category.label),
                  ),
              ],
              onChanged: onThirdChanged,
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.actionRed.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(
                color: AppColors.actionRed.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('newsAdd.selectedCategory'),
                  style: const TextStyle(
                    color: AppColors.actionRed,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    mainCategory,
                    if ((subCategory ?? '').isNotEmpty) subCategory,
                    if ((thirdCategory ?? '').isNotEmpty) thirdCategory,
                  ].whereType<String>().join(' > '),
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishCard extends StatelessWidget {
  const _PublishCard({
    required this.factCheck,
    required this.publishAtController,
    required this.saving,
    required this.onFactCheckChanged,
    required this.onSaveDraft,
    required this.onPublish,
    required this.onSchedule,
  });

  final bool factCheck;
  final TextEditingController publishAtController;
  final bool saving;
  final ValueChanged<bool> onFactCheckChanged;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 2),
            child: Text(
              context.t('newsAdd.publishing'),
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: factCheck
                      ? const Color(0xFF1F8B3D)
                      : AppColors.iconMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t('newsAdd.factCheck'),
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _ToggleSwitch(
                  value: factCheck,
                  onChanged: onFactCheckChanged,
                  activeColor: const Color(0xFF1F8B3D),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('newsAdd.scheduledPublish'),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: publishAtController,
                    cursorColor: AppColors.deepOcean,
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: context.t('newsAdd.datePlaceholder'),
                      hintStyle: const TextStyle(
                        color: AppColors.placeholder,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9\.\:\s]')),
                    ],
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: AppColors.iconMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _PublishActionButton(
                  label: 'newsAdd.draft',
                  icon: Symbols.draft,
                  variant: _PublishVariant.outline,
                  loading: saving,
                  onTap: onSaveDraft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PublishActionButton(
                  label: 'newsAdd.publish',
                  icon: Symbols.upload,
                  variant: _PublishVariant.primary,
                  loading: saving,
                  onTap: onPublish,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PublishActionButton(
            label: 'newsAdd.scheduleSave',
            icon: Symbols.schedule_send,
            variant: _PublishVariant.muted,
            loading: saving,
            onTap: onSchedule,
          ),
        ],
      ),
    );
  }
}

enum _PublishVariant { primary, outline, muted }

class _PublishActionButton extends StatelessWidget {
  const _PublishActionButton({
    required this.label,
    required this.icon,
    required this.variant,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final _PublishVariant variant;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color? borderColor;
    switch (variant) {
      case _PublishVariant.primary:
        bg = AppColors.actionRed;
        fg = Colors.white;
        borderColor = null;
      case _PublishVariant.outline:
        bg = Colors.white;
        fg = AppColors.deepOcean;
        borderColor = AppColors.line;
      case _PublishVariant.muted:
        bg = AppColors.surface.withValues(alpha: 0.8);
        fg = AppColors.deepOcean;
        borderColor = AppColors.line;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: loading ? null : onTap,
        child: Container(
          height: _newsAddActionHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: borderColor == null ? null : Border.all(color: borderColor),
            boxShadow: variant == _PublishVariant.primary
                ? [
                    BoxShadow(
                      color: AppColors.actionRed.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else
                SymbolIcon(icon, color: fg, size: 15),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.t(label),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
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
