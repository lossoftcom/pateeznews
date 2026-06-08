import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../news/data/admin_news_repository.dart';

/// News source picker: dropdown for selecting a published news article + manual link input.
/// When a news article is selected, fetches full detail (summary, keywords, etc.) via a
/// secondary query and calls [onNewsSelected] with all data.
class SocialNewsSourcePicker extends StatefulWidget {
  const SocialNewsSourcePicker({
    super.key,
    required this.newsRepository,
    required this.selectedLink,
    required this.manualLink,
    required this.onNewsSelected,
    required this.onManualLinkChanged,
  });

  final AdminNewsRepository newsRepository;
  final String selectedLink;
  final String manualLink;
  final void Function({
    required String title,
    required String imageUrl,
    required String link,
    required String summary,
    required String keywords,
    required String category,
    required String type,
  })
  onNewsSelected;
  final ValueChanged<String> onManualLinkChanged;

  @override
  State<SocialNewsSourcePicker> createState() => _SocialNewsSourcePickerState();
}

class _SocialNewsSourcePickerState extends State<SocialNewsSourcePicker> {
  List<Map<String, dynamic>> _newsList = [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNews());
  }

  Future<void> _loadNews() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.newsRepository.fetchPosts(
        search: '',
        language: 'Tümü',
        category: 'Tümü',
        type: 'Tümü',
        status: 'published',
        publisher: 'Tümü',
        page: 1,
        pageSize: 50,
        sortKey: 'date',
        sortAscending: false,
      );
      if (!mounted) return;
      setState(() {
        _newsList = result.posts
            .map(
              (p) => <String, dynamic>{
                'id': p.id,
                'title': p.title,
                'slug': p.slug,
                'cover_image': p.thumbnailUrl,
                'category': p.category,
                'type': p.type,
              },
            )
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Fetch extended post details (summary, keywords) by post id.
  Future<void> _fetchPostDetail(Map<String, dynamic> news) async {
    final postId = news['id']?.toString() ?? '';
    if (postId.isEmpty) {
      // Fallback: use what we have
      widget.onNewsSelected(
        title: (news['title'] ?? '') as String,
        imageUrl: (news['cover_image'] ?? '') as String,
        link: (news['slug'] ?? '') as String,
        summary: '',
        keywords: '',
        category: (news['category'] ?? '') as String,
        type: (news['type'] ?? '') as String,
      );
      return;
    }

    try {
      // Build the API URL the same way SupabaseAdminNewsRepository does
      const apiBase = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
      Uri uri;
      if (apiBase.isNotEmpty) {
        uri = Uri.parse(apiBase).resolve('/api/admin/query');
      } else if (!kIsWeb) {
        final host = defaultTargetPlatform == TargetPlatform.android
            ? 'http://10.0.2.2:4321'
            : 'http://127.0.0.1:4321';
        uri = Uri.parse(host).resolve('/api/admin/query');
      } else {
        uri = Uri.base.resolve('/api/admin/query');
      }

      final response = await adminHttpClient
          .post(
            uri,
            headers: await adminJsonHeaders(),
            body: jsonEncode({
              'table': 'posts',
              'method': 'select',
              'select':
                  'summary,keywords,thumbnail_url,title,slug,category,type',
              'filters': [
                {
                  'type': 'comparison',
                  'op': 'eq',
                  'column': 'id',
                  'value': int.tryParse(postId) ?? postId,
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 8));

      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] is List) {
        final rows = (decoded['data'] as List).whereType<Map>().toList();
        if (rows.isNotEmpty) {
          final row = rows.first;
          if (!mounted) return;
          widget.onNewsSelected(
            title: (row['title'] ?? news['title'] ?? '').toString(),
            imageUrl: (row['thumbnail_url'] ?? news['cover_image'] ?? '')
                .toString(),
            link: (row['slug'] ?? news['slug'] ?? '').toString(),
            summary: (row['summary'] ?? '').toString(),
            keywords: (row['keywords'] ?? '').toString(),
            category: (row['category'] ?? news['category'] ?? '').toString(),
            type: (row['type'] ?? news['type'] ?? '').toString(),
          );
          return;
        }
      }
    } catch (_) {
      // Fallback to basic data
    }

    if (!mounted) return;
    widget.onNewsSelected(
      title: (news['title'] ?? '') as String,
      imageUrl: (news['cover_image'] ?? '') as String,
      link: (news['slug'] ?? '') as String,
      summary: '',
      keywords: '',
      category: (news['category'] ?? '') as String,
      type: (news['type'] ?? '') as String,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(
                context.t('social.publish.newsSource'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepOcean,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              if (!_loading)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _loadNews,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: AppColors.iconMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.t('social.publish.refreshNews'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.iconMuted,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Dropdown
        if (_loading)
          Container(
            width: double.infinity,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.value * 2),
              border: Border.all(color: AppColors.line),
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_error != null)
          Container(
            width: double.infinity,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.actionRed.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.value * 2),
              border: Border.all(
                color: AppColors.actionRed.withValues(alpha: 0.2),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              context.t('social.publish.newsError'),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.actionRed,
                letterSpacing: 0,
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value * 2),
              border: Border.all(color: AppColors.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: widget.selectedLink.isEmpty ? null : widget.selectedLink,
                isExpanded: true,
                hint: Text(
                  context.t('social.publish.newsSourceHint'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.placeholder,
                    letterSpacing: 0,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.deepOcean,
                  fontFamily: 'PateezSans',
                  letterSpacing: 0,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.iconMuted,
                ),
                items: _newsList.map((news) {
                  final title = (news['title'] ?? '') as String;
                  final slug = (news['slug'] ?? '') as String;
                  return DropdownMenuItem<String>(
                    value: slug,
                    child: Text(
                      title.isEmpty ? slug : title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (slug) {
                  if (slug == null) return;
                  final news = _newsList.firstWhere(
                    (n) => n['slug'] == slug,
                    orElse: () => <String, dynamic>{},
                  );
                  unawaited(_fetchPostDetail(news));
                },
              ),
            ),
          ),

        // Manual link
        const SizedBox(height: 14),
        Text(
          context.t('social.publish.manualLink'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.deepOcean,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: TextField(
            onChanged: widget.onManualLinkChanged,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.deepOcean,
              letterSpacing: 0,
            ),
            decoration: InputDecoration(
              hintText: context.t('social.publish.manualLinkHint'),
              hintStyle: const TextStyle(
                color: AppColors.placeholder,
                fontSize: 13,
                letterSpacing: 0,
              ),
              prefixIcon: const Icon(
                Icons.link_rounded,
                size: 18,
                color: AppColors.iconMuted,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value * 2),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value * 2),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value * 2),
                borderSide: const BorderSide(color: AppColors.deepOcean),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
