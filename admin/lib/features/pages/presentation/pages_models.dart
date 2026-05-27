class AdminPageCategory {
  const AdminPageCategory({
    required this.id,
    required this.label,
    required this.languageCode,
    required this.type,
    this.parentId,
    this.parentLabel,
    this.menuLabel,
  });

  final String id;
  final String label;
  final String languageCode;
  final String type;
  final String? parentId;
  final String? parentLabel;
  final String? menuLabel;

  String get displayLabel {
    final parts = [
      menuLabel?.trim() ?? '',
      parentLabel?.trim() ?? '',
      label,
    ].where((part) => part.isNotEmpty).toList(growable: false);
    return parts.join(' > ');
  }
}

class AdminPageLanguage {
  const AdminPageLanguage({required this.code, required this.name});

  final String code;
  final String name;
}

class AdminPageParentOption {
  const AdminPageParentOption({
    required this.id,
    required this.title,
    required this.languageCode,
  });

  final String id;
  final String title;
  final String languageCode;
}

class AdminPagesFilterOptions {
  const AdminPagesFilterOptions({
    required this.languages,
    required this.categories,
    required this.types,
    required this.parents,
  });

  final List<AdminPageLanguage> languages;
  final List<AdminPageCategory> categories;
  final List<String> types;
  final List<AdminPageParentOption> parents;
}

class AdminPage {
  const AdminPage({
    required this.id,
    required this.rowNumber,
    required this.title,
    required this.slug,
    required this.category,
    required this.categoryId,
    required this.type,
    required this.status,
    required this.languageCode,
    required this.location,
    required this.parentPageId,
    required this.showTitle,
    required this.showBreadcrumb,
    required this.showSidebar,
    required this.registeredOnly,
    required this.menuOrder,
    required this.contentDeltaJson,
    required this.contentPlainText,
    required this.metaTitle,
    required this.metaKeywords,
    required this.metaDescription,
    required this.canonicalUrl,
    required this.createdAt,
    this.parentCategory,
  });

  final String id;
  final int rowNumber;
  final String title;
  final String slug;
  final String category;
  final String categoryId;
  final String type;
  final String status;
  final String languageCode;
  final String location;
  final String parentPageId;
  final bool showTitle;
  final bool showBreadcrumb;
  final bool showSidebar;
  final bool registeredOnly;
  final int menuOrder;
  final String contentDeltaJson;
  final String contentPlainText;
  final String metaTitle;
  final String metaKeywords;
  final String metaDescription;
  final String canonicalUrl;
  final DateTime? createdAt;
  final String? parentCategory;

  bool get active => status == 'active';

  String get displayTitle {
    final value = title.trim();
    return value.isEmpty ? 'pages.untitled' : value;
  }

  String get displayCategory {
    final value = category.trim();
    return value.isEmpty ? '-' : value;
  }

  String get displayType {
    final value = type.trim();
    return value.isEmpty ? 'custom' : value;
  }

  String get displayLanguage {
    final value = languageCode.trim();
    return value.isEmpty ? 'tr' : value;
  }
}

class AdminPagesPageResult {
  const AdminPagesPageResult({required this.pages, required this.totalCount});

  final List<AdminPage> pages;
  final int totalCount;
}

class AdminPageFormData {
  const AdminPageFormData({
    required this.title,
    required this.slug,
    required this.languageCode,
    required this.categoryId,
    required this.category,
    required this.type,
    required this.status,
    required this.location,
    required this.parentPageId,
    required this.showTitle,
    required this.showBreadcrumb,
    required this.showSidebar,
    required this.registeredOnly,
    required this.menuOrder,
    required this.contentDeltaJson,
    required this.contentPlainText,
    required this.metaTitle,
    required this.metaKeywords,
    required this.metaDescription,
    required this.canonicalUrl,
  });

  final String title;
  final String slug;
  final String languageCode;
  final String categoryId;
  final String category;
  final String type;
  final String status;
  final String location;
  final String parentPageId;
  final bool showTitle;
  final bool showBreadcrumb;
  final bool showSidebar;
  final bool registeredOnly;
  final int menuOrder;
  final String contentDeltaJson;
  final String contentPlainText;
  final String metaTitle;
  final String metaKeywords;
  final String metaDescription;
  final String canonicalUrl;
}
