import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/mock/home_mock_data.dart';
import '../../core/network/local_api_base_url.dart';
import 'frontend_link_launcher.dart';

const String _kFrontendApiBaseUrl = String.fromEnvironment(
  'PATEEZNEWS_API_BASE_URL',
);

enum ArticleShareTarget { system, instagram, facebook, x, whatsapp }

extension ArticleShareTargetApi on ArticleShareTarget {
  String get apiPlatform {
    switch (this) {
      case ArticleShareTarget.system:
        return 'mobile_share';
      case ArticleShareTarget.instagram:
        return 'instagram';
      case ArticleShareTarget.facebook:
        return 'facebook';
      case ArticleShareTarget.x:
        return 'x';
      case ArticleShareTarget.whatsapp:
        return 'whatsapp';
    }
  }
}

String frontendShareUrlForArticle(NewsArticle article) {
  final slug = article.slug.trim();
  if (slug.isNotEmpty) {
    return frontendApiUri(
      '/haber/${Uri.encodeComponent(slug)}',
      configuredBaseUrl: _kFrontendApiBaseUrl,
    ).toString();
  }

  final videoUrl = article.primaryVideoUrl.trim();
  if (videoUrl.isNotEmpty) return _absoluteFrontendUrl(videoUrl);
  return _absoluteFrontendUrl(article.imageUrl);
}

Future<bool> shareArticle(
  BuildContext context, {
  required NewsArticle article,
  required ArticleShareTarget target,
}) async {
  final shareUrl = frontendShareUrlForArticle(article);
  if (shareUrl.isEmpty) return false;

  final title = article.title.trim();
  final text = articleShareText(article, shareUrl);

  switch (target) {
    case ArticleShareTarget.system:
    case ArticleShareTarget.instagram:
      return _openSystemShare(
        context,
        text: text,
        title: title.isEmpty ? 'Pateez' : title,
      );
    case ArticleShareTarget.facebook:
      return openFrontendUri(
        Uri.https('www.facebook.com', '/sharer/sharer.php', {'u': shareUrl}),
        preferNativeApp: true,
      );
    case ArticleShareTarget.x:
      return openFrontendUri(
        Uri.https('x.com', '/intent/tweet', {
          if (title.isNotEmpty) 'text': title,
          'url': shareUrl,
          'lang': 'tr',
        }),
        preferNativeApp: true,
      );
    case ArticleShareTarget.whatsapp:
      return openFrontendUri(
        Uri(
          scheme: 'https',
          host: 'wa.me',
          path: '/',
          queryParameters: {'text': text},
        ),
        preferNativeApp: true,
      );
  }
}

String articleShareText(NewsArticle article, String shareUrl) {
  final title = article.title.trim();
  final category = article.category.trim();
  return [
    if (title.isNotEmpty) title,
    if (category.isNotEmpty) category,
    shareUrl,
  ].join('\n');
}

Future<bool> _openSystemShare(
  BuildContext context, {
  required String text,
  required String title,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final result = await SharePlus.instance.share(
    ShareParams(
      text: text,
      title: title,
      subject: title,
      sharePositionOrigin: origin,
    ),
  );
  return result.status == ShareResultStatus.success;
}

String _absoluteFrontendUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '';
  final uri = Uri.tryParse(raw);
  if (uri != null && uri.hasScheme) return raw;
  return frontendApiUri(
    raw,
    configuredBaseUrl: _kFrontendApiBaseUrl,
  ).toString();
}
