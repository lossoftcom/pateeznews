import 'dart:math' as math;

import '../../../core/mock/home_mock_data.dart';

int compareNewsByLatest(NewsArticle a, NewsArticle b) {
  if (a.isPinned != b.isPinned) return b.isPinned ? 1 : -1;
  final date = b.publishedAt.compareTo(a.publishedAt);
  if (date != 0) return date;
  return b.views.compareTo(a.views);
}

int compareNewsByPopularity(NewsArticle a, NewsArticle b) {
  if (a.isPinned != b.isPinned) return b.isPinned ? 1 : -1;
  final score = _popularityScore(b).compareTo(_popularityScore(a));
  return score != 0 ? score : compareNewsByLatest(a, b);
}

double _popularityScore(NewsArticle article) {
  final now = DateTime.now();
  final ageMinutes = now.difference(article.publishedAt).inMinutes;
  final ageHours = math.max(0, ageMinutes) / 60;
  final recency = math.exp(-ageHours / 168);
  final positive =
      _log(article.views) * 1.0 +
      _log(article.likes) * 2.4 +
      _log(article.comments) * 2.2 +
      _log(article.shares) * 2.8 +
      _log(article.saves) * 2.5;
  final negative = _log(article.dislikes) * 1.1;
  return math.max(0, positive - negative) * (0.78 + recency * 0.22);
}

double _log(int value) {
  return math.log(math.max(0, value) + 1);
}
