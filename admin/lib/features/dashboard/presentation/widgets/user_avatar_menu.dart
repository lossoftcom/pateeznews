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
          onEnter: (_) => _openMenu(),
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

    return Container(
      width: 36,
      height: 36,
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.support),
      ),
      child: ClipOval(
        child: ColoredBox(
          color: AppColors.surface,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Center(
                  child: _AvatarInitials(profile: profile, session: session),
                )
              : AdminCachedImage(
                  url: adminImageUrl(avatarUrl, width: 96),
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  memCacheWidth: 96,
                  errorWidget: Center(
                    child: _AvatarInitials(
                      profile: profile,
                      session: session,
                    ),
                  ),
                ),
        ),
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
