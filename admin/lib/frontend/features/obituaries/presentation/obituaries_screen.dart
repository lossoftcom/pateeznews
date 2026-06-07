import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/data_unavailable_state.dart';
import '../../../shared/widgets/feature_app_bar.dart';
import '../../account/data/frontend_auth_repository.dart';
import '../data/death_notice_repository.dart';

const Color _memorialBlack = Color(0xFF111214);
const Color _memorialPanel = Color(0xFF16181B);
const Color _memorialBorder = Color(0xFF465568);
const Color _memorialGold = Color(0xFFA8864A);
const Color _memorialMuted = Color(0xFF9298A1);
const Color _memorialSoft = Color(0xFF24272B);

class ObituariesScreen extends StatefulWidget {
  const ObituariesScreen({
    super.key,
    this.initialData = const DeathNoticeData.empty(),
    this.repository = const DeathNoticeRepository(),
    this.authState,
  });

  final DeathNoticeData initialData;
  final DeathNoticeRepository repository;
  final FrontendAuthState? authState;

  @override
  State<ObituariesScreen> createState() => _ObituariesScreenState();
}

class _ObituariesScreenState extends State<ObituariesScreen> {
  late DeathNoticeData _data;
  var _refreshing = false;
  final _pendingMessages = <String, List<_CondolenceMessage>>{};

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
  }

  @override
  void didUpdateWidget(covariant ObituariesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_refreshing || _data.hasNotices || !widget.initialData.hasNotices) {
      return;
    }
    _data = widget.initialData;
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final data = await widget.repository.fetch(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _data = data;
      _refreshing = false;
    });
  }

  Future<bool> _submitCondolence({
    required DeathNoticeItem notice,
    required String guestName,
    required String guestEmail,
    required String message,
  }) async {
    final authState = widget.authState;
    final submitted = await widget.repository.submitCondolence(
      CondolenceDraft(
        noticeId: notice.id,
        noticeName: notice.name,
        message: message,
        guestName: guestName,
        guestEmail: guestEmail,
        authToken: authState?.session.accessToken ?? '',
      ),
    );
    if (!mounted || !submitted) return false;
    setState(() {
      final author = authState?.displayName.trim().isNotEmpty == true
          ? authState!.displayName
          : guestName.trim();
      final messages = _pendingMessages[notice.id] ?? <_CondolenceMessage>[];
      _pendingMessages[notice.id] = [
        _CondolenceMessage(author: author, body: message),
        ...messages,
      ];
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            const FeatureAppBar(title: 'Ölüm İlanları'),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.deepOcean,
                backgroundColor: AppColors.surface,
                displacement: 32,
                onRefresh: _refresh,
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.lg,
                    AppSpacing.pageHorizontal,
                    AppSpacing.xxxl + bottomInset,
                  ),
                  children: [
                    if (_data.notices.isEmpty)
                      const DataUnavailableState()
                    else ...[
                      _HeaderCard(data: _data)
                          .animate()
                          .fadeIn(duration: 340.ms, curve: Curves.easeOutCubic)
                          .slideY(
                            begin: 0.04,
                            end: 0,
                            duration: 340.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      const SizedBox(height: AppSpacing.md),
                      for (var i = 0; i < _data.notices.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.md),
                        _ObituaryCard(
                              notice: _data.notices[i],
                              source: _data.source,
                              fetchedAt: _data.fetchedAt,
                              authState: widget.authState,
                              pendingMessages:
                                  _pendingMessages[_data.notices[i].id] ??
                                  const [],
                              onSubmit:
                                  ({
                                    required guestName,
                                    required guestEmail,
                                    required message,
                                  }) => _submitCondolence(
                                    notice: _data.notices[i],
                                    guestName: guestName,
                                    guestEmail: guestEmail,
                                    message: message,
                                  ),
                            )
                            .animate()
                            .fadeIn(
                              delay: (70 * (i + 1)).ms,
                              duration: 320.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .slideY(
                              begin: 0.05,
                              end: 0,
                              delay: (70 * (i + 1)).ms,
                              duration: 320.ms,
                              curve: Curves.easeOutCubic,
                            ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.data});

  final DeathNoticeData data;

  @override
  Widget build(BuildContext context) {
    final dateLabel = data.serviceDateLabel.isEmpty
        ? 'Bugün'
        : data.serviceDateLabel;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _memorialBlack,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.black),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _memorialGold.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _memorialGold.withValues(alpha: 0.42)),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Symbols.leaf_line,
              color: _memorialGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ÖLÜM İLANLARI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.eyebrow.copyWith(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${data.city} · $dateLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: _memorialGold,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${data.updateIntervalMinutes} dk',
              style: AppTypography.meta.copyWith(
                color: _memorialMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObituaryCard extends StatefulWidget {
  const _ObituaryCard({
    required this.notice,
    required this.source,
    required this.fetchedAt,
    required this.authState,
    required this.pendingMessages,
    required this.onSubmit,
  });

  final DeathNoticeItem notice;
  final String source;
  final String fetchedAt;
  final FrontendAuthState? authState;
  final List<_CondolenceMessage> pendingMessages;
  final Future<bool> Function({
    required String guestName,
    required String guestEmail,
    required String message,
  })
  onSubmit;

  @override
  State<_ObituaryCard> createState() => _ObituaryCardState();
}

class _ObituaryCardState extends State<_ObituaryCard> {
  var _composerOpen = false;

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _memorialBlack,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.black),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _memorialPanel,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _memorialBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notice.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleM.copyWith(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _DateBadge(label: notice.deathDateLabel),
                  ],
                ),
                const SizedBox(height: 7),
                if (notice.routeLabel.isNotEmpty)
                  Text(
                    notice.routeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.eyebrow.copyWith(
                      color: _memorialGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  notice.shortDescription.isEmpty
                      ? 'Açıklama bilgisi bekleniyor.'
                      : notice.shortDescription,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: _memorialMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.48,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          _CondolenceButton(
            open: _composerOpen,
            onTap: () => setState(() => _composerOpen = !_composerOpen),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _composerOpen
                ? Padding(
                    key: const ValueKey('composer'),
                    padding: const EdgeInsets.only(top: 12),
                    child: _CondolenceComposer(
                      authState: widget.authState,
                      onSubmit: widget.onSubmit,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty-composer')),
          ),
          if (widget.pendingMessages.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PendingCondolences(messages: widget.pendingMessages),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.source} kaynağı',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: _memorialMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _timeLabel(widget.fetchedAt),
                style: AppTypography.meta.copyWith(
                  color: _memorialMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.isEmpty ? 'Bugün' : label,
        style: AppTypography.meta.copyWith(
          color: _memorialMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CondolenceButton extends StatelessWidget {
  const _CondolenceButton({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          height: 39,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: open
                ? _memorialGold.withValues(alpha: 0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _memorialBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                open ? Symbols.chat_3_fill : Symbols.heart_3_line,
                size: 16,
                color: _memorialGold,
              ),
              const SizedBox(width: 8),
              Text(
                open ? 'Taziye Mesajı Yaz' : 'Taziye Mesajı Yaz',
                style: AppTypography.titleS.copyWith(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CondolenceComposer extends StatefulWidget {
  const _CondolenceComposer({required this.authState, required this.onSubmit});

  final FrontendAuthState? authState;
  final Future<bool> Function({
    required String guestName,
    required String guestEmail,
    required String message,
  })
  onSubmit;

  @override
  State<_CondolenceComposer> createState() => _CondolenceComposerState();
}

class _CondolenceComposerState extends State<_CondolenceComposer> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  final _focus = FocusNode();
  var _focused = false;
  var _canSend = false;
  var _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onChange);
    _nameController.addListener(_onChange);
    _emailController.addListener(_onChange);
    _focus.addListener(_onFocus);
  }

  void _onChange() {
    final isGuest = widget.authState == null;
    final canSend =
        _messageController.text.trim().isNotEmpty &&
        (!isGuest ||
            (_nameController.text.trim().isNotEmpty &&
                _emailController.text.trim().isNotEmpty));
    if (canSend != _canSend) setState(() => _canSend = canSend);
  }

  void _onFocus() {
    if (_focus.hasFocus != _focused) {
      setState(() => _focused = _focus.hasFocus);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onChange);
    _nameController.removeListener(_onChange);
    _emailController.removeListener(_onChange);
    _focus.removeListener(_onFocus);
    _messageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_canSend || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final message = _messageController.text.trim();
    final submitted = await widget.onSubmit(
      guestName: _nameController.text.trim(),
      guestEmail: _emailController.text.trim(),
      message: message,
    );
    if (!mounted) return;
    if (submitted) {
      _messageController.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _sending = false;
        _canSend = false;
      });
      return;
    }
    setState(() {
      _sending = false;
      _error = 'Taziye mesajı gönderilemedi. Lütfen tekrar deneyin.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = widget.authState;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _memorialSoft,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _focused ? _memorialGold : _memorialBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ComposerAvatar(authState: authState),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    if (authState == null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _GuestField(
                              controller: _nameController,
                              hint: 'Adınız',
                              keyboardType: TextInputType.name,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _GuestField(
                              controller: _emailController,
                              hint: 'E-posta',
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: _messageController,
                      focusNode: _focus,
                      cursorColor: _memorialGold,
                      cursorWidth: 1.4,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 600,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.45,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Taziye mesajınızı yazın...',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: _memorialMuted,
                          fontSize: 13,
                          height: 1.45,
                        ),
                        counterText: '',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(canSend: _canSend && !_sending, onTap: _send),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTypography.meta.copyWith(
                color: AppColors.actionRed,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuestField extends StatelessWidget {
  const _GuestField({
    required this.controller,
    required this.hint,
    required this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _memorialBorder.withValues(alpha: 0.72)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        cursorColor: _memorialGold,
        style: AppTypography.bodySmall.copyWith(
          color: Colors.white,
          fontSize: 12,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.bodySmall.copyWith(
            color: _memorialMuted,
            fontSize: 12,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 9),
        ),
      ),
    );
  }
}

class _ComposerAvatar extends StatelessWidget {
  const _ComposerAvatar({required this.authState});

  final FrontendAuthState? authState;

  @override
  Widget build(BuildContext context) {
    final initials = authState?.initials ?? 'M';
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _memorialGold.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: _memorialGold.withValues(alpha: 0.4)),
      ),
      child: Text(
        initials.characters.take(2).toString().toUpperCase(),
        style: AppTypography.titleS.copyWith(
          color: _memorialGold,
          fontSize: 12,
          fontWeight: FontWeight.w900,
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
    return Material(
      color: canSend ? _memorialGold : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: canSend ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(
            Symbols.send_rounded,
            size: 16,
            color: canSend ? _memorialBlack : _memorialMuted,
          ),
        ),
      ),
    );
  }
}

class _PendingCondolences extends StatelessWidget {
  const _PendingCondolences({required this.messages});

  final List<_CondolenceMessage> messages;

  @override
  Widget build(BuildContext context) {
    final visible = messages.take(2).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final message in visible) ...[
          _CondolenceTile(message: message),
          if (message != visible.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CondolenceTile extends StatelessWidget {
  const _CondolenceTile({required this.message});

  final _CondolenceMessage message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 25,
          height: 25,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _memorialGold.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            message.author.characters.first.toUpperCase(),
            style: AppTypography.meta.copyWith(
              color: _memorialGold,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: _memorialBorder.withValues(alpha: 0.72),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleS.copyWith(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      'Onay bekliyor',
                      style: AppTypography.meta.copyWith(
                        color: _memorialGold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  message.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: _memorialMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CondolenceMessage {
  const _CondolenceMessage({required this.author, required this.body});

  final String author;
  final String body;
}

String _timeLabel(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return '';
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
