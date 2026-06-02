import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../data/news_detail_mock.dart';

/// Detay sayfasının yorumlar bölümü.
///
/// Yapı:
///   - Başlık (toplam yorum sayısı + filtre dropdown).
///   - Yorum yazma composer (üst sticky-feel).
///   - Görünür yorumlar listesi: avatar, ad, doğrulama, zaman, gövde,
///     beğen / yanıtla aksiyonları.
///   - "Tüm yorumları gör" CTA.
class DetailCommentsSection extends StatelessWidget {
  const DetailCommentsSection({
    super.key,
    required this.thread,
    required this.currentUser,
    required this.onSeeAll,
  });

  final NewsCommentThread thread;
  final NewsAuthor currentUser;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentsHeader(total: thread.total),
          const SizedBox(height: AppSpacing.lg),
          _Composer(currentUser: currentUser),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < thread.visible.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.softLine,
                ),
              ),
            _CommentTile(comment: thread.visible[i]),
          ],
          const SizedBox(height: AppSpacing.lg),
          _SeeAllCta(onTap: onSeeAll, total: thread.total),
        ],
      ),
    );
  }
}

class _CommentsHeader extends StatelessWidget {
  const _CommentsHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: AppColors.actionRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          'Yorumlar',
          style: AppTypography.titleM.copyWith(
            color: AppColors.inkStrong,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.surfaceInk,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            CountFormat.compact(total),
            style: AppTypography.meta.copyWith(
              color: AppColors.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'En beğenilen',
                    style: AppTypography.meta.copyWith(
                      color: AppColors.deepOcean,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Symbols.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.deepOcean,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.currentUser});

  final NewsAuthor currentUser;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _focused = false;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _focus.addListener(_onFocus);
  }

  void _onChange() {
    final canSend = _controller.text.trim().isNotEmpty;
    if (canSend != _canSend) setState(() => _canSend = canSend);
  }

  void _onFocus() {
    if (_focus.hasFocus != _focused) {
      setState(() => _focused = _focus.hasFocus);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _focus.removeListener(_onFocus);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    if (!_canSend) return;
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: _focused ? AppColors.surface : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _focused ? AppColors.deepOcean : AppColors.softLine,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ComposerAvatar(author: widget.currentUser),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              cursorColor: AppColors.actionRed,
              cursorWidth: 1.4,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: AppTypography.bodySmall.copyWith(
                fontSize: 13.5,
                color: AppColors.ink,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: 'Sen ne düşünüyorsun?',
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.placeholder,
                  fontSize: 13.5,
                  height: 1.4,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _SendButton(canSend: _canSend, onTap: _send),
        ],
      ),
    );
  }
}

class _ComposerAvatar extends StatelessWidget {
  const _ComposerAvatar({required this.author});

  final NewsAuthor author;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    const size = 32.0;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceInk,
        child: CachedImage(
          url: author.avatarUrl,
          fit: BoxFit.cover,
          memCacheWidth: (size * dpr).round(),
          placeholderColor: AppColors.surfaceInk,
          errorWidget: Container(
            color: AppColors.surfaceInk,
            alignment: Alignment.center,
            child: Text(
              author.name.characters.first.toUpperCase(),
              style: AppTypography.titleS.copyWith(
                color: AppColors.deepOcean,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.canSend, required this.onTap});

  final bool canSend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = canSend ? AppColors.actionRed : AppColors.surfaceInk;
    final fg = canSend ? Colors.white : AppColors.placeholder;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: canSend ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(Symbols.send_rounded, size: 16, color: fg),
        ),
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  const _CommentTile({required this.comment});

  final NewsComment comment;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _liked = false;
  late int _likes = widget.comment.likes;

  void _toggleLike() {
    setState(() {
      if (_liked) {
        _liked = false;
        _likes--;
      } else {
        _liked = true;
        _likes++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(author: c.author, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      c.author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleS.copyWith(
                        color: AppColors.inkStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (c.author.isVerified || c.author.isOfficial) ...[
                    const SizedBox(width: 4),
                    VerifiedBadge(official: c.author.isOfficial, size: 11),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    '·',
                    style: AppTypography.meta.copyWith(
                      color: AppColors.support,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    RelativeTime.format(c.publishedAt),
                    style: AppTypography.meta.copyWith(
                      color: AppColors.support,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                c.body,
                style: AppTypography.body.copyWith(
                  color: AppColors.ink,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MicroAction(
                    icon: _liked
                        ? Symbols.favorite_rounded
                        : Symbols.favorite_outline_rounded,
                    color: _liked ? AppColors.actionRed : AppColors.support,
                    label: CountFormat.compact(_likes),
                    bold: _liked,
                    onTap: _toggleLike,
                  ),
                  const SizedBox(width: 16),
                  _MicroAction(
                    icon: Symbols.reply_rounded,
                    color: AppColors.inkSoft,
                    label: 'Yanıtla',
                    onTap: () {},
                  ),
                  const Spacer(),
                  _MicroAction(
                    icon: Symbols.flag_outlined,
                    color: AppColors.support,
                    label: '',
                    onTap: () {},
                  ),
                ],
              ),
              if (c.replies.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _ReplyTrail(reply: c.replies.first),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReplyTrail extends StatelessWidget {
  const _ReplyTrail({required this.reply});

  final NewsComment reply;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.softLine, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(author: reply.author, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        reply.author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleS.copyWith(
                          color: AppColors.inkStrong,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      RelativeTime.format(reply.publishedAt),
                      style: AppTypography.meta.copyWith(
                        color: AppColors.support,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reply.body,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.inkSoft,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.author, required this.size});

  final NewsAuthor author;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceInk,
        child: CachedImage(
          url: author.avatarUrl,
          fit: BoxFit.cover,
          memCacheWidth: (size * dpr).round(),
          placeholderColor: AppColors.surfaceInk,
          errorWidget: Container(
            color: AppColors.surfaceInk,
            alignment: Alignment.center,
            child: Text(
              author.name.characters.first.toUpperCase(),
              style: AppTypography.titleS.copyWith(
                color: AppColors.deepOcean,
                fontSize: size * 0.42,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MicroAction extends StatelessWidget {
  const _MicroAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.bold = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: AppTypography.meta.copyWith(
                    color: color,
                    fontSize: 11,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SeeAllCta extends StatelessWidget {
  const _SeeAllCta({required this.onTap, required this.total});

  final VoidCallback onTap;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.softLine, width: 1),
          ),
          child: Row(
            children: [
              const Icon(
                Symbols.forum_outlined,
                size: 16,
                color: AppColors.deepOcean,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${CountFormat.compact(total)} yorumun tamamını gör',
                  style: AppTypography.titleS.copyWith(
                    color: AppColors.inkStrong,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const Icon(
                Symbols.arrow_forward_rounded,
                size: 16,
                color: AppColors.deepOcean,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
