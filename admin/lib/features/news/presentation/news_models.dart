class AdminNewsMetricData {
  const AdminNewsMetricData({
    required this.total,
    required this.published,
    required this.views,
    required this.scheduled,
  });

  final int total;
  final int published;
  final int views;
  final int scheduled;
}

class AdminNewsFilterItem {
  const AdminNewsFilterItem({
    required this.id,
    required this.label,
    this.parentLabel,
  });

  final String id;
  final String label;
  final String? parentLabel;

  String get displayLabel {
    final parent = parentLabel?.trim();
    if (parent == null || parent.isEmpty) return label;
    return '$parent > $label';
  }
}

class AdminNewsFilterOptions {
  const AdminNewsFilterOptions({
    required this.languages,
    required this.categories,
    required this.types,
    required this.publishers,
  });

  final List<AdminNewsFilterItem> languages;
  final List<AdminNewsFilterItem> categories;
  final List<AdminNewsFilterItem> types;
  final List<AdminNewsFilterItem> publishers;
}

class AdminNewsPost {
  const AdminNewsPost({
    required this.id,
    required this.rowNumber,
    required this.title,
    required this.category,
    required this.type,
    required this.status,
    required this.slug,
    required this.createdAt,
    required this.thumbnailUrl,
    required this.likesCount,
    required this.commentsCount,
    required this.languageCode,
    required this.isPinned,
    required this.publisherId,
    required this.publisherName,
    required this.publisherUsername,
    required this.publisherEmail,
    this.parentCategory,
  });

  final String id;
  final int rowNumber;
  final String title;
  final String category;
  final String type;
  final String status;
  final String slug;
  final DateTime? createdAt;
  final String thumbnailUrl;
  final int likesCount;
  final int commentsCount;
  final String languageCode;
  final bool isPinned;
  final String publisherId;
  final String publisherName;
  final String publisherUsername;
  final String publisherEmail;
  final String? parentCategory;

  bool get published => status == 'published';

  String get displayTitle => title.trim().isEmpty ? 'Untitled Post' : title;

  String get displayType {
    final value = type.trim();
    if (value.isEmpty) return 'standard';
    return value;
  }

  String get displayCategory {
    final value = category.trim();
    if (value.isEmpty) return '-';
    return value;
  }

  String get displayLanguage {
    final value = languageCode.trim();
    if (value.isEmpty) return 'tr';
    return value;
  }

  String get displayPublisher {
    final value = publisherName.trim();
    if (value.isEmpty) return '-';
    return value;
  }

  String get displayPublisherUsername {
    final value = publisherUsername.trim();
    if (value.isEmpty) return '';
    return value.startsWith('@') ? value : '@$value';
  }

  String get displayPublisherEmail => publisherEmail.trim();

  String get createdDate {
    final date = createdAt;
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String get createdTime {
    final date = createdAt;
    if (date == null) return '';
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class AdminNewsPageResult {
  const AdminNewsPageResult({required this.posts, required this.totalCount});

  final List<AdminNewsPost> posts;
  final int totalCount;
}
