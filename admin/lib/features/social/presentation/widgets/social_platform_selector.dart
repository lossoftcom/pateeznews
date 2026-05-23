import 'package:flutter/material.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../social_platform_data.dart';

/// Horizontal chip-based platform selector.
class SocialPlatformSelector extends StatelessWidget {
  const SocialPlatformSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<SocialPlatform> selected;
  final ValueChanged<Set<SocialPlatform>> onChanged;

  void _toggle(SocialPlatform p) {
    final next = Set<SocialPlatform>.from(selected);
    if (next.contains(p)) {
      next.remove(p);
    } else {
      next.add(p);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(
                context.t('social.publish.connectedAccounts'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepOcean,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 8),
              if (selected.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.actionRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    context.t(
                      'social.publish.platformCount',
                      values: {'count': selected.length},
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.actionRed,
                      letterSpacing: 0,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: socialPlatforms.map((info) {
            final active = selected.contains(info.platform);
            return _PlatformChip(
              info: info,
              active: active,
              onTap: () => _toggle(info.platform),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PlatformChip extends StatefulWidget {
  const _PlatformChip({
    required this.info,
    required this.active,
    required this.onTap,
  });

  final SocialPlatformInfo info;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_PlatformChip> createState() => _PlatformChipState();
}

class _PlatformChipState extends State<_PlatformChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final active = widget.active;
    final brandColor = info.color;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? brandColor.withValues(alpha: 0.10)
                  : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value * 2),
              border: Border.all(
                color: active ? brandColor : AppColors.line,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PlatformIcon(info: info, active: active),
                const SizedBox(width: 6),
                Text(
                  info.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? brandColor : AppColors.inkSoft,
                    letterSpacing: 0,
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: brandColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformIcon extends StatelessWidget {
  const _PlatformIcon({required this.info, required this.active});

  final SocialPlatformInfo info;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? info.color : AppColors.iconMuted;

    // Special gradient for Instagram
    if (info.platform == SocialPlatform.instagram && active) {
      return ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0xFFFCAF45),
            Color(0xFFF77737),
            Color(0xFFE1306C),
            Color(0xFFC13584),
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(bounds),
        child: Icon(info.icon, size: 16, color: Colors.white),
      );
    }

    return Icon(info.icon, size: 16, color: color);
  }
}
