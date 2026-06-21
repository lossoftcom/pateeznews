import 'package:flutter/widgets.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/mock/home_mock_data.dart';

/// Tek bir sosyal bağlantı (platform + adres + ikon).
@immutable
class ProfileSocialLink {
  const ProfileSocialLink({
    required this.key,
    required this.label,
    required this.url,
    required this.icon,
    required this.color,
  });

  final String key;
  final String label;
  final String url;
  final IconData icon;
  final Color color;
}

@immutable
class ProfilePreview {
  const ProfilePreview({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatarUrl,
    required this.isVerified,
    required this.isOfficial,
  });

  final String id;
  final String name;
  final String handle;
  final String avatarUrl;
  final bool isVerified;
  final bool isOfficial;
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
    this.id = '',
    required this.name,
    required this.handle,
    required this.roleLabel,
    this.role = '',
    this.expertise = '',
    required this.aboutMe,
    required this.email,
    required this.showEmail,
    required this.avatarUrl,
    this.avatarPath = '',
    required this.coverUrl,
    this.coverPath = '',
    required this.joinedLabel,
    required this.joinedYear,
    required this.isVerified,
    required this.isOnline,
    required this.isOwnProfile,
    this.isFollowing = false,
    this.writerApplicationStatus = 'none',
    this.writerApplicationAt,
    this.writerApplicationReviewedAt,
    this.website = '',
    this.address = '',
    this.city = 'Niğde',
    this.rssFeeds = true,
    required this.postsCount,
    required this.followers,
    required this.following,
    this.likedPostsCount = 0,
    this.commentsCount = 0,
    required this.socialLinks,
    required this.followerAvatars,
    required this.followingAvatars,
    this.followerProfiles = const [],
    this.followingProfiles = const [],
    required this.posts,
  });

  final String id;
  final String name;
  final String handle;
  final String roleLabel;
  final String role;
  final String expertise;
  final String aboutMe;
  final String email;
  final bool showEmail;
  final String avatarUrl;
  final String avatarPath;
  final String coverUrl;
  final String coverPath;
  final String joinedLabel;
  final String joinedYear;
  final bool isVerified;
  final bool isOnline;
  final bool isOwnProfile;
  final bool isFollowing;
  final String writerApplicationStatus;
  final DateTime? writerApplicationAt;
  final DateTime? writerApplicationReviewedAt;
  final String website;
  final String address;
  final String city;
  final bool rssFeeds;
  final int postsCount;
  final int followers;
  final int following;
  final int likedPostsCount;
  final int commentsCount;
  final List<ProfileSocialLink> socialLinks;
  final List<String> followerAvatars;
  final List<String> followingAvatars;
  final List<ProfilePreview> followerProfiles;
  final List<ProfilePreview> followingProfiles;
  final List<NewsArticle> posts;

  bool get hasAbout => aboutMe.trim().isNotEmpty;

  bool get hasWriterAccess {
    final value = role.trim().toLowerCase();
    return value == 'admin' ||
        value == 'super_admin' ||
        value == 'moderator' ||
        value == 'editor' ||
        value == 'publisher' ||
        value == 'writer' ||
        value == 'yazar';
  }

  bool get writerApplicationPending =>
      writerApplicationStatus.trim().toLowerCase() == 'pending';

  bool get showWriterApplicationAction {
    final status = writerApplicationStatus.trim().toLowerCase();
    return isOwnProfile && !hasWriterAccess && status != 'approved';
  }

  String get writerApplicationLabel => writerApplicationPending
      ? 'Yazarlık başvurusu beklemede'
      : 'Yazarlık için başvur';

  ProfileData copyWith({
    String? id,
    String? name,
    String? handle,
    String? roleLabel,
    String? role,
    String? expertise,
    String? aboutMe,
    String? email,
    bool? showEmail,
    String? avatarUrl,
    String? avatarPath,
    String? coverUrl,
    String? coverPath,
    String? joinedLabel,
    String? joinedYear,
    bool? isVerified,
    bool? isOnline,
    bool? isOwnProfile,
    bool? isFollowing,
    String? writerApplicationStatus,
    DateTime? writerApplicationAt,
    DateTime? writerApplicationReviewedAt,
    String? website,
    String? address,
    String? city,
    bool? rssFeeds,
    int? postsCount,
    int? followers,
    int? following,
    int? likedPostsCount,
    int? commentsCount,
    List<ProfileSocialLink>? socialLinks,
    List<String>? followerAvatars,
    List<String>? followingAvatars,
    List<ProfilePreview>? followerProfiles,
    List<ProfilePreview>? followingProfiles,
    List<NewsArticle>? posts,
  }) {
    return ProfileData(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      roleLabel: roleLabel ?? this.roleLabel,
      role: role ?? this.role,
      expertise: expertise ?? this.expertise,
      aboutMe: aboutMe ?? this.aboutMe,
      email: email ?? this.email,
      showEmail: showEmail ?? this.showEmail,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarPath: avatarPath ?? this.avatarPath,
      coverUrl: coverUrl ?? this.coverUrl,
      coverPath: coverPath ?? this.coverPath,
      joinedLabel: joinedLabel ?? this.joinedLabel,
      joinedYear: joinedYear ?? this.joinedYear,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
      isOwnProfile: isOwnProfile ?? this.isOwnProfile,
      isFollowing: isFollowing ?? this.isFollowing,
      writerApplicationStatus:
          writerApplicationStatus ?? this.writerApplicationStatus,
      writerApplicationAt: writerApplicationAt ?? this.writerApplicationAt,
      writerApplicationReviewedAt:
          writerApplicationReviewedAt ?? this.writerApplicationReviewedAt,
      website: website ?? this.website,
      address: address ?? this.address,
      city: city ?? this.city,
      rssFeeds: rssFeeds ?? this.rssFeeds,
      postsCount: postsCount ?? this.postsCount,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      likedPostsCount: likedPostsCount ?? this.likedPostsCount,
      commentsCount: commentsCount ?? this.commentsCount,
      socialLinks: socialLinks ?? this.socialLinks,
      followerAvatars: followerAvatars ?? this.followerAvatars,
      followingAvatars: followingAvatars ?? this.followingAvatars,
      followerProfiles: followerProfiles ?? this.followerProfiles,
      followingProfiles: followingProfiles ?? this.followingProfiles,
      posts: posts ?? this.posts,
    );
  }

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
      name: (name == null || name.trim().isEmpty)
          ? 'Pateez Niğde'
          : name.trim(),
      handle: _normalizeHandle(handle, fallback: '@pateez'),
      roleLabel: (roleLabel == null || roleLabel.trim().isEmpty)
          ? 'Yayıncı'
          : roleLabel.trim(),
      expertise: (roleLabel == null || roleLabel.trim().isEmpty)
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
      avatarPath: avatarUrl?.trim() ?? '',
      coverUrl: 'https://picsum.photos/seed/pateez-profile-cover/1200/520',
      coverPath: '',
      joinedLabel: 'Mart 2026',
      joinedYear: '2026',
      isVerified: isVerified ?? true,
      isOnline: true,
      isOwnProfile: isOwnProfile,
      website: 'https://pateez.com',
      address: '',
      city: 'Niğde',
      rssFeeds: true,
      postsCount: HomeMockData.feed.length,
      followers: 12840,
      following: 86,
      socialLinks: const [
        ProfileSocialLink(
          key: 'instagram',
          label: 'Instagram',
          url: 'https://instagram.com/pateez',
          icon: Symbols.instagram_fill,
          color: Color(0xFFE4405F),
        ),
        ProfileSocialLink(
          key: 'x',
          label: 'X',
          url: 'https://x.com/pateez',
          icon: Symbols.twitter_x_fill,
          color: Color(0xFF000000),
        ),
        ProfileSocialLink(
          key: 'facebook',
          label: 'Facebook',
          url: 'https://facebook.com/pateez',
          icon: Symbols.facebook_fill,
          color: Color(0xFF1877F2),
        ),
        ProfileSocialLink(
          key: 'whatsapp',
          label: 'WhatsApp',
          url: 'https://wa.me/0',
          icon: Symbols.whatsapp_fill,
          color: Color(0xFF25D366),
        ),
        ProfileSocialLink(
          key: 'website',
          label: 'Web sitesi',
          url: 'https://pateez.com',
          icon: Symbols.public_rounded,
          color: Color(0xFF607D8B),
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
