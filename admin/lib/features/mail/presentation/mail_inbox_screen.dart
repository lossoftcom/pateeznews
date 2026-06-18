import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/admin_date_time_picker.dart';
import '../../../shared/widgets/admin_rich_text_editor.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../../news/presentation/widgets/article_text_block.dart'
    show ArticleRichTextEditor;
import '../data/admin_mail_repository.dart';
import 'contact_list_models.dart';
import 'mail_settings_models.dart';
import 'mail_template_models.dart';
import 'mail_inbox_models.dart';
import 'widgets/mail_html_view.dart';
import 'widgets/mail_inbox_table_card.dart';

const _mailMaxAttachmentCount = 10;
const _mailMaxAttachmentBytes = 10 * 1024 * 1024;
const _mailMaxAttachmentTotalBytes = 18 * 1024 * 1024;

class MailInboxScreen extends StatefulWidget {
  const MailInboxScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminMailRepository(),
  });

  final AdminSession session;
  final AdminMailRepository repository;

  @override
  State<MailInboxScreen> createState() => _MailInboxScreenState();
}

class _MailInboxScreenState extends State<MailInboxScreen> {
  var _messages = <AdminMailMessage>[];
  var _accounts = <AdminMailAccount>[];
  var _templates = <AdminMailTemplate>[];
  final _selectedMessageIds = <int>{};
  var _quickFilter = mailQuickInbox;
  var _folderFilter = mailFilterAll;
  var _accountFilter = mailFilterAll;
  var _dateFilter = mailDateAll;
  var _searchQuery = '';
  var _page = 1;
  var _pageSize = 25;
  var _sortState = const TableSortState(key: 'date', ascending: false);
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInbox());
  }

  Future<void> _loadInbox() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.repository.fetchInbox(widget.session),
        widget.repository.fetchAccounts(widget.session),
        widget.repository.fetchTemplates(widget.session),
      ]);
      if (!mounted) return;
      setState(() {
        _messages = results[0] as List<AdminMailMessage>;
        _accounts = results[1] as List<AdminMailAccount>;
        _templates = results[2] as List<AdminMailTemplate>;
        _loading = false;
        _resetListState();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMailError(error);
    }
  }

  void _showMailError(Object error) {
    AdminToast.show(
      context,
      message: error.toString(),
      tone: AdminToastTone.error,
    );
  }

  List<AdminMailMessage> get _filteredMessages {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _messages.where((message) {
      if (!_matchesQuickFilter(message)) return false;
      if (_folderFilter != mailFilterAll && message.folder != _folderFilter) {
        return false;
      }
      if (_accountFilter != mailFilterAll &&
          message.account != _accountFilter) {
        return false;
      }
      if (!_matchesDateFilter(message)) return false;
      if (query.isEmpty) return true;

      final searchable = [
        message.senderName,
        message.senderEmail,
        message.recipientEmail,
        message.subject,
        message.preview,
        message.account,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    filtered.sort((left, right) {
      final result = switch (_sortState.key) {
        'id' => left.id.compareTo(right.id),
        'sender' => left.senderName.compareTo(right.senderName),
        'subject' => left.subject.compareTo(right.subject),
        'account' => left.account.compareTo(right.account),
        'status' => left.read.toString().compareTo(right.read.toString()),
        'date' || _ => left.sentAt.compareTo(right.sentAt),
      };
      return _sortState.ascending ? result : -result;
    });

    return filtered;
  }

  List<AdminMailMessage> get _pagedMessages {
    final filtered = _filteredMessages;
    if (filtered.isEmpty) return const <AdminMailMessage>[];
    final start = (_page - 1) * _pageSize;
    if (start >= filtered.length) return filtered.take(_pageSize).toList();
    final end = start + _pageSize > filtered.length
        ? filtered.length
        : start + _pageSize;
    return filtered.sublist(start, end);
  }

  bool _matchesQuickFilter(AdminMailMessage message) {
    return switch (_quickFilter) {
      mailQuickAll => true,
      mailQuickInbox => message.folder == mailFolderInbox,
      mailQuickContact => mailMessageIsContact(message),
      mailQuickUnread => !message.read,
      mailQuickStarred => message.starred,
      mailQuickAttachments => message.hasAttachments || message.hasImages,
      mailQuickSent => message.isOutboxSource,
      mailQuickDraft => message.folder == mailFolderDraft,
      mailQuickScheduled => message.folder == mailFolderScheduled,
      mailQuickSpam => message.folder == mailFolderSpam,
      mailQuickTrash => message.folder == mailFolderTrash,
      _ => true,
    };
  }

  bool _matchesDateFilter(AdminMailMessage message) {
    if (_dateFilter == mailDateAll) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(
      message.sentAt.year,
      message.sentAt.month,
      message.sentAt.day,
    );
    return switch (_dateFilter) {
      mailDateToday => messageDay == today,
      mailDateSevenDays => message.sentAt.isAfter(
        today.subtract(const Duration(days: 7)),
      ),
      mailDateThirtyDays => message.sentAt.isAfter(
        today.subtract(const Duration(days: 30)),
      ),
      _ => true,
    };
  }

  void _resetListState() {
    _page = 1;
    _selectedMessageIds.clear();
  }

  void _changeQuickFilter(String value) {
    setState(() {
      _quickFilter = value;
      _resetListState();
    });
  }

  void _changeFolder(String? value) {
    if (value == null) return;
    setState(() {
      _folderFilter = value;
      _resetListState();
    });
  }

  void _changeAccount(String? value) {
    if (value == null) return;
    setState(() {
      _accountFilter = value;
      _resetListState();
    });
  }

  void _changeDate(String? value) {
    if (value == null) return;
    setState(() {
      _dateFilter = value;
      _resetListState();
    });
  }

  void _changePageSize(int? value) {
    if (value == null || value == _pageSize) return;
    setState(() {
      _pageSize = value;
      _resetListState();
    });
  }

  void _changeSearch(String value) {
    setState(() {
      _searchQuery = value;
      _resetListState();
    });
  }

  void _changePage(int value) {
    if (value == _page) return;
    setState(() {
      _page = value;
      _selectedMessageIds.clear();
    });
  }

  void _changeSort(String sortKey) {
    setState(() {
      _sortState = _sortState.toggled(sortKey);
      _resetListState();
    });
  }

  void _toggleMessage(int id) {
    setState(() {
      if (_selectedMessageIds.contains(id)) {
        _selectedMessageIds.remove(id);
      } else {
        _selectedMessageIds.add(id);
      }
    });
  }

  void _toggleAllMessages() {
    final pageIds = _pagedMessages.map((message) => message.id).toSet();
    setState(() {
      if (pageIds.isNotEmpty && _selectedMessageIds.containsAll(pageIds)) {
        _selectedMessageIds.removeAll(pageIds);
      } else {
        _selectedMessageIds
          ..clear()
          ..addAll(pageIds);
      }
    });
  }

  void _updateMessage(AdminMailMessage message, AdminMailMessage updated) {
    setState(() {
      _messages = [
        for (final current in _messages)
          if (current.id == message.id) updated else current,
      ];
    });
  }

  Future<void> _markRead(AdminMailMessage message, bool read) async {
    if (!message.isInboxSource) return;
    try {
      await widget.repository.updateInboxMessages(widget.session, [
        message.id,
      ], read ? 'read' : 'unread');
      if (mounted) _updateMessage(message, message.copyWith(read: read));
    } catch (error) {
      if (mounted) _showMailError(error);
    }
  }

  Future<void> _toggleStar(AdminMailMessage message) async {
    if (!message.isInboxSource) return;
    try {
      await widget.repository.updateInboxMessages(widget.session, [
        message.id,
      ], message.starred ? 'unstar' : 'star');
      if (mounted) {
        _updateMessage(message, message.copyWith(starred: !message.starred));
      }
    } catch (error) {
      if (mounted) _showMailError(error);
    }
  }

  Future<void> _moveMessage(AdminMailMessage message, String folder) async {
    if (!message.isInboxSource) return;
    try {
      await widget.repository.updateInboxMessages(widget.session, [
        message.id,
      ], folder);
      if (!mounted) return;
      _updateMessage(message, message.copyWith(folder: folder));
      _selectedMessageIds.remove(message.id);
    } catch (error) {
      if (mounted) _showMailError(error);
    }
  }

  Future<void> _deleteMessage(AdminMailMessage message) async {
    if (!message.isInboxSource) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('mail.deleteTitle'),
      message: context.t('mail.deleteMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed) return;
    try {
      await widget.repository.deleteInboxMessages(widget.session, [message.id]);
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .where((current) => current.id != message.id)
            .toList(growable: false);
        _selectedMessageIds.remove(message.id);
      });
    } catch (error) {
      if (mounted) _showMailError(error);
    }
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('mail.deleteSelectedTitle'),
      message: context.t(
        'mail.deleteSelectedMessage',
        values: {'count': _selectedMessageIds.length},
      ),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed) return;
    try {
      final ids = _selectedMessageIds.toList(growable: false);
      await widget.repository.deleteInboxMessages(widget.session, ids);
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .where((message) => !ids.contains(message.id))
            .toList(growable: false);
        _selectedMessageIds.clear();
      });
    } catch (error) {
      if (mounted) _showMailError(error);
    }
  }

  void _openMessage(AdminMailMessage message) {
    if (message.isInboxSource) unawaited(_markRead(message, true));
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('common.cancel'),
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final mobile = screenWidth < 700;
        final drawerWidth = mobile
            ? screenWidth
            : screenWidth <= 1120
            ? (screenWidth - 24).clamp(680.0, 860.0).toDouble()
            : 860.0;

        return SafeArea(
          child: Align(
            alignment: mobile ? Alignment.center : Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: drawerWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      spreadRadius: 2,
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: _MailPreviewDrawer(
                  message: message.isInboxSource
                      ? message.copyWith(read: true)
                      : message,
                  thread: _threadFor(message),
                  onReply:
                      message.isInboxSource &&
                          message.senderEmail.trim().isNotEmpty
                      ? () {
                          Navigator.of(context).pop();
                          _showComposeDrawer(
                            initial: _MailComposeInitialData.reply(message),
                          );
                        }
                      : null,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  List<AdminMailMessage> _threadFor(AdminMailMessage message) {
    final subject = _normalizedThreadSubject(message.subject);
    if (subject.isEmpty) return <AdminMailMessage>[message];
    final parties = {
      message.senderEmail.trim().toLowerCase(),
      message.recipientEmail.trim().toLowerCase(),
    }..remove('');
    final thread = _messages.where((candidate) {
      if (_normalizedThreadSubject(candidate.subject) != subject) return false;
      if (candidate.id == message.id) return true;
      final candidateParties = {
        candidate.senderEmail.trim().toLowerCase(),
        candidate.recipientEmail.trim().toLowerCase(),
      }..remove('');
      return candidateParties.any(parties.contains);
    }).toList()..sort((left, right) => left.sentAt.compareTo(right.sentAt));
    return thread.isEmpty ? <AdminMailMessage>[message] : thread;
  }

  String _normalizedThreadSubject(String subject) {
    var value = subject.trim().toLowerCase();
    var changed = true;
    while (changed) {
      final next = value.replaceFirst(
        RegExp(r'^(re|fw|fwd)\s*:\s*', caseSensitive: false),
        '',
      );
      changed = next != value;
      value = next.trim();
    }
    return value;
  }

  void _showComposeDrawer({_MailComposeInitialData? initial}) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('common.cancel'),
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final mobile = screenWidth < 700;
        final drawerWidth = mobile
            ? screenWidth
            : screenWidth <= 1120
            ? (screenWidth - 24).clamp(740.0, 900.0).toDouble()
            : 900.0;

        return SafeArea(
          child: Align(
            alignment: mobile ? Alignment.center : Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: drawerWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      spreadRadius: 2,
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: _MailComposeDrawer(
                  session: widget.session,
                  repository: widget.repository,
                  accounts: _accounts,
                  templates: _templates,
                  initial: initial,
                  onSaved: _loadInbox,
                  onError: _showMailError,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  void _refreshDesign() {
    unawaited(_loadInbox());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final mobile = constraints.maxWidth < 800;
        final compact = constraints.maxWidth < 900;
        final filtered = _filteredMessages;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MailTitle(),
            const SizedBox(height: 24),
            Expanded(
              child: MailInboxTableCard(
                allMessages: _messages,
                messages: _pagedMessages,
                page: _page,
                pageSize: _pageSize,
                totalCount: filtered.length,
                searchQuery: _searchQuery,
                quickFilter: _quickFilter,
                folderFilter: _folderFilter,
                accountFilter: _accountFilter,
                dateFilter: _dateFilter,
                selectedMessageIds: _selectedMessageIds,
                sortState: _sortState,
                onQuickFilterChanged: _changeQuickFilter,
                onFolderChanged: _changeFolder,
                onAccountChanged: _changeAccount,
                onDateChanged: _changeDate,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onPageChanged: _changePage,
                onToggleMessage: _toggleMessage,
                onToggleAllMessages: _toggleAllMessages,
                onSort: _changeSort,
                onOpenMessage: _openMessage,
                onMarkRead: (message, read) =>
                    unawaited(_markRead(message, read)),
                onToggleStar: (message) => unawaited(_toggleStar(message)),
                onArchive: (message) =>
                    unawaited(_moveMessage(message, mailFolderArchive)),
                onMoveSpam: (message) =>
                    unawaited(_moveMessage(message, mailFolderSpam)),
                onMoveTrash: (message) =>
                    unawaited(_moveMessage(message, mailFolderTrash)),
                onRestoreInbox: (message) =>
                    unawaited(_moveMessage(message, mailFolderInbox)),
                onDelete: (message) => _deleteMessage(message),
                onDeleteSelected: () => _deleteSelectedMessages(),
                onRefresh: _refreshDesign,
                onCompose: _showComposeDrawer,
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
          ],
        );

        if (mobile) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              18,
              horizontalPadding,
              28,
            ),
            child: content,
          );
        }

        if (compact) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              28,
              horizontalPadding,
              28,
            ),
            child: SizedBox(height: 1160, child: content),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            28,
            horizontalPadding,
            28,
          ),
          child: content,
        );
      },
    );
  }
}

class _MailTitle extends StatelessWidget {
  const _MailTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t('mail.inbox.title'),
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _MailPreviewDrawer extends StatelessWidget {
  const _MailPreviewDrawer({
    required this.message,
    required this.thread,
    this.onReply,
  });

  final AdminMailMessage message;
  final List<AdminMailMessage> thread;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;
        return Padding(
          padding: EdgeInsets.all(mobile ? 14 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(0, mobile ? 2 : 8, 0, 10),
                child: Row(
                  children: [
                    const SymbolIcon(
                      Symbols.draft,
                      color: AppColors.deepOcean,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.t('mail.detailTitle'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.deepOcean,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      mouseCursor: SystemMouseCursors.click,
                      tooltip: context.t('common.cancel'),
                      icon: const SymbolIcon(
                        Symbols.close,
                        color: AppColors.deepOcean,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    mobile ? 14 : 20,
                    mobile ? 14 : 18,
                    mobile ? 14 : 20,
                    mobile ? 14 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.value),
                    border: Border.all(
                      color: AppColors.line.withValues(alpha: 0.82),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MailDetailHeader(message: message),
                      SizedBox(height: mobile ? 14 : 16),
                      _MailDetailGrid(message: message),
                      SizedBox(height: mobile ? 14 : 16),
                      Expanded(
                        child: thread.length > 1
                            ? _MailThreadPreview(
                                message: message,
                                thread: thread,
                              )
                            : _MailConversationItem(
                                message: message,
                                active: true,
                                expandHtml: true,
                              ),
                      ),
                      if (message.attachments.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _MailAttachmentSummary(
                          attachments: message.attachments,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _MailPreviewActions(mobile: mobile, onReply: onReply),
            ],
          ),
        );
      },
    );
  }
}

class _MailPreviewActions extends StatelessWidget {
  const _MailPreviewActions({required this.mobile, this.onReply});

  final bool mobile;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final close = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      style:
          TextButton.styleFrom(
            foregroundColor: AppColors.deepOcean,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ).copyWith(
            mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
          ),
      child: Text(context.t('common.cancel')),
    );

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onReply != null) ...[
            _ComposeFooterButton(
              label: 'mail.action.reply',
              icon: Symbols.reply_rounded,
              onPressed: onReply,
            ),
            const SizedBox(height: 10),
          ],
          close,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onReply != null) ...[
          _ComposeFooterButton(
            label: 'mail.action.reply',
            icon: Symbols.reply_rounded,
            onPressed: onReply,
          ),
          const SizedBox(width: 12),
        ],
        close,
      ],
    );
  }
}

class _MailThreadPreview extends StatelessWidget {
  const _MailThreadPreview({required this.message, required this.thread});

  final AdminMailMessage message;
  final List<AdminMailMessage> thread;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t('mail.detail.conversation'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in thread)
          if (item.id == message.id)
            Expanded(
              child: _MailConversationItem(
                message: item,
                active: true,
                expandHtml: true,
              ),
            )
          else ...[
            _MailConversationItem(message: item, active: false),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _MailConversationItem extends StatelessWidget {
  const _MailConversationItem({
    required this.message,
    required this.active,
    this.expandHtml = false,
  });

  final AdminMailMessage message;
  final bool active;
  final bool expandHtml;

  @override
  Widget build(BuildContext context) {
    final sender = message.isOutboxSource
        ? context.t('mail.status.sent')
        : message.senderName;
    final mailBody = MailHtmlView(
      key: ValueKey('${message.id}-${message.contentHtml.hashCode}'),
      html: message.contentHtml,
      fallbackText: message.preview,
      height: expandHtml ? null : 360,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: active ? AppColors.line : AppColors.softLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sender,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${formatAdminFullDate(context, message.sentAt)} ${formatAdminTime(message.sentAt)}',
                style: const TextStyle(
                  color: AppColors.support,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (active && expandHtml)
            Expanded(child: mailBody)
          else if (active)
            mailBody
          else
            Text(
              message.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.deepOcean,
                height: 1.45,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }
}

class _MailAttachmentSummary extends StatelessWidget {
  const _MailAttachmentSummary({required this.attachments});

  final List<AdminMailAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final attachment in attachments)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.deepOcean.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.softLine),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SymbolIcon(
                  attachment.isImage ? Symbols.image_outlined : Symbols.draft,
                  size: 16,
                  color: AppColors.deepOcean,
                ),
                const SizedBox(width: 7),
                Text(
                  '${attachment.filename} · ${_formatAttachmentSize(attachment.size)}',
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MailComposeInitialData {
  const _MailComposeInitialData({this.recipients = '', this.subject = ''});

  factory _MailComposeInitialData.reply(AdminMailMessage message) {
    final subject = message.subject.trim();
    return _MailComposeInitialData(
      recipients: message.senderEmail,
      subject: subject.toLowerCase().startsWith('re:')
          ? subject
          : 'Re: $subject',
    );
  }

  final String recipients;
  final String subject;
}

class _MailComposeAttachment {
  const _MailComposeAttachment({
    required this.filename,
    required this.contentType,
    required this.size,
    required this.contentBase64,
  });

  final String filename;
  final String contentType;
  final int size;
  final String contentBase64;

  bool get isImage => contentType.toLowerCase().startsWith('image/');

  AdminMailComposeAttachmentPayload toPayload() {
    return AdminMailComposeAttachmentPayload(
      filename: filename,
      contentType: contentType,
      size: size,
      contentBase64: contentBase64,
    );
  }
}

String _formatAttachmentSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
}

String _guessMimeType(String filename) {
  final name = filename.toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  if (name.endsWith('.gif')) return 'image/gif';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.svg')) return 'image/svg+xml';
  if (name.endsWith('.pdf')) return 'application/pdf';
  if (name.endsWith('.txt')) return 'text/plain';
  if (name.endsWith('.csv')) return 'text/csv';
  if (name.endsWith('.doc')) return 'application/msword';
  if (name.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (name.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (name.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (name.endsWith('.zip')) return 'application/zip';
  return 'application/octet-stream';
}

class _MailDetailHeader extends StatelessWidget {
  const _MailDetailHeader({required this.message});

  final AdminMailMessage message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.deepOcean.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.support.withValues(alpha: 0.42),
            ),
          ),
          child: Center(
            child: Text(
              message.senderName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${message.senderName} <${message.senderEmail}>',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MailDetailGrid extends StatelessWidget {
  const _MailDetailGrid({required this.message});

  final AdminMailMessage message;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MailDetailItem(label: 'mail.sender', value: message.senderEmail),
        _MailDetailItem(label: 'mail.recipient', value: message.recipientEmail),
        _MailDetailItem(label: 'mail.account', value: message.account),
        _MailDetailItem(
          label: 'Date',
          value:
              '${formatAdminFullDate(context, message.sentAt)} ${formatAdminTime(message.sentAt)}',
        ),
      ],
    );
  }
}

class _MailDetailItem extends StatelessWidget {
  const _MailDetailItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(label),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MailComposeDrawer extends StatefulWidget {
  const _MailComposeDrawer({
    required this.session,
    required this.repository,
    required this.accounts,
    required this.templates,
    this.initial,
    required this.onSaved,
    required this.onError,
  });

  final AdminSession session;
  final AdminMailRepository repository;
  final List<AdminMailAccount> accounts;
  final List<AdminMailTemplate> templates;
  final _MailComposeInitialData? initial;
  final Future<void> Function() onSaved;
  final ValueChanged<Object> onError;

  @override
  State<_MailComposeDrawer> createState() => _MailComposeDrawerState();
}

class _MailComposeDrawerState extends State<_MailComposeDrawer> {
  late final TextEditingController _recipientsController;
  late final TextEditingController _subjectController;
  late quill.QuillController _editorController;
  String? _accountValue;
  String? _templateValue;
  final _attachments = <_MailComposeAttachment>[];
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _recipientsController = TextEditingController(
      text: initial?.recipients ?? '',
    );
    _subjectController = TextEditingController(text: initial?.subject ?? '');
    _editorController = quill.QuillController(
      document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _accountValue = widget.accounts.firstOrNull?.id.toString();
    _templateValue = null;
  }

  @override
  void dispose() {
    _recipientsController.dispose();
    _subjectController.dispose();
    _editorController.dispose();
    super.dispose();
  }

  Future<void> _submit({bool draft = false, DateTime? scheduledAt}) async {
    if (_saving) return;
    final recipients = _recipientsController.text.trim();
    final subject = _subjectController.text.trim();
    final selectedTemplate = _selectedTemplate();
    final content = _composeContentHtml(selectedTemplate).trim();
    if (recipients.isEmpty || subject.isEmpty || content.isEmpty) {
      widget.onError(
        const AdminMailException('Alıcı, konu ve içerik zorunludur'),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.sendMail(
        widget.session,
        AdminMailComposePayload(
          accountId: int.tryParse(_accountValue ?? ''),
          templateId: selectedTemplate?.id,
          recipients: recipients,
          subject: subject,
          content: content,
          attachments: _attachments
              .map((attachment) => attachment.toPayload())
              .toList(growable: false),
          draft: draft,
          scheduledAt: scheduledAt,
        ),
      );
      await widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      widget.onError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  AdminMailTemplate? _selectedTemplate() {
    final id = int.tryParse(_templateValue ?? '');
    if (id == null) return null;
    for (final template in widget.templates) {
      if (template.id == id) return template;
    }
    return null;
  }

  String _composeContentHtml(AdminMailTemplate? selectedTemplate) {
    if (selectedTemplate != null) return selectedTemplate.body;
    return adminQuillHtml(_editorController);
  }

  void _selectTemplate(String? value) {
    final id = int.tryParse(value ?? '');
    AdminMailTemplate? template;
    if (id != null) {
      for (final item in widget.templates) {
        if (item.id == id) {
          template = item;
          break;
        }
      }
    }
    setState(() {
      _templateValue = template?.id.toString();
      if (template != null) {
        _subjectController.text = template.subject;
      }
    });
  }

  Future<void> _schedule() async {
    final scheduledAt = await showAdminDateTimePicker(
      context,
      initialValue: DateTime.now().add(const Duration(hours: 1)),
    );
    if (scheduledAt == null || !mounted) return;
    await _submit(scheduledAt: scheduledAt);
  }

  Future<void> _pickAttachments({required bool imagesOnly}) async {
    try {
      final files = await openFiles(
        acceptedTypeGroups: imagesOnly
            ? const [
                XTypeGroup(label: 'Görseller', mimeTypes: ['image/*']),
              ]
            : const [XTypeGroup(label: 'Dosyalar')],
      );
      if (files.isEmpty) return;
      for (final file in files) {
        if (_attachments.length >= _mailMaxAttachmentCount) {
          throw const AdminMailException('En fazla 10 ek eklenebilir');
        }
        final size = await file.length();
        if (size > _mailMaxAttachmentBytes) {
          throw AdminMailException(
            '${file.name} tek dosya sınırını aşıyor (${_formatAttachmentSize(_mailMaxAttachmentBytes)})',
          );
        }
        final total =
            _attachments.fold<int>(
              0,
              (sum, attachment) => sum + attachment.size,
            ) +
            size;
        if (total > _mailMaxAttachmentTotalBytes) {
          throw AdminMailException(
            'Toplam ek sınırı aşılıyor (${_formatAttachmentSize(_mailMaxAttachmentTotalBytes)})',
          );
        }
        final bytes = await file.readAsBytes();
        final contentType = file.mimeType ?? _guessMimeType(file.name);
        setState(() {
          _attachments.add(
            _MailComposeAttachment(
              filename: file.name,
              contentType: contentType,
              size: bytes.length,
              contentBase64: base64Encode(bytes),
            ),
          );
        });
      }
    } catch (error) {
      if (mounted) widget.onError(error);
    }
  }

  void _removeAttachment(_MailComposeAttachment attachment) {
    setState(() => _attachments.remove(attachment));
  }

  Future<void> _pickContacts() async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => _MailContactPickerDialog(
        session: widget.session,
        repository: widget.repository,
      ),
    );
    if (selected == null || selected.isEmpty) return;
    final current = _recipientsController.text
        .split(RegExp(r'[,;\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    current.addAll(selected);
    _recipientsController.text = current.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;
        final selectedTemplate = _selectedTemplate();
        return Padding(
          padding: EdgeInsets.all(mobile ? 14 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MailComposeHeader(mobile: mobile),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    mobile ? 14 : 20,
                    mobile ? 14 : 18,
                    mobile ? 14 : 20,
                    mobile ? 14 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.value),
                    border: Border.all(
                      color: AppColors.line.withValues(alpha: 0.82),
                    ),
                  ),
                  child: mobile
                      ? SingleChildScrollView(
                          child: _MailComposeForm(
                            mobile: true,
                            accounts: widget.accounts,
                            templates: widget.templates,
                            selectedAccount: _accountValue,
                            selectedTemplate: _templateValue,
                            selectedTemplateModel: selectedTemplate,
                            recipientsController: _recipientsController,
                            subjectController: _subjectController,
                            editorController: _editorController,
                            editorKey: const ValueKey('mail-compose-content'),
                            attachments: _attachments,
                            onAccountChanged: (value) =>
                                setState(() => _accountValue = value),
                            onTemplateChanged: _selectTemplate,
                            onAddFiles: () =>
                                unawaited(_pickAttachments(imagesOnly: false)),
                            onAddImages: () =>
                                unawaited(_pickAttachments(imagesOnly: true)),
                            onRemoveAttachment: _removeAttachment,
                            onPickContacts: () => unawaited(_pickContacts()),
                          ),
                        )
                      : _MailComposeForm(
                          mobile: false,
                          accounts: widget.accounts,
                          templates: widget.templates,
                          selectedAccount: _accountValue,
                          selectedTemplate: _templateValue,
                          selectedTemplateModel: selectedTemplate,
                          recipientsController: _recipientsController,
                          subjectController: _subjectController,
                          editorController: _editorController,
                          editorKey: const ValueKey('mail-compose-content'),
                          attachments: _attachments,
                          onAccountChanged: (value) =>
                              setState(() => _accountValue = value),
                          onTemplateChanged: _selectTemplate,
                          onAddFiles: () =>
                              unawaited(_pickAttachments(imagesOnly: false)),
                          onAddImages: () =>
                              unawaited(_pickAttachments(imagesOnly: true)),
                          onRemoveAttachment: _removeAttachment,
                          onPickContacts: () => unawaited(_pickContacts()),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              _MailComposeActions(
                mobile: mobile,
                saving: _saving,
                onDraft: () => unawaited(_submit(draft: true)),
                onSchedule: () => unawaited(_schedule()),
                onSend: () => unawaited(_submit()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MailComposeHeader extends StatelessWidget {
  const _MailComposeHeader({required this.mobile});

  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final aiButton = TextButton.icon(
      onPressed: () {},
      style:
          TextButton.styleFrom(
            foregroundColor: AppColors.deepOcean,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ).copyWith(
            mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
          ),
      icon: const SymbolIcon(Symbols.edit_square, size: 18),
      label: Text(context.t('mail.compose.aiWrite')),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.t('mail.compose.sendTitle'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (!mobile) aiButton,
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              mouseCursor: SystemMouseCursors.click,
              tooltip: context.t('common.cancel'),
              icon: const SymbolIcon(
                Symbols.close,
                color: AppColors.deepOcean,
                size: 22,
              ),
            ),
          ],
        ),
        if (mobile) ...[const SizedBox(height: 8), aiButton],
      ],
    );
  }
}

class _MailComposeForm extends StatelessWidget {
  const _MailComposeForm({
    required this.mobile,
    required this.accounts,
    required this.templates,
    required this.selectedAccount,
    required this.selectedTemplate,
    required this.selectedTemplateModel,
    required this.recipientsController,
    required this.subjectController,
    required this.editorController,
    required this.editorKey,
    required this.attachments,
    required this.onAccountChanged,
    required this.onTemplateChanged,
    required this.onAddFiles,
    required this.onAddImages,
    required this.onRemoveAttachment,
    required this.onPickContacts,
  });

  final bool mobile;
  final List<AdminMailAccount> accounts;
  final List<AdminMailTemplate> templates;
  final String? selectedAccount;
  final String? selectedTemplate;
  final AdminMailTemplate? selectedTemplateModel;
  final TextEditingController recipientsController;
  final TextEditingController subjectController;
  final quill.QuillController editorController;
  final Key editorKey;
  final List<_MailComposeAttachment> attachments;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<String?> onTemplateChanged;
  final VoidCallback onAddFiles;
  final VoidCallback onAddImages;
  final ValueChanged<_MailComposeAttachment> onRemoveAttachment;
  final VoidCallback onPickContacts;

  @override
  Widget build(BuildContext context) {
    final accountField = _ComposeSelectField(
      label: 'mail.account',
      hint: 'mail.account',
      value: selectedAccount,
      items: [
        for (final account in accounts)
          _ComposeOption(account.id.toString(), account.accountName),
      ],
      onChanged: onAccountChanged,
    );
    final templateField = _ComposeSelectField(
      label: 'mail.compose.template',
      hint: 'mail.compose.template',
      value: selectedTemplate,
      items: [
        for (final template in templates)
          _ComposeOption(template.id.toString(), template.nameKey),
      ],
      onChanged: onTemplateChanged,
    );
    final recipientField = _ComposeTextField(
      label: 'mail.send.to',
      hint: 'mail.compose.recipientsHint',
      controller: recipientsController,
      action: TextButton.icon(
        onPressed: onPickContacts,
        style:
            TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.deepOcean,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        icon: const SymbolIcon(Symbols.add, size: 18),
        label: Text(context.t('mail.compose.addContact')),
      ),
    );
    final subjectField = _ComposeTextField(
      label: 'mail.subject',
      hint: 'mail.compose.subjectHint',
      controller: subjectController,
    );

    final formFields = <Widget>[
      if (mobile)
        Column(
          children: [accountField, const SizedBox(height: 12), templateField],
        )
      else
        Row(
          children: [
            Expanded(child: accountField),
            const SizedBox(width: 14),
            Expanded(child: templateField),
          ],
        ),
      const SizedBox(height: 12),
      if (mobile)
        Column(
          children: [recipientField, const SizedBox(height: 12), subjectField],
        )
      else
        Row(
          children: [
            Expanded(flex: 3, child: recipientField),
            const SizedBox(width: 14),
            Expanded(flex: 2, child: subjectField),
          ],
        ),
      const SizedBox(height: 12),
      Text(
        context.t('mail.compose.content'),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.deepOcean,
          letterSpacing: 0,
        ),
      ),
      const SizedBox(height: 6),
    ];

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...formFields,
          SizedBox(
            height: 430,
            child: _MailComposeContentArea(
              key: editorKey,
              selectedTemplate: selectedTemplateModel,
              editorController: editorController,
              minHeight: 360,
            ),
          ),
          const SizedBox(height: 14),
          _MailAttachmentPicker(
            attachments: attachments,
            onAddFiles: onAddFiles,
            onAddImages: onAddImages,
            onRemoveAttachment: onRemoveAttachment,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...formFields,
        Expanded(
          child: SingleChildScrollView(
            child: _MailComposeContentArea(
              key: editorKey,
              selectedTemplate: selectedTemplateModel,
              editorController: editorController,
              minHeight: 430,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _MailAttachmentPicker(
          attachments: attachments,
          onAddFiles: onAddFiles,
          onAddImages: onAddImages,
          onRemoveAttachment: onRemoveAttachment,
        ),
      ],
    );
  }
}

class _MailComposeContentArea extends StatelessWidget {
  const _MailComposeContentArea({
    super.key,
    required this.selectedTemplate,
    required this.editorController,
    required this.minHeight,
  });

  final AdminMailTemplate? selectedTemplate;
  final quill.QuillController editorController;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final template = selectedTemplate;
    if (template == null) {
      return ArticleRichTextEditor(
        controller: editorController,
        placeholder: 'mail.compose.contentHint',
        minHeight: minHeight,
      );
    }

    return MailHtmlView(
      key: ValueKey(
        'compose-template-${template.id}-${template.updatedAt.toIso8601String()}',
      ),
      html: template.body,
      fallbackText: template.previewText.isNotEmpty
          ? template.previewText
          : template.subject,
      height: minHeight,
    );
  }
}

class _ComposeOption {
  const _ComposeOption(this.value, this.label);

  final String value;
  final String label;
}

class _ComposeSelectField extends StatelessWidget {
  const _ComposeSelectField({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final String? value;
  final List<_ComposeOption> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ComposeFieldShell(
      label: label,
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.82)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: items.any((item) => item.value == value) ? value : null,
            hint: Text(context.t(hint)),
            borderRadius: BorderRadius.circular(AppRadius.value),
            dropdownColor: Colors.white,
            focusColor: Colors.transparent,
            mouseCursor: SystemMouseCursors.click,
            dropdownMenuItemMouseCursor: SystemMouseCursors.click,
            icon: const SymbolIcon(
              Symbols.keyboard_arrow_down,
              color: AppColors.iconMuted,
              size: 18,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            items: [
              for (final item in items)
                DropdownMenuItem(value: item.value, child: Text(item.label)),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _ComposeTextField extends StatelessWidget {
  const _ComposeTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.action,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _ComposeFieldShell(
      label: label,
      action: action,
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 2,
        cursorColor: AppColors.support,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        decoration: _composeInputDecoration(context, hint: hint),
      ),
    );
  }
}

class _ComposeFieldShell extends StatelessWidget {
  const _ComposeFieldShell({
    required this.label,
    required this.child,
    this.action,
  });

  final String label;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            children: [
              Text(
                context.t(label),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepOcean,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              if (action case final Widget currentAction) currentAction,
            ],
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

InputDecoration _composeInputDecoration(BuildContext context, {String? hint}) {
  return InputDecoration(
    hintText: hint == null ? null : context.t(hint),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.placeholder,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: BorderSide(color: AppColors.line.withValues(alpha: 0.82)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: AppColors.support, width: 1.4),
    ),
  );
}

class _MailAttachmentPicker extends StatelessWidget {
  const _MailAttachmentPicker({
    required this.attachments,
    required this.onAddFiles,
    required this.onAddImages,
    required this.onRemoveAttachment,
  });

  final List<_MailComposeAttachment> attachments;
  final VoidCallback onAddFiles;
  final VoidCallback onAddImages;
  final ValueChanged<_MailComposeAttachment> onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    final totalSize = attachments.fold<int>(
      0,
      (sum, attachment) => sum + attachment.size,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.t('mail.compose.attachments'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepOcean,
                  letterSpacing: 0,
                ),
              ),
              _AttachmentActionButton(
                icon: Symbols.upload,
                label: 'mail.compose.addAttachment',
                onPressed: onAddFiles,
              ),
              _AttachmentActionButton(
                icon: Symbols.image_outlined,
                label: 'mail.compose.addImage',
                onPressed: onAddImages,
              ),
              Text(
                '${_formatAttachmentSize(totalSize)} / ${_formatAttachmentSize(_mailMaxAttachmentTotalBytes)}',
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final attachment in attachments)
                  _AttachmentChip(
                    attachment: attachment,
                    onRemove: () => onRemoveAttachment(attachment),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            context.t(
              'mail.compose.attachmentLimits',
              values: {
                'file': _formatAttachmentSize(_mailMaxAttachmentBytes),
                'total': _formatAttachmentSize(_mailMaxAttachmentTotalBytes),
              },
            ),
            style: const TextStyle(
              color: AppColors.support,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentActionButton extends StatelessWidget {
  const _AttachmentActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextButton.icon(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.deepOcean,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                side: BorderSide(color: AppColors.line.withValues(alpha: 0.82)),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        icon: SymbolIcon(icon, size: 17),
        label: Text(context.t(label)),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment, required this.onRemove});

  final _MailComposeAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.82)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SymbolIcon(
            attachment.isImage ? Symbols.image_outlined : Symbols.draft,
            size: 16,
            color: AppColors.deepOcean,
          ),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              '${attachment.filename} · ${_formatAttachmentSize(attachment.size)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: context.t('mail.compose.removeAttachment'),
            icon: const SymbolIcon(
              Symbols.close,
              size: 15,
              color: AppColors.support,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _MailContactPickerDialog extends StatefulWidget {
  const _MailContactPickerDialog({
    required this.session,
    required this.repository,
  });

  final AdminSession session;
  final AdminMailRepository repository;

  @override
  State<_MailContactPickerDialog> createState() =>
      _MailContactPickerDialogState();
}

class _MailContactPickerDialogState extends State<_MailContactPickerDialog> {
  final _searchController = TextEditingController();
  var _lists = <AdminContactList>[];
  var _contacts = <AdminMailContact>[];
  final _selected = <String>{};
  int? _selectedListId;
  var _loading = true;

  List<AdminMailContact> get _filteredContacts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _contacts;
    return _contacts
        .where((contact) {
          return [
            contact.email,
            contact.firstName,
            contact.lastName,
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    unawaited(_loadLists());
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLists() async {
    try {
      final lists = await widget.repository.fetchContactLists(widget.session);
      if (!mounted) return;
      setState(() {
        _lists = lists;
        _selectedListId = lists.firstOrNull?.id;
      });
      if (_selectedListId != null) {
        await _loadContacts(_selectedListId!);
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadContacts(int listId) async {
    setState(() {
      _loading = true;
      _selectedListId = listId;
    });
    try {
      final contacts = await widget.repository.fetchContacts(
        widget.session,
        listId,
        limit: 500,
      );
      if (!mounted) return;
      setState(() {
        _contacts = contacts.where((contact) => contact.active).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _contacts = const <AdminMailContact>[];
          _loading = false;
        });
      }
    }
  }

  void _toggle(String email) {
    setState(() {
      if (_selected.contains(email)) {
        _selected.remove(email);
      } else {
        _selected.add(email);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('mail.compose.contactPickerTitle'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const SymbolIcon(
                      Symbols.close,
                      color: AppColors.deepOcean,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.softLine),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 230,
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        for (final list in _lists)
                          _ContactListButton(
                            list: list,
                            selected: list.id == _selectedListId,
                            onTap: () => unawaited(_loadContacts(list.id)),
                          ),
                      ],
                    ),
                  ),
                  Container(width: 1, color: AppColors.softLine),
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextField(
                            controller: _searchController,
                            decoration: _composeInputDecoration(
                              context,
                              hint: 'mail.inbox.searchPlaceholder',
                            ),
                          ),
                        ),
                        Expanded(
                          child: _loading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.deepOcean,
                                  ),
                                )
                              : ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    12,
                                  ),
                                  children: [
                                    for (final contact in _filteredContacts)
                                      CheckboxListTile(
                                        value: _selected.contains(
                                          contact.email,
                                        ),
                                        onChanged: (_) =>
                                            _toggle(contact.email),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        contentPadding: EdgeInsets.zero,
                                        activeColor: AppColors.deepOcean,
                                        title: Text(
                                          [contact.firstName, contact.lastName]
                                                  .where(
                                                    (item) =>
                                                        item.trim().isNotEmpty,
                                                  )
                                                  .join(' ')
                                                  .trim()
                                                  .isEmpty
                                              ? contact.email
                                              : [
                                                  contact.firstName,
                                                  contact.lastName,
                                                ].join(' '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(contact.email),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.softLine)),
              ),
              child: Row(
                children: [
                  Text(
                    context.t(
                      'mail.compose.selectedContacts',
                      values: {'count': _selected.length},
                    ),
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.t('common.cancel')),
                  ),
                  const SizedBox(width: 10),
                  _ComposeFooterButton(
                    label: 'mail.compose.addSelectedContacts',
                    icon: Symbols.add,
                    primary: true,
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pop(_selected.toList(growable: false)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactListButton extends StatelessWidget {
  const _ContactListButton({
    required this.list,
    required this.selected,
    required this.onTap,
  });

  final AdminContactList list;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.value),
          mouseCursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(
                color: selected ? AppColors.line : AppColors.softLine,
              ),
            ),
            child: Row(
              children: [
                const SymbolIcon(
                  Symbols.groups_outlined,
                  size: 18,
                  color: AppColors.deepOcean,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  list.contactCount.toString(),
                  style: const TextStyle(
                    color: AppColors.support,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MailComposeActions extends StatelessWidget {
  const _MailComposeActions({
    required this.mobile,
    required this.saving,
    required this.onDraft,
    required this.onSchedule,
    required this.onSend,
  });

  final bool mobile;
  final bool saving;
  final VoidCallback onDraft;
  final VoidCallback onSchedule;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final draft = _ComposeFooterButton(
      label: 'mail.compose.draftSave',
      icon: Symbols.draft,
      onPressed: saving ? null : onDraft,
    );
    final schedule = _ComposeFooterButton(
      label: 'mail.compose.schedule',
      icon: Symbols.schedule,
      onPressed: saving ? null : onSchedule,
    );
    final send = _ComposeFooterButton(
      label: 'mail.compose.send',
      icon: Symbols.schedule_send,
      primary: true,
      onPressed: saving ? null : onSend,
    );

    if (mobile) {
      return Row(
        children: [
          Expanded(child: draft),
          const SizedBox(width: 8),
          Expanded(child: schedule),
          const SizedBox(width: 8),
          Expanded(child: send),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        draft,
        const SizedBox(width: 12),
        schedule,
        const SizedBox(width: 12),
        send,
      ],
    );
  }
}

class _ComposeFooterButton extends StatelessWidget {
  const _ComposeFooterButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: primary ? AppColors.actionRed : Colors.white,
              foregroundColor: primary ? Colors.white : AppColors.deepOcean,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                side: primary
                    ? BorderSide.none
                    : BorderSide(color: AppColors.line.withValues(alpha: 0.82)),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: WidgetStatePropertyAll(
                onPressed == null
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SymbolIcon(icon, size: 18, color: primary ? Colors.white : null),
            const SizedBox(width: 8),
            Flexible(child: Text(context.t(label))),
          ],
        ),
      ),
    );
  }
}
