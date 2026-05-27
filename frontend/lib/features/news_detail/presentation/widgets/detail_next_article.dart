import 'package:flutter/material.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Detay sayfasının sonunda yer alan sinematik "sıradaki haber" önizlemesi.
///
/// Tasarım hedefi: kullanıcının kaydırması doğal bir devam akışı oluştursun.
/// CTA, "okumaya devam et" eyebrow'u ya da buton yok — sadece bir sonraki
/// haberin tam genişlik kapağı, kategori-bölge meta'sı ve başlığı. Tap aksiyonu
/// + listener'daki overscroll, aynı sinematik geçişle bir sonraki habere açar.
class DetailNextArticleHandoff extends StatelessWidget {
  const DetailNextArticleHandoff({
    super.key,
    required this.next,
    required this.onTap,
  });

  final NewsArticle next;
  final VoidCallback onTap;

  static const double _aspectRatio = 4 / 5;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = width / _aspectRatio;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Cover(url: next.imageUrl),
              const _TopScrim(),
              const _BottomScrim(),
              Positioned(
                left: AppSpacing.pageHorizontal,
                right: AppSpacing.pageHorizontal,
                bottom: AppSpacing.xxxl,
                child: _Overlay(next: next),
              ),
              const Positioned(
                top: AppSpacing.lg,
                left: 0,
                right: 0,
                child: Center(child: _PullHandle()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (MediaQuery.sizeOf(context).width * dpr).round();
    return Image.network(
      url,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: cacheWidth > 0 ? cacheWidth : null,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: AppColors.surfaceSoft);
      },
      errorBuilder: (_, _, _) => Container(
        color: AppColors.surfaceInk,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          color: AppColors.support,
          size: 36,
        ),
      ),
    );
  }
}

class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x9A000000), Color(0x33000000), Color(0x00000000)],
          stops: [0, 0.32, 0.6],
        ),
      ),
    );
  }
}

class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x00000000),
            Colors.black.withValues(alpha: 0.20),
            Colors.black.withValues(alpha: 0.64),
            Colors.black.withValues(alpha: 0.88),
          ],
          stops: const [0, 0.55, 0.85, 1],
        ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.next});

  final NewsArticle next;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.actionRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                next.category.toUpperCase(),
                style: AppTypography.eyebrow.copyWith(
                  color: Colors.white,
                  fontSize: 10.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.location_on_rounded,
              size: 13,
              color: Color(0xCCFFFFFF),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                next.region,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'PateezInter',
                  color: Color(0xCCFFFFFF),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          next.title,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'PateezInter',
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            height: 1.08,
            shadows: [
              Shadow(
                color: Color(0x66000000),
                offset: Offset(0, 1),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const Icon(
              Icons.menu_book_rounded,
              size: 12,
              color: Color(0xAAFFFFFF),
            ),
            const SizedBox(width: 5),
            Text(
              '${next.readMinutes} dk okuma',
              style: const TextStyle(
                fontFamily: 'PateezInter',
                color: Color(0xAAFFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 2.5,
              height: 2.5,
              decoration: const BoxDecoration(
                color: Color(0x88FFFFFF),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              RelativeTime.format(next.publishedAt),
              style: const TextStyle(
                fontFamily: 'PateezInter',
                color: Color(0xAAFFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Görselin üst kısmında, scroll'un buradan başladığını ima eden sade tutamak.
class _PullHandle extends StatelessWidget {
  const _PullHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
