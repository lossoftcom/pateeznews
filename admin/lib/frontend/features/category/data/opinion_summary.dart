import 'package:flutter/material.dart';

import '../../../core/mock/home_mock_data.dart';

@immutable
class OpinionAuthorSummary {
  const OpinionAuthorSummary({
    required this.key,
    required this.author,
    required this.initials,
    required this.info,
    required this.latestArticle,
    required this.postCount,
    required this.totalViews,
  });

  final String key;
  final NewsAuthor author;
  final String initials;
  final String info;
  final NewsArticle latestArticle;
  final int postCount;
  final int totalViews;
}

List<OpinionAuthorSummary> buildOpinionAuthorSummaries(
  List<NewsArticle> articles,
) {
  if (articles.isEmpty) return const [];

  final states = <String, _OpinionAuthorState>{};
  for (final article in articles) {
    final author = article.author;
    final name = author.name.trim().isEmpty ? 'Pateez' : author.name.trim();
    final handle = (author.handle ?? '').trim();
    final key = _authorKey(author, name, handle);
    final current = states[key];
    if (current == null) {
      states[key] = _OpinionAuthorState(
        author: author,
        fallbackName: name,
        latestArticle: article,
        postCount: 1,
        totalViews: article.views,
      );
      continue;
    }

    current.postCount += 1;
    current.totalViews += article.views;
    if (article.publishedAt.isAfter(current.latestArticle.publishedAt)) {
      current.latestArticle = article;
    }
    if (current.author.avatarUrl.trim().isEmpty &&
        author.avatarUrl.trim().isNotEmpty) {
      current.author = author;
    }
    if ((current.author.handle ?? '').trim().isEmpty && handle.isNotEmpty) {
      current.author = author;
    }
  }

  final summaries = states.entries
      .map((entry) {
        final state = entry.value;
        final author = state.author;
        final name = author.name.trim().isEmpty
            ? state.fallbackName
            : author.name.trim();
        final info = _authorInfo(author, state.latestArticle);
        return OpinionAuthorSummary(
          key: entry.key,
          author: NewsAuthor(
            id: author.id,
            name: name,
            avatarUrl: author.avatarUrl,
            handle: author.handle,
            bio: author.bio,
            expertise: author.expertise,
            isVerified: author.isVerified,
            isOfficial: author.isOfficial,
          ),
          initials: _initials(name),
          info: info,
          latestArticle: state.latestArticle,
          postCount: state.postCount,
          totalViews: state.totalViews,
        );
      })
      .toList(growable: false);

  return summaries..sort((a, b) {
    final latest = b.latestArticle.publishedAt.compareTo(
      a.latestArticle.publishedAt,
    );
    if (latest != 0) return latest;
    return b.postCount.compareTo(a.postCount);
  });
}

bool isOpinionNavigationItem({required String label, required String value}) {
  final key = '${label.trim()} ${value.trim()}'.toLowerCase();
  return key.contains('köşe') ||
      key.contains('kose') ||
      key.contains('opinion');
}

String _authorKey(NewsAuthor author, String name, String handle) {
  final cleanId = author.id.trim();
  if (cleanId.isNotEmpty) return 'id:$cleanId';
  if (handle.isNotEmpty) {
    return 'handle:${handle.replaceFirst(RegExp(r'^@+'), '').toLowerCase()}';
  }
  return 'name:${_keySafe(name)}';
}

String _authorInfo(NewsAuthor author, NewsArticle latestArticle) {
  final expertise = author.expertise.trim();
  if (expertise.isNotEmpty) return expertise;
  final bio = author.bio.trim();
  if (bio.isNotEmpty) return bio;
  return latestArticle.summary.trim();
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return 'P';
  final first = parts.first.characters.first;
  final second = parts.length > 1 ? parts.last.characters.first : '';
  return (first + second).toUpperCase();
}

String _keySafe(String value) {
  return value.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9ğüşöçıİĞÜŞÖÇ]+'),
    '-',
  );
}

class _OpinionAuthorState {
  _OpinionAuthorState({
    required this.author,
    required this.fallbackName,
    required this.latestArticle,
    required this.postCount,
    required this.totalViews,
  });

  NewsAuthor author;
  final String fallbackName;
  NewsArticle latestArticle;
  int postCount;
  int totalViews;
}
