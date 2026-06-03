import 'package:flutter/widgets.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/mock/home_mock_data.dart';

/// Tek bir sosyal bağlantı (platform + adres + ikon).
@immutable
class ProfileSocialLink {
  const ProfileSocialLink({
    required this.label,
    required this.url,
    required this.icon,
  });

  final String label;
  final String url;
  final IconData icon;
}

/// Kullanıcı profili için sade içerik katmanı.
///
/// Alanlar Astro önyüzdeki profil ekranıyla (profiles tablosu) birebir aynıdır:
/// kimlik, uzmanlık/rol, hakkında, katılım, e‑posta, sosyal bağlantılar,
/// istatistikler (haber / takipçi / takip / katıldı) ve kullanıcının haberleri.
/// Gerçek API entegrasyonunda bu model repository'den beslenir; sunum katmanı
/// yalnızca buna bağlı kalır.
@immutable
class ProfileData {
  const ProfileData({
    required this.name,
    required this.handle,
    required this.roleLabel,
    required this.aboutMe,
    required this.email,
    required this.showEmail,
    required this.avatarUrl,
    required this.coverUrl,
    required this.joinedLabel,
    required this.joinedYear,
    required this.isVerified,
    required this.isOnline,
    required this.isOwnProfile,
    required this.postsCount,
    required this.followers,
    required this.following,
    required this.socialLinks,
    required this.followerAvatars,
    required this.followingAvatars,
    required this.posts,
  });

  final String name;
  final String handle;
  final String roleLabel;
  final String aboutMe;
  final String email;
  final bool showEmail;
  final String avatarUrl;
  final String coverUrl;
  final String joinedLabel;
  final String joinedYear;
  final bool isVerified;
  final bool isOnline;
  final bool isOwnProfile;
  final int postsCount;
  final int followers;
  final int following;
  final List<ProfileSocialLink> socialLinks;
  final List<String> followerAvatars;
  final List<String> followingAvatars;
  final List<NewsArticle> posts;

  bool get hasAbout => aboutMe.trim().isNotEmpty;

  /// Tasarım önizlemesi için zengin örnek profil. Kimlik alanları (ad, kullanıcı
  /// adı, e‑posta, avatar, rol) verilirse gerçek hesaptan ezilir; istatistik,
  /// hakkında, kapak ve gönderiler örnek kalır (backend bağlanınca değişir).
  factory ProfileData.demo({
    String? name,
    String? handle,
    String? email,
    String? avatarUrl,
    String? roleLabel,
    bool? isVerified,
    bool isOwnProfile = true,
  }) {
    return ProfileData(
      name: (name == null || name.trim().isEmpty) ? 'Pateez Niğde' : name.trim(),
      handle: _normalizeHandle(handle, fallback: '@pateez'),
      roleLabel: (roleLabel == null || roleLabel.trim().isEmpty)
          ? 'Yayıncı'
          : roleLabel.trim(),
      aboutMe:
          'Niğde ve çevresinden güncel haberler, yerel gündem ve kültür. '
          'Doğru, tarafsız ve hızlı habercilik için buradayız.',
      email: (email == null || email.trim().isEmpty)
          ? 'pateezcom@gmail.com'
          : email.trim(),
      showEmail: true,
      avatarUrl: (avatarUrl == null || avatarUrl.trim().isEmpty)
          ? 'https://picsum.photos/seed/pateez-profile-avatar/240/240'
          : avatarUrl.trim(),
      coverUrl: 'https://picsum.photos/seed/pateez-profile-cover/1200/520',
      joinedLabel: 'Mart 2026',
      joinedYear: '2026',
      isVerified: isVerified ?? true,
      isOnline: true,
      isOwnProfile: isOwnProfile,
      postsCount: HomeMockData.feed.length,
      followers: 12840,
      following: 86,
      socialLinks: const [
        ProfileSocialLink(
          label: 'Instagram',
          url: 'https://instagram.com/pateez',
          icon: Symbols.instagram_fill,
        ),
        ProfileSocialLink(
          label: 'X',
          url: 'https://x.com/pateez',
          icon: Symbols.twitter_x_fill,
        ),
        ProfileSocialLink(
          label: 'Facebook',
          url: 'https://facebook.com/pateez',
          icon: Symbols.facebook_fill,
        ),
        ProfileSocialLink(
          label: 'WhatsApp',
          url: 'https://wa.me/0',
          icon: Symbols.whatsapp_fill,
        ),
        ProfileSocialLink(
          label: 'Web sitesi',
          url: 'https://pateez.com',
          icon: Symbols.public_rounded,
        ),
      ],
      followerAvatars: const [
        'https://picsum.photos/seed/pateez-fo1/96/96',
        'https://picsum.photos/seed/pateez-fo2/96/96',
        'https://picsum.photos/seed/pateez-fo3/96/96',
        'https://picsum.photos/seed/pateez-fo4/96/96',
        'https://picsum.photos/seed/pateez-fo5/96/96',
      ],
      followingAvatars: const [
        'https://picsum.photos/seed/pateez-fg1/96/96',
        'https://picsum.photos/seed/pateez-fg2/96/96',
        'https://picsum.photos/seed/pateez-fg3/96/96',
        'https://picsum.photos/seed/pateez-fg4/96/96',
        'https://picsum.photos/seed/pateez-fg5/96/96',
      ],
      posts: HomeMockData.feed,
    );
  }

  static String _normalizeHandle(String? value, {required String fallback}) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return fallback;
    return raw.startsWith('@') ? raw : '@$raw';
  }
}
