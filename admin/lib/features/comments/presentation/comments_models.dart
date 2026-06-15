class AdminCommentMetricData {
  const AdminCommentMetricData({
    required this.total,
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.totalChange,
    required this.approvedChange,
    required this.pendingChange,
    required this.rejectedChange,
  });

  final int total;
  final int approved;
  final int pending;
  final int rejected;
  final String totalChange;
  final String approvedChange;
  final String pendingChange;
  final String rejectedChange;
}

class AdminCommentFilterItem {
  const AdminCommentFilterItem({required this.id, required this.label});

  final String id;
  final String label;
}

class AdminCommentFilterOptions {
  const AdminCommentFilterOptions({required this.posts, required this.users});

  final List<AdminCommentFilterItem> posts;
  final List<AdminCommentFilterItem> users;
}

class AdminComment {
  const AdminComment({
    required this.id,
    required this.rowNumber,
    required this.content,
    required this.postId,
    required this.userId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.likesCount,
    required this.repliesCount,
    required this.reportsCount,
    required this.isPinned,
    required this.postTitle,
    required this.userName,
    required this.userAvatar,
    required this.guestName,
    required this.guestEmail,
    this.userFullName = '',
    this.userEmail = '',
    this.userUsername = '',
  });

  final String id;
  final int rowNumber;
  final String content;
  final String postId;
  final String userId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int likesCount;
  final int repliesCount;
  final int reportsCount;
  final bool isPinned;
  final String postTitle;
  final String userName;
  final String userAvatar;
  final String guestName;
  final String guestEmail;
  final String userFullName;
  final String userEmail;
  final String userUsername;

  bool get hasReports => reportsCount > 0;

  bool get isRegisteredUser => userId.trim().isNotEmpty;

  String get profileDisplayName {
    final fullName = userFullName.trim();
    if (fullName.isNotEmpty) return fullName;
    final name = userName.trim();
    if (name.isNotEmpty) return name;
    final username = userUsername.trim();
    if (username.isNotEmpty) return username;
    return '';
  }

  String get profileEmail => userEmail.trim();

  String get profileHandle {
    final username = userUsername.trim();
    if (username.isEmpty) return '';
    return username.startsWith('@') ? username : '@$username';
  }

  String get profileSlug =>
      userUsername.trim().replaceFirst(RegExp(r'^@+'), '');

  String get displayUser {
    final profileName = profileDisplayName;
    if (profileName.isNotEmpty) return profileName;
    final guest = guestName.trim();
    if (guest.isNotEmpty) return guest;
    return 'Anonymous User';
  }

  String get displayPost {
    final value = postTitle.trim();
    return value.isEmpty ? 'Unnamed Post' : value;
  }

  String get createdDate {
    final value = createdAt;
    if (value == null) return '-';
    final local = value.toLocal();
    return '${_two(local.day)}.${_two(local.month)}.${local.year}';
  }

  String get createdTime {
    final value = createdAt;
    if (value == null) return '';
    final local = value.toLocal();
    return '${_two(local.hour)}:${_two(local.minute)}';
  }

  String get initials {
    final source = displayUser.trim();
    final words = source
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return source.isEmpty ? 'Y' : source[0].toUpperCase();
  }
}

class AdminCommentsPageResult {
  const AdminCommentsPageResult({
    required this.comments,
    required this.totalCount,
  });

  final List<AdminComment> comments;
  final int totalCount;
}

String _two(int value) => value.toString().padLeft(2, '0');
