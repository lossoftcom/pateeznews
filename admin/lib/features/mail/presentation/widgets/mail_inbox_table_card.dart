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
import '../mail_mobile_chrome.dart';
import '../mail_inbox_models.dart';

const mailFilterAll = '__all';
const mailQuickAll = 'all';
const mailQuickInbox = 'inbox';
const mailQuickContact = 'contact';
const mailQuickUnread = 'unread';
const mailQuickStarred = 'starred';
const mailQuickAttachments = 'attachments';
const mailQuickSent = 'sent';
const mailQuickDraft = 'draft';
const mailQuickScheduled = 'scheduled';
const mailQuickSpam = 'spam';
const mailQuickTrash = 'trash';
const mailDateAll = 'all';
const mailDateToday = 'today';
const mailDateSevenDays = 'seven_days';
const mailDateThirtyDays = 'thirty_days';

bool mailMessageIsContact(AdminMailMessage message) {
  return message.labels.any((label) {
    final normalized = label
        .trim()
        .toLowerCase()
        .replaceAll('i̇', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's');
    return normalized == 'iletisim' || normalized == 'contact';
  });
}

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
      mailQuickContact => messages.where(mailMessageIsContact).length,
      mailQuickUnread => messages.where((message) => !message.read).length,
      mailQuickStarred => messages.where((message) => message.starred).length,
      mailQuickAttachments =>
        messages
            .where((message) => message.hasAttachments || message.hasImages)
            .length,
      mailQuickSent =>
        messages.where((message) => message.isOutboxSource).length,
      mailQuickDraft =>
        messages.where((message) => message.folder == mailFolderDraft).length,
      mailQuickScheduled =>
        messages
            .where((message) => message.folder == mailFolderScheduled)
            .length,
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
      mailQuickContact ||
      mailQuickStarred ||
      mailQuickSent ||
      mailQuickDraft ||
      mailQuickScheduled ||
      mailQuickSpam ||
      mailQuickTrash => _countFor(value),
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _MailFolderItemData(
        value: mailQuickContact,
        label: 'mail.filter.contact',
        icon: Symbols.chat_bubble_outline,
        color: AppColors.actionRed,
      ),
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
        value: mailQuickSent,
        label: 'mail.outbox.title',
        icon: Symbols.schedule_send,
        color: const Color(0xFF3B82F6),
      ),
      _MailFolderItemData(
        value: mailQuickDraft,
        label: 'mail.folder.draft',
        icon: Symbols.draft,
        color: AppColors.support,
      ),
      _MailFolderItemData(
        value: mailQuickScheduled,
        label: 'mail.folder.scheduled',
        icon: Symbols.schedule,
        color: AppColors.warmHorizon,
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
        final width = constraints.maxWidth;
        final density = width < 560
            ? _MailMetricDensity.tight
            : width < 840
            ? _MailMetricDensity.compact
            : _MailMetricDensity.regular;
        final gap = switch (density) {
          _MailMetricDensity.tight => 6.0,
          _MailMetricDensity.compact => 8.0,
          _MailMetricDensity.regular => 12.0,
        };

        return Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Expanded(
                child: _MailMetricBox(data: items[index], density: density),
              ),
              if (index != items.length - 1) SizedBox(width: gap),
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

enum _MailMetricDensity { regular, compact, tight }

class _MailMetricBox extends StatelessWidget {
  const _MailMetricBox({required this.data, required this.density});

  final _MailMetricData data;
  final _MailMetricDensity density;

  @override
  Widget build(BuildContext context) {
    final isTight = density == _MailMetricDensity.tight;
    final isCompact = density == _MailMetricDensity.compact;
    final label = context.t(data.label);
    final minHeight = isTight
        ? 68.0
        : isCompact
        ? 72.0
        : 78.0;
    final horizontalPadding = isTight
        ? 8.0
        : isCompact
        ? 10.0
        : 14.0;
    final verticalPadding = isTight
        ? 8.0
        : isCompact
        ? 10.0
        : 12.0;
    final iconBoxSize = isTight
        ? 26.0
        : isCompact
        ? 30.0
        : 34.0;
    final iconSize = isTight
        ? 16.0
        : isCompact
        ? 17.0
        : 19.0;
    final gap = isTight
        ? 6.0
        : isCompact
        ? 8.0
        : 12.0;
    final labelStyle = TextStyle(
      color: AppColors.inkSoft,
      fontSize: isTight
          ? 10
          : isCompact
          ? 11
          : 12,
      height: 1,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
    final valueStyle = TextStyle(
      color: AppColors.deepOcean,
      fontSize: isTight
          ? 18
          : isCompact
          ? 19
          : 21,
      height: 1,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showLabel = constraints.maxWidth >= 96;
          final showIcon = constraints.maxWidth >= 68;

          Widget icon() {
            return Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              child: Center(
                child: SymbolIcon(data.icon, color: data.color, size: iconSize),
              ),
            );
          }

          if (!showLabel) {
            return Tooltip(
              message: label,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showIcon) ...[icon(), SizedBox(width: gap)],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(data.value, style: valueStyle),
                    ),
                  ),
                ],
              ),
            );
          }

          return Row(
            children: [
              if (showIcon) ...[icon(), SizedBox(width: gap)],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: valueStyle,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
                value: mailFolderOutbox,
                child: Text(context.t('mail.outbox.title')),
              ),
              DropdownMenuItem(
                value: mailFolderDraft,
                child: Text(context.t('mail.folder.draft')),
              ),
              DropdownMenuItem(
                value: mailFolderScheduled,
                child: Text(context.t('mail.folder.scheduled')),
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
  static const double _senderWidth = 190;
  static const double _subjectMinWidth = 300;
  static const double _subjectMaxWidth = 460;
  static const double _attachmentWidth = 60;
  static const double _accountWidth = 156;
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
        final tableWidth = AdminTableChrome.desktopTableWidth(
          constraints: constraints,
          preferredMinWidth: _minWidth,
        );
        final layout = _MailTableColumnLayout.forWidth(tableWidth);

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
                    layout: layout,
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
                                    layout: layout,
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

class _MailTableColumnLayout {
  const _MailTableColumnLayout({
    required this.selectWidth,
    required this.idWidth,
    required this.senderWidth,
    required this.subjectWidth,
    required this.spacerWidth,
    required this.attachmentWidth,
    required this.accountWidth,
    required this.dateWidth,
    required this.statusWidth,
    required this.menuWidth,
  });

  final double selectWidth;
  final double idWidth;
  final double senderWidth;
  final double subjectWidth;
  final double spacerWidth;
  final double attachmentWidth;
  final double accountWidth;
  final double dateWidth;
  final double statusWidth;
  final double menuWidth;

  factory _MailTableColumnLayout.forWidth(double tableWidth) {
    final scale = AdminTableChrome.compactScale(
      tableWidth: tableWidth,
      preferredMinWidth: _MailDataTable._minWidth,
    );
    final selectWidth = AdminTableChrome.scaledColumn(
      _MailDataTable._selectWidth,
      scale,
      minWidth: 38,
    );
    final idWidth = AdminTableChrome.scaledColumn(
      _MailDataTable._idWidth,
      scale,
      minWidth: 44,
    );
    final senderWidth = AdminTableChrome.scaledColumn(
      _MailDataTable._senderWidth,
      scale,
      minWidth: 122,
    );
    final attachmentWidth = AdminTableChrome.scaledColumn(
      _MailDataTable._attachmentWidth,
      scale,
      minWidth: 44,
    );
    final accountWidth = AdminTableChrome.scaledColumn(
      _MailDataTable._accountWidth,
      scale,
      minWidth: 102,
    );
    final dateWidth = AdminTableChrome.scaledColumn(
      _MailDataTable._dateWidth,
      scale,
      minWidth: 92,
    );
    final statusWidth = AdminTableChrome.scaledColumn(
      _MailDataTable._statusWidth,
      scale,
      minWidth: 58,
    );
    final menuWidth = AdminTableChrome.scaledColumn(
      _MailDataTable._menuWidth,
      scale,
      minWidth: 54,
    );
    const contentSpacing =
        _MailDataTable._horizontalPadding + _MailDataTable._tableBorderWidth;
    final fixedWidth =
        contentSpacing +
        selectWidth +
        idWidth +
        senderWidth +
        attachmentWidth +
        accountWidth +
        dateWidth +
        statusWidth +
        menuWidth;
    final availableSubjectWidth = tableWidth - fixedWidth;
    final subjectWidth = tableWidth >= _MailDataTable._minWidth
        ? availableSubjectWidth
              .clamp(
                _MailDataTable._subjectMinWidth,
                _MailDataTable._subjectMaxWidth,
              )
              .toDouble()
        : availableSubjectWidth.clamp(112.0, double.infinity).toDouble();
    final spacerWidth = tableWidth >= _MailDataTable._minWidth
        ? (availableSubjectWidth - subjectWidth)
              .clamp(0, double.infinity)
              .toDouble()
        : 0.0;

    return _MailTableColumnLayout(
      selectWidth: selectWidth,
      idWidth: idWidth,
      senderWidth: senderWidth,
      subjectWidth: subjectWidth,
      spacerWidth: spacerWidth,
      attachmentWidth: attachmentWidth,
      accountWidth: accountWidth,
      dateWidth: dateWidth,
      statusWidth: statusWidth,
      menuWidth: menuWidth,
    );
  }
}

class _MailHeader extends StatelessWidget {
  const _MailHeader({
    required this.selectedCount,
    required this.totalCount,
    required this.layout,
    required this.sortState,
    required this.onToggleAllMessages,
    required this.onSort,
  });

  final int selectedCount;
  final int totalCount;
  final _MailTableColumnLayout layout;
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
            width: layout.selectWidth,
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
            width: layout.idWidth,
            label: 'ID',
            sortKey: 'id',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: layout.senderWidth,
            label: 'mail.sender',
            sortKey: 'sender',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: layout.subjectWidth,
            label: 'mail.subject',
            sortKey: 'subject',
            sortState: sortState,
            onSort: onSort,
          ),
          if (layout.spacerWidth > 0) SizedBox(width: layout.spacerWidth),
          SizedBox(
            width: layout.attachmentWidth,
            child: const _HeaderText('mail.attachments', centered: true),
          ),
          _SortableColumnHeader(
            width: layout.accountWidth,
            label: 'mail.account',
            sortKey: 'account',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: layout.dateWidth,
            label: 'Date',
            sortKey: 'date',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: layout.statusWidth,
            label: 'Status',
            sortKey: 'status',
            sortState: sortState,
            onSort: onSort,
          ),
          SizedBox(
            width: layout.menuWidth,
            child: const _HeaderText('Action', centered: true),
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
    required this.layout,
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
  final _MailTableColumnLayout layout;
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
      constraints: const BoxConstraints(minHeight: 66),
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
            width: layout.selectWidth,
            child: _MailCheckbox(value: selected, onChanged: (_) => onToggle()),
          ),
          SizedBox(
            width: layout.idWidth,
            child: _RowSelectTapTarget(
              onTap: onToggle,
              child: Text(
                message.displayId.toString(),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(
            width: layout.senderWidth,
            child: _RowSelectTapTarget(
              onTap: () => onOpenMessage(message),
              child: _SenderCell(message: message),
            ),
          ),
          SizedBox(
            width: layout.subjectWidth,
            child: _RowSelectTapTarget(
              onTap: () => onOpenMessage(message),
              child: _SubjectCell(message: message),
            ),
          ),
          if (layout.spacerWidth > 0) SizedBox(width: layout.spacerWidth),
          SizedBox(
            width: layout.attachmentWidth,
            child: _AttachmentCell(message: message),
          ),
          SizedBox(
            width: layout.accountWidth,
            child: _TextCell(value: message.account),
          ),
          SizedBox(
            width: layout.dateWidth,
            child: _MailDateCell(dateTime: message.sentAt),
          ),
          SizedBox(
            width: layout.statusWidth,
            child: _MailStatusBadge(message: message),
          ),
          SizedBox(
            width: layout.menuWidth,
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
    final preview = message.preview.trim();
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: message.subject,
                style: TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: message.read ? FontWeight.w600 : FontWeight.w800,
                ),
              ),
              if (preview.isNotEmpty)
                TextSpan(
                  text: ' - $preview',
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, height: 1.28, letterSpacing: 0),
        ),
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
    final status = _mailStatusVisual(message);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: status.background,
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                context.t(status.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: status.color,
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

class _MailStatusVisual {
  const _MailStatusVisual({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;
}

_MailStatusVisual _mailStatusVisual(AdminMailMessage message) {
  if (message.isOutboxSource) {
    return switch (message.status) {
      'draft' => _MailStatusVisual(
        label: 'mail.status.draft',
        color: AppColors.support,
        background: AppColors.support.withValues(alpha: 0.1),
      ),
      'scheduled' => _MailStatusVisual(
        label: 'mail.status.scheduled',
        color: AppColors.warmHorizon,
        background: AppColors.warmHorizon.withValues(alpha: 0.12),
      ),
      'queued' || 'sending' => _MailStatusVisual(
        label: 'mail.status.queued',
        color: const Color(0xFF3B82F6),
        background: const Color(0xFFEAF2FF),
      ),
      'failed' || 'bounce' => _MailStatusVisual(
        label: 'mail.status.failed',
        color: AppColors.actionRed,
        background: AppColors.actionRed.withValues(alpha: 0.1),
      ),
      _ => const _MailStatusVisual(
        label: 'mail.status.sent',
        color: Color(0xFF198754),
        background: Color(0xFFE6F4EA),
      ),
    };
  }

  if (!message.read) {
    return const _MailStatusVisual(
      label: 'mail.status.unread',
      color: Color(0xFF198754),
      background: Color(0xFFE6F4EA),
    );
  }
  return _MailStatusVisual(
    label: 'mail.status.read',
    color: AppColors.inkSoft,
    background: AppColors.support.withValues(alpha: 0.1),
  );
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
    final inboxMessage = message.isInboxSource;
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
            if (inboxMessage && !inTrash)
              _MailMenuItem(
                icon: message.read ? Symbols.visibility_off : Symbols.check,
                label: message.read
                    ? 'mail.action.markUnread'
                    : 'mail.action.markRead',
                onTap: message.read ? onMarkUnread : onMarkRead,
              ),
            if (inboxMessage && !inTrash)
              _MailMenuItem(
                icon: Symbols.verified,
                label: message.starred
                    ? 'mail.action.unstar'
                    : 'mail.action.star',
                onTap: onToggleStar,
              ),
            if (inboxMessage && !inTrash && message.folder != mailFolderArchive)
              _MailMenuItem(
                icon: Symbols.folder_open,
                label: 'mail.action.archive',
                onTap: onArchive,
              ),
            if (inboxMessage &&
                (message.folder == mailFolderSpam ||
                    message.folder == mailFolderTrash))
              _MailMenuItem(
                icon: Symbols.alternate_email,
                label: 'mail.action.moveInbox',
                onTap: onRestoreInbox,
              ),
            if (inboxMessage && !inTrash && message.folder != mailFolderSpam)
              _MailMenuItem(
                icon: Symbols.visibility_off,
                label: 'mail.action.moveSpam',
                onTap: onMoveSpam,
              ),
            if (inboxMessage && !inTrash)
              _MailMenuItem(
                icon: Symbols.delete,
                label: 'mail.action.moveTrash',
                onTap: onMoveTrash,
                danger: true,
              ),
            if (inboxMessage && inTrash)
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
    return AdminTablePagination(
      page: page,
      pageCount: lastPage,
      onPageChanged: onPageChanged,
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
                  value: mailFolderOutbox,
                  child: Text(context.t('mail.outbox.title')),
                ),
                DropdownMenuItem(
                  value: mailFolderDraft,
                  child: Text(context.t('mail.folder.draft')),
                ),
                DropdownMenuItem(
                  value: mailFolderScheduled,
                  child: Text(context.t('mail.folder.scheduled')),
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
        MailMobileSearchPanel(
          query: searchQuery,
          hintText: context.t('mail.inbox.searchPlaceholder'),
          onSearchChanged: onSearchChanged,
          recordCount: totalCount,
          pageSize: pageSize,
          onPageSizeChanged: onPageSizeChanged,
          filterCount: _activeFilterCount,
        ),
        const SizedBox(height: 4),
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
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AdminMobileFiltersButton(
                          label: context.t('Filtreler'),
                          count: _activeFilterCount,
                          active: _activeFilterCount > 0,
                          fullWidth: true,
                          onPressed: () => _openFilters(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminMobilePrimaryButton(
                          icon: Symbols.add,
                          label: context.t('mail.action.compose'),
                          fullWidth: true,
                          onPressed: onCompose,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AdminMobileActionButton(
                    label: context.t('mail.action.refresh'),
                    leading: const SymbolIcon(
                      Symbols.download,
                      color: AppColors.deepOcean,
                      size: 18,
                    ),
                    fullWidth: true,
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
    final inboxMessage = message.isInboxSource;
    final status = _mailStatusVisual(message);
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
              AdminMobileCheckbox(
                value: selected,
                onChanged: (_) => onToggle(),
              ),
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
                  if (inboxMessage && !inTrash)
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
                  if (inboxMessage && !inTrash)
                    AdminMobileMenuAction(
                      icon: Symbols.verified,
                      label: context.t(
                        message.starred
                            ? 'mail.action.unstar'
                            : 'mail.action.star',
                      ),
                      onTap: () => onToggleStar(message),
                    ),
                  if (inboxMessage &&
                      !inTrash &&
                      message.folder != mailFolderArchive)
                    AdminMobileMenuAction(
                      icon: Symbols.folder_open,
                      label: context.t('mail.action.archive'),
                      onTap: () => onArchive(message),
                    ),
                  if (inboxMessage &&
                      (message.folder == mailFolderSpam ||
                          message.folder == mailFolderTrash))
                    AdminMobileMenuAction(
                      icon: Symbols.alternate_email,
                      label: context.t('mail.action.moveInbox'),
                      onTap: () => onRestoreInbox(message),
                    ),
                  if (inboxMessage &&
                      !inTrash &&
                      message.folder != mailFolderSpam)
                    AdminMobileMenuAction(
                      icon: Symbols.visibility_off,
                      label: context.t('mail.action.moveSpam'),
                      onTap: () => onMoveSpam(message),
                    ),
                  if (inboxMessage && !inTrash)
                    AdminMobileMenuAction(
                      icon: Symbols.delete,
                      label: context.t('mail.action.moveTrash'),
                      danger: true,
                      onTap: () => onMoveTrash(message),
                    ),
                  if (inboxMessage && inTrash)
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
                label: context.t(status.label),
                color: status.color,
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
