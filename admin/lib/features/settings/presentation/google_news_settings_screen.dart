import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_google_news_settings_repository.dart';

class GoogleNewsSettingsScreen extends StatefulWidget {
  const GoogleNewsSettingsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminGoogleNewsSettingsRepository(),
  });

  final AdminSession session;
  final AdminGoogleNewsSettingsRepository repository;

  @override
  State<GoogleNewsSettingsScreen> createState() =>
      _GoogleNewsSettingsScreenState();
}

class _GoogleNewsSettingsScreenState extends State<GoogleNewsSettingsScreen> {
  static const _rssFullOption = 'googleNews.option.showFullContent';
  static const _rssSummaryOption = 'googleNews.option.showSummary';
  static const _categoryAllOption = 'googleNews.option.allCategories';
  static const _categoryNewsOption = 'googleNews.option.news';
  static const _categoryVideoOption = 'googleNews.option.video';

  final _publicationNameController = TextEditingController(text: 'Pateez');
  final _feedPostLimitController = TextEditingController(text: '50');

  var _active = true;
  var _rssContent = _rssFullOption;
  var _language = 'language.name.tr';
  var _category = _categoryAllOption;
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _publicationNameController.dispose();
    _feedPostLimitController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await widget.repository.fetchSettings('tr');
      if (!mounted) return;
      _applySettings(settings);
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _applySettings(GoogleNewsSettingsData settings) {
    _active = settings.enabled;
    _publicationNameController.text = settings.publicationName;
    _feedPostLimitController.text = settings.feedLimit.toString();
    _rssContent = settings.rssContentMode == GoogleNewsRssContentMode.summary
        ? _rssSummaryOption
        : _rssFullOption;
    _language = _languageOptionForCode(settings.languageCode);
  }

  Future<void> _saveSettings() async {
    if (_loading || _saving) return;
    final publicationName = _publicationNameController.text.trim();
    if (publicationName.isEmpty) {
      _showMessage('googleNews.error.publicationNameRequired');
      return;
    }
    final feedLimit = _boundedInt(
      _feedPostLimitController.text,
      fallback: 50,
      min: 1,
      max: 100,
    );
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.saveSettings(
        session: widget.session,
        settings: GoogleNewsSettingsData(
          languageCode: _languageCode,
          enabled: _active,
          publicationName: publicationName,
          rssContentMode: _rssMode,
          feedLimit: feedLimit,
        ),
      );
      if (!mounted) return;
      _applySettings(saved);
      setState(() => _saving = false);
      _showMessage('googleNews.saveSuccess', tone: AdminToastTone.success);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('${context.t('settings.save_error')}: $error');
    }
  }

  Future<void> _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _showMessage('googleNews.copySuccess', tone: AdminToastTone.success);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  void _showMessage(
    String message, {
    AdminToastTone tone = AdminToastTone.info,
  }) {
    AdminToast.show(context, message: context.t(message), tone: tone);
  }

  String get _languageCode {
    return switch (_language) {
      'language.name.en' => 'en',
      'language.name.ar' => 'ar',
      _ => 'tr',
    };
  }

  String get _rssMode => _rssContent == _rssSummaryOption
      ? GoogleNewsRssContentMode.summary
      : GoogleNewsRssContentMode.full;

  String get _typeParam {
    if (_category == _categoryNewsOption) return 'article';
    if (_category == _categoryVideoOption) return 'video';
    return '';
  }

  String get _generatedFeedUrl {
    final params = <String, String>{'lang': _languageCode};
    if (_typeParam.isNotEmpty) params['type'] = _typeParam;
    return _absoluteUrl('/service/feed/google-news', params);
  }

  String get _primaryFeedUrl =>
      _absoluteUrl('/service/feed/google-news', {'lang': _languageCode});

  String get _newsSitemapUrl => _absoluteUrl('/news-sitemap.xml');

  String _absoluteUrl(String path, [Map<String, String>? query]) {
    final uri = Uri.base.resolve(path).replace(queryParameters: query);
    if (uri.hasScheme && uri.host.isNotEmpty) return uri.toString();
    return Uri.https('www.pateez.com', path, query).toString();
  }

  String _languageOptionForCode(String code) {
    return switch (code.trim().toLowerCase()) {
      'en' => 'language.name.en',
      'ar' => 'language.name.ar',
      _ => 'language.name.tr',
    };
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
              Text(
                context.t('googleNews.title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 22),
              if (_loading)
                const _GoogleNewsStatusCard(
                  message: 'googleNews.loading',
                  progress: true,
                )
              else if (_error != null)
                _GoogleNewsStatusCard(
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadSettings,
                )
              else
                _GoogleNewsLayout(
                  left: _SettingsCard(
                    active: _active,
                    enabled: !_saving,
                    saving: _saving,
                    publicationNameController: _publicationNameController,
                    rssContent: _rssContent,
                    feedPostLimitController: _feedPostLimitController,
                    onActiveChanged: (value) {
                      if (_saving) return;
                      setState(() => _active = value);
                    },
                    onRssContentChanged: (value) {
                      if (value == null || _saving) return;
                      setState(() => _rssContent = value);
                    },
                    onSave: _saveSettings,
                  ),
                  right: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FeedGeneratorCard(
                        language: _language,
                        category: _category,
                        generatedUrl: _generatedFeedUrl,
                        onCopyUrl: () => _copyUrl(_generatedFeedUrl),
                        onOpenUrl: () => _openUrl(_generatedFeedUrl),
                        onLanguageChanged: (value) {
                          if (value == null || _saving) return;
                          setState(() => _language = value);
                        },
                        onCategoryChanged: (value) {
                          if (value == null || _saving) return;
                          setState(() => _category = value);
                        },
                      ),
                      const SizedBox(height: 20),
                      _IntegrationEndpointsCard(
                        newsSitemapUrl: _newsSitemapUrl,
                        primaryFeedUrl: _primaryFeedUrl,
                        onOpenUrl: _openUrl,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GoogleNewsStatusCard extends StatelessWidget {
  const _GoogleNewsStatusCard({
    required this.message,
    this.progress = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool progress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _GoogleNewsCard(
      child: Row(
        children: [
          if (progress)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.actionRed,
              ),
            )
          else
            const SymbolIcon(
              Symbols.info_outline_rounded,
              color: AppColors.actionRed,
              size: 20,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.t(message),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 12),
            _PrimaryButton(
              label: actionLabel!,
              icon: Symbols.refresh,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _GoogleNewsLayout extends StatelessWidget {
  const _GoogleNewsLayout({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 20), right],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 286, child: left),
            const SizedBox(width: 24),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.active,
    required this.enabled,
    required this.saving,
    required this.publicationNameController,
    required this.rssContent,
    required this.feedPostLimitController,
    required this.onActiveChanged,
    required this.onRssContentChanged,
    required this.onSave,
  });

  final bool active;
  final bool enabled;
  final bool saving;
  final TextEditingController publicationNameController;
  final String rssContent;
  final TextEditingController feedPostLimitController;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<String?> onRssContentChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _GoogleNewsCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle('googleNews.settings.title'),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(child: _FieldLabel('googleNews.field.status')),
              _CompactCheckSwitch(
                value: active,
                enabled: enabled,
                onChanged: onActiveChanged,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _FullTextField(
            label: 'googleNews.field.publicationName',
            controller: publicationNameController,
            enabled: enabled,
            isRequired: true,
          ),
          const SizedBox(height: 22),
          _FullSelectField(
            label: 'googleNews.field.rssContent',
            helper: 'googleNews.help.rssContent',
            value: rssContent,
            options: const [
              'googleNews.option.showFullContent',
              'googleNews.option.showSummary',
            ],
            onChanged: onRssContentChanged,
            enabled: enabled,
            isRequired: true,
          ),
          const SizedBox(height: 22),
          _FullTextField(
            label: 'googleNews.field.feedPostLimit',
            helper: 'googleNews.help.feedPostLimit',
            controller: feedPostLimitController,
            keyboardType: TextInputType.number,
            enabled: enabled,
            isRequired: true,
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: _PrimaryButton(
              label: 'Save Changes',
              icon: Symbols.check,
              busy: saving,
              onPressed: enabled ? onSave : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedGeneratorCard extends StatelessWidget {
  const _FeedGeneratorCard({
    required this.language,
    required this.category,
    required this.generatedUrl,
    required this.onCopyUrl,
    required this.onOpenUrl,
    required this.onLanguageChanged,
    required this.onCategoryChanged,
  });

  final String language;
  final String category;
  final String generatedUrl;
  final VoidCallback onCopyUrl;
  final VoidCallback onOpenUrl;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return _GoogleNewsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle('googleNews.feed.title'),
          const SizedBox(height: 22),
          _FullSelectField(
            label: 'Language',
            value: language,
            options: const [
              'language.name.en',
              'language.name.tr',
              'language.name.ar',
            ],
            onChanged: onLanguageChanged,
          ),
          const SizedBox(height: 18),
          _FullSelectField(
            label: 'Category',
            value: category,
            options: const [
              'googleNews.option.allCategories',
              'googleNews.option.news',
              'googleNews.option.video',
            ],
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 18),
          _FeedUrlField(
            url: generatedUrl,
            onCopy: onCopyUrl,
            onOpen: onOpenUrl,
          ),
        ],
      ),
    );
  }
}

class _FeedUrlField extends StatelessWidget {
  const _FeedUrlField({
    required this.url,
    required this.onCopy,
    required this.onOpen,
  });

  final String url;
  final VoidCallback onCopy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('googleNews.field.generatedFeedUrl'),
        const SizedBox(height: 8),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: AppColors.line)),
                ),
                child: IconButton(
                  onPressed: onOpen,
                  padding: EdgeInsets.zero,
                  icon: const SymbolIcon(
                    Symbols.open_in_new,
                    color: AppColors.iconMuted,
                    size: 16,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 42,
                child: TextButton(
                  onPressed: onCopy,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.actionRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(AppRadius.value),
                        bottomRight: Radius.circular(AppRadius.value),
                      ),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  child: Text(context.t('common.copy')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntegrationEndpointsCard extends StatelessWidget {
  const _IntegrationEndpointsCard({
    required this.newsSitemapUrl,
    required this.primaryFeedUrl,
    required this.onOpenUrl,
  });

  final String newsSitemapUrl;
  final String primaryFeedUrl;
  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return _GoogleNewsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle('googleNews.integration.title'),
          const SizedBox(height: 28),
          Text(
            context.t('googleNews.integration.description'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.placeholder,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          _EndpointBox(
            title: 'googleNews.integration.newsSitemapTitle',
            description: 'googleNews.integration.newsSitemapDescription',
            url: newsSitemapUrl,
            icon: Symbols.article,
            accent: Color(0xFF2F80ED),
            background: Color(0xFFEAF3FF),
            onOpenUrl: onOpenUrl,
          ),
          const SizedBox(height: 14),
          _EndpointBox(
            title: 'googleNews.integration.publisherFeedTitle',
            description: 'googleNews.integration.publisherFeedDescription',
            url: primaryFeedUrl,
            icon: Symbols.draft,
            accent: Color(0xFFF39C12),
            background: Color(0xFFFFF7DB),
            onOpenUrl: onOpenUrl,
          ),
        ],
      ),
    );
  }
}

class _EndpointBox extends StatelessWidget {
  const _EndpointBox({
    required this.title,
    required this.description,
    required this.url,
    required this.icon,
    required this.accent,
    required this.background,
    required this.onOpenUrl,
  });

  final String title;
  final String description;
  final String url;
  final IconData icon;
  final Color accent;
  final Color background;
  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: accent.withValues(alpha: 0.78)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SymbolIcon(icon, color: accent, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.t(title),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.t(description),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _EndpointUrlRow(url: url, onOpen: () => onOpenUrl(url)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndpointUrlRow extends StatelessWidget {
  const _EndpointUrlRow({required this.url, required this.onOpen});

  final String url;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final urlField = Container(
          height: 34,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(
            url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        );
        final viewButton = SizedBox(
          height: 34,
          child: TextButton(
            onPressed: onOpen,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.deepOcean,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            child: Text(context.t('newsAdd.fileView')),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [urlField, const SizedBox(height: 8), viewButton],
          );
        }

        return Row(
          children: [
            Expanded(child: urlField),
            const SizedBox(width: 8),
            viewButton,
          ],
        );
      },
    );
  }
}

class _GoogleNewsCard extends StatelessWidget {
  const _GoogleNewsCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t(label),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _FullTextField extends StatelessWidget {
  const _FullTextField({
    required this.label,
    required this.controller,
    this.helper,
    this.keyboardType,
    this.enabled = true,
    this.isRequired = false,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label, isRequired: isRequired),
        const SizedBox(height: 8),
        _TextInput(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
        ),
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

class _FullSelectField extends StatelessWidget {
  const _FullSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.helper,
    this.enabled = true,
    this.isRequired = false,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String? helper;
  final bool enabled;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label, isRequired: isRequired),
        const SizedBox(height: 8),
        _SelectInput(
          value: value,
          options: options,
          enabled: enabled,
          onChanged: onChanged,
        ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {this.isRequired = false});

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppColors.deepOcean,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
    if (!isRequired) {
      return Text(
        context.t(label),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: context.t(label)),
          TextSpan(
            text: ' *',
            style: style?.copyWith(color: AppColors.actionRed),
          ),
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    this.keyboardType,
    this.enabled = true,
  });

  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        textAlignVertical: TextAlignVertical.center,
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        decoration: _inputDecoration(context),
      ),
    );
  }
}

class _SelectInput extends StatelessWidget {
  const _SelectInput({
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final bool enabled;
  final ValueChanged<String?> onChanged;

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
                    context.t(option),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: busy ? null : onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: onPressed == null || busy
                  ? AppColors.softLine
                  : AppColors.actionRed,
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
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              SymbolIcon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.t(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactCheckSwitch extends StatelessWidget {
  const _CompactCheckSwitch({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 42,
          height: 24,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value && enabled ? AppColors.actionRed : AppColors.softLine,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value && enabled
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
                  ? SymbolIcon(
                      Symbols.check,
                      color: enabled
                          ? AppColors.actionRed
                          : AppColors.iconMuted,
                      size: 12,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final radius = Radius.circular(AppRadius.value);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, radius).deflate(0.5),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 6.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

InputDecoration _inputDecoration(BuildContext context) {
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

int _boundedInt(
  String value, {
  required int fallback,
  required int min,
  required int max,
}) {
  final parsed = int.tryParse(value.trim()) ?? fallback;
  return parsed.clamp(min, max).toInt();
}
