import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/presentation/home_screen.dart';
import 'widgets/pateez_bottom_nav.dart';
import 'widgets/section_placeholder.dart';

/// Bottom navigation ile yönetilen üst kabuk.
///
/// Sekmeler arası geçiş `IndexedStack` ile yapılır; böylece ana sayfa state'i
/// kaybolmaz, kaydırma konumu korunur.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  static const _items = <PateezNavItem>[
    PateezNavItem(
      label: 'Anasayfa',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    PateezNavItem(
      label: 'Video',
      icon: Icons.play_circle_outline_rounded,
      activeIcon: Icons.play_circle_rounded,
    ),
    PateezNavItem(
      label: 'Uygulamalar',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
    ),
    PateezNavItem(
      label: 'Hesap',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
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
            children: const [
              HomeScreen(),
              SectionPlaceholder(
                icon: Icons.play_circle_outline_rounded,
                title: 'Video akışı',
                message:
                    'Editör seçimi kısa videolar burada yayına alındığında '
                    'sana özel akış hazır olacak.',
              ),
              SectionPlaceholder(
                icon: Icons.grid_view_rounded,
                title: 'Pateez uygulamaları',
                message:
                    'Anketler, testler ve mini araçlar bu bölümde tek '
                    'çatı altında toplanacak.',
              ),
              SectionPlaceholder(
                icon: Icons.person_outline_rounded,
                title: 'Hesabın',
                message:
                    'Giriş yaptıktan sonra kaydettiğin haberler, takip '
                    'ettiğin kategoriler ve tercihlerin burada görünecek.',
              ),
            ],
          ),
        ),
        bottomNavigationBar: PateezBottomNav(
          items: _items,
          activeIndex: _index,
          onSelected: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
