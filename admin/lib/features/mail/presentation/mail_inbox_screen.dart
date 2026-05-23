import 'package:flutter/material.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import 'mail_inbox_models.dart';
import 'widgets/mail_inbox_table_card.dart';

class MailInboxScreen extends StatefulWidget {
  const MailInboxScreen({super.key});

  @override
  State<MailInboxScreen> createState() => _MailInboxScreenState();
}

class _MailInboxScreenState extends State<MailInboxScreen> {
  var _messages = List<AdminMailMessage>.of(sampleAdminMailMessages);
  final _selectedMessageIds = <int>{};
  var _quickFilter = mailQuickInbox;
  var _folderFilter = mailFilterAll;
  var _accountFilter = mailFilterAll;
  var _dateFilter = mailDateAll;
  var _searchQuery = '';
  var _page = 1;
  var _pageSize = 25;
  var _sortState = const TableSortState(key: 'date', ascending: false);

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
      mailQuickUnread => !message.read,
      mailQuickStarred => message.starred,
      mailQuickAttachments => message.hasAttachments || message.hasImages,
      mailQuickInvoice => message.labels.any(
        (label) => label.toLowerCase() == 'fatura',
      ),
      mailQuickSent => message.folder == mailFolderSent,
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

  void _markRead(AdminMailMessage message, bool read) {
    _updateMessage(message, message.copyWith(read: read));
  }

  void _toggleStar(AdminMailMessage message) {
    _updateMessage(message, message.copyWith(starred: !message.starred));
  }

  void _moveMessage(AdminMailMessage message, String folder) {
    _updateMessage(message, message.copyWith(folder: folder));
    _selectedMessageIds.remove(message.id);
  }

  Future<void> _deleteMessage(AdminMailMessage message) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('mail.deleteTitle'),
      message: context.t('mail.deleteMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed) return;
    setState(() {
      _messages = _messages
          .where((current) => current.id != message.id)
          .toList(growable: false);
      _selectedMessageIds.remove(message.id);
    });
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
    setState(() {
      _messages = _messages
          .where((message) => !_selectedMessageIds.contains(message.id))
          .toList(growable: false);
      _selectedMessageIds.clear();
    });
  }

  void _openMessage(AdminMailMessage message) {
    _markRead(message, true);
    showDialog<void>(
      context: context,
      builder: (context) =>
          _MailPreviewDialog(message: message.copyWith(read: true)),
    );
  }

  void _showComposeDrawer() {
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
                child: const _MailComposeDrawer(),
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
    setState(() {
      _selectedMessageIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
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
                onMarkRead: _markRead,
                onToggleStar: _toggleStar,
                onArchive: (message) =>
                    _moveMessage(message, mailFolderArchive),
                onMoveSpam: (message) => _moveMessage(message, mailFolderSpam),
                onMoveTrash: (message) =>
                    _moveMessage(message, mailFolderTrash),
                onRestoreInbox: (message) =>
                    _moveMessage(message, mailFolderInbox),
                onDelete: (message) => _deleteMessage(message),
                onDeleteSelected: () => _deleteSelectedMessages(),
                onRefresh: _refreshDesign,
                onCompose: _showComposeDrawer,
              ),
            ),
          ],
        );

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

class _MailPreviewDialog extends StatelessWidget {
  const _MailPreviewDialog({required this.message});

  final AdminMailMessage message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('mail.detailTitle'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.deepOcean,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    mouseCursor: SystemMouseCursors.click,
                    icon: const SymbolIcon(
                      Symbols.close,
                      color: AppColors.deepOcean,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MailDetailHeader(message: message),
                    const SizedBox(height: 20),
                    _MailDetailGrid(message: message),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.value),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text(
                        message.preview,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.deepOcean,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 22),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.softLine)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style:
                        TextButton.styleFrom(
                          foregroundColor: AppColors.deepOcean,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ).copyWith(
                          mouseCursor: const WidgetStatePropertyAll(
                            SystemMouseCursors.click,
                          ),
                        ),
                    child: Text(context.t('common.cancel')),
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

class _MailComposeDrawer extends StatelessWidget {
  const _MailComposeDrawer();

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
                      ? const SingleChildScrollView(
                          child: _MailComposeForm(mobile: true),
                        )
                      : const _MailComposeForm(mobile: false),
                ),
              ),
              const SizedBox(height: 16),
              _MailComposeActions(mobile: mobile),
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
  const _MailComposeForm({required this.mobile});

  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final accountField = _ComposeSelectField(
      label: 'mail.account',
      hint: 'mail.account',
      items: const ['Pateez Ana Mail', 'Teknik Mail', 'Iletisim Mail'],
    );
    final templateField = _ComposeSelectField(
      label: 'mail.compose.template',
      hint: 'mail.compose.template',
      items: const ['Standart Cevap', 'Haber Bilgilendirme', 'Bulten Taslagi'],
    );
    final recipientField = _ComposeTextField(
      label: 'mail.send.to',
      hint: 'mail.compose.recipientsHint',
      action: TextButton.icon(
        onPressed: () {},
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
    final subjectField = const _ComposeTextField(
      label: 'mail.subject',
      hint: 'mail.compose.subjectHint',
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
          const SizedBox(height: 350, child: _MailRichEditorPreview()),
          const SizedBox(height: 14),
          const _MailAttachmentPicker(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...formFields,
        const Expanded(child: _MailRichEditorPreview()),
        const SizedBox(height: 14),
        const _MailAttachmentPicker(),
      ],
    );
  }
}

class _ComposeSelectField extends StatelessWidget {
  const _ComposeSelectField({
    required this.label,
    required this.hint,
    required this.items,
  });

  final String label;
  final String hint;
  final List<String> items;

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
            value: null,
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
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (_) {},
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
    this.action,
  });

  final String label;
  final String hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _ComposeFieldShell(
      label: label,
      action: action,
      child: TextField(
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

class _MailRichEditorPreview extends StatelessWidget {
  const _MailRichEditorPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.82)),
      ),
      child: Column(
        children: [
          const _MailEditorToolbar(),
          Expanded(
            child: TextField(
              expands: true,
              maxLines: null,
              minLines: null,
              cursorColor: AppColors.support,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w500,
                height: 1.5,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: context.t('mail.compose.contentHint'),
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.placeholder,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                ),
                contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MailEditorToolbar extends StatelessWidget {
  const _MailEditorToolbar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.line.withValues(alpha: 0.82)),
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const _EditorSelectChip(label: 'Inter', width: 128),
          const _EditorSelectChip(label: '13', width: 74),
          const _ToolbarDivider(),
          _EditorTextTool(label: 'T', tooltip: 'mail.compose.heading'),
          _EditorTextTool(label: 'Tt', tooltip: 'mail.compose.fontSize'),
          const _ToolbarDivider(),
          _EditorTextTool(label: 'B', tooltip: 'mail.compose.bold'),
          _EditorTextTool(label: 'I', tooltip: 'mail.compose.italic'),
          _EditorTextTool(label: 'U', tooltip: 'mail.compose.underline'),
          _EditorTextTool(label: 'S', tooltip: 'mail.compose.strike'),
          const _ToolbarDivider(),
          _EditorIconTool(
            icon: Symbols.format_list_numbered,
            tooltip: 'mail.compose.list',
          ),
          _EditorIconTool(
            icon: Symbols.short_text,
            tooltip: 'mail.compose.align',
          ),
          _EditorIconTool(icon: Symbols.code, tooltip: 'mail.compose.code'),
          _EditorIconTool(icon: Symbols.undo, tooltip: 'mail.compose.undo'),
          _EditorIconTool(icon: Symbols.redo, tooltip: 'mail.compose.redo'),
          const _ToolbarDivider(),
          _EditorIconTool(
            icon: Symbols.open_in_new,
            tooltip: 'mail.compose.link',
          ),
          _EditorIconTool(icon: Symbols.photo_camera, tooltip: 'mail.image'),
        ],
      ),
    );
  }
}

class _EditorSelectChip extends StatelessWidget {
  const _EditorSelectChip({required this.label, required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.82)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          const SymbolIcon(
            Symbols.keyboard_arrow_down,
            color: AppColors.iconMuted,
            size: 17,
          ),
        ],
      ),
    );
  }
}

class _EditorTextTool extends StatelessWidget {
  const _EditorTextTool({required this.label, required this.tooltip});

  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.t(tooltip),
      child: _EditorToolSurface(
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _EditorIconTool extends StatelessWidget {
  const _EditorIconTool({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.t(tooltip),
      child: _EditorToolSurface(
        child: SymbolIcon(icon, color: AppColors.deepOcean, size: 18),
      ),
    );
  }
}

class _EditorToolSurface extends StatelessWidget {
  const _EditorToolSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.62)),
        ),
        child: child,
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.line.withValues(alpha: 0.82),
    );
  }
}

class _MailAttachmentPicker extends StatelessWidget {
  const _MailAttachmentPicker();

  @override
  Widget build(BuildContext context) {
    return Row(
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
        const SizedBox(width: 14),
        SizedBox(
          height: 34,
          child: TextButton(
            onPressed: () {},
            style:
                TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.deepOcean,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.value),
                    side: BorderSide(
                      color: AppColors.line.withValues(alpha: 0.82),
                    ),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SymbolIcon(Symbols.upload, size: 17),
                const SizedBox(width: 8),
                Text(context.t('mail.compose.addAttachment')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MailComposeActions extends StatelessWidget {
  const _MailComposeActions({required this.mobile});

  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final draft = _ComposeFooterButton(
      label: 'mail.compose.draftSave',
      icon: Symbols.draft,
      onPressed: () => Navigator.of(context).pop(),
    );
    final schedule = _ComposeFooterButton(
      label: 'mail.compose.schedule',
      icon: Symbols.schedule,
      onPressed: () => Navigator.of(context).pop(),
    );
    final send = _ComposeFooterButton(
      label: 'mail.compose.send',
      icon: Symbols.schedule_send,
      primary: true,
      onPressed: () => Navigator.of(context).pop(),
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
  final VoidCallback onPressed;
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
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
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
