import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_table_chrome.dart';

import '../../../../core/localization/admin_date_formatter.dart';
import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/admin_mobile_list.dart';
import '../../../../shared/widgets/sortable_table_header.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import '../mail_inbox_models.dart';

const mailFilterAll = '__all';
const mailQuickAll = 'all';
const mailQuickInbox = 'inbox';
const mailQuickUnread = 'unread';
const mailQuickStarred = 'starred';
const mailQuickAttachments = 'attachments';
const mailQuickInvoice = 'invoice';
const mailQuickSent = 'sent';
const mailQuickSpam = 'spam';
const mailQuickTrash = 'trash';
const mailDateAll = 'all';
const mailDateToday = 'today';
const mailDateSevenDays = 'seven_days';
const mailDateThirtyDays = 'thirty_days';

class MailInboxTableCard extends StatelessWidget {
  const MailInboxTableCard({
    super.key,
    required this.allMessages,
    required this.messages,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchQuery,
    required this.quickFilter,
    required this.folderFilter,
    required this.accountFilter,
    required this.dateFilter,
    required this.selectedMessageIds,
    required this.sortState,
    required this.onQuickFilterChanged,
    required this.onFolderChanged,
    required this.onAccountChanged,
    required this.onDateChanged,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onToggleMessage,
    required this.onToggleAllMessages,
    required this.onSort,
    required this.onOpenMessage,
    required this.onMarkRead,
    required this.onToggleStar,
    required this.onArchive,
    required this.onMoveSpam,
    required this.onMoveTrash,
    required this.onRestoreInbox,
    required this.onDelete,
    required this.onDeleteSelected,
    required this.onRefresh,
    required this.onCompose,
  });

  final List<AdminMailMessage> allMessages;
  final List<AdminMailMessage> messages;
  final int page;
  final int pageSize;
  final int totalCount;
  final String searchQuery;
  final String quickFilter;
  final String folderFilter;
  final String accountFilter;
  final String dateFilter;
  final Set<int> selectedMessageIds;
  final TableSortState sortState;
  final ValueChanged<String> onQuickFilterChanged;
  final ValueChanged<String?> onFolderChanged;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<String?> onDateChanged;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onToggleMessage;
  final VoidCallback onToggleAllMessages;
  final ValueChanged<String> onSort;
  final ValueChanged<AdminMailMessage> onOpenMessage;
  final void Function(AdminMailMessage message, bool read) onMarkRead;
  final ValueChanged<AdminMailMessage> onToggleStar;
  final ValueChanged<AdminMailMessage> onArchive;
  final ValueChanged<AdminMailMessage> onMoveSpam;
  final ValueChanged<AdminMailMessage> onMoveTrash;
  final ValueChanged<AdminMailMessage> onRestoreInbox;
  final ValueChanged<AdminMailMessage> onDelete;
  final VoidCallback onDeleteSelected;
  final VoidCallback onRefresh;
  final VoidCallback onCompose;

  static const double toolbarHeight = 38;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AdminMobile.breakpoint) {
          return _MailInboxMobileView(
            allMessages: allMessages,
            messages: messages,
            page: page,
            pageSize: pageSize,
            totalCount: totalCount,
            searchQuery: searchQuery,
            quickFilter: quickFilter,
            folderFilter: folderFilter,
            accountFilter: accountFilter,
            dateFilter: dateFilter,
            selectedMessageIds: selectedMessageIds,
            onQuickFilterChanged: onQuickFilterChanged,
            onFolderChanged: onFolderChanged,
            onAccountChanged: onAccountChanged,
            onDateChanged: onDateChanged,
            onPageSizeChanged: onPageSizeChanged,
            onSearchChanged: onSearchChanged,
            onPageChanged: onPageChanged,
            onToggleMessage: onToggleMessage,
            onOpenMessage: onOpenMessage,
            onMarkRead: onMarkRead,
            onToggleStar: onToggleStar,
            onArchive: onArchive,
            onMoveSpam: onMoveSpam,
            onMoveTrash: onMoveTrash,
            onRestoreInbox: onRestoreInbox,
            onDelete: onDelete,
            onDeleteSelected: onDeleteSelected,
            onRefresh: onRefresh,
            onCompose: onCompose,
          );
        }
        final sideNavigation = constraints.maxWidth >= 980;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MailMetricGrid(messages: allMessages),
            const SizedBox(height: 20),
            _MailFilters(
              messages: allMessages,
              folderFilter: folderFilter,
              accountFilter: accountFilter,
              dateFilter: dateFilter,
              onFolderChanged: onFolderChanged,
              onAccountChanged: onAccountChanged,
              onDateChanged: onDateChanged,
            ),
            const SizedBox(height: 18),
            _MailToolbar(
              pageSize: pageSize,
              searchQuery: searchQuery,
              selectedCount: selectedMessageIds.length,
              onPageSizeChanged: onPageSizeChanged,
              onSearchChanged: onSearchChanged,
              onDeleteSelected: onDeleteSelected,
              onRefresh: onRefresh,
              onCompose: onCompose,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _MailDataTable(
                messages: messages,
                selectedMessageIds: selectedMessageIds,
                sortState: sortState,
                onToggleMessage: onToggleMessage,
                onToggleAllMessages: onToggleAllMessages,
                onSort: onSort,
                onOpenMessage: onOpenMessage,
                onMarkRead: onMarkRead,
                onToggleStar: onToggleStar,
                onArchive: onArchive,
                onMoveSpam: onMoveSpam,
                onMoveTrash: onMoveTrash,
                onRestoreInbox: onRestoreInbox,
                onDelete: onDelete,
              ),
            ),
            const SizedBox(height: 16),
            _MailFooter(
              page: page,
              pageSize: pageSize,
              totalCount: totalCount,
              onPageChanged: onPageChanged,
            ),
          ],
        );

        if (sideNavigation) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 204,
                child: MailFolderPanel(
                  messages: allMessages,
                  selectedFilter: quickFilter,
                  onChanged: onQuickFilterChanged,
                  vertical: true,
                ),
              ),
              const SizedBox(width: 22),
              Expanded(child: content),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MailFolderPanel(
              messages: allMessages,
              selectedFilter: quickFilter,
              onChanged: onQuickFilterChanged,
            ),
            const SizedBox(height: 18),
            _MailMetricGrid(messages: allMessages),
            const SizedBox(height: 20),
            _MailFilters(
              messages: allMessages,
              folderFilter: folderFilter,
              accountFilter: accountFilter,
              dateFilter: dateFilter,
              onFolderChanged: onFolderChanged,
              onAccountChanged: onAccountChanged,
              onDateChanged: onDateChanged,
            ),
            const SizedBox(height: 18),
            _MailToolbar(
              pageSize: pageSize,
              searchQuery: searchQuery,
              selectedCount: selectedMessageIds.length,
              onPageSizeChanged: onPageSizeChanged,
              onSearchChanged: onSearchChanged,
              onDeleteSelected: onDeleteSelected,
              onRefresh: onRefresh,
              onCompose: onCompose,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _MailDataTable(
                messages: messages,
                selectedMessageIds: selectedMessageIds,
                sortState: sortState,
                onToggleMessage: onToggleMessage,
                onToggleAllMessages: onToggleAllMessages,
                onSort: onSort,
                onOpenMessage: onOpenMessage,
                onMarkRead: onMarkRead,
                onToggleStar: onToggleStar,
                onArchive: onArchive,
                onMoveSpam: onMoveSpam,
                onMoveTrash: onMoveTrash,
                onRestoreInbox: onRestoreInbox,
                onDelete: onDelete,
              ),
            ),
            const SizedBox(height: 16),
            _MailFooter(
              page: page,
              pageSize: pageSize,
              totalCount: totalCount,
              onPageChanged: onPageChanged,
            ),
          ],
        );
      },
    );
  }
}

class MailFolderPanel extends StatelessWidget {
  const MailFolderPanel({
    super.key,
    required this.messages,
    required this.selectedFilter,
    required this.onChanged,
    this.vertical = false,
  });

  final List<AdminMailMessage> messages;
  final String selectedFilter;
  final ValueChanged<String> onChanged;
  final bool vertical;

  int _countFor(String value) {
    return switch (value) {
      mailQuickAll => messages.length,
      mailQuickInbox =>
        messages.where((message) => message.folder == mailFolderInbox).length,
      mailQuickUnread => messages.where((message) => !message.read).length,
      mailQuickStarred => messages.where((message) => message.starred).length,
      mailQuickAttachments =>
        messages
            .where((message) => message.hasAttachments || message.hasImages)
            .length,
      mailQuickInvoice =>
        messages
            .where(
              (message) => message.labels.any(
                (label) => label.toLowerCase() == 'fatura',
              ),
            )
            .length,
      mailQuickSent =>
        messages.where((message) => message.folder == mailFolderSent).length,
      mailQuickSpam =>
        messages.where((message) => message.folder == mailFolderSpam).length,
      mailQuickTrash =>
        messages.where((message) => message.folder == mailFolderTrash).length,
      _ => 0,
    };
  }

  int _sideCountFor(String value) {
    return switch (value) {
      mailQuickUnread ||
      mailQuickStarred ||
      mailQuickSent ||
      mailQuickSpam ||
      mailQuickTrash => _countFor(value),
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _MailFolderItemData(
        value: mailQuickAll,
        label: 'All',
        icon: Symbols.draft,
        color: AppColors.deepOcean,
      ),
      _MailFolderItemData(
        value: mailQuickInbox,
        label: 'nav.mail.inbox',
        icon: Symbols.alternate_email,
        color: AppColors.deepOcean,
      ),
      _MailFolderItemData(
        value: mailQuickUnread,
        label: 'mail.stats.unread',
        icon: Symbols.visibility_off,
        color: AppColors.warmHorizon,
      ),
      _MailFolderItemData(
        value: mailQuickStarred,
        label: 'mail.filter.starred',
        icon: Symbols.verified,
        color: AppColors.warmHorizon,
      ),
      _MailFolderItemData(
        value: mailQuickAttachments,
        label: 'mail.filter.attachments',
        icon: Symbols.draft,
        color: const Color(0xFF198754),
      ),
      _MailFolderItemData(
        value: mailQuickInvoice,
        label: 'mail.filter.invoice',
        icon: Symbols.article,
        color: AppColors.inkSoft,
      ),
      _MailFolderItemData(
        value: mailQuickSent,
        label: 'mail.outbox.title',
        icon: Symbols.schedule_send,
        color: const Color(0xFF3B82F6),
      ),
      _MailFolderItemData(
        value: mailQuickSpam,
        label: 'mail.folder.spam',
        icon: Symbols.visibility_off,
        color: AppColors.warmHorizon,
      ),
      _MailFolderItemData(
        value: mailQuickTrash,
        label: 'mail.folder.trash',
        icon: Symbols.delete,
        color: AppColors.actionRed,
      ),
    ];

    final children = [
      for (final item in items)
        _MailFolderButton(
          data: item,
          count: vertical ? _sideCountFor(item.value) : _countFor(item.value),
          selected: selectedFilter == item.value,
          vertical: vertical,
          onTap: () => onChanged(item.value),
        ),
    ];

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }
}

class _MailFolderItemData {
  const _MailFolderItemData({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

class _MailFolderButton extends StatelessWidget {
  const _MailFolderButton({
    required this.data,
    required this.count,
    required this.selected,
    required this.vertical,
    required this.onTap,
  });

  final _MailFolderItemData data;
  final int count;
  final bool selected;
  final bool vertical;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.deepOcean : AppColors.inkSoft;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: vertical ? 40 : 38,
          margin: EdgeInsets.only(
            right: vertical ? 0 : 8,
            bottom: vertical ? 6 : 0,
          ),
          padding: EdgeInsets.symmetric(horizontal: vertical ? 16 : 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.surface
                : vertical
                ? Colors.transparent
                : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected
                  ? AppColors.line
                  : vertical
                  ? Colors.transparent
                  : AppColors.softLine.withValues(alpha: 0.84),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SymbolIcon(
                data.icon,
                size: 18,
                color: selected ? color : data.color,
              ),
              const SizedBox(width: 8),
              if (vertical)
                Expanded(
                  child: Text(
                    context.t(data.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                )
              else
                Text(
                  context.t(data.label),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.deepOcean
                        : data.color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: selected ? Colors.white : data.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
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

class _MailMetricGrid extends StatelessWidget {
  const _MailMetricGrid({required this.messages});

  final List<AdminMailMessage> messages;

  @override
  Widget build(BuildContext context) {
    final unread = messages.where((message) => !message.read).length;
    final archived = messages
        .where((message) => message.folder == mailFolderArchive)
        .length;
    final attachments = messages
        .where((message) => message.hasAttachments || message.hasImages)
        .length;

    final items = [
      _MailMetricData(
        label: 'mail.stats.total_mail',
        value: messages.length.toString(),
        icon: Symbols.alternate_email,
        color: AppColors.deepOcean,
      ),
      _MailMetricData(
        label: 'mail.stats.unread',
        value: unread.toString(),
        icon: Symbols.visibility_off,
        color: AppColors.warmHorizon,
      ),
      _MailMetricData(
        label: 'mail.stats.archive',
        value: archived.toString(),
        icon: Symbols.folder_open,
        color: const Color(0xFF3B82F6),
      ),
      _MailMetricData(
        label: 'mail.stats.with_attachments',
        value: attachments.toString(),
        icon: Symbols.draft,
        color: const Color(0xFF198754),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 840;
        if (compact) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in items)
                SizedBox(
                  width: constraints.maxWidth < 540
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2,
                  child: _MailMetricBox(data: item),
                ),
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Expanded(child: _MailMetricBox(data: items[index])),
              if (index != items.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _MailMetricData {
  const _MailMetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MailMetricBox extends StatelessWidget {
  const _MailMetricBox({required this.data});

  final _MailMetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: Center(
              child: SymbolIcon(data.icon, color: data.color, size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(data.label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
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

class _MailFilters extends StatelessWidget {
  const _MailFilters({
    required this.messages,
    required this.folderFilter,
    required this.accountFilter,
    required this.dateFilter,
    required this.onFolderChanged,
    required this.onAccountChanged,
    required this.onDateChanged,
  });

  final List<AdminMailMessage> messages;
  final String folderFilter;
  final String accountFilter;
  final String dateFilter;
  final ValueChanged<String?> onFolderChanged;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<String?> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final accounts = messages.map((message) => message.account).toSet().toList()
      ..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        final filters = [
          _FilterSelect(
            label: 'mail.folder',
            value: folderFilter,
            items: [
              DropdownMenuItem(
                value: mailFilterAll,
                child: Text(context.t('All')),
              ),
              DropdownMenuItem(
                value: mailFolderInbox,
                child: Text(context.t('mail.folder.inbox')),
              ),
              DropdownMenuItem(
                value: mailFolderArchive,
                child: Text(context.t('mail.folder.archive')),
              ),
              DropdownMenuItem(
                value: mailFolderSent,
                child: Text(context.t('mail.folder.sent')),
              ),
              DropdownMenuItem(
                value: mailFolderSpam,
                child: Text(context.t('mail.folder.spam')),
              ),
              DropdownMenuItem(
                value: mailFolderTrash,
                child: Text(context.t('mail.folder.trash')),
              ),
            ],
            onChanged: onFolderChanged,
          ),
          _FilterSelect(
            label: 'mail.account',
            value: accountFilter,
            items: [
              DropdownMenuItem(
                value: mailFilterAll,
                child: Text(context.t('All')),
              ),
              for (final account in accounts)
                DropdownMenuItem(value: account, child: Text(account)),
            ],
            onChanged: onAccountChanged,
          ),
          _FilterSelect(
            label: 'mail.dateRange',
            value: dateFilter,
            items: [
              DropdownMenuItem(
                value: mailDateAll,
                child: Text(context.t('All')),
              ),
              DropdownMenuItem(
                value: mailDateToday,
                child: Text(context.t('mail.date.today')),
              ),
              DropdownMenuItem(
                value: mailDateSevenDays,
                child: Text(context.t('mail.date.last7')),
              ),
              DropdownMenuItem(
                value: mailDateThirtyDays,
                child: Text(context.t('mail.date.last30')),
              ),
            ],
            onChanged: onDateChanged,
          ),
        ];

        if (compact) {
          return Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              for (final filter in filters)
                SizedBox(
                  width: constraints.maxWidth < 560
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 16) / 2,
                  child: filter,
                ),
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < filters.length; index++) ...[
              Expanded(child: filters[index]),
              if (index != filters.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

class _FilterSelect extends StatelessWidget {
  const _FilterSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.any((item) => item.value == value)
        ? value
        : (items.isEmpty ? null : items.first.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(label),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: MailInboxTableCard.toolbarHeight,
            padding: const EdgeInsets.only(left: 12, right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: safeValue,
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
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MailToolbar extends StatelessWidget {
  const _MailToolbar({
    required this.pageSize,
    required this.searchQuery,
    required this.selectedCount,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onDeleteSelected,
    required this.onRefresh,
    required this.onCompose,
  });

  final int pageSize;
  final String searchQuery;
  final int selectedCount;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onDeleteSelected;
  final VoidCallback onRefresh;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        final pageSizeSelect = _PageSizeSelect(
          value: pageSize,
          onChanged: onPageSizeChanged,
        );
        final search = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: compact ? double.infinity : 260,
            maxWidth: compact ? double.infinity : 300,
          ),
          child: _MailSearchField(
            value: searchQuery,
            onChanged: onSearchChanged,
          ),
        );
        final deleteButton = selectedCount == 0
            ? null
            : _BulkDeleteButton(
                selectedCount: selectedCount,
                onPressed: onDeleteSelected,
              );
        final refreshButton = _SoftActionButton(
          label: 'mail.action.refresh',
          icon: Symbols.download,
          onPressed: onRefresh,
        );
        final composeButton = _PrimaryActionButton(
          label: 'mail.action.compose',
          icon: Symbols.add,
          onPressed: onCompose,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: pageSizeSelect),
              if (deleteButton != null) ...[
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: deleteButton),
              ],
              const SizedBox(height: 14),
              search,
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [refreshButton, composeButton],
              ),
            ],
          );
        }

        return Row(
          children: [
            pageSizeSelect,
            if (deleteButton != null) ...[
              const SizedBox(width: 12),
              deleteButton,
            ],
            const Spacer(),
            search,
            const SizedBox(width: 12),
            refreshButton,
            const SizedBox(width: 10),
            composeButton,
          ],
        );
      },
    );
  }
}

class _PageSizeSelect extends StatelessWidget {
  const _PageSizeSelect({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminTablePageSizeSelect(value: value, onChanged: onChanged);
  }
}

class _MailSearchField extends StatefulWidget {
  const _MailSearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_MailSearchField> createState() => _MailSearchFieldState();
}

class _MailSearchFieldState extends State<_MailSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _MailSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MailInboxTableCard.toolbarHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: TextField(
        controller: _controller,
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        textAlignVertical: TextAlignVertical.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: context.t('mail.inbox.searchPlaceholder'),
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.placeholder,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12, right: 9),
            child: SymbolIcon(
              Symbols.search,
              color: AppColors.iconMuted,
              size: 18,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 39,
            minHeight: MailInboxTableCard.toolbarHeight,
          ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _SoftActionButton extends StatelessWidget {
  const _SoftActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MailInboxTableCard.toolbarHeight,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.deepOcean,
              minimumSize: const Size(0, MailInboxTableCard.toolbarHeight),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                side: BorderSide(color: AppColors.line.withValues(alpha: 0.78)),
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
            SymbolIcon(icon, color: AppColors.deepOcean, size: 17),
            const SizedBox(width: 7),
            Text(context.t(label)),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MailInboxTableCard.toolbarHeight,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, MailInboxTableCard.toolbarHeight),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
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
            SymbolIcon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 7),
            Text(context.t(label)),
          ],
        ),
      ),
    );
  }
}

class _BulkDeleteButton extends StatelessWidget {
  const _BulkDeleteButton({
    required this.selectedCount,
    required this.onPressed,
  });

  final int selectedCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 34),
              maximumSize: const Size(double.infinity, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
            const SymbolIcon(Symbols.delete, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              context.t(
                'mail.selectedDelete',
                values: {'count': selectedCount},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MailDataTable extends StatelessWidget {
  const _MailDataTable({
    required this.messages,
    required this.selectedMessageIds,
    required this.sortState,
    required this.onToggleMessage,
    required this.onToggleAllMessages,
    required this.onSort,
    required this.onOpenMessage,
    required this.onMarkRead,
    required this.onToggleStar,
    required this.onArchive,
    required this.onMoveSpam,
    required this.onMoveTrash,
    required this.onRestoreInbox,
    required this.onDelete,
  });

  final List<AdminMailMessage> messages;
  final Set<int> selectedMessageIds;
  final TableSortState sortState;
  final ValueChanged<int> onToggleMessage;
  final VoidCallback onToggleAllMessages;
  final ValueChanged<String> onSort;
  final ValueChanged<AdminMailMessage> onOpenMessage;
  final void Function(AdminMailMessage message, bool read) onMarkRead;
  final ValueChanged<AdminMailMessage> onToggleStar;
  final ValueChanged<AdminMailMessage> onArchive;
  final ValueChanged<AdminMailMessage> onMoveSpam;
  final ValueChanged<AdminMailMessage> onMoveTrash;
  final ValueChanged<AdminMailMessage> onRestoreInbox;
  final ValueChanged<AdminMailMessage> onDelete;

  static const double _selectWidth = 42;
  static const double _idWidth = 58;
  static const double _senderWidth = 160;
  static const double _subjectMinWidth = 240;
  static const double _attachmentWidth = 60;
  static const double _accountWidth = 120;
  static const double _dateWidth = 140;
  static const double _statusWidth = 82;
  static const double _menuWidth = 76;
  static const double _horizontalPadding = 32;
  static const double _tableBorderWidth = 2;
  static const double _minWidth =
      _horizontalPadding +
      _tableBorderWidth +
      _selectWidth +
      _idWidth +
      _senderWidth +
      _subjectMinWidth +
      _attachmentWidth +
      _accountWidth +
      _dateWidth +
      _statusWidth +
      _menuWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < _minWidth
            ? _minWidth
            : constraints.maxWidth;
        final fixedWidth =
            _horizontalPadding +
            _tableBorderWidth +
            _selectWidth +
            _idWidth +
            _senderWidth +
            _attachmentWidth +
            _accountWidth +
            _dateWidth +
            _statusWidth +
            _menuWidth;
        final subjectWidth = (tableWidth - fixedWidth) < _subjectMinWidth
            ? _subjectMinWidth
            : tableWidth - fixedWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(
                  color: AppColors.line.withValues(alpha: 0.72),
                ),
              ),
              child: Column(
                children: [
                  _MailHeader(
                    selectedCount: selectedMessageIds.length,
                    totalCount: messages.length,
                    subjectWidth: subjectWidth,
                    sortState: sortState,
                    onToggleAllMessages: onToggleAllMessages,
                    onSort: onSort,
                  ),
                  Expanded(
                    child: messages.isEmpty
                        ? const _MailEmpty()
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final message in messages)
                                  _MailRow(
                                    message: message,
                                    subjectWidth: subjectWidth,
                                    selected: selectedMessageIds.contains(
                                      message.id,
                                    ),
                                    onToggle: () => onToggleMessage(message.id),
                                    onOpenMessage: onOpenMessage,
                                    onMarkRead: onMarkRead,
                                    onToggleStar: onToggleStar,
                                    onArchive: onArchive,
                                    onMoveSpam: onMoveSpam,
                                    onMoveTrash: onMoveTrash,
                                    onRestoreInbox: onRestoreInbox,
                                    onDelete: onDelete,
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MailHeader extends StatelessWidget {
  const _MailHeader({
    required this.selectedCount,
    required this.totalCount,
    required this.subjectWidth,
    required this.sortState,
    required this.onToggleAllMessages,
    required this.onSort,
  });

  final int selectedCount;
  final int totalCount;
  final double subjectWidth;
  final TableSortState sortState;
  final VoidCallback onToggleAllMessages;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _MailDataTable._selectWidth,
            child: _MailCheckbox(
              value: selectedCount == 0 || totalCount == 0
                  ? false
                  : selectedCount == totalCount
                  ? true
                  : null,
              tristate: true,
              onChanged: (_) => onToggleAllMessages(),
            ),
          ),
          _SortableColumnHeader(
            width: _MailDataTable._idWidth,
            label: 'ID',
            sortKey: 'id',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: _MailDataTable._senderWidth,
            label: 'mail.sender',
            sortKey: 'sender',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: subjectWidth,
            label: 'mail.subject',
            sortKey: 'subject',
            sortState: sortState,
            onSort: onSort,
          ),
          const SizedBox(
            width: _MailDataTable._attachmentWidth,
            child: _HeaderText('mail.attachments', centered: true),
          ),
          _SortableColumnHeader(
            width: _MailDataTable._accountWidth,
            label: 'mail.account',
            sortKey: 'account',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: _MailDataTable._dateWidth,
            label: 'Date',
            sortKey: 'date',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: _MailDataTable._statusWidth,
            label: 'Status',
            sortKey: 'status',
            sortState: sortState,
            onSort: onSort,
          ),
          const SizedBox(
            width: _MailDataTable._menuWidth,
            child: _HeaderText('Action', centered: true),
          ),
        ],
      ),
    );
  }
}

class _SortableColumnHeader extends StatelessWidget {
  const _SortableColumnHeader({
    required this.width,
    required this.label,
    required this.sortKey,
    required this.sortState,
    required this.onSort,
  });

  final double width;
  final String label;
  final String sortKey;
  final TableSortState sortState;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: SortableTableHeader(
        label: label,
        sortKey: sortKey,
        sortState: sortState,
        onSort: onSort,
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.label, {this.centered = false});

  final String label;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      child: Text(
        context.t(label),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MailRow extends StatelessWidget {
  const _MailRow({
    required this.message,
    required this.subjectWidth,
    required this.selected,
    required this.onToggle,
    required this.onOpenMessage,
    required this.onMarkRead,
    required this.onToggleStar,
    required this.onArchive,
    required this.onMoveSpam,
    required this.onMoveTrash,
    required this.onRestoreInbox,
    required this.onDelete,
  });

  final AdminMailMessage message;
  final double subjectWidth;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<AdminMailMessage> onOpenMessage;
  final void Function(AdminMailMessage message, bool read) onMarkRead;
  final ValueChanged<AdminMailMessage> onToggleStar;
  final ValueChanged<AdminMailMessage> onArchive;
  final ValueChanged<AdminMailMessage> onMoveSpam;
  final ValueChanged<AdminMailMessage> onMoveTrash;
  final ValueChanged<AdminMailMessage> onRestoreInbox;
  final ValueChanged<AdminMailMessage> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selected ? AppColors.surface : Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _MailDataTable._selectWidth,
            child: _MailCheckbox(value: selected, onChanged: (_) => onToggle()),
          ),
          SizedBox(
            width: _MailDataTable._idWidth,
            child: _RowSelectTapTarget(
              onTap: onToggle,
              child: Text(
                message.id.toString(),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(
            width: _MailDataTable._senderWidth,
            child: _RowSelectTapTarget(
              onTap: () => onOpenMessage(message),
              child: _SenderCell(message: message),
            ),
          ),
          SizedBox(
            width: subjectWidth,
            child: _RowSelectTapTarget(
              onTap: () => onOpenMessage(message),
              child: _SubjectCell(message: message),
            ),
          ),
          SizedBox(
            width: _MailDataTable._attachmentWidth,
            child: _AttachmentCell(message: message),
          ),
          SizedBox(
            width: _MailDataTable._accountWidth,
            child: _TextCell(value: message.account),
          ),
          SizedBox(
            width: _MailDataTable._dateWidth,
            child: _MailDateCell(dateTime: message.sentAt),
          ),
          SizedBox(
            width: _MailDataTable._statusWidth,
            child: _MailStatusBadge(message: message),
          ),
          SizedBox(
            width: _MailDataTable._menuWidth,
            child: Align(
              alignment: Alignment.center,
              child: _MailRowMenu(
                message: message,
                onOpen: () => onOpenMessage(message),
                onMarkRead: () => onMarkRead(message, true),
                onMarkUnread: () => onMarkRead(message, false),
                onToggleStar: () => onToggleStar(message),
                onArchive: () => onArchive(message),
                onMoveSpam: () => onMoveSpam(message),
                onMoveTrash: () => onMoveTrash(message),
                onRestoreInbox: () => onRestoreInbox(message),
                onDelete: () => onDelete(message),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MailCheckbox extends StatelessWidget {
  const _MailCheckbox({
    required this.value,
    required this.onChanged,
    this.tristate = false,
  });

  final bool? value;
  final ValueChanged<bool?> onChanged;
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      tristate: tristate,
      mouseCursor: SystemMouseCursors.click,
      activeColor: AppColors.deepOcean,
      checkColor: Colors.white,
      side: BorderSide(color: AppColors.line.withValues(alpha: 0.76)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      onChanged: onChanged,
    );
  }
}

class _RowSelectTapTarget extends StatelessWidget {
  const _RowSelectTapTarget({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _SenderCell extends StatelessWidget {
  const _SenderCell({required this.message});

  final AdminMailMessage message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MailAvatar(label: message.senderName, unread: !message.read),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      message.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 12,
                        fontWeight: message.read
                            ? FontWeight.w600
                            : FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (message.starred)
                    const SymbolIcon(
                      Symbols.verified,
                      color: AppColors.warmHorizon,
                      size: 15,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                message.senderEmail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.support,
                  fontSize: 10,
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

class _MailAvatar extends StatelessWidget {
  const _MailAvatar({required this.label, required this.unread});

  final String label;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: unread
            ? AppColors.deepOcean.withValues(alpha: 0.1)
            : AppColors.support.withValues(alpha: 0.13),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.support.withValues(alpha: 0.42)),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: unread ? AppColors.deepOcean : AppColors.inkSoft,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _SubjectCell extends StatelessWidget {
  const _SubjectCell({required this.message});

  final AdminMailMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.deepOcean,
              fontSize: 12,
              fontWeight: message.read ? FontWeight.w600 : FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message.preview,
            softWrap: true,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentCell extends StatelessWidget {
  const _AttachmentCell({required this.message});

  final AdminMailMessage message;

  @override
  Widget build(BuildContext context) {
    if (!message.hasAttachments && !message.hasImages) {
      return const Center(
        child: Text(
          '-',
          style: TextStyle(
            color: AppColors.support,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.hasAttachments)
            _MiniBadge(label: context.t('mail.attachment')),
          if (message.hasImages) ...[
            const SizedBox(height: 4),
            _MiniBadge(label: context.t('mail.image')),
          ],
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.support.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.inkSoft,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}

class _MailDateCell extends StatelessWidget {
  const _MailDateCell({required this.dateTime});

  final DateTime dateTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatAdminFullDate(context, dateTime),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w500,
            fontSize: 11,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatAdminTime(dateTime),
          style: const TextStyle(
            color: AppColors.support,
            fontWeight: FontWeight.w400,
            fontSize: 10,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _MailStatusBadge extends StatelessWidget {
  const _MailStatusBadge({required this.message});

  final AdminMailMessage message;

  @override
  Widget build(BuildContext context) {
    final sent = message.folder == mailFolderSent;
    final active = !message.read || sent;
    final label = sent
        ? 'mail.status.sent'
        : message.read
        ? 'mail.status.read'
        : 'mail.status.unread';
    final textColor = active ? const Color(0xFF198754) : AppColors.inkSoft;
    final dotColor = active ? const Color(0xFF198754) : AppColors.support;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFE6F4EA)
              : AppColors.support.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                context.t(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MailRowMenu extends StatefulWidget {
  const _MailRowMenu({
    required this.message,
    required this.onOpen,
    required this.onMarkRead,
    required this.onMarkUnread,
    required this.onToggleStar,
    required this.onArchive,
    required this.onMoveSpam,
    required this.onMoveTrash,
    required this.onRestoreInbox,
    required this.onDelete,
  });

  final AdminMailMessage message;
  final VoidCallback onOpen;
  final VoidCallback onMarkRead;
  final VoidCallback onMarkUnread;
  final VoidCallback onToggleStar;
  final VoidCallback onArchive;
  final VoidCallback onMoveSpam;
  final VoidCallback onMoveTrash;
  final VoidCallback onRestoreInbox;
  final VoidCallback onDelete;

  @override
  State<_MailRowMenu> createState() => _MailRowMenuState();
}

class _MailRowMenuState extends State<_MailRowMenu> {
  final _layerLink = LayerLink();
  OverlayEntry? _menuEntry;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _openMenu() {
    if (_menuEntry != null) return;

    _menuEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeMenu,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: _MailMenuCard(
                message: widget.message,
                onOpen: () => _runAndClose(widget.onOpen),
                onMarkRead: () => _runAndClose(widget.onMarkRead),
                onMarkUnread: () => _runAndClose(widget.onMarkUnread),
                onToggleStar: () => _runAndClose(widget.onToggleStar),
                onArchive: () => _runAndClose(widget.onArchive),
                onMoveSpam: () => _runAndClose(widget.onMoveSpam),
                onMoveTrash: () => _runAndClose(widget.onMoveTrash),
                onRestoreInbox: () => _runAndClose(widget.onRestoreInbox),
                onDelete: () => _runAndClose(widget.onDelete),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_menuEntry!);
  }

  void _runAndClose(VoidCallback action) {
    _closeMenu();
    action();
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _toggleMenu() {
    if (_menuEntry == null) {
      _openMenu();
    } else {
      _closeMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: context.t('mail.actions'),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleMenu,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                '...',
                style: TextStyle(
                  color: AppColors.support.withValues(alpha: 0.92),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MailMenuCard extends StatelessWidget {
  const _MailMenuCard({
    required this.message,
    required this.onOpen,
    required this.onMarkRead,
    required this.onMarkUnread,
    required this.onToggleStar,
    required this.onArchive,
    required this.onMoveSpam,
    required this.onMoveTrash,
    required this.onRestoreInbox,
    required this.onDelete,
  });

  final AdminMailMessage message;
  final VoidCallback onOpen;
  final VoidCallback onMarkRead;
  final VoidCallback onMarkUnread;
  final VoidCallback onToggleStar;
  final VoidCallback onArchive;
  final VoidCallback onMoveSpam;
  final VoidCallback onMoveTrash;
  final VoidCallback onRestoreInbox;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final inTrash = message.folder == mailFolderTrash;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 224,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MailMenuItem(
              icon: Symbols.visibility,
              label: 'mail.action.open',
              onTap: onOpen,
            ),
            if (!inTrash)
              _MailMenuItem(
                icon: message.read ? Symbols.visibility_off : Symbols.check,
                label: message.read
                    ? 'mail.action.markUnread'
                    : 'mail.action.markRead',
                onTap: message.read ? onMarkUnread : onMarkRead,
              ),
            if (!inTrash)
              _MailMenuItem(
                icon: Symbols.verified,
                label: message.starred
                    ? 'mail.action.unstar'
                    : 'mail.action.star',
                onTap: onToggleStar,
              ),
            if (!inTrash && message.folder != mailFolderArchive)
              _MailMenuItem(
                icon: Symbols.folder_open,
                label: 'mail.action.archive',
                onTap: onArchive,
              ),
            if (message.folder == mailFolderSpam ||
                message.folder == mailFolderTrash)
              _MailMenuItem(
                icon: Symbols.alternate_email,
                label: 'mail.action.moveInbox',
                onTap: onRestoreInbox,
              ),
            if (!inTrash && message.folder != mailFolderSpam)
              _MailMenuItem(
                icon: Symbols.visibility_off,
                label: 'mail.action.moveSpam',
                onTap: onMoveSpam,
              ),
            if (!inTrash)
              _MailMenuItem(
                icon: Symbols.delete,
                label: 'mail.action.moveTrash',
                onTap: onMoveTrash,
                danger: true,
              ),
            if (inTrash)
              _MailMenuItem(
                icon: Symbols.delete,
                label: 'Delete',
                onTap: onDelete,
                danger: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _MailMenuItem extends StatelessWidget {
  const _MailMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.actionRed : AppColors.deepOcean;

    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(AppRadius.value),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            SymbolIcon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MailEmpty extends StatelessWidget {
  const _MailEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('mail.inbox.empty'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MailFooter extends StatelessWidget {
  const _MailFooter({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.onPageChanged,
  });

  final int page;
  final int pageSize;
  final int totalCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final lastPage = totalCount == 0 ? 1 : ((totalCount - 1) ~/ pageSize) + 1;
    final from = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final to = totalCount == 0
        ? 0
        : (page * pageSize > totalCount ? totalCount : page * pageSize);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final summary = Text(
          context.t(
            'common.recordRange',
            values: {'from': from, 'to': to, 'total': totalCount},
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        );
        final pager = _MailPagination(
          page: page,
          lastPage: lastPage,
          onPageChanged: onPageChanged,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 16),
              summary,
              const SizedBox(height: 14),
              pager,
            ],
          );
        }

        return Column(
          children: [
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 16),
            Row(children: [summary, const Spacer(), pager]),
          ],
        );
      },
    );
  }
}

class _MailPagination extends StatelessWidget {
  const _MailPagination({
    required this.page,
    required this.lastPage,
    required this.onPageChanged,
  });

  final int page;
  final int lastPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PagerButton(
          label: '<<',
          enabled: page > 1,
          onPressed: () => onPageChanged(1),
        ),
        const SizedBox(width: 8),
        _PagerButton(
          label: '<',
          enabled: page > 1,
          onPressed: () => onPageChanged(page - 1),
        ),
        const SizedBox(width: 8),
        AdminTablePageButton(label: page.toString(), selected: true),
        const SizedBox(width: 8),
        _PagerButton(
          label: '>',
          enabled: page < lastPage,
          onPressed: () => onPageChanged(page + 1),
        ),
        const SizedBox(width: 8),
        _PagerButton(
          label: '>>',
          enabled: page < lastPage,
          onPressed: () => onPageChanged(lastPage),
        ),
      ],
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 34,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style:
            TextButton.styleFrom(
              backgroundColor: Colors.white,
              disabledForegroundColor: AppColors.support.withValues(
                alpha: 0.42,
              ),
              foregroundColor: AppColors.deepOcean,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                side: BorderSide(
                  color: AppColors.line.withValues(
                    alpha: enabled ? 0.72 : 0.38,
                  ),
                ),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: WidgetStatePropertyAll(
                enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
              ),
            ),
        child: Text(label),
      ),
    );
  }
}


class _MailInboxMobileView extends StatelessWidget {
  const _MailInboxMobileView({
    required this.allMessages,
    required this.messages,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchQuery,
    required this.quickFilter,
    required this.folderFilter,
    required this.accountFilter,
    required this.dateFilter,
    required this.selectedMessageIds,
    required this.onQuickFilterChanged,
    required this.onFolderChanged,
    required this.onAccountChanged,
    required this.onDateChanged,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onToggleMessage,
    required this.onOpenMessage,
    required this.onMarkRead,
    required this.onToggleStar,
    required this.onArchive,
    required this.onMoveSpam,
    required this.onMoveTrash,
    required this.onRestoreInbox,
    required this.onDelete,
    required this.onDeleteSelected,
    required this.onRefresh,
    required this.onCompose,
  });

  final List<AdminMailMessage> allMessages;
  final List<AdminMailMessage> messages;
  final int page;
  final int pageSize;
  final int totalCount;
  final String searchQuery;
  final String quickFilter;
  final String folderFilter;
  final String accountFilter;
  final String dateFilter;
  final Set<int> selectedMessageIds;
  final ValueChanged<String> onQuickFilterChanged;
  final ValueChanged<String?> onFolderChanged;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<String?> onDateChanged;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onToggleMessage;
  final ValueChanged<AdminMailMessage> onOpenMessage;
  final void Function(AdminMailMessage message, bool read) onMarkRead;
  final ValueChanged<AdminMailMessage> onToggleStar;
  final ValueChanged<AdminMailMessage> onArchive;
  final ValueChanged<AdminMailMessage> onMoveSpam;
  final ValueChanged<AdminMailMessage> onMoveTrash;
  final ValueChanged<AdminMailMessage> onRestoreInbox;
  final ValueChanged<AdminMailMessage> onDelete;
  final VoidCallback onDeleteSelected;
  final VoidCallback onRefresh;
  final VoidCallback onCompose;

  int get _activeFilterCount {
    var count = 0;
    if (folderFilter != mailFilterAll) count++;
    if (accountFilter != mailFilterAll) count++;
    if (dateFilter != mailDateAll) count++;
    return count;
  }

  void _openFilters(BuildContext context) {
    final accounts = allMessages.map((m) => m.account).toSet().toList()..sort();
    showAdminMobileFilterSheet(
      context: context,
      onClear: () {
        onFolderChanged(mailFilterAll);
        onAccountChanged(mailFilterAll);
        onDateChanged(mailDateAll);
      },
      contentBuilder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminMobileFilterField(
              label: context.t('mail.folder'),
              value: folderFilter,
              items: [
                DropdownMenuItem(
                  value: mailFilterAll,
                  child: Text(context.t('All')),
                ),
                DropdownMenuItem(
                  value: mailFolderInbox,
                  child: Text(context.t('mail.folder.inbox')),
                ),
                DropdownMenuItem(
                  value: mailFolderArchive,
                  child: Text(context.t('mail.folder.archive')),
                ),
                DropdownMenuItem(
                  value: mailFolderSent,
                  child: Text(context.t('mail.folder.sent')),
                ),
                DropdownMenuItem(
                  value: mailFolderSpam,
                  child: Text(context.t('mail.folder.spam')),
                ),
                DropdownMenuItem(
                  value: mailFolderTrash,
                  child: Text(context.t('mail.folder.trash')),
                ),
              ],
              onChanged: (value) {
                onFolderChanged(value);
                setSheetState(() {});
              },
            ),
            AdminMobileFilterField(
              label: context.t('mail.account'),
              value: accountFilter,
              items: [
                DropdownMenuItem(
                  value: mailFilterAll,
                  child: Text(context.t('All')),
                ),
                for (final account in accounts)
                  DropdownMenuItem(value: account, child: Text(account)),
              ],
              onChanged: (value) {
                onAccountChanged(value);
                setSheetState(() {});
              },
            ),
            AdminMobileFilterField(
              label: context.t('mail.dateRange'),
              value: dateFilter,
              items: [
                DropdownMenuItem(
                  value: mailDateAll,
                  child: Text(context.t('All')),
                ),
                DropdownMenuItem(
                  value: mailDateToday,
                  child: Text(context.t('mail.date.today')),
                ),
                DropdownMenuItem(
                  value: mailDateSevenDays,
                  child: Text(context.t('mail.date.last7')),
                ),
                DropdownMenuItem(
                  value: mailDateThirtyDays,
                  child: Text(context.t('mail.date.last30')),
                ),
              ],
              onChanged: (value) {
                onDateChanged(value);
                setSheetState(() {});
              },
            ),
            AdminMobileFilterField(
              label: 'Sayfa boyutu',
              value: pageSize.toString(),
              items: const [
                DropdownMenuItem(value: '25', child: Text('25')),
                DropdownMenuItem(value: '50', child: Text('50')),
                DropdownMenuItem(value: '100', child: Text('100')),
              ],
              onChanged: (value) {
                onPageSizeChanged(int.tryParse(value ?? ''));
                setSheetState(() {});
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastPage = totalCount == 0 ? 1 : ((totalCount - 1) ~/ pageSize) + 1;
    final from = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final to = totalCount == 0
        ? 0
        : (page * pageSize > totalCount ? totalCount : page * pageSize);
    final rangeText = context.t(
      'common.recordRange',
      values: {'from': from, 'to': to, 'total': totalCount},
    );
    final hasSelection = selectedMessageIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MailFolderPanel(
          messages: allMessages,
          selectedFilter: quickFilter,
          onChanged: onQuickFilterChanged,
        ),
        const SizedBox(height: 16),
        _MailMetricGrid(messages: allMessages),
        const SizedBox(height: 16),
        AdminMobileToolbar(
          query: searchQuery,
          hintText: context.t('mail.inbox.searchPlaceholder'),
          onSearchChanged: onSearchChanged,
          activeFilterCount: _activeFilterCount,
          onOpenFilters: () => _openFilters(context),
        ),
        const SizedBox(height: 12),
        hasSelection
            ? AdminMobileSelectionBar(
                selectedCount: selectedMessageIds.length,
                label: context.t(
                  'mail.selectedDelete',
                  values: {'count': selectedMessageIds.length},
                ),
                onClear: () {
                  for (final id in selectedMessageIds.toList()) {
                    onToggleMessage(id);
                  }
                },
                onDelete: onDeleteSelected,
              )
            : Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PrimaryActionButton(
                    label: 'mail.action.compose',
                    icon: Symbols.add,
                    onPressed: onCompose,
                  ),
                  _SoftActionButton(
                    label: 'mail.action.refresh',
                    icon: Symbols.download,
                    onPressed: onRefresh,
                  ),
                ],
              ),
        const SizedBox(height: 14),
        Expanded(
          child: AdminMobileListView(
            loading: false,
            itemCount: messages.length,
            emptyLabel: context.t('mail.inbox.empty'),
            itemBuilder: (context, index) {
              final message = messages[index];
              return _MailInboxMobileCard(
                message: message,
                selected: selectedMessageIds.contains(message.id),
                onToggle: () => onToggleMessage(message.id),
                onOpenMessage: onOpenMessage,
                onMarkRead: onMarkRead,
                onToggleStar: onToggleStar,
                onArchive: onArchive,
                onMoveSpam: onMoveSpam,
                onMoveTrash: onMoveTrash,
                onRestoreInbox: onRestoreInbox,
                onDelete: onDelete,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AdminMobilePager(
          page: page,
          lastPage: lastPage,
          rangeText: rangeText,
          loading: false,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _MailInboxMobileCard extends StatelessWidget {
  const _MailInboxMobileCard({
    required this.message,
    required this.selected,
    required this.onToggle,
    required this.onOpenMessage,
    required this.onMarkRead,
    required this.onToggleStar,
    required this.onArchive,
    required this.onMoveSpam,
    required this.onMoveTrash,
    required this.onRestoreInbox,
    required this.onDelete,
  });

  final AdminMailMessage message;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<AdminMailMessage> onOpenMessage;
  final void Function(AdminMailMessage message, bool read) onMarkRead;
  final ValueChanged<AdminMailMessage> onToggleStar;
  final ValueChanged<AdminMailMessage> onArchive;
  final ValueChanged<AdminMailMessage> onMoveSpam;
  final ValueChanged<AdminMailMessage> onMoveTrash;
  final ValueChanged<AdminMailMessage> onRestoreInbox;
  final ValueChanged<AdminMailMessage> onDelete;

  @override
  Widget build(BuildContext context) {
    final inTrash = message.folder == mailFolderTrash;
    final sent = message.folder == mailFolderSent;
    final active = !message.read || sent;
    final statusLabel = sent
        ? 'mail.status.sent'
        : message.read
        ? 'mail.status.read'
        : 'mail.status.unread';
    final statusColor = active ? const Color(0xFF198754) : AppColors.support;
    final hasAttachment = message.hasAttachments || message.hasImages;

    return AdminMobileCard(
      selected: selected,
      onTap: () => onOpenMessage(message),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminMobileCheckbox(value: selected, onChanged: (_) => onToggle()),
              const SizedBox(width: 12),
              AdminMobileAvatar(label: message.senderName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.senderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: message.read
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: AppColors.deepOcean,
                            ),
                          ),
                        ),
                        if (message.starred) ...[
                          const SizedBox(width: 6),
                          const SymbolIcon(
                            Symbols.verified,
                            color: AppColors.warmHorizon,
                            size: 15,
                          ),
                        ],
                      ],
                    ),
                    if (message.senderEmail.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        message.senderEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.support,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AdminMobileMenuButton(
                actions: [
                  AdminMobileMenuAction(
                    icon: Symbols.visibility,
                    label: context.t('mail.action.open'),
                    onTap: () => onOpenMessage(message),
                  ),
                  if (!inTrash)
                    AdminMobileMenuAction(
                      icon: message.read
                          ? Symbols.visibility_off
                          : Symbols.check,
                      label: context.t(
                        message.read
                            ? 'mail.action.markUnread'
                            : 'mail.action.markRead',
                      ),
                      onTap: () => onMarkRead(message, !message.read),
                    ),
                  if (!inTrash)
                    AdminMobileMenuAction(
                      icon: Symbols.verified,
                      label: context.t(
                        message.starred
                            ? 'mail.action.unstar'
                            : 'mail.action.star',
                      ),
                      onTap: () => onToggleStar(message),
                    ),
                  if (!inTrash && message.folder != mailFolderArchive)
                    AdminMobileMenuAction(
                      icon: Symbols.folder_open,
                      label: context.t('mail.action.archive'),
                      onTap: () => onArchive(message),
                    ),
                  if (message.folder == mailFolderSpam ||
                      message.folder == mailFolderTrash)
                    AdminMobileMenuAction(
                      icon: Symbols.alternate_email,
                      label: context.t('mail.action.moveInbox'),
                      onTap: () => onRestoreInbox(message),
                    ),
                  if (!inTrash && message.folder != mailFolderSpam)
                    AdminMobileMenuAction(
                      icon: Symbols.visibility_off,
                      label: context.t('mail.action.moveSpam'),
                      onTap: () => onMoveSpam(message),
                    ),
                  if (!inTrash)
                    AdminMobileMenuAction(
                      icon: Symbols.delete,
                      label: context.t('mail.action.moveTrash'),
                      danger: true,
                      onTap: () => onMoveTrash(message),
                    ),
                  if (inTrash)
                    AdminMobileMenuAction(
                      icon: Symbols.delete,
                      label: context.t('Delete'),
                      danger: true,
                      onTap: () => onDelete(message),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: message.read ? FontWeight.w600 : FontWeight.w800,
              color: AppColors.deepOcean,
            ),
          ),
          if (message.preview.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              message.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.32,
                color: AppColors.support,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (hasAttachment) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AdminMobileChip(
                label: 'Ek dosya',
                icon: Symbols.folder_open,
                color: AppColors.support,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.softLine.withValues(alpha: 0.9)),
          const SizedBox(height: 10),
          Row(
            children: [
              AdminMobileStatusPill(
                label: context.t(statusLabel),
                color: statusColor,
              ),
              const Spacer(),
              if (message.account.trim().isNotEmpty) ...[
                Flexible(
                  child: Text(
                    message.account,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.support,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                formatAdminFullDate(context, message.sentAt),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.support,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
