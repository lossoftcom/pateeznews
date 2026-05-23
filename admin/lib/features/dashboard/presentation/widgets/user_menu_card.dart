import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import 'user_menu_item.dart';

class UserMenuCard extends StatelessWidget {
  const UserMenuCard({
    super.key,
    required this.onProfile,
    required this.onAccountSettings,
    required this.onLogout,
  });

  final VoidCallback onProfile;
  final VoidCallback onAccountSettings;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 176,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserMenuItem(
              icon: Symbols.person,
              label: 'Profile',
              onTap: onProfile,
            ),
            UserMenuItem(
              icon: Symbols.lock,
              label: 'Account Settings',
              onTap: onAccountSettings,
            ),
            UserMenuItem(
              icon: Symbols.logout,
              label: 'Logout',
              onTap: onLogout,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}
