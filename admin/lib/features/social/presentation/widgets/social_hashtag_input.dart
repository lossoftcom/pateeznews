import 'package:flutter/material.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';

/// Hashtag input with chip display and add button.
class SocialHashtagInput extends StatefulWidget {
  const SocialHashtagInput({
    super.key,
    required this.hashtags,
    required this.onChanged,
  });

  final List<String> hashtags;
  final ValueChanged<List<String>> onChanged;

  @override
  State<SocialHashtagInput> createState() => _SocialHashtagInputState();
}

class _SocialHashtagInputState extends State<SocialHashtagInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _addTag() {
    final raw = _controller.text.trim().replaceAll('#', '').replaceAll(' ', '');
    if (raw.isEmpty) return;
    if (widget.hashtags.contains(raw)) return;
    widget.onChanged([...widget.hashtags, raw]);
    _controller.clear();
    _focus.requestFocus();
  }

  void _removeTag(String tag) {
    widget.onChanged(widget.hashtags.where((t) => t != tag).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            context.t('social.publish.hashtags'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.deepOcean,
              letterSpacing: 0,
            ),
          ),
        ),

        // Input row
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.deepOcean,
                    letterSpacing: 0,
                  ),
                  decoration: InputDecoration(
                    hintText: context.t('social.publish.hashtagHint'),
                    hintStyle: const TextStyle(
                      color: AppColors.placeholder,
                      fontSize: 13,
                      letterSpacing: 0,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 10, right: 4),
                      child: Text(
                        '#',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.support,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 0,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.value * 2),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.value * 2),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.value * 2),
                      borderSide: const BorderSide(color: AppColors.deepOcean),
                    ),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 38,
              child: TextButton(
                onPressed: _addTag,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.deepOcean,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.value * 2),
                  ),
                ),
                child: Text(
                  context.t('social.publish.addHashtag'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Tags
        if (widget.hashtags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.hashtags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.deepOcean.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(AppRadius.value * 3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepOcean,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _removeTag(tag),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppColors.iconMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
