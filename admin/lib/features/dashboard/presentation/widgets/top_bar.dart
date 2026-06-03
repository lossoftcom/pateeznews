import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/features/auth/data/admin_auth_models.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_date_formatter.dart';
import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import 'app_search_field.dart';
import 'language_select.dart';
import 'top_bar_icon_action.dart';
import 'user_avatar_menu.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.compact,
    required this.session,
    required this.profile,
    required this.onLogout,
    required this.onAccountSettings,
    this.onOpenFrontend,
  });

  final bool compact;
  final AdminSession session;
  final AdminProfile? profile;
  final VoidCallback onLogout;
  final VoidCallback onAccountSettings;
  final VoidCallback? onOpenFrontend;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final searchWidth = (constraints.maxWidth - 288).clamp(220.0, 360.0);
          const compactSideWidth = 84.0;
          return Row(
            children: compact
                ? [
                    SizedBox(
                      width: onOpenFrontend == null ? 48 : compactSideWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: context.t('nav.menu'),
                          mouseCursor: SystemMouseCursors.click,
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                          icon: const SymbolIcon(Symbols.menu),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          context.t('brand.name'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepOcean,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: onOpenFrontend == null ? 36 : compactSideWidth,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (onOpenFrontend != null) ...[
                            TopBarIconAction(
                              icon: Symbols.open_in_new,
                              tooltip: context.t('nav.sitePreview'),
                              onPressed: onOpenFrontend!,
                            ),
                            const SizedBox(width: 6),
                          ],
                          UserAvatarMenu(
                            session: session,
                            profile: profile,
                            onLogout: onLogout,
                            onAccountSettings: onAccountSettings,
                          ),
                        ],
                      ),
                    ),
                  ]
                : [
                    SizedBox(width: searchWidth, child: const AppSearchField()),
                    const SizedBox(width: 8),
                    const LanguageSelect(),
                    const SizedBox(width: 8),
                    TopBarIconAction(
                      icon: Symbols.open_in_new,
                      tooltip: context.t('nav.sitePreview'),
                      label: context.t('nav.sitePreview'),
                      onPressed: onOpenFrontend ?? () {},
                    ),
                    const SizedBox(width: 12),
                    const _TopBarDateTime(),
                    const Spacer(),
                    TopBarIconAction(
                      icon: Symbols.notifications,
                      tooltip: context.t('nav.notifications'),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    UserAvatarMenu(
                      session: session,
                      profile: profile,
                      onLogout: onLogout,
                      onAccountSettings: onAccountSettings,
                    ),
                  ],
          );
        },
      ),
    );
  }
}

class _TopBarDateTime extends StatefulWidget {
  const _TopBarDateTime();

  @override
  State<_TopBarDateTime> createState() => _TopBarDateTimeState();
}

class _TopBarDateTimeState extends State<_TopBarDateTime> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatAdminFullDate(context, _now),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              height: 1.12,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatAdminTime(_now),
            maxLines: 1,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              height: 1.1,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
