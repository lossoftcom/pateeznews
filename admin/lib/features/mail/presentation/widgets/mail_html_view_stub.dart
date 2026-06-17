import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class MailHtmlView extends StatelessWidget {
  const MailHtmlView({
    super.key,
    required this.html,
    required this.fallbackText,
    this.height = 520,
  });

  final String html;
  final String fallbackText;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 160, maxHeight: height),
      child: SingleChildScrollView(
        child: SelectableText(
          fallbackText.trim().isEmpty ? html : fallbackText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.deepOcean,
            height: 1.55,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
