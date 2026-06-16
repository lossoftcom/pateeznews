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

  String get displaySource {
    final value = sourceName.trim();
    if (value.isEmpty) return '-';
    return value;
  }

  String get displayMediaType {
    final value = mediaType.trim().toLowerCase();
    return value == 'video' ? 'video' : 'image';
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

  factory StoryFormData.empty() {
    return const StoryFormData(
      title: '',
      mediaUrl: '',
      mediaType: 'image',
      sourceName: '',
      expiresAt: null,
      isActive: true,
    );
  }

  factory StoryFormData.fromStory(AdminStory story) {
    return StoryFormData(
      title: story.title,
      mediaUrl: story.mediaUrl,
      mediaType: story.displayMediaType,
      sourceName: story.sourceName,
      expiresAt: story.expiresAt,
      isActive: story.isActive,
    );
  }

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

/// Re-openable editor payload for a single story, used by the Web Stories editor.
class AdminStoryContent {
  const AdminStoryContent({
    required this.storyData,
    required this.title,
    required this.markup,
  });

  /// Saved editor state (the `story_data` jsonb column); empty map for a story
  /// that has never been opened in the editor.
  final Map<String, dynamic> storyData;
  final String title;
  final String markup;
}
