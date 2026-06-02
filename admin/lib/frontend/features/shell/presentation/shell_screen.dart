import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../account/presentation/account_sign_in_screen.dart';
import '../../home/presentation/home_screen.dart';
import 'widgets/pateez_bottom_nav.dart';
import 'widgets/section_placeholder.dart';

/// Bottom navigation ile yönetilen üst kabuk.
///
/// Sekmeler arası geçiş `IndexedStack` ile yapılır; böylece ana sayfa state'i
/// kaybolmaz, kaydırma konumu korunur.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, this.accountPage});

  final Widget? accountPage;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
  var _hasOpenedAccount = false;

  static const _items = <PateezNavItem>[
    PateezNavItem(
      label: 'Anasayfa',
      icon: Symbols.home_outlined,
      activeIcon: Symbols.home_rounded,
    ),
    PateezNavItem(
      label: 'Video',
      icon: Symbols.play_circle_outline_rounded,
      activeIcon: Symbols.play_circle_rounded,
    ),
    PateezNavItem(
      label: 'Uygulamalar',
      icon: Symbols.grid_view_outlined,
      activeIcon: Symbols.grid_view_rounded,
    ),
    PateezNavItem(
      label: 'Hesap',
      icon: Symbols.person_outline_rounded,
      activeIcon: Symbols.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        body: SafeArea(
          top: false,
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: [
              const HomeScreen(),
              const SectionPlaceholder(
                icon: Symbols.play_circle_outline_rounded,
                title: 'Video akışı',
                message:
                    'Editör seçimi kısa videolar burada yayına alındığında '
                    'sana özel akış hazır olacak.',
              ),
              const SectionPlaceholder(
                icon: Symbols.grid_view_rounded,
                title: 'Pateez uygulamaları',
                message:
                    'Anketler, testler ve mini araçlar bu bölümde tek '
                    'çatı altında toplanacak.',
              ),
              _hasOpenedAccount && widget.accountPage != null
                  ? widget.accountPage!
                  : const AccountSignInScreen(),
            ],
          ),
        ),
        bottomNavigationBar: PateezBottomNav(
          items: _items,
          activeIndex: _index,
          onSelected: (i) => setState(() {
            if (i == 3) _hasOpenedAccount = true;
            _index = i;
          }),
        ),
      ),
    );
  }
}
