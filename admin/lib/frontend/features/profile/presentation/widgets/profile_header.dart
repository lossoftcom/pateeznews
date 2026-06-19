import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';
import '../../../../shared/widgets/follow_pill.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../data/profile_content.dart';

/// Profil üst bloğu: kapak görseli, üzerine taşan çerçeveli kare avatar (doğrulama
/// rozetiyle), ad, @kullanıcı + rol etiketi, çevrimiçi durumu ve aksiyon
/// (kendi profilinde "Profili Düzenle", başkasında takip) butonu.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.data,
    this.onEdit,
    this.onFollow,
    this.followBusy = false,
  });

  final ProfileData data;
  final VoidCallback? onEdit;
  final VoidCallback? onFollow;
  final bool followBusy;

  static const double _coverHeight = 176;
  static const double _avatarSize = 112;
  static const double _avatarOverlap = _avatarSize / 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Cover(url: data.coverUrl, height: _coverHeight),
                const SizedBox(height: _avatarOverlap + 8),
              ],
            ),
            Positioned(
              left: AppSpacing.pageHorizontal,
              top: _coverHeight - _avatarOverlap,
              child: _Avatar(url: data.avatarUrl, verified: data.isVerified),
            ),
            Positioned(
              right: AppSpacing.pageHorizontal,
              top: _coverHeight + 10,
              child: data.isOwnProfile
                  ? _EditButton(onTap: onEdit ?? () {})
                  : FollowPill(
                      following: data.isFollowing,
                      loading: followBusy,
                      onTap: onFollow,
                    ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            0,
            AppSpacing.pageHorizontal,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display.copyWith(
                  fontSize: 26,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _IdentityRow(
                handle: data.handle,
                roleLabel: data.roleLabel,
                online: data.isOnline,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.height});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedImage(
            url: url,
            fit: BoxFit.cover,
            errorWidget: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.deepOcean, AppColors.ink],
                ),
              ),
            ),
          ),
          // Üstte status bar ikonları, altta beyaz çerçeveli avatar için kontrast.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x47000000),
                  Color(0x00000000),
                  Color(0x1A000000),
                ],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.verified});

  final String url;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ProfileHeader._avatarSize,
      height: ProfileHeader._avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Beyaz çerçeveli daire her zaman tam boyutta dolar; görsel olsun
          // (BoxFit.cover) ya da olmasın (ortalı kişi ikonu) avatar aynı çapta
          // görünür. Positioned.fill, çerçeveyi içeriğe göre küçülmekten korur.
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepOcean.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: ColoredBox(
                  color: AppColors.surfaceInk,
                  child: CachedImage(
                    url: url,
                    fit: BoxFit.cover,
                    memCacheWidth: 240,
                    placeholderColor: AppColors.surfaceInk,
                    errorWidget: const Center(
                      child: Icon(
                        Symbols.person_rounded,
                        color: AppColors.support,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (verified)
            const Positioned(
              right: -2,
              bottom: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(2),
                  child: VerifiedBadge(official: true, size: 22),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
    required this.handle,
    required this.roleLabel,
    required this.online,
  });

  final String handle;
  final String roleLabel;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                handle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              _RolePill(label: roleLabel),
            ],
          ),
        ),
        if (online) ...[
          const SizedBox(width: AppSpacing.sm),
          const _OnlineChip(),
        ],
      ],
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warmHorizon.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Symbols.sparkling_fill,
            size: 12,
            color: AppColors.warmHorizon,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.eyebrow.copyWith(
              color: AppColors.inkStrong,
              fontSize: 10.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineChip extends StatelessWidget {
  const _OnlineChip();

  static const Color _green = Color(0xFF22A565);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Çevrimiçi',
            style: AppTypography.eyebrow.copyWith(
              color: _green,
              fontSize: 10.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.deepOcean,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.edit_square, size: 15, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                'Profili Düzenle',
                style: AppTypography.titleS.copyWith(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
