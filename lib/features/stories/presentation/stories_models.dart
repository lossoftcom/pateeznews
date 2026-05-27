class AdminStory {
  const AdminStory({
    required this.id,
    required this.rowNumber,
    required this.title,
    required this.mediaUrl,
    required this.mediaType,
    required this.sourceName,
    required this.publisherId,
    required this.createdAt,
    required this.expiresAt,
    required this.isActive,
    required this.viewCount,
  });

  final String id;
  final int rowNumber;
  final String title;
  final String mediaUrl;
  final String mediaType;
  final String sourceName;
  final String publisherId;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  final int viewCount;

  String get displayTitle => title.trim().isEmpty ? 'Untitled Story' : title;

  String get displayMediaType {
    final value = mediaType.trim().toLowerCase();
    if (value == 'video') return 'video';
    return 'image';
  }

  String get displaySource {
    final value = sourceName.trim();
    if (value.isEmpty) return '-';
    return value;
  }
}

class StoryFormData {
  const StoryFormData({
    required this.title,
    required this.mediaUrl,
    required this.mediaType,
    required this.sourceName,
    required this.expiresAt,
    required this.isActive,
  });

  final String title;
  final String mediaUrl;
  final String mediaType;
  final String sourceName;
  final DateTime? expiresAt;
  final bool isActive;
}

class AdminStoriesPageResult {
  const AdminStoriesPageResult({
    required this.stories,
    required this.totalCount,
  });

  final List<AdminStory> stories;
  final int totalCount;
}
