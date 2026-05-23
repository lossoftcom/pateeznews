import 'package:web/web.dart' as web;

Future<void> openCommentLink(String url) async {
  if (url.trim().isEmpty) return;
  web.window.open(url, '_blank');
}
