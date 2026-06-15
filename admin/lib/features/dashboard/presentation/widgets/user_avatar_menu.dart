import 'package:flutter/material.dart';
import 'package:pateeznews_admin/features/auth/data/admin_auth_models.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/data/admin_image_url.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
import 'user_menu_card.dart';

class UserAvatarMenu extends StatefulWidget {
  const UserAvatarMenu({
    super.key,
    required this.session,
    required this.profile,
    required this.onLogout,
    required this.onAccountSettings,
  });

  final AdminSession session;
  final AdminProfile? profile;
  final VoidCallback onLogout;
  final VoidCallback onAccountSettings;

  @override
  State<UserAvatarMenu> createState() => _UserAvatarMenuState();
}

class _UserAvatarMenuState extends State<UserAvatarMenu> {
  final _layerLink = LayerLink();
  OverlayEntry? _menuEntry;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _openMenu() {
    if (_menuEntry != null) return;

    _menuEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeMenu,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 10),
              child: UserMenuCard(
                onProfile: _closeMenu,
                onAccountSettings: () {
                  _closeMenu();
                  widget.onAccountSettings();
                },
                onLogout: () {
                  _closeMenu();
                  widget.onLogout();
                },
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_menuEntry!);
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _toggleMenu() {
    if (_menuEntry == null) {
      _openMenu();
    } else {
      _closeMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final title = profile?.displayName ?? widget.session.user.email ?? 'Profil';

    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: title,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleMenu,
            child: _AvatarCircle(profile: profile, session: widget.session),
          ),
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.profile, required this.session});

  final AdminProfile? profile;
  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl?.trim();
    final hasImage = avatarUrl != null && avatarUrl.isNotEmpty;

    final fallback = Center(
      child: _AvatarInitials(profile: profile, session: session),
    );

    // Sabit 40×40 kutu + dairesel decoration + antiAlias kırpma:
    // içerik (foto/baş harf) daireye tam oturur, üzerine kalın çerçeve çizilir
    // → her yerleşimde kusursuz TAM DAİRE (asla oval olmaz).
    return SizedBox(
      width: 40,
      height: 40,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.deepOcean, width: 2.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? AdminCachedImage(
                url: adminImageUrl(avatarUrl, width: 96),
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                memCacheWidth: 96,
                errorWidget: fallback,
              )
            : fallback,
      ),
    );
  }

}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.profile, required this.session});

  final AdminProfile? profile;
  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    final email = session.user.email?.trim();
    final initials =
        profile?.initials ??
        ((email == null || email.isEmpty) ? 'P' : email[0].toUpperCase());

    return Text(
      initials,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}
