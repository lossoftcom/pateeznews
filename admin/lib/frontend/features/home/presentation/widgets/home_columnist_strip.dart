import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'section_header.dart';

/// Ana sayfada haberlerin arasına giren "Yazarlar" (köşe yazısı) şeridi.
///
/// Tasarım hedefi: piyasa ve hava şeritleriyle aynı ritim — açık başlık +
/// kullanıcı kaydırınca akan kartlar. Sakin ve minimal; haber kartlarının
/// önüne geçmez (yumuşak gölge, ölçülü tipografi, küçük yazar fotoğrafı).
///
/// Şu an sunum amaçlı örnek köşe yazılarıyla çalışır; backend bağlanınca
/// liste canlı yazar verisinden beslenir, sunum katmanı aynı kalır.
class HomeColumnistStrip extends StatelessWidget {
  const HomeColumnistStrip({super.key, this.onSeeAll});

  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final items = _Columnist.sample;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Yazarlar', actionLabel: 'Tümü', onAction: onSeeAll),
        SizedBox(
          height: 162,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              2,
              AppSpacing.pageHorizontal,
              2,
            ),
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _ColumnistCard(item: items[index]),
          ),
        ),
      ],
    );
  }
}

class _ColumnistCard extends StatelessWidget {
  const _ColumnistCard({required this.item});

  final _Columnist item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleM.copyWith(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.inkStrong,
              height: 1.22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.excerpt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12.5,
              color: AppColors.inkSoft,
              height: 1.42,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              _Avatar(initials: item.initials, color: item.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleS.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepOcean,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta.copyWith(
                        fontSize: 11,
                        color: AppColors.support,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Baş harfli, yumuşak tonlu yuvarlak yazar avatarı (ağ görseli gerektirmez).
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.color});

  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTypography.titleS.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Şeritte gösterilen tek bir köşe yazısı (sunum modeli).
@immutable
class _Columnist {
  const _Columnist({
    required this.name,
    required this.initials,
    required this.title,
    required this.excerpt,
    required this.date,
    required this.color,
  });

  final String name;
  final String initials;
  final String title;
  final String excerpt;
  final String date;
  final Color color;

  static const sample = <_Columnist>[
    _Columnist(
      name: 'Taha Kılınç',
      initials: 'TK',
      title: 'Gözlerden ve gündemlerden uzakta',
      excerpt:
          'Osmanlı’nın ardından ortaya çıkan küçük devletlerin sessiz hikâyesi '
          've Balkanlardan kalan izler.',
      date: 'Perşembe, 18 Haziran 2026',
      color: Color(0xFF2C3E50),
    ),
    _Columnist(
      name: 'Nihal B. Karaca',
      initials: 'NK',
      title: 'Sinemanın hafızası ve diğer şeyler',
      excerpt:
          'Schindler’in Listesi’nden Jurassic Park’a, bir yönetmenin yarım '
          'asra yayılan görüntü dünyası.',
      date: 'Çarşamba, 17 Haziran 2026',
      color: Color(0xFFB45309),
    ),
    _Columnist(
      name: 'Hakan Albayrak',
      initials: 'HA',
      title: 'Şehrin sessiz tanıkları',
      excerpt:
          'Niğde’nin dar sokaklarında yüz yıllık taş evler, hâlâ kendi '
          'zamanının hikâyesini fısıldıyor.',
      date: 'Salı, 16 Haziran 2026',
      color: Color(0xFF0F766E),
    ),
    _Columnist(
      name: 'Elif Çamlıca',
      initials: 'EÇ',
      title: 'Bir kuşağın ortak hafızası',
      excerpt:
          'Anadolu’nun küçük şehirlerinde büyümek, hatırlamak ve unutmamak '
          'üzerine kısa bir deneme.',
      date: 'Pazartesi, 15 Haziran 2026',
      color: Color(0xFF6D28D9),
    ),
  ];
}
