import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/network/admin_api_headers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/media_service.dart';
import '../../../../shared/icons/symbols.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import '../../../settings/data/admin_ai_settings_repository.dart';
import '../../data/admin_news_headline_repository.dart';

const _headlineTargets = <String, _HeadlineTargetSpec>{
  'headline_square': _HeadlineTargetSpec(
    labelKey: 'newsAdd.headlineGenerator.target.headlineSquare',
    ratioLabel: '1:1',
  ),
  'article_4x3': _HeadlineTargetSpec(
    labelKey: 'newsAdd.headlineGenerator.target.article4x3',
    ratioLabel: '4:3',
  ),
  'landscape_16x9': _HeadlineTargetSpec(
    labelKey: 'newsAdd.headlineGenerator.target.landscape16x9',
    ratioLabel: '16:9',
  ),
  'social_9x16': _HeadlineTargetSpec(
    labelKey: 'newsAdd.headlineGenerator.target.social9x16',
    ratioLabel: '9:16',
  ),
};

class NewsHeadlineGeneratorDialog extends StatefulWidget {
  const NewsHeadlineGeneratorDialog({
    super.key,
    required this.languageCode,
    required this.contextData,
    required this.source,
    required this.displayImageUrl,
    this.promptRepository = const SupabaseAdminAiSettingsRepository(),
    this.headlineRepository = const HttpAdminNewsHeadlineRepository(),
    this.mediaService,
    this.initialAssignToManset = true,
    this.initialAssignToArticleImageBlock = true,
    this.initialAssignToCover = false,
    this.initialTarget = 'headline_square',
  });

  final String languageCode;
  final AdminNewsHeadlineContext contextData;
  final AdminNewsHeadlineSource source;
  final String displayImageUrl;
  final AdminAiSettingsRepository promptRepository;
  final AdminNewsHeadlineRepository headlineRepository;
  final MediaService? mediaService;
  final bool initialAssignToManset;
  final bool initialAssignToArticleImageBlock;
  final bool initialAssignToCover;
  final String initialTarget;

  @override
  State<NewsHeadlineGeneratorDialog> createState() =>
      _NewsHeadlineGeneratorDialogState();
}

class NewsHeadlineGeneratorResult {
  const NewsHeadlineGeneratorResult({
    required this.mediaItem,
    required this.altText,
    required this.assignToManset,
    required this.assignToArticleImageBlock,
    required this.assignToCover,
  });

  final MediaItem mediaItem;
  final String altText;
  final bool assignToManset;
  final bool assignToArticleImageBlock;
  final bool assignToCover;
}

class _NewsHeadlineGeneratorDialogState
    extends State<NewsHeadlineGeneratorDialog> {
  late final TextEditingController _kickerController;
  late final TextEditingController _topController;
  late final TextEditingController _mainController;
  late final TextEditingController _bottomController;
  late final TextEditingController _supportController;
  late final TextEditingController _taglineController;
  late final TextEditingController _altTextController;

  var _target = 'headline_square';
  var _prompts = const <AdminAiPrompt>[];
  String? _promptId;
  AdminNewsHeadlinePlan? _plan;
  AdminNewsHeadlinePreview? _preview;
  String? _error;
  var _loadingPrompts = true;
  var _planning = false;
  var _rendering = false;
  var _saving = false;
  var _assignToManset = true;
  var _assignToArticleImageBlock = true;
  var _assignToCover = false;

  MediaService get _mediaService => widget.mediaService ?? MediaService();

  @override
  void initState() {
    super.initState();
    _target = _headlineTargets.containsKey(widget.initialTarget)
        ? widget.initialTarget
        : 'headline_square';
    _assignToManset = widget.initialAssignToManset;
    _assignToArticleImageBlock = widget.initialAssignToArticleImageBlock;
    _assignToCover = widget.initialAssignToCover;
    _kickerController = TextEditingController();
    _topController = TextEditingController();
    _mainController = TextEditingController(text: widget.contextData.title);
    _bottomController = TextEditingController();
    _supportController = TextEditingController(
      text: widget.contextData.summary,
    );
    _taglineController = TextEditingController(
      text: widget.contextData.categoryPath,
    );
    _altTextController = TextEditingController(text: widget.source.altText);
    for (final controller in [
      _kickerController,
      _topController,
      _mainController,
      _bottomController,
      _supportController,
      _taglineController,
      _altTextController,
    ]) {
      controller.addListener(_clearPreviewAfterEdit);
    }
    unawaited(_loadPrompts());
  }

  @override
  void dispose() {
    _kickerController.dispose();
    _topController.dispose();
    _mainController.dispose();
    _bottomController.dispose();
    _supportController.dispose();
    _taglineController.dispose();
    _altTextController.dispose();
    super.dispose();
  }

  Future<void> _loadPrompts() async {
    try {
      final prompts = await widget.promptRepository.fetchPrompts(
        widget.languageCode,
      );
      final headlinePrompts = prompts
          .where(
            (prompt) =>
                prompt.isActive &&
                prompt.purpose == adminAiPromptPurposeHeadlineImage &&
                prompt.prompt.trim().isNotEmpty,
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _prompts = headlinePrompts;
        _promptId = headlinePrompts.isEmpty ? null : headlinePrompts.first.id;
        _loadingPrompts = false;
        _error = headlinePrompts.isEmpty
            ? context.t('newsAdd.headlineGenerator.noPrompt')
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPrompts = false;
        _error = error.toString();
      });
    }
  }

  void _clearPreviewAfterEdit() {
    if (_preview == null || !mounted) return;
    setState(() => _preview = null);
  }

  Future<void> _generatePlan() async {
    final promptId = _promptId?.trim() ?? '';
    if (promptId.isEmpty || _planning || _rendering || _saving) return;
    setState(() {
      _planning = true;
      _error = null;
      _preview = null;
    });
    try {
      final plan = await widget.headlineRepository.generatePlan(
        languageCode: widget.languageCode,
        promptId: promptId,
        target: _target,
        context: widget.contextData,
        source: widget.source,
      );
      if (!mounted) return;
      _applyPlan(plan);
      setState(() {
        _plan = plan;
        _planning = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _planning = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _renderPreview() async {
    final plan = _editedPlan;
    if (_rendering || _planning || _saving) return;
    setState(() {
      _rendering = true;
      _error = null;
    });
    try {
      final preview = await widget.headlineRepository.renderPreview(
        languageCode: widget.languageCode,
        target: _target,
        context: widget.contextData,
        source: widget.source,
        plan: plan,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _preview = preview;
        _rendering = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rendering = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _confirm() async {
    final preview = _preview;
    if (preview == null || _saving || _planning || _rendering) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uploaded = await _mediaService.uploadFile(
        fileName: preview.fileName,
        bytes: preview.bytes,
        type: 'image',
        customFilename: preview.fileName,
        languageCode: widget.languageCode,
      );
      if (!mounted) return;
      if (uploaded == null) {
        setState(() {
          _saving = false;
          _error = context.t('newsAdd.headlineGenerator.uploadFailed');
        });
        return;
      }
      Navigator.of(context).pop(
        NewsHeadlineGeneratorResult(
          mediaItem: uploaded,
          altText: _altTextController.text.trim(),
          assignToManset: _assignToManset,
          assignToArticleImageBlock: _assignToArticleImageBlock,
          assignToCover: _assignToCover,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  AdminNewsHeadlinePlan get _editedPlan {
    final current =
        _plan ??
        AdminNewsHeadlinePlan.fromJson({
          'schemaVersion': 1,
          'templateId': 'classic-red-yellow-blue',
          'target': _target,
          'headline': <String, Object?>{},
          'media': <String, Object?>{},
        });
    return current.copyWithText(
      kicker: _kickerController.text,
      top: _topController.text,
      main: _mainController.text,
      bottom: _bottomController.text,
      support: _supportController.text,
      tagline: _taglineController.text,
      altText: _altTextController.text,
    );
  }

  void _applyPlan(AdminNewsHeadlinePlan plan) {
    _kickerController.text = plan.kicker;
    _topController.text = plan.top;
    _mainController.text = plan.main;
    _bottomController.text = plan.bottom;
    _supportController.text = plan.support;
    _taglineController.text = plan.tagline;
    _altTextController.text = plan.altText.isEmpty
        ? widget.source.altText
        : plan.altText;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 980;
    final width = narrow
        ? size.width - 32
        : (size.width * 0.72).clamp(940.0, 1240.0).toDouble();
    final height = (size.height - 52).clamp(620.0, 860.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: width,
        height: height.toDouble(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: const Color(0xFFDDE5E8)),
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
            _Header(onClose: () => Navigator.of(context).maybePop()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: narrow
                    ? Column(
                        children: [
                          Expanded(flex: 5, child: _sourceAndPreview()),
                          const SizedBox(height: 14),
                          Expanded(flex: 6, child: _controls()),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: _sourceAndPreview()),
                          const SizedBox(width: 18),
                          Expanded(flex: 6, child: _controls()),
                        ],
                      ),
              ),
            ),
            _Footer(
              planning: _planning,
              rendering: _rendering,
              saving: _saving,
              canPlan:
                  !_loadingPrompts && (_promptId?.trim().isNotEmpty ?? false),
              canRender: _mainController.text.trim().isNotEmpty,
              canConfirm: _preview != null,
              onPlan: _generatePlan,
              onRender: _renderPreview,
              onConfirm: _confirm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceAndPreview() {
    return _PanelFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle('newsAdd.headlineGenerator.source'),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.value),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.softLine),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: _HeadlineSourceImage(
                  url: widget.displayImageUrl,
                  fit: BoxFit.contain,
                  errorWidget: const _ImageFallback(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _InfoLine(
            label: 'newsAdd.headlineGenerator.sourceUrl',
            value: widget.source.originalUrl,
            maxLines: 2,
          ),
          _InfoLine(
            label: 'newsAdd.headlineGenerator.sourceAlt',
            value: widget.source.altText,
            maxLines: 1,
          ),
          const SizedBox(height: 10),
          _SectionTitle('newsAdd.headlineGenerator.preview'),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(color: AppColors.softLine),
              ),
              child: _preview == null
                  ? Text(
                      context.t('newsAdd.headlineGenerator.previewEmpty'),
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8),
                      child:
                          _preview!.contentType.toLowerCase().startsWith(
                            'image/svg',
                          )
                          ? SvgPicture.memory(
                              _preview!.bytes,
                              fit: BoxFit.contain,
                            )
                          : Image.memory(_preview!.bytes, fit: BoxFit.contain),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return _PanelFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle('newsAdd.headlineGenerator.newsInfo'),
          const SizedBox(height: 8),
          _InfoLine(
            label: 'newsAdd.headlineGenerator.newsTitle',
            value: widget.contextData.title,
            maxLines: 1,
          ),
          _InfoLine(
            label: 'newsAdd.headlineGenerator.newsSummary',
            value: widget.contextData.summary,
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PromptDropdown(
                  loading: _loadingPrompts,
                  prompts: _prompts,
                  value: _promptId,
                  onChanged: (value) => setState(() => _promptId = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TargetDropdown(
                  value: _target,
                  onChanged: (value) {
                    setState(() {
                      _target = value ?? 'headline_square';
                      _assignToManset = _target == 'headline_square';
                      _preview = null;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionTitle('newsAdd.headlineGenerator.manualEdit'),
          const SizedBox(height: 8),
          _ManualFieldsGrid(
            children: [
              _TextFieldLine(
                label: 'newsAdd.headlineGenerator.kicker',
                controller: _kickerController,
              ),
              _TextFieldLine(
                label: 'newsAdd.headlineGenerator.top',
                controller: _topController,
              ),
              _TextFieldLine(
                label: 'newsAdd.headlineGenerator.main',
                controller: _mainController,
              ),
              _TextFieldLine(
                label: 'newsAdd.headlineGenerator.bottom',
                controller: _bottomController,
              ),
              _TextFieldLine(
                label: 'newsAdd.headlineGenerator.support',
                controller: _supportController,
              ),
              _TextFieldLine(
                label: 'newsAdd.headlineGenerator.tagline',
                controller: _taglineController,
              ),
              _TextFieldLine(
                label: 'newsAdd.headlineGenerator.altText',
                controller: _altTextController,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _SectionTitle('newsAdd.headlineGenerator.assignments'),
          const SizedBox(height: 8),
          _CheckLine(
            label: 'newsAdd.headlineGenerator.assignManset',
            value: _assignToManset,
            enabled: _target == 'headline_square',
            onChanged: (value) => setState(() => _assignToManset = value),
          ),
          const SizedBox(height: 6),
          _CheckLine(
            label: 'newsAdd.headlineGenerator.assignBlock',
            value: _assignToArticleImageBlock,
            onChanged: (value) {
              setState(() => _assignToArticleImageBlock = value);
            },
          ),
          const SizedBox(height: 6),
          _CheckLine(
            label: 'newsAdd.headlineGenerator.assignCover',
            value: _assignToCover,
            onChanged: (value) => setState(() => _assignToCover = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.actionRed,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeadlineTargetSpec {
  const _HeadlineTargetSpec({required this.labelKey, required this.ratioLabel});

  final String labelKey;
  final String ratioLabel;
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8EEF1))),
      ),
      child: Row(
        children: [
          const SymbolIcon(
            Symbols.auto_awesome,
            color: AppColors.actionRed,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.t('newsAdd.headlineGenerator.title'),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const SymbolIcon(Symbols.close, size: 20),
            color: AppColors.inkSoft,
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.planning,
    required this.rendering,
    required this.saving,
    required this.canPlan,
    required this.canRender,
    required this.canConfirm,
    required this.onPlan,
    required this.onRender,
    required this.onConfirm,
  });

  final bool planning;
  final bool rendering;
  final bool saving;
  final bool canPlan;
  final bool canRender;
  final bool canConfirm;
  final VoidCallback onPlan;
  final VoidCallback onRender;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFE8EEF1))),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 10,
        runSpacing: 10,
        children: [
          _ActionButton(
            icon: Symbols.auto_awesome,
            label: planning
                ? 'newsAdd.headlineGenerator.planning'
                : 'newsAdd.headlineGenerator.generatePlan',
            enabled: canPlan && !planning && !rendering && !saving,
            onTap: onPlan,
            color: AppColors.actionRed,
          ),
          _ActionButton(
            icon: Symbols.image_search_outlined,
            label: rendering
                ? 'newsAdd.headlineGenerator.rendering'
                : 'newsAdd.headlineGenerator.renderPreview',
            enabled: canRender && !planning && !rendering && !saving,
            onTap: onRender,
            color: AppColors.deepOcean,
          ),
          _ActionButton(
            icon: Symbols.check_circle_outline,
            label: saving
                ? 'newsAdd.headlineGenerator.saving'
                : 'newsAdd.headlineGenerator.confirm',
            enabled: canConfirm && !planning && !rendering && !saving,
            onTap: onConfirm,
            color: AppColors.deepOcean,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: TextButton.icon(
        onPressed: enabled ? onTap : null,
        icon: SymbolIcon(icon, size: 18),
        label: Text(context.t(label)),
        style: TextButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: const Color(0xFFE3EBEF)),
      ),
      child: child,
    );
  }
}

class _PromptDropdown extends StatelessWidget {
  const _PromptDropdown({
    required this.loading,
    required this.prompts,
    required this.value,
    required this.onChanged,
  });

  final bool loading;
  final List<AdminAiPrompt> prompts;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _DropdownBox(
      label: 'newsAdd.headlineGenerator.prompt',
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: [
          for (final prompt in prompts)
            DropdownMenuItem(value: prompt.id, child: Text(prompt.title)),
        ],
        onChanged: loading || prompts.isEmpty ? null : onChanged,
        decoration: _inputDecoration(context),
        hint: Text(
          context.t(
            loading
                ? 'newsAdd.headlineGenerator.loadingPrompts'
                : 'newsAdd.headlineGenerator.promptEmpty',
          ),
        ),
      ),
    );
  }
}

class _TargetDropdown extends StatelessWidget {
  const _TargetDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _DropdownBox(
      label: 'newsAdd.headlineGenerator.target',
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: [
          for (final entry in _headlineTargets.entries)
            DropdownMenuItem(
              value: entry.key,
              child: Text(
                '${context.t(entry.value.labelKey)} - ${entry.value.ratioLabel}',
              ),
            ),
        ],
        onChanged: onChanged,
        decoration: _inputDecoration(context),
      ),
    );
  }
}

class _DropdownBox extends StatelessWidget {
  const _DropdownBox({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_FieldLabel(label), const SizedBox(height: 8), child],
    );
  }
}

class _ManualFieldsGrid extends StatelessWidget {
  const _ManualFieldsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(children: children);
        }
        final rows = <Widget>[];
        for (var index = 0; index < children.length; index += 2) {
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[index]),
                const SizedBox(width: 12),
                Expanded(
                  child: index + 1 < children.length
                      ? children[index + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _TextFieldLine extends StatelessWidget {
  const _TextFieldLine({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(label),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 1,
            decoration: _inputDecoration(context),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && value;
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: InkWell(
        onTap: enabled ? () => onChanged(!value) : null,
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: Container(
          height: 36,
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: active
                ? AppColors.actionRed.withValues(alpha: 0.07)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: active
                  ? AppColors.actionRed.withValues(alpha: 0.25)
                  : AppColors.softLine,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.t(label),
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
              Checkbox(
                value: active,
                onChanged: enabled
                    ? (checked) => onChanged(checked == true)
                    : null,
                activeColor: AppColors.actionRed,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t(label),
      style: const TextStyle(
        color: AppColors.deepOcean,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t(label),
      style: const TextStyle(
        color: AppColors.inkSoft,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.maxLines = 2,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final text = value.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${context.t(label)}: ',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(text: text),
          ],
        ),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          height: 1.35,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _HeadlineSourceImage extends StatefulWidget {
  const _HeadlineSourceImage({
    required this.url,
    required this.fit,
    required this.errorWidget,
  });

  final String url;
  final BoxFit fit;
  final Widget errorWidget;

  @override
  State<_HeadlineSourceImage> createState() => _HeadlineSourceImageState();
}

class _HeadlineSourceImageState extends State<_HeadlineSourceImage> {
  Future<Map<String, String>>? _headersFuture;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didUpdateWidget(covariant _HeadlineSourceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _configure();
  }

  void _configure() {
    _headersFuture = _needsAdminImageHeaders(widget.url)
        ? adminAuthHeaders()
        : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_headersFuture == null) return _buildImage(null);
    return FutureBuilder<Map<String, String>>(
      future: _headersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(color: AppColors.surface);
        }
        return _buildImage(snapshot.data);
      },
    );
  }

  Widget _buildImage(Map<String, String>? headers) {
    return AdminCachedImage(
      url: widget.url,
      fit: widget.fit,
      httpHeaders: headers,
      errorWidget: widget.errorWidget,
    );
  }
}

bool _needsAdminImageHeaders(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && uri.path.startsWith('/api/admin/');
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: SymbolIcon(
          Symbols.broken_image_outlined,
          color: AppColors.inkSoft,
          size: 28,
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(BuildContext context) {
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: Color(0xFFDDE5E8)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: Color(0xFFDDE5E8)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: AppColors.actionRed, width: 1.3),
    ),
  );
}
