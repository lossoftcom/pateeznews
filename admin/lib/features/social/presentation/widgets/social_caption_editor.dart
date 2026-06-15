import 'package:flutter/material.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../social_platform_data.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

/// Rich-ish caption editor with toolbar and character counter.
class SocialCaptionEditor extends StatelessWidget {
  const SocialCaptionEditor({
    super.key,
    required this.controller,
    required this.selectedPlatforms,
    required this.onChanged,
    this.platformCharLimits = const {},
  });

  final TextEditingController controller;
  final Set<SocialPlatform> selectedPlatforms;
  final ValueChanged<String> onChanged;
  final Map<SocialPlatform, int> platformCharLimits;

  int get _minCharLimit {
    if (selectedPlatforms.isEmpty) return 2200;
    return selectedPlatforms
        .map((p) => platformCharLimits[p] ?? platformInfoFor(p).charLimit)
        .reduce((a, b) => a < b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final limit = _minCharLimit;
    final length = controller.text.length;
    final overLimit = length > limit;
    final ratio = limit > 0 ? (length / limit).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            context.t('social.publish.caption'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.deepOcean,
              letterSpacing: 0,
            ),
          ),
        ),

        // Toolbar
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.value * 2),
            ),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _ToolbarButton(
                icon: Symbols.format_bold_rounded,
                tooltip: 'Bold',
                onTap: () => _insertWrap('**'),
              ),
              _ToolbarButton(
                icon: Symbols.format_italic_rounded,
                tooltip: 'Italic',
                onTap: () => _insertWrap('_'),
              ),
              const SizedBox(
                height: 20,
                child: VerticalDivider(width: 16, thickness: 1),
              ),
              _ToolbarButton(
                icon: Symbols.link_rounded,
                tooltip: 'Link',
                onTap: () {},
              ),
              _ToolbarButton(
                icon: Symbols.tag_rounded,
                tooltip: 'Hashtag',
                onTap: () => _insertText('#'),
              ),
              _ToolbarButton(
                icon: Symbols.emoji_emotions_outlined,
                tooltip: 'Emoji',
                onTap: () {},
              ),
              const Spacer(),
              // Character counter ring
              SizedBox(
                width: 28,
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 2.5,
                      backgroundColor: AppColors.line,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        overLimit
                            ? AppColors.actionRed
                            : ratio > 0.8
                            ? AppColors.warmHorizon
                            : AppColors.deepOcean,
                      ),
                    ),
                    Text(
                      '${(ratio * 100).toInt()}',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: overLimit
                            ? AppColors.actionRed
                            : AppColors.inkSoft,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Text field
        Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.line),
              right: BorderSide(color: AppColors.line),
              bottom: BorderSide(color: AppColors.line),
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.value * 2),
            ),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: 6,
            minLines: 4,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.deepOcean,
              height: 1.6,
              letterSpacing: 0,
            ),
            decoration: InputDecoration(
              hintText: context.t('social.publish.captionHint'),
              hintStyle: const TextStyle(
                color: AppColors.placeholder,
                fontSize: 13,
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.value * 2),
                ),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.value * 2),
                ),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.value * 2),
                ),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Character info
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Text(
                '$length / $limit',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: overLimit ? AppColors.actionRed : AppColors.support,
                  letterSpacing: 0,
                ),
              ),
              if (overLimit) ...[
                const SizedBox(width: 6),
                Icon(
                  Symbols.warning_amber_rounded,
                  size: 13,
                  color: AppColors.actionRed,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _insertWrap(String wrapper) {
    final sel = controller.selection;
    final text = controller.text;
    if (sel.isValid && sel.start != sel.end) {
      final selected = text.substring(sel.start, sel.end);
      final replacement = '$wrapper$selected$wrapper';
      controller.text = text.replaceRange(sel.start, sel.end, replacement);
      onChanged(controller.text);
    }
  }

  void _insertText(String insert) {
    final sel = controller.selection;
    final text = controller.text;
    final offset = sel.isValid ? sel.baseOffset : text.length;
    controller.text =
        '${text.substring(0, offset)}$insert${text.substring(offset)}';
    controller.selection = TextSelection.collapsed(
      offset: offset + insert.length,
    );
    onChanged(controller.text);
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: AppColors.iconMuted),
        ),
      ),
    );
  }
}
