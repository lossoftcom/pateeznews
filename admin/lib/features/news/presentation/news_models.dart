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
    this.categoryPath = const [],
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
  final List<String> categoryPath;
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

class AdminNewsEditorLanguage {
  const AdminNewsEditorLanguage({required this.code, required this.name});

  final String code;
  final String name;

  factory AdminNewsEditorLanguage.fromJson(Map<dynamic, dynamic> json) {
    return AdminNewsEditorLanguage(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class AdminNewsEditorCategory {
  const AdminNewsEditorCategory({
    required this.id,
    required this.label,
    required this.parentId,
    required this.languageCode,
    required this.orderIndex,
    this.menuId = '',
    this.type = '',
    this.value = '',
    this.icon = '',
  });

  final String id;
  final String label;
  final String parentId;
  final String languageCode;
  final int orderIndex;
  final String menuId;
  final String type;
  final String value;
  final String icon;

  factory AdminNewsEditorCategory.fromJson(Map<dynamic, dynamic> json) {
    return AdminNewsEditorCategory(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      parentId: json['parent_id']?.toString() ?? '',
      languageCode: json['language_code']?.toString() ?? '',
      orderIndex: _modelAsInt(json['order_index']),
      menuId: json['menu_id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
    );
  }
}

class AdminNewsEditorPublisher {
  const AdminNewsEditorPublisher({required this.id, required this.name});

  final String id;
  final String name;

  factory AdminNewsEditorPublisher.fromJson(Map<dynamic, dynamic> json) {
    final fullName = json['full_name']?.toString().trim() ?? '';
    final username = json['username']?.toString().trim() ?? '';
    final email = json['email']?.toString().trim() ?? '';
    return AdminNewsEditorPublisher(
      id: json['id']?.toString() ?? '',
      name: fullName.isNotEmpty
          ? fullName
          : username.isNotEmpty
          ? username
          : email,
    );
  }
}

class AdminNewsEditorBootstrap {
  const AdminNewsEditorBootstrap({
    required this.languages,
    required this.categories,
    required this.publishers,
  });

  final List<AdminNewsEditorLanguage> languages;
  final List<AdminNewsEditorCategory> categories;
  final List<AdminNewsEditorPublisher> publishers;
}

class AdminNewsEditorPost {
  const AdminNewsEditorPost({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.type,
    required this.thumbnailUrl,
    required this.thumbnailAlt,
    required this.seoTitle,
    required this.seoDescription,
    required this.keywords,
    required this.slug,
    required this.status,
    required this.languageCode,
    required this.publisherId,
    required this.isPinned,
    required this.showInManset,
    required this.factChecked,
    required this.schemaType,
    required this.publishedAt,
    required this.cardData,
    required this.items,
    required this.faqData,
  });

  final String id;
  final String title;
  final String summary;
  final String category;
  final String type;
  final String thumbnailUrl;
  final String thumbnailAlt;
  final String seoTitle;
  final String seoDescription;
  final String keywords;
  final String slug;
  final String status;
  final String languageCode;
  final String publisherId;
  final bool isPinned;
  final bool showInManset;
  final bool factChecked;
  final String schemaType;
  final DateTime? publishedAt;
  final Map<String, Object?> cardData;
  final List<Map<String, Object?>> items;
  final List<Map<String, Object?>> faqData;

  factory AdminNewsEditorPost.fromJson(Map<dynamic, dynamic> json) {
    return AdminNewsEditorPost(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      type: json['type']?.toString() ?? 'article',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      thumbnailAlt: json['thumbnail_alt']?.toString() ?? '',
      seoTitle: json['seo_title']?.toString() ?? '',
      seoDescription: json['seo_description']?.toString() ?? '',
      keywords: json['keywords']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      languageCode: json['language_code']?.toString() ?? 'tr',
      publisherId: json['publisher_id']?.toString() ?? '',
      isPinned: json['is_pinned'] == true,
      showInManset: json['show_in_manset'] == true,
      factChecked: json['fact_checked'] == true,
      schemaType: json['schema_type']?.toString() ?? 'NewsArticle',
      publishedAt: _modelParseDate(json['published_at']),
      cardData: _modelAsMap(json['card_data']),
      items: _modelAsMapList(json['items']),
      faqData: _modelAsMapList(json['faq_data']),
    );
  }
}

class AdminNewsEditorSavePayload {
  const AdminNewsEditorSavePayload({required this.values});

  final Map<String, Object?> values;
}

int _modelAsInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _modelParseDate(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

Map<String, Object?> _modelAsMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map(
      (key, nestedValue) => MapEntry(key.toString(), nestedValue),
    );
  }
  return const {};
}

List<Map<String, Object?>> _modelAsMapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, nestedValue) => MapEntry(key.toString(), nestedValue)),
  ];
}
