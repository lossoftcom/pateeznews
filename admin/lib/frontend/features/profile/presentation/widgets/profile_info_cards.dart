import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';
import '../../data/profile_content.dart';

/// Profilin "kenar" bilgileri: Hakkında, Sosyal Bağlantılar ve Takipçiler /
/// Takip Edilen önizlemesi. Hepsi beyaz kart, 4px keskin radius, projenin
/// tipografi ve renk diliyle.
class ProfileInfoSection extends StatelessWidget {
  const ProfileInfoSection({super.key, required this.data});

  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
        AppSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AboutCard(data: data),
          const SizedBox(height: AppSpacing.md),
          _SocialCard(links: data.socialLinks),
          const SizedBox(height: AppSpacing.md),
          _FollowsCard(data: data),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleS.copyWith(
              color: AppColors.inkStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.data});

  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Hakkında',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.hasAbout
                ? data.aboutMe
                : 'Bu kullanıcı henüz bir açıklama eklemedi.',
            style: AppTypography.body.copyWith(
              color: data.hasAbout ? AppColors.inkSoft : AppColors.support,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.softLine),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Symbols.schedule_rounded,
            text: '${data.joinedLabel} tarihinde katıldı',
          ),
          if (data.showEmail && data.email.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            _InfoRow(icon: Symbols.alternate_email_rounded, text: data.email),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.iconMuted),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(color: AppColors.inkSoft),
          ),
        ),
      ],
    );
  }
}

class _SocialCard extends StatelessWidget {
  const _SocialCard({required this.links});

  final List<ProfileSocialLink> links;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Sosyal Bağlantılar',
      child: links.isEmpty
          ? Text(
              'Henüz sosyal bağlantı eklenmemiş.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.support),
            )
          : Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: links
                  .map((link) => _SocialButton(link: link))
                  .toList(growable: false),
            ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.link});

  final ProfileSocialLink link;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: link.label,
      button: true,
      child: Material(
        color: AppColors.surfaceInk,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(link.icon, size: 19, color: AppColors.inkSoft),
          ),
        ),
      ),
    );
  }
}

class _FollowsCard extends StatelessWidget {
  const _FollowsCard({required this.data});

  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FollowBlock(
            label: 'Takipçiler',
            count: data.followers,
            avatars: data.followerAvatars,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: AppColors.softLine),
          const SizedBox(height: AppSpacing.lg),
          _FollowBlock(
            label: 'Takip Edilen',
            count: data.following,
            avatars: data.followingAvatars,
          ),
        ],
      ),
    );
  }
}

class _FollowBlock extends StatelessWidget {
  const _FollowBlock({
    required this.label,
    required this.count,
    required this.avatars,
  });

  final String label;
  final int count;
  final List<String> avatars;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTypography.titleS.copyWith(
                color: AppColors.inkStrong,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '($count)',
              style: AppTypography.meta.copyWith(color: AppColors.support),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _AvatarStack(avatars: avatars, total: count),
      ],
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.avatars, required this.total});

  final List<String> avatars;
  final int total;

  static const double _size = 34;
  static const double _step = 24;

  @override
  Widget build(BuildContext context) {
    if (avatars.isEmpty) {
      return Text(
        'Henüz kimse yok.',
        style: AppTypography.bodySmall.copyWith(color: AppColors.support),
      );
    }
    final shown = avatars.take(5).toList(growable: false);
    final extra = total - shown.length;
    final hasExtra = extra > 0;
    final cellCount = shown.length + (hasExtra ? 1 : 0);
    final width = _size + (cellCount - 1) * _step;

    return SizedBox(
      height: _size,
      width: width,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(left: i * _step, child: _AvatarDot(url: shown[i])),
          if (hasExtra)
            Positioned(
              left: shown.length * _step,
              child: _ExtraDot(count: extra),
            ),
        ],
      ),
    );
  }
}

class _AvatarDot extends StatelessWidget {
  const _AvatarDot({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _AvatarStack._size,
      height: _AvatarStack._size,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(1.5),
      child: ClipOval(
        child: ColoredBox(
          color: AppColors.surfaceInk,
          child: CachedImage(
            url: url,
            fit: BoxFit.cover,
            memCacheWidth: 96,
            placeholderColor: AppColors.surfaceInk,
            errorWidget: const ColoredBox(color: AppColors.surfaceInk),
          ),
        ),
      ),
    );
  }
}

class _ExtraDot extends StatelessWidget {
  const _ExtraDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _AvatarStack._size,
      height: _AvatarStack._size,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceInk,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '+${count > 99 ? 99 : count}',
          style: AppTypography.eyebrow.copyWith(
            color: AppColors.inkSoft,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
