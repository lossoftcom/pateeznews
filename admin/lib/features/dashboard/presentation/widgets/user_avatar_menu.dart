import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pateeznews_admin/features/auth/data/admin_auth_models.dart';

import '../../../../core/theme/app_colors.dart';
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
              : Image.network(
                  _publicUrl(avatarUrl),
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, _, _) {
                    return Center(
                      child: _AvatarInitials(
                        profile: profile,
                        session: session,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  String _publicUrl(String value) {
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:')) {
      return value;
    }
    final base = !kIsWeb
        ? switch (defaultTargetPlatform) {
            TargetPlatform.android => Uri.parse('http://10.0.2.2:4321'),
            _ => Uri.parse('http://localhost:4321'),
          }
        : Uri.base;
    return base.resolve(value).toString();
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
