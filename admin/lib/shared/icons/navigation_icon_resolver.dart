import 'package:flutter/widgets.dart';

import 'symbols.dart';

IconData resolveNavigationIcon(
  String name, {
  String type = '',
  bool selected = false,
  IconData? fallback,
}) {
  final key = _normalizeNavigationIconKey(name);
  final normalizedType = _normalizeNavigationIconKey(type);

  if (key == 'home' || key == 'house') {
    return selected ? Symbols.home_rounded : Symbols.home_outlined;
  }
  if (key == 'poll' || key == 'survey' || key == 'survey_line') {
    return Symbols.survey_line;
  }
  if (key == 'quiz' || key == 'questionnaire' || key == 'questionnaire_line') {
    return Symbols.questionnaire_line;
  }
  if (key.contains('video') || key == 'smart_display' || key == 'movie') {
    return selected
        ? Symbols.play_circle_rounded
        : Symbols.play_circle_outline_rounded;
  }
  if (key == 'format_list_numbered' ||
      key == 'list' ||
      key == 'contents' ||
      key == 'toc') {
    return Symbols.format_list_numbered;
  }
  if (key == 'restaurant' ||
      key == 'local_dining' ||
      key == 'recipe' ||
      key == 'tarif') {
    return Symbols.restaurant_line;
  }
  if (key == 'calendar_month' || key == 'calendar_event' || key == 'event') {
    return Symbols.calendar_event_line;
  }
  if (key == 'schedule') return Symbols.schedule;
  if (key == 'location_on' ||
      key == 'where_to_vote' ||
      key == 'map_pin' ||
      normalizedType == 'district') {
    return Symbols.location_on_rounded;
  }
  if (key == 'trending_up' || normalizedType == 'trends') {
    return Symbols.trending_up_rounded;
  }
  if (key == 'auto_stories' || key == 'menu_book' || key == 'library_books') {
    return Symbols.menu_book_rounded;
  }
  if (key == 'forum' || key == 'chat') return Symbols.forum_outlined;
  if (key == 'favorite') return Symbols.favorite_outline_rounded;
  if (key == 'share') return Symbols.ios_share_rounded;
  if (key == 'account_balance' || key == 'government') {
    return Symbols.government_line;
  }
  if (key == 'spa' || key == 'leaf' || key == 'forest') {
    return Symbols.leaf_line;
  }
  if (key == 'language' || key == 'public') return Symbols.language;
  if (key == 'newspaper') return Symbols.newspaper;
  if (key == 'notifications') return Symbols.notifications;
  if (key == 'person') return Symbols.person;
  if (key == 'group') return Symbols.group;
  if (key == 'lock') return Symbols.lock;
  if (key == 'visibility') return Symbols.visibility;
  if (key == 'search') return Symbols.search;
  if (key == 'code') return Symbols.code;
  if (key == 'download') return Symbols.download;
  if (key == 'upload') return Symbols.upload;
  if (key == 'menu') return Symbols.menu;

  if (normalizedType == 'category') {
    return fallback ?? Symbols.grid_view_outlined;
  }
  return fallback ?? Symbols.short_text;
}

String _normalizeNavigationIconKey(String value) {
  return value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
}
