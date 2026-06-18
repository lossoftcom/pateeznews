import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/services/frontend_link_launcher.dart';
import '../../../../shared/widgets/cached_image.dart';
import '../../data/profile_content.dart';

/// Profilin "kenar" bilgileri: Hakkında, Sosyal Bağlantılar ve Takipçiler /
/// Takip Edilen önizlemesi. Hepsi beyaz kart, 4px keskin radius, projenin
/// tipografi ve renk diliyle.
class ProfileInfoSection extends StatelessWidget {
  const ProfileInfoSection({super.key, required this.data, this.onProfileTap});

  final ProfileData data;
  final ValueChanged<ProfilePreview>? onProfileTap;

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
          _ActivityCard(data: data),
          const SizedBox(height: AppSpacing.md),
          _FollowsCard(data: data, onProfileTap: onProfileTap),
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
          if (data.city.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            _InfoRow(icon: Symbols.location_on_rounded, text: data.city),
          ],
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

  Future<void> _open() async {
    final raw = link.url.trim();
    if (raw.isEmpty) return;
    try {
      await openFrontendLink(raw, preferNativeApp: true);
    } catch (_) {
      // Link açılamazsa profil ekranı akışı bozulmamalı.
    }
  }

  Color get _iconColor {
    if (link.key == 'snapchat') return AppColors.inkStrong;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: link.label,
      button: true,
      child: Material(
        color: link.color,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(link.icon, size: 20, color: _iconColor),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.data});

  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Aktivite',
      child: Row(
        children: [
          Expanded(
            child: _ActivityMetric(
              icon: Symbols.heart_3_line,
              label: 'Beğendiği haberler',
              value: data.likedPostsCount,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _ActivityMetric(
              icon: Symbols.chat_3_line,
              label: 'Yaptığı yorumlar',
              value: data.commentsCount,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceInk,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.actionRed),
          const SizedBox(height: AppSpacing.sm),
          Text(
            CountFormat.compact(value),
            style: AppTypography.titleM.copyWith(color: AppColors.inkStrong),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              color: AppColors.support,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowsCard extends StatelessWidget {
  const _FollowsCard({required this.data, required this.onProfileTap});

  final ProfileData data;
  final ValueChanged<ProfilePreview>? onProfileTap;

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
            profiles: data.followerProfiles,
            onProfileTap: onProfileTap,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: AppColors.softLine),
          const SizedBox(height: AppSpacing.lg),
          _FollowBlock(
            label: 'Takip Edilen',
            count: data.following,
            avatars: data.followingAvatars,
            profiles: data.followingProfiles,
            onProfileTap: onProfileTap,
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
    required this.profiles,
    required this.onProfileTap,
  });

  final String label;
  final int count;
  final List<String> avatars;
  final List<ProfilePreview> profiles;
  final ValueChanged<ProfilePreview>? onProfileTap;

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
        _AvatarStack(
          avatars: avatars,
          profiles: profiles,
          total: count,
          onProfileTap: onProfileTap,
        ),
      ],
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({
    required this.avatars,
    required this.profiles,
    required this.total,
    required this.onProfileTap,
  });

  final List<String> avatars;
  final List<ProfilePreview> profiles;
  final int total;
  final ValueChanged<ProfilePreview>? onProfileTap;

  static const double _size = 34;
  static const double _step = 24;

  @override
  Widget build(BuildContext context) {
    final items = profiles.isNotEmpty
        ? profiles
        : [
            for (var i = 0; i < avatars.length; i++)
              ProfilePreview(
                id: '',
                name: '',
                handle: '',
                avatarUrl: avatars[i],
                isVerified: false,
                isOfficial: false,
              ),
          ];
    if (items.isEmpty) {
      return Text(
        'Henüz kimse yok.',
        style: AppTypography.bodySmall.copyWith(color: AppColors.support),
      );
    }
    final shown = items.take(5).toList(growable: false);
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
            Positioned(
              left: i * _step,
              child: _AvatarDot(
                profile: shown[i],
                onTap: shown[i].id.trim().isEmpty ? null : onProfileTap,
              ),
            ),
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
  const _AvatarDot({required this.profile, required this.onTap});

  final ProfilePreview profile;
  final ValueChanged<ProfilePreview>? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
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
            url: profile.avatarUrl,
            fit: BoxFit.cover,
            memCacheWidth: 96,
            placeholderColor: AppColors.surfaceInk,
            errorWidget: _AvatarFallback(profile: profile),
          ),
        ),
      ),
    );
    final handler = onTap;
    if (handler == null) return child;
    return Semantics(
      button: true,
      label: profile.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => handler(profile),
        child: child,
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.profile});

  final ProfilePreview profile;

  @override
  Widget build(BuildContext context) {
    final name = profile.name.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return ColoredBox(
      color: AppColors.surfaceInk,
      child: Center(
        child: Text(
          initial,
          style: AppTypography.titleS.copyWith(
            color: AppColors.deepOcean,
            fontSize: 13,
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
