import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../social_platform_data.dart';

Future<SocialPlatformPublishOptions?> showSocialPlatformOptionsDialog(
  BuildContext context, {
  required SocialPublishData data,
}) {
  var draft = data.platformOptions;
  return showDialog<SocialPlatformPublishOptions>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);
      final width = (size.width - 48).clamp(620.0, 880.0).toDouble();
      final height = (size.height - 48).clamp(560.0, 820.0).toDouble();

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SizedBox(
          width: width,
          height: height,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            clipBehavior: Clip.antiAlias,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
                      child: Row(
                        children: [
                          _IconBadge(
                            icon: Symbols.settings_input_component_outlined,
                            color: AppColors.deepOcean,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Platform ayarları',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.deepOcean,
                                    letterSpacing: 0,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Buradaki alanlar sadece Bundle Social API gerçekten destekliyorsa gönderilir.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.support,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Kapat',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Symbols.close, size: 20),
                            color: AppColors.deepOcean,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.line),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                        child: SocialPlatformOptionsPanel(
                          data: data.copyWith(platformOptions: draft),
                          showHeader: false,
                          onChanged: (options) =>
                              setModalState(() => draft = options),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.line),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.deepOcean,
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                            child: const Text('İptal'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(draft),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.deepOcean,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.value,
                                ),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            child: const Text('Kaydet'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

class SocialPlatformOptionsPanel extends StatelessWidget {
  const SocialPlatformOptionsPanel({
    super.key,
    required this.data,
    required this.onChanged,
    this.showHeader = true,
  });

  final SocialPublishData data;
  final ValueChanged<SocialPlatformPublishOptions> onChanged;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final visiblePlatforms = data.selectedPlatforms.intersection({
      SocialPlatform.instagram,
      SocialPlatform.facebook,
      SocialPlatform.tiktok,
      SocialPlatform.twitter,
    });
    if (visiblePlatforms.isEmpty) return const SizedBox.shrink();

    final content = Column(
      children: [
        if (visiblePlatforms.contains(SocialPlatform.instagram))
          _InstagramOptions(
            options: data.platformOptions.instagram,
            postType: data.postType,
            onChanged: (value) =>
                onChanged(data.platformOptions.copyWith(instagram: value)),
          ),
        if (visiblePlatforms.contains(SocialPlatform.facebook))
          _FacebookOptions(
            options: data.platformOptions.facebook,
            postType: data.postType,
            onChanged: (value) =>
                onChanged(data.platformOptions.copyWith(facebook: value)),
          ),
        if (visiblePlatforms.contains(SocialPlatform.tiktok))
          _TiktokOptions(
            options: data.platformOptions.tiktok,
            onChanged: (value) =>
                onChanged(data.platformOptions.copyWith(tiktok: value)),
          ),
        if (visiblePlatforms.contains(SocialPlatform.twitter))
          _TwitterOptions(
            options: data.platformOptions.twitter,
            onChanged: (value) =>
                onChanged(data.platformOptions.copyWith(twitter: value)),
          ),
      ],
    );

    if (!showHeader) return content;

    return _PanelShell(
      icon: Symbols.settings_input_component_outlined,
      title: 'Platform ayarları',
      subtitle: 'Sadece Bundle Social API alanları gönderilir.',
      child: content,
    );
  }
}

class _InstagramOptions extends StatelessWidget {
  const _InstagramOptions({
    required this.options,
    required this.postType,
    required this.onChanged,
  });

  final SocialInstagramPublishOptions options;
  final SocialPostType postType;
  final ValueChanged<SocialInstagramPublishOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final isReel = postType == SocialPostType.reels;
    return _OptionSection(
      icon: Symbols.instagram_fill,
      title: 'Instagram',
      color: const Color(0xFFE1306C),
      children: [
        _ResponsiveFields(
          children: [
            _TextOptionField(
              label: 'Alt metin',
              value: options.altText,
              hint: 'Erişilebilirlik açıklaması',
              help:
                  'Görselde ne olduğunu anlatır. Ekran okuyucu ve erişilebilirlik için kullanılır.',
              onChanged: (value) => onChanged(options.copyWith(altText: value)),
            ),
            _TextOptionField(
              label: 'Konum ID',
              value: options.locationId,
              hint: 'Instagram locationId',
              help:
                  'Şehir adı yazılmaz. Instagram/Meta tarafındaki gerçek konum numarası yazılır.',
              onChanged: (value) =>
                  onChanged(options.copyWith(locationId: value)),
            ),
            _TextOptionField(
              label: 'Ortak üreticiler',
              value: options.collaborators,
              hint: 'kullanici1, kullanici2',
              help:
                  'Gönderide ortak üretici olarak görünecek kullanıcı adlarıdır. Birden fazlaysa virgülle ayır.',
              onChanged: (value) =>
                  onChanged(options.copyWith(collaborators: value)),
            ),
            _TextOptionField(
              label: 'Etiketli kullanıcılar',
              value: options.taggedUsers,
              hint: 'kullanici1, kullanici2',
              help:
                  'Gönderide etiketlenecek kullanıcı adlarıdır. Bu story link/poll stickeri değildir.',
              onChanged: (value) =>
                  onChanged(options.copyWith(taggedUsers: value)),
            ),
            _TextOptionField(
              label: 'Kapak görsel URL',
              value: options.thumbnailUrl,
              hint: 'https://...',
              help:
                  'Reels/video kapağı için kullanılacak hazır görsel adresidir. Emin değilsen boş bırak.',
              onChanged: (value) =>
                  onChanged(options.copyWith(thumbnailUrl: value)),
            ),
            _NumberOptionField(
              label: 'Kapak zamanı ms',
              value: options.thumbnailOffsetMs,
              hint: '1500',
              help:
                  'Videonun kaçıncı milisaniyesi kapak olsun. 1000 yazarsan 1. saniye demektir.',
              onChanged: (value) => onChanged(
                options.copyWith(
                  thumbnailOffsetMs: value,
                  clearThumbnailOffset: value == null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SwitchGrid(
          children: [
            _OptionSwitch(
              label: 'Reels akışta görünsün',
              value: options.shareToFeed,
              enabled: isReel,
              onChanged: (value) =>
                  onChanged(options.copyWith(shareToFeed: value)),
            ),
            _OptionSwitch(
              label: 'Görseli sığdır',
              value: options.autoFitImage,
              onChanged: (value) =>
                  onChanged(options.copyWith(autoFitImage: value)),
            ),
            _OptionSwitch(
              label: 'Görseli kırp',
              value: options.autoCropImage,
              onChanged: (value) =>
                  onChanged(options.copyWith(autoCropImage: value)),
            ),
          ],
        ),
        if (!isReel)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _InlineNote(
              text: 'shareToFeed yalnızca Reels gönderiminde uygulanır.',
            ),
          ),
      ],
    );
  }
}

class _FacebookOptions extends StatelessWidget {
  const _FacebookOptions({
    required this.options,
    required this.postType,
    required this.onChanged,
  });

  final SocialFacebookPublishOptions options;
  final SocialPostType postType;
  final ValueChanged<SocialFacebookPublishOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    return _OptionSection(
      icon: Symbols.facebook_rounded,
      title: 'Facebook',
      color: const Color(0xFF1877F2),
      children: [
        _ResponsiveFields(
          children: [
            _TextOptionField(
              label: 'Alt metin',
              value: options.altText,
              hint: 'Medya açıklaması',
              help:
                  'Facebook medyasını kısaca açıklar. Görseli göremeyen kullanıcılar için faydalıdır.',
              onChanged: (value) => onChanged(options.copyWith(altText: value)),
            ),
            _TextOptionField(
              label: 'Kapak görsel URL',
              value: options.thumbnailUrl,
              hint: 'https://...',
              help:
                  'Video veya link önizlemesinde kapak olarak kullanılacak görsel adresidir.',
              onChanged: (value) =>
                  onChanged(options.copyWith(thumbnailUrl: value)),
            ),
            _TextOptionField(
              label: 'Native planlama zamanı',
              value: options.nativeScheduleTime,
              hint: 'ISO tarih',
              help:
                  'Facebook tarafındaki kendi planlama zamanı. Emin değilsen boş bırak, üstteki Zamanla düğmesini kullan.',
              onChanged: (value) =>
                  onChanged(options.copyWith(nativeScheduleTime: value)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _InlineNote(
          text: postType == SocialPostType.feed
              ? 'Facebook link alanı akış gönderisinde native gönderilir.'
              : 'Facebook link alanı hikaye/reels için native gönderilmez.',
        ),
      ],
    );
  }
}

class _TiktokOptions extends StatelessWidget {
  const _TiktokOptions({required this.options, required this.onChanged});

  final SocialTiktokPublishOptions options;
  final ValueChanged<SocialTiktokPublishOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    return _OptionSection(
      icon: Symbols.music_note_rounded,
      title: 'TikTok',
      color: const Color(0xFF111827),
      children: [
        _ResponsiveFields(
          children: [
            _DropdownOptionField(
              label: 'Gizlilik',
              value: options.privacy,
              values: const {
                'PUBLIC_TO_EVERYONE': 'Herkese açık',
                'MUTUAL_FOLLOW_FRIENDS': 'Arkadaşlar',
                'SELF_ONLY': 'Sadece ben',
              },
              help:
                  'TikTok videosunu kimlerin göreceğini seçer. Normal paylaşım için Herkese açık bırak.',
              onChanged: (value) => onChanged(options.copyWith(privacy: value)),
            ),
            _TextOptionField(
              label: 'Kapak görsel URL',
              value: options.thumbnailUrl,
              hint: 'https://...',
              help:
                  'TikTok kapağı olarak kullanılacak görsel adresidir. Yoksa TikTok videodan kapak seçer.',
              onChanged: (value) =>
                  onChanged(options.copyWith(thumbnailUrl: value)),
            ),
            _NumberOptionField(
              label: 'Kapak zamanı ms',
              value: options.thumbnailOffsetMs,
              hint: '1500',
              help:
                  'Videoda kapak karesi kaçıncı milisaniyeden alınsın. 1000 = 1 saniye.',
              onChanged: (value) => onChanged(
                options.copyWith(
                  thumbnailOffsetMs: value,
                  clearThumbnailOffset: value == null,
                ),
              ),
            ),
            _NumberOptionField(
              label: 'Foto kapak index',
              value: options.photoCoverIndex,
              hint: '0',
              help:
                  'Fotoğraf gönderisinde kaçıncı görsel kapak olsun. İlk görsel için 0 yazılır.',
              onChanged: (value) => onChanged(
                options.copyWith(
                  photoCoverIndex: value,
                  clearPhotoCoverIndex: value == null,
                ),
              ),
            ),
            _TextOptionField(
              label: 'Müzik Sound ID',
              value: options.musicSoundId,
              hint: 'musicSoundId',
              help:
                  'TikTok/Bundle müzik aramasından dönen ses kimliğidir. Rastgele şarkı adı yazılmaz.',
              onChanged: (value) =>
                  onChanged(options.copyWith(musicSoundId: value)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SwitchGrid(
          children: [
            _OptionSwitch(
              label: 'Yorumları kapat',
              value: options.disableComments,
              onChanged: (value) =>
                  onChanged(options.copyWith(disableComments: value)),
            ),
            _OptionSwitch(
              label: 'Duet kapat',
              value: options.disableDuet,
              onChanged: (value) =>
                  onChanged(options.copyWith(disableDuet: value)),
            ),
            _OptionSwitch(
              label: 'Stitch kapat',
              value: options.disableStitch,
              onChanged: (value) =>
                  onChanged(options.copyWith(disableStitch: value)),
            ),
            _OptionSwitch(
              label: 'AI üretimi',
              value: options.isAiGenerated,
              onChanged: (value) =>
                  onChanged(options.copyWith(isAiGenerated: value)),
            ),
            _OptionSwitch(
              label: 'Markalı içerik',
              value: options.isBrandContent,
              onChanged: (value) =>
                  onChanged(options.copyWith(isBrandContent: value)),
            ),
            _OptionSwitch(
              label: 'Organik marka',
              value: options.isOrganicBrandContent,
              onChanged: (value) =>
                  onChanged(options.copyWith(isOrganicBrandContent: value)),
            ),
            _OptionSwitch(
              label: 'Otomatik müzik',
              value: options.autoAddMusic,
              onChanged: (value) =>
                  onChanged(options.copyWith(autoAddMusic: value)),
            ),
            _OptionSwitch(
              label: 'Otomatik ölçekle',
              value: options.autoScale,
              onChanged: (value) =>
                  onChanged(options.copyWith(autoScale: value)),
            ),
            _OptionSwitch(
              label: 'Taslağa yükle',
              value: options.uploadToDraft,
              onChanged: (value) =>
                  onChanged(options.copyWith(uploadToDraft: value)),
            ),
          ],
        ),
      ],
    );
  }
}

class _TwitterOptions extends StatelessWidget {
  const _TwitterOptions({required this.options, required this.onChanged});

  final SocialTwitterPublishOptions options;
  final ValueChanged<SocialTwitterPublishOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    return _OptionSection(
      icon: Symbols.alternate_email_rounded,
      title: 'X',
      color: const Color(0xFF111827),
      children: [
        _ResponsiveFields(
          children: [
            _DropdownOptionField(
              label: 'Yanıt izni',
              value: options.replySettings,
              values: const {
                'EVERYONE': 'Herkes',
                'FOLLOWING': 'Takip ettiklerim',
                'MENTIONED_USERS': 'Sadece bahsedilenler',
                'SUBSCRIBERS': 'Aboneler',
                'VERIFIED': 'Doğrulanmış hesaplar',
              },
              help:
                  'X gönderisine kimlerin cevap yazabileceğini seçer. X tarafında hikaye veya reels yoktur.',
              onChanged: (value) =>
                  onChanged(options.copyWith(replySettings: value)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const _InlineNote(
          text:
              'Thread seçimi format sekmesinden yapılır; medya sınırı seçili hesaba göre Bundle Social tarafında doğrulanır.',
        ),
      ],
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value * 2),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBadge(icon: icon, color: AppColors.deepOcean),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepOcean,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.support,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _OptionSection extends StatelessWidget {
  const _OptionSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });

  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconBadge(icon: icon, color: color, small: true),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepOcean,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 520;
        final itemWidth = twoColumns
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth.clamp(180.0, constraints.maxWidth),
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class _SwitchGrid extends StatelessWidget {
  const _SwitchGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 10, children: children);
  }
}

class _TextOptionField extends StatelessWidget {
  const _TextOptionField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onChanged,
    this.help = '',
  });

  final String label;
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  final String help;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          decoration: _inputDecoration(label: label, hint: hint),
        ),
        if (help.isNotEmpty) ...[
          const SizedBox(height: 5),
          _FieldHelp(text: help),
        ],
      ],
    );
  }
}

class _FieldHelp extends StatelessWidget {
  const _FieldHelp({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        height: 1.32,
        color: AppColors.support,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}

class _NumberOptionField extends StatelessWidget {
  const _NumberOptionField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onChanged,
    this.help = '',
  });

  final String label;
  final int? value;
  final String hint;
  final ValueChanged<int?> onChanged;
  final String help;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: value?.toString() ?? '',
          onChanged: (raw) {
            final trimmed = raw.trim();
            onChanged(trimmed.isEmpty ? null : int.tryParse(trimmed));
          },
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          decoration: _inputDecoration(label: label, hint: hint),
        ),
        if (help.isNotEmpty) ...[
          const SizedBox(height: 5),
          _FieldHelp(text: help),
        ],
      ],
    );
  }
}

class _DropdownOptionField extends StatelessWidget {
  const _DropdownOptionField({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.help = '',
  });

  final String label;
  final String value;
  final Map<String, String> values;
  final ValueChanged<String> onChanged;
  final String help;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: values.containsKey(value) ? value : values.keys.first,
          isExpanded: true,
          items: [
            for (final entry in values.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          decoration: _inputDecoration(label: label, hint: ''),
        ),
        if (help.isNotEmpty) ...[
          const SizedBox(height: 5),
          _FieldHelp(text: help),
        ],
      ],
    );
  }
}

class _OptionSwitch extends StatelessWidget {
  const _OptionSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: value,
      child: FilterChip(
        selected: value,
        onSelected: enabled ? onChanged : null,
        avatar: Icon(
          value
              ? Symbols.check_rounded
              : Symbols.radio_button_unchecked_rounded,
          size: 15,
          color: enabled
              ? (value ? AppColors.actionRed : AppColors.iconMuted)
              : AppColors.iconMuted.withValues(alpha: 0.45),
        ),
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: enabled
              ? AppColors.deepOcean
              : AppColors.support.withValues(alpha: 0.65),
          letterSpacing: 0,
        ),
        backgroundColor: Colors.white,
        selectedColor: AppColors.actionRed.withValues(alpha: 0.08),
        side: BorderSide(
          color: value
              ? AppColors.actionRed.withValues(alpha: 0.28)
              : AppColors.line,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Symbols.info_outline_rounded,
          size: 15,
          color: AppColors.support.withValues(alpha: 0.78),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              height: 1.35,
              color: AppColors.support,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.color,
    this.small = false,
  });

  final IconData icon;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 24.0 : 30.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.value * 1.4),
      ),
      child: Icon(icon, size: small ? 14 : 16, color: color),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  required String hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint.isEmpty ? null : hint,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    labelStyle: const TextStyle(
      fontSize: 11,
      color: AppColors.support,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    hintStyle: TextStyle(
      fontSize: 12,
      color: AppColors.support.withValues(alpha: 0.62),
      letterSpacing: 0,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value * 1.5),
      borderSide: const BorderSide(color: AppColors.deepOcean, width: 1.2),
    ),
  );
}
