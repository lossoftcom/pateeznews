import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/widgets/admin_table_chrome.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/admin_mobile_list.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_sms_repository.dart';
import 'sms_message_preview.dart';

enum _SmsOutboxStatus { sent, queued, scheduled, failed }

extension _SmsOutboxStatusData on _SmsOutboxStatus {
  String get labelKey {
    return switch (this) {
      _SmsOutboxStatus.sent => 'sms.outbox.status.sent',
      _SmsOutboxStatus.queued => 'sms.outbox.status.queued',
      _SmsOutboxStatus.scheduled => 'sms.outbox.status.scheduled',
      _SmsOutboxStatus.failed => 'sms.outbox.status.failed',
    };
  }

  Color get dotColor {
    return switch (this) {
      _SmsOutboxStatus.sent => const Color(0xFF198754),
      _SmsOutboxStatus.queued => const Color(0xFF0D6EFD),
      _SmsOutboxStatus.scheduled => const Color(0xFFF59E0B),
      _SmsOutboxStatus.failed => AppColors.actionRed,
    };
  }

  Color get backgroundColor => dotColor.withValues(alpha: 0.10);
}

class _SmsOutboxMessage {
  const _SmsOutboxMessage({
    required this.id,
    required this.recipient,
    required this.phone,
    required this.message,
    required this.senderLine,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String recipient;
  final String phone;
  final String message;
  final String senderLine;
  final _SmsOutboxStatus status;
  final DateTime createdAt;
}

class SmsOutboxScreen extends StatefulWidget {
  const SmsOutboxScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminSmsRepository(),
  });

  final AdminSession session;
  final AdminSmsRepository repository;

  @override
  State<SmsOutboxScreen> createState() => _SmsOutboxScreenState();
}

class _SmsOutboxScreenState extends State<SmsOutboxScreen> {
  final _searchController = TextEditingController();
  final _selectedIds = <int>{};
  var _messages = <_SmsOutboxMessage>[];
  var _statusFilter = 'all';
  var _page = 1;
  var _pageSize = 25;
  var _sortState = const TableSortState(key: 'date', ascending: false);
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMessages());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.repository.fetchOutboxMessages(widget.session);
      if (!mounted) return;
      setState(() {
        _messages = rows.map(_messageFromRepository).toList(growable: false);
        _loading = false;
        _resetListState();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSmsError(error);
    }
  }

  void _showSmsError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  _SmsOutboxMessage _messageFromRepository(AdminSmsOutboxMessage message) {
    return _SmsOutboxMessage(
      id: message.id,
      recipient: message.recipient.isEmpty ? message.phone : message.recipient,
      phone: message.phone,
      message: message.message,
      senderLine: message.senderLine,
      status: _statusFromRepository(message.status),
      createdAt: message.createdAt,
    );
  }

  _SmsOutboxStatus _statusFromRepository(String value) {
    return switch (value) {
      'sent' || 'delivered' => _SmsOutboxStatus.sent,
      'scheduled' => _SmsOutboxStatus.scheduled,
      'failed' || 'error' => _SmsOutboxStatus.failed,
      _ => _SmsOutboxStatus.queued,
    };
  }

  List<_SmsOutboxMessage> get _filteredMessages {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _messages.where((message) {
      if (_statusFilter != 'all' && message.status.name != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final searchable = [
        message.recipient,
        message.phone,
        message.message,
        message.senderLine,
        message.status.labelKey,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    filtered.sort((left, right) {
      final result = switch (_sortState.key) {
        'recipient' => left.recipient.compareTo(right.recipient),
        'message' => left.message.compareTo(right.message),
        'sender' => left.senderLine.compareTo(right.senderLine),
        'status' => left.status.index.compareTo(right.status.index),
        'date' || _ => left.createdAt.compareTo(right.createdAt),
      };
      return _sortState.ascending ? result : -result;
    });

    return filtered;
  }

  List<_SmsOutboxMessage> get _pagedMessages {
    final filtered = _filteredMessages;
    if (filtered.isEmpty) return const <_SmsOutboxMessage>[];
    final start = (_page - 1) * _pageSize;
    if (start >= filtered.length) return filtered.take(_pageSize).toList();
    final end = start + _pageSize > filtered.length
        ? filtered.length
        : start + _pageSize;
    return filtered.sublist(start, end);
  }

  void _resetListState() {
    _page = 1;
    _selectedIds.clear();
  }

  void _toggleAll() {
    final ids = _pagedMessages.map((message) => message.id).toSet();
    setState(() {
      if (ids.isNotEmpty && _selectedIds.containsAll(ids)) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds
          ..clear()
          ..addAll(ids);
      }
    });
  }

  void _toggleOne(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _changeFilter(String value) {
    setState(() {
      _statusFilter = value;
      _resetListState();
    });
  }

  void _changeSort(String key) {
    setState(() {
      _sortState = _sortState.toggled(key);
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
    setState(_resetListState);
  }

  void _changePage(int value) {
    if (value == _page) return;
    setState(() {
      _page = value;
      _selectedIds.clear();
    });
  }

  void _refresh() {
    unawaited(_loadMessages());
  }

  void _openSendDrawer() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('common.cancel'),
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final mobile = screenWidth < 700;
        final availableWidth = screenWidth - 24;
        final drawerWidth = mobile
            ? screenWidth
            : availableWidth > 1040
            ? 1040.0
            : availableWidth;

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
                child: SmsSendDrawer(
                  onClose: () => Navigator.of(dialogContext).pop(),
                  onSend: (draft) {
                    Navigator.of(dialogContext).pop();
                    unawaited(_sendDraftMessage(draft));
                  },
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

  Future<void> _sendDraftMessage(SmsSendDraft draft) async {
    final phones = draft.recipients
        .split(RegExp(r'[\n,;|]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (phones.isEmpty || draft.message.trim().isEmpty) return;
    try {
      final created = <_SmsOutboxMessage>[];
      for (final phone in phones) {
        final message = await widget.repository.sendOutboxMessage(
          widget.session,
          phone: phone,
          text: draft.message.trim(),
          senderLine: draft.senderLine.trim(),
        );
        created.add(_messageFromRepository(message));
      }
      if (!mounted) return;
      setState(() {
        _messages = [...created, ..._messages];
        _resetListState();
      });
    } catch (error) {
      if (mounted) _showSmsError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _pagedMessages;
    final totalCount = _filteredMessages.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AdminMobile.breakpoint) {
          final lastPage = totalCount == 0
              ? 1
              : ((totalCount - 1) ~/ _pageSize) + 1;
          final from = totalCount == 0 ? 0 : ((_page - 1) * _pageSize) + 1;
          final to = totalCount == 0
              ? 0
              : (_page * _pageSize > totalCount
                    ? totalCount
                    : _page * _pageSize);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SmsOutboxHeader(),
                const SizedBox(height: 20),
                _SmsOutboxMetrics(messages: _messages),
                const SizedBox(height: 16),
                _SmsOutboxFilters(
                  selected: _statusFilter,
                  onChanged: _changeFilter,
                ),
                const SizedBox(height: 12),
                AdminMobileToolbar(
                  controller: _searchController,
                  query: _searchController.text,
                  hintText: context.t('sms.outbox.searchPlaceholder'),
                  onSearchChanged: _changeSearch,
                  activeFilterCount: 0,
                  onOpenFilters: () {},
                  showFilters: false,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AdminMobileActionButton(
                        label: context.t('sms.outbox.refresh'),
                        leading: const SymbolIcon(
                          Symbols.redo,
                          color: AppColors.deepOcean,
                          size: 18,
                        ),
                        fullWidth: true,
                        onPressed: _refresh,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AdminMobilePrimaryButton(
                        icon: Symbols.add,
                        label: context.t('sms.outbox.new'),
                        fullWidth: true,
                        onPressed: _openSendDrawer,
                      ),
                    ),
                  ],
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                const SizedBox(height: 14),
                Expanded(
                  child: _SmsOutboxMobileList(
                    messages: messages,
                    loading: _loading,
                    onSendAgain: _openSendDrawer,
                  ),
                ),
                const SizedBox(height: 12),
                AdminMobilePager(
                  page: _page,
                  lastPage: lastPage,
                  rangeText: context.t(
                    'common.recordRange',
                    values: {'from': from, 'to': to, 'total': totalCount},
                  ),
                  loading: _loading,
                  onPageChanged: _changePage,
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SmsOutboxHeader(),
              const SizedBox(height: 24),
              _SmsOutboxMetrics(messages: _messages),
              const SizedBox(height: 18),
              _SmsOutboxFilters(
                selected: _statusFilter,
                onChanged: _changeFilter,
              ),
              const SizedBox(height: 12),
              _SmsOutboxToolbar(
                controller: _searchController,
                pageSize: _pageSize,
                selectedCount: _selectedIds.length,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onRefresh: _refresh,
                onNewSms: _openSendDrawer,
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 18),
              Expanded(
                child: _SmsOutboxTable(
                  messages: messages,
                  selectedIds: _selectedIds,
                  sortState: _sortState,
                  onToggleAll: _toggleAll,
                  onToggleOne: _toggleOne,
                  onSort: _changeSort,
                  onSendAgain: _openSendDrawer,
                ),
              ),
              const SizedBox(height: 16),
              _SmsOutboxFooter(
                page: _page,
                pageSize: _pageSize,
                totalCount: totalCount,
                onPageChanged: _changePage,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SmsOutboxMobileList extends StatelessWidget {
  const _SmsOutboxMobileList({
    required this.messages,
    required this.loading,
    required this.onSendAgain,
  });

  final List<_SmsOutboxMessage> messages;
  final bool loading;
  final VoidCallback onSendAgain;

  @override
  Widget build(BuildContext context) {
    return AdminMobileListView(
      loading: loading,
      itemCount: messages.length,
      emptyLabel: context.t('sms.outbox.empty'),
      itemBuilder: (context, index) {
        return _SmsOutboxMobileCard(
          message: messages[index],
          onSendAgain: onSendAgain,
        );
      },
    );
  }
}

class _SmsOutboxMobileCard extends StatelessWidget {
  const _SmsOutboxMobileCard({
    required this.message,
    required this.onSendAgain,
  });

  final _SmsOutboxMessage message;
  final VoidCallback onSendAgain;

  @override
  Widget build(BuildContext context) {
    final sender = message.senderLine.trim();

    return AdminMobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminMobileThumb(fallbackIcon: Symbols.short_text),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.recipient.isEmpty
                          ? message.phone
                          : message.recipient,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepOcean,
                      ),
                    ),
                    if (message.phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        message.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                    icon: Symbols.redo,
                    label: context.t('sms.outbox.action.sendAgain'),
                    onTap: onSendAgain,
                  ),
                ],
              ),
            ],
          ),
          if (message.message.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.softLine.withValues(alpha: 0.9)),
          const SizedBox(height: 10),
          Row(
            children: [
              AdminMobileStatusPill(
                label: context.t(message.status.labelKey),
                color: message.status.dotColor,
              ),
              const Spacer(),
              if (sender.isNotEmpty) ...[
                Flexible(
                  child: Text(
                    sender,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.support,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                formatAdminFullDate(context, message.createdAt),
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

class _SmsOutboxHeader extends StatelessWidget {
  const _SmsOutboxHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t('sms.outbox.title'),
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _SmsOutboxMetrics extends StatelessWidget {
  const _SmsOutboxMetrics({required this.messages});

  final List<_SmsOutboxMessage> messages;

  @override
  Widget build(BuildContext context) {
    final sent = messages
        .where((message) => message.status == _SmsOutboxStatus.sent)
        .length;
    final queued = messages
        .where((message) => message.status == _SmsOutboxStatus.queued)
        .length;
    final scheduled = messages
        .where((message) => message.status == _SmsOutboxStatus.scheduled)
        .length;
    final failed = messages
        .where((message) => message.status == _SmsOutboxStatus.failed)
        .length;
    final items = [
      _SmsOutboxMetricData(
        icon: Symbols.alternate_email,
        label: 'sms.outbox.metric.sent',
        value: '$sent',
        color: AppColors.deepOcean,
      ),
      _SmsOutboxMetricData(
        icon: Symbols.schedule_send,
        label: 'sms.outbox.metric.queued',
        value: '$queued',
        color: const Color(0xFF3B82F6),
      ),
      _SmsOutboxMetricData(
        icon: Symbols.schedule,
        label: _SmsOutboxStatus.scheduled.labelKey,
        value: '$scheduled',
        color: AppColors.warmHorizon,
      ),
      _SmsOutboxMetricData(
        icon: Symbols.warning,
        label: 'sms.outbox.metric.failed',
        value: '$failed',
        color: AppColors.actionRed,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in items)
                SizedBox(
                  width: constraints.maxWidth < 540
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2,
                  child: _SmsOutboxMetricCard(data: item),
                ),
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Expanded(child: _SmsOutboxMetricCard(data: items[index])),
              if (index != items.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _SmsOutboxMetricData {
  const _SmsOutboxMetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _SmsOutboxMetricCard extends StatelessWidget {
  const _SmsOutboxMetricCard({required this.data});

  final _SmsOutboxMetricData data;

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

class _SmsOutboxFilters extends StatelessWidget {
  const _SmsOutboxFilters({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final filters = [
      const _SmsOutboxFilterData(
        value: 'all',
        label: 'sms.outbox.filter.all',
        icon: Symbols.draft,
      ),
      _SmsOutboxFilterData(
        value: _SmsOutboxStatus.sent.name,
        label: _SmsOutboxStatus.sent.labelKey,
        icon: Symbols.check,
      ),
      _SmsOutboxFilterData(
        value: _SmsOutboxStatus.queued.name,
        label: _SmsOutboxStatus.queued.labelKey,
        icon: Symbols.schedule_send,
      ),
      _SmsOutboxFilterData(
        value: _SmsOutboxStatus.scheduled.name,
        label: _SmsOutboxStatus.scheduled.labelKey,
        icon: Symbols.schedule,
      ),
      _SmsOutboxFilterData(
        value: _SmsOutboxStatus.failed.name,
        label: _SmsOutboxStatus.failed.labelKey,
        icon: Symbols.close,
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in filters)
          _SmsOutboxFilterPill(
            filter: filter,
            selected: selected == filter.value,
            onTap: () => onChanged(filter.value),
          ),
      ],
    );
  }
}

class _SmsOutboxFilterData {
  const _SmsOutboxFilterData({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

class _SmsOutboxFilterPill extends StatelessWidget {
  const _SmsOutboxFilterPill({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final _SmsOutboxFilterData filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.deepOcean : AppColors.inkSoft;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected
                  ? AppColors.deepOcean.withValues(alpha: 0.22)
                  : AppColors.line.withValues(alpha: 0.82),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SymbolIcon(filter.icon, color: foreground, size: 18),
              const SizedBox(width: 8),
              Text(
                context.t(filter.label),
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmsOutboxToolbar extends StatelessWidget {
  const _SmsOutboxToolbar({
    required this.controller,
    required this.pageSize,
    required this.selectedCount,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onNewSms,
  });

  final TextEditingController controller;
  final int pageSize;
  final int selectedCount;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final VoidCallback onNewSms;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final left = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SmsOutboxPageSizeSelect(
              value: pageSize,
              onChanged: onPageSizeChanged,
            ),
            if (selectedCount > 0) ...[
              const SizedBox(width: 10),
              Text(
                context.t(
                  'sms.outbox.selected',
                  values: {'count': selectedCount},
                ),
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: compact ? constraints.maxWidth : 280,
              child: _SmsOutboxSearchField(
                controller: controller,
                onChanged: onSearchChanged,
              ),
            ),
            _SmsOutboxSoftActionButton(
              icon: Symbols.redo,
              label: 'sms.outbox.refresh',
              onPressed: onRefresh,
            ),
            _SmsOutboxPrimaryActionButton(
              icon: Symbols.add,
              label: 'sms.outbox.new',
              onPressed: onNewSms,
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 12), actions],
          );
        }

        return Row(children: [left, const Spacer(), actions]);
      },
    );
  }
}

class _SmsOutboxPageSizeSelect extends StatelessWidget {
  const _SmsOutboxPageSizeSelect({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminTablePageSizeSelect(value: value, onChanged: onChanged);
  }
}

class _SmsOutboxSearchField extends StatelessWidget {
  const _SmsOutboxSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminTableSearchField(
      controller: controller,
      hintText: context.t('sms.outbox.searchPlaceholder'),
      onChanged: onChanged,
    );
  }
}

class _SmsOutboxSoftActionButton extends StatelessWidget {
  const _SmsOutboxSoftActionButton({
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
      height: 38,
      child: TextButton(
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(icon, size: 17, color: AppColors.deepOcean),
            const SizedBox(width: 7),
            Flexible(child: Text(context.t(label))),
          ],
        ),
      ),
    );
  }
}

class _SmsOutboxPrimaryActionButton extends StatelessWidget {
  const _SmsOutboxPrimaryActionButton({
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
      height: 38,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
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
            SymbolIcon(icon, size: 17, color: Colors.white),
            const SizedBox(width: 7),
            Flexible(child: Text(context.t(label))),
          ],
        ),
      ),
    );
  }
}

class _SmsOutboxTable extends StatelessWidget {
  const _SmsOutboxTable({
    required this.messages,
    required this.selectedIds,
    required this.sortState,
    required this.onToggleAll,
    required this.onToggleOne,
    required this.onSort,
    required this.onSendAgain,
  });

  final List<_SmsOutboxMessage> messages;
  final Set<int> selectedIds;
  final TableSortState sortState;
  final VoidCallback onToggleAll;
  final ValueChanged<int> onToggleOne;
  final ValueChanged<String> onSort;
  final VoidCallback onSendAgain;

  static const _selectWidth = 42.0;
  static const _recipientWidth = 160.0;
  static const _messageMinWidth = 260.0;
  static const _senderWidth = 120.0;
  static const _statusWidth = 110.0;
  static const _dateWidth = 150.0;
  static const _menuWidth = 70.0;
  static const _horizontalPadding = 32.0;
  static const _columnsMinWidth =
      _selectWidth +
      _recipientWidth +
      _messageMinWidth +
      _senderWidth +
      _statusWidth +
      _dateWidth +
      _menuWidth;
  static const _minWidth = _columnsMinWidth + _horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final allSelected =
        messages.isNotEmpty &&
        messages.every((message) => selectedIds.contains(message.id));
    final someSelected =
        messages.any((message) => selectedIds.contains(message.id)) &&
        !allSelected;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math.max(constraints.maxWidth, _minWidth);
        final contentWidth = tableWidth - _horizontalPadding;
        final messageWidth =
            _messageMinWidth +
            (contentWidth - _columnsMinWidth).clamp(0.0, 320.0).toDouble();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.softLine.withValues(alpha: 0.86),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: _selectWidth,
                          child: _SmsOutboxCheckbox(
                            value: allSelected
                                ? true
                                : someSelected
                                ? null
                                : false,
                            tristate: true,
                            onChanged: (_) => onToggleAll(),
                          ),
                        ),
                        _SmsOutboxHeaderSortable(
                          width: _recipientWidth,
                          label: 'sms.outbox.column.recipient',
                          sortKey: 'recipient',
                          sortState: sortState,
                          onSort: onSort,
                        ),
                        _SmsOutboxHeaderSortable(
                          width: messageWidth,
                          label: 'sms.outbox.column.message',
                          sortKey: 'message',
                          sortState: sortState,
                          onSort: onSort,
                        ),
                        _SmsOutboxHeaderSortable(
                          width: _senderWidth,
                          label: 'sms.outbox.column.sender',
                          sortKey: 'sender',
                          sortState: sortState,
                          onSort: onSort,
                        ),
                        _SmsOutboxHeaderSortable(
                          width: _statusWidth,
                          label: 'sms.outbox.column.status',
                          sortKey: 'status',
                          sortState: sortState,
                          onSort: onSort,
                        ),
                        _SmsOutboxHeaderSortable(
                          width: _dateWidth,
                          label: 'sms.outbox.column.date',
                          sortKey: 'date',
                          sortState: sortState,
                          onSort: onSort,
                        ),
                        SizedBox(
                          width: _menuWidth,
                          child: const _SmsOutboxHeaderText(
                            'sms.outbox.column.actions',
                            centered: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: messages.isEmpty
                        ? const _SmsOutboxEmpty()
                        : ListView.builder(
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              return _SmsOutboxRow(
                                message: message,
                                messageWidth: messageWidth,
                                selected: selectedIds.contains(message.id),
                                onToggle: () => onToggleOne(message.id),
                                onSendAgain: onSendAgain,
                              );
                            },
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

class _SmsOutboxRow extends StatelessWidget {
  const _SmsOutboxRow({
    required this.message,
    required this.messageWidth,
    required this.selected,
    required this.onToggle,
    required this.onSendAgain,
  });

  final _SmsOutboxMessage message;
  final double messageWidth;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onSendAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
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
            width: _SmsOutboxTable._selectWidth,
            child: _SmsOutboxCheckbox(
              value: selected,
              onChanged: (_) => onToggle(),
            ),
          ),
          SizedBox(
            width: _SmsOutboxTable._recipientWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.recipient,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.placeholder,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: messageWidth,
            child: Text(
              message.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(
            width: _SmsOutboxTable._senderWidth,
            child: Text(
              message.senderLine,
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
          SizedBox(
            width: _SmsOutboxTable._statusWidth,
            child: _SmsOutboxStatusBadge(status: message.status),
          ),
          SizedBox(
            width: _SmsOutboxTable._dateWidth,
            child: _SmsOutboxDateCell(message: message),
          ),
          SizedBox(
            width: _SmsOutboxTable._menuWidth,
            child: Align(
              alignment: Alignment.center,
              child: _SmsOutboxRowMenu(onSendAgain: onSendAgain),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmsOutboxCheckbox extends StatelessWidget {
  const _SmsOutboxCheckbox({
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
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onChanged: onChanged,
    );
  }
}

class _SmsOutboxHeaderSortable extends StatelessWidget {
  const _SmsOutboxHeaderSortable({
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
    final selected = sortState.key == sortKey;
    final icon = SymbolIcon(
      Symbols.keyboard_arrow_down,
      color: selected ? AppColors.deepOcean : AppColors.support,
      size: 14,
    );

    return SizedBox(
      width: width,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSort(sortKey),
          child: Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  context.t(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.deepOcean : AppColors.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              selected && sortState.ascending
                  ? RotatedBox(quarterTurns: 2, child: icon)
                  : icon,
            ],
          ),
        ),
      ),
    );
  }
}

class _SmsOutboxHeaderText extends StatelessWidget {
  const _SmsOutboxHeaderText(this.label, {this.centered = false});

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
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SmsOutboxDateCell extends StatelessWidget {
  const _SmsOutboxDateCell({required this.message});

  final _SmsOutboxMessage message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatAdminFullDate(context, message.createdAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          formatAdminTime(message.createdAt),
          style: const TextStyle(
            color: AppColors.support,
            fontSize: 10,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _SmsOutboxRowMenu extends StatefulWidget {
  const _SmsOutboxRowMenu({required this.onSendAgain});

  final VoidCallback onSendAgain;

  @override
  State<_SmsOutboxRowMenu> createState() => _SmsOutboxRowMenuState();
}

class _SmsOutboxRowMenuState extends State<_SmsOutboxRowMenu> {
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
              child: _SmsOutboxMenuCard(
                onSendAgain: () => _runAndClose(widget.onSendAgain),
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
        message: context.t('sms.outbox.actions'),
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

class _SmsOutboxMenuCard extends StatelessWidget {
  const _SmsOutboxMenuCard({required this.onSendAgain});

  final VoidCallback onSendAgain;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 170,
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
        child: _SmsOutboxMenuItem(
          icon: Symbols.redo,
          label: 'sms.outbox.action.sendAgain',
          onTap: onSendAgain,
        ),
      ),
    );
  }
}

class _SmsOutboxMenuItem extends StatelessWidget {
  const _SmsOutboxMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(AppRadius.value),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            SymbolIcon(icon, color: AppColors.deepOcean, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.deepOcean,
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

class _SmsOutboxEmpty extends StatelessWidget {
  const _SmsOutboxEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('sms.outbox.empty'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SmsOutboxStatusBadge extends StatelessWidget {
  const _SmsOutboxStatusBadge({required this.status});

  final _SmsOutboxStatus status;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: status.backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: status.dotColor.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: status.dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                context.t(status.labelKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: status.dotColor,
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

class _SmsOutboxFooter extends StatelessWidget {
  const _SmsOutboxFooter({
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
        final pager = _SmsOutboxPagination(
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

class _SmsOutboxPagination extends StatelessWidget {
  const _SmsOutboxPagination({
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
        _SmsOutboxPagerButton(
          label: '<<',
          enabled: page > 1,
          onPressed: () => onPageChanged(1),
        ),
        const SizedBox(width: 8),
        _SmsOutboxPagerButton(
          label: '<',
          enabled: page > 1,
          onPressed: () => onPageChanged(page - 1),
        ),
        const SizedBox(width: 8),
        AdminTablePageButton(label: page.toString(), selected: true),
        const SizedBox(width: 8),
        _SmsOutboxPagerButton(
          label: '>',
          enabled: page < lastPage,
          onPressed: () => onPageChanged(page + 1),
        ),
        const SizedBox(width: 8),
        _SmsOutboxPagerButton(
          label: '>>',
          enabled: page < lastPage,
          onPressed: () => onPageChanged(lastPage),
        ),
      ],
    );
  }
}

class _SmsOutboxPagerButton extends StatelessWidget {
  const _SmsOutboxPagerButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AdminTablePageButton(
      label: label,
      enabled: enabled,
      onPressed: onPressed,
    );
  }
}

class SmsSendDrawer extends StatefulWidget {
  const SmsSendDrawer({super.key, required this.onClose, required this.onSend});

  final VoidCallback onClose;
  final ValueChanged<SmsSendDraft> onSend;

  @override
  State<SmsSendDrawer> createState() => _SmsSendDrawerState();
}

class _SmsSendDrawerState extends State<SmsSendDrawer> {
  final _recipientController = TextEditingController();
  final _senderController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_refresh);
  }

  @override
  void dispose() {
    _messageController
      ..removeListener(_refresh)
      ..dispose();
    _recipientController.dispose();
    _senderController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final message = _messageController.text;
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 820;
        return Padding(
          padding: EdgeInsets.all(mobile ? 14 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SmsSendHeader(onClose: widget.onClose),
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
                          child: _SmsSendContent(
                            recipientController: _recipientController,
                            senderController: _senderController,
                            messageController: _messageController,
                            message: message,
                            mobile: true,
                          ),
                        )
                      : _SmsSendContent(
                          recipientController: _recipientController,
                          senderController: _senderController,
                          messageController: _messageController,
                          message: message,
                          mobile: false,
                        ),
                ),
              ),
              const SizedBox(height: 16),
              _SmsSendActions(
                mobile: mobile,
                onQueue: _submit,
                onSchedule: _submit,
                onSend: _submit,
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit() {
    widget.onSend(
      SmsSendDraft(
        recipients: _recipientController.text,
        senderLine: _senderController.text,
        message: _messageController.text,
      ),
    );
  }
}

class SmsSendDraft {
  const SmsSendDraft({
    required this.recipients,
    required this.senderLine,
    required this.message,
  });

  final String recipients;
  final String senderLine;
  final String message;
}

class _SmsSendHeader extends StatelessWidget {
  const _SmsSendHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.sms_outlined, size: 21, color: AppColors.iconMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.t('sms.outbox.drawer.title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          mouseCursor: SystemMouseCursors.click,
          tooltip: context.t('common.cancel'),
          icon: const SymbolIcon(
            Symbols.close,
            color: AppColors.deepOcean,
            size: 22,
          ),
        ),
      ],
    );
  }
}

class _SmsSendContent extends StatelessWidget {
  const _SmsSendContent({
    required this.recipientController,
    required this.senderController,
    required this.messageController,
    required this.message,
    required this.mobile,
  });

  final TextEditingController recipientController;
  final TextEditingController senderController;
  final TextEditingController messageController;
  final String message;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final info = _SmsSendInfoFields(
      recipientController: recipientController,
      senderController: senderController,
      mobile: mobile,
    );

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          info,
          const SizedBox(height: 14),
          SizedBox(
            height: 430,
            child: _SmsSendEditor(controller: messageController),
          ),
          const SizedBox(height: 14),
          SizedBox(height: 600, child: _SmsSendPreviewPanel(message: message)),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 14),
                SizedBox(
                  height: 340,
                  child: _SmsSendEditor(controller: messageController),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(width: 360, child: _SmsSendPreviewPanel(message: message)),
      ],
    );
  }
}

class _SmsSendInfoFields extends StatelessWidget {
  const _SmsSendInfoFields({
    required this.recipientController,
    required this.senderController,
    required this.mobile,
  });

  final TextEditingController recipientController;
  final TextEditingController senderController;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final accountField = _SmsSendField(
      controller: senderController,
      label: 'sms.outbox.drawer.account',
      hint: 'SMS hesabı',
    );
    const templateField = _SmsSendSelectField(
      label: 'sms.outbox.drawer.template',
      value: 'sms.outbox.drawer.templateValue',
    );
    final recipientField = _SmsSendField(
      controller: recipientController,
      label: 'sms.outbox.drawer.to',
      hint: '+90 532 000 00 00',
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
        icon: const SymbolIcon(Symbols.group, size: 18),
        label: Text(context.t('sms.outbox.drawer.addContact')),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        recipientField,
      ],
    );
  }
}

class _SmsSendField extends StatelessWidget {
  const _SmsSendField({
    required this.controller,
    required this.label,
    required this.hint,
    this.action,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _SmsSendFieldShell(
      label: label,
      action: action,
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 1,
        cursorColor: AppColors.support,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        decoration: _smsSendInputDecoration(hint),
      ),
    );
  }
}

class _SmsSendSelectField extends StatelessWidget {
  const _SmsSendSelectField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _SmsSendFieldShell(
      label: label,
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.82)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.t(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SymbolIcon(
              Symbols.keyboard_arrow_down,
              size: 18,
              color: AppColors.iconMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SmsSendFieldShell extends StatelessWidget {
  const _SmsSendFieldShell({
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

InputDecoration _smsSendInputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    hintStyle: const TextStyle(
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

class _SmsSendPreviewPanel extends StatelessWidget {
  const _SmsSendPreviewPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            SmsImessagePreview(
              message: message,
              contactName: 'Jane',
              avatarInitial: 'P',
              width: 284,
              height: 470,
              maxBubbleLines: 8,
            ),
            const SizedBox(height: 12),
            SmsStatsRow(message: message, compact: true),
          ],
        ),
      ),
    );
  }
}

class _SmsSendActions extends StatelessWidget {
  const _SmsSendActions({
    required this.mobile,
    required this.onQueue,
    required this.onSchedule,
    required this.onSend,
  });

  final bool mobile;
  final VoidCallback onQueue;
  final VoidCallback onSchedule;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final queue = _SmsSendFooterButton(
      label: 'sms.outbox.drawer.queue',
      icon: Symbols.draft,
      onPressed: onQueue,
    );
    final schedule = _SmsSendFooterButton(
      label: 'sms.outbox.drawer.schedule',
      icon: Symbols.schedule,
      onPressed: onSchedule,
    );
    final send = _SmsSendFooterButton(
      label: 'sms.outbox.drawer.send',
      icon: Symbols.schedule_send,
      primary: true,
      onPressed: onSend,
    );

    if (mobile) {
      return Row(
        children: [
          Expanded(child: queue),
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
        queue,
        const SizedBox(width: 12),
        schedule,
        const SizedBox(width: 12),
        send,
      ],
    );
  }
}

class _SmsSendFooterButton extends StatelessWidget {
  const _SmsSendFooterButton({
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

class _SmsSendEditor extends StatelessWidget {
  const _SmsSendEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final stats = SmsSegmentStats.fromText(controller.text);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xFF282B33),
            child: Row(
              children: [
                Text(
                  context.t('sms.outbox.drawer.message'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 20),
                const _SmsEditorToolbarLabel(label: 'B'),
                const SizedBox(width: 8),
                const _SmsEditorToolbarLabel(label: 'I', italic: true),
                const Spacer(),
                SmsMetricPill(
                  label: '${stats.characterCount} ${stats.encodingLabel}',
                  compact: true,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                SmsMetricPill(
                  label: '${stats.segmentCount} SMS',
                  compact: true,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                SmsMetricPill(
                  label:
                      '${stats.remaining} ${context.t('sms.preview.remaining')}',
                  compact: true,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: Colors.white,
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: null,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.45,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                focusColor: Colors.white,
                hoverColor: Colors.white,
                hintText: context.t('sms.outbox.drawer.messageHint'),
                hintStyle: const TextStyle(
                  color: AppColors.placeholder,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmsEditorToolbarLabel extends StatelessWidget {
  const _SmsEditorToolbarLabel({required this.label, this.italic = false});

  final String label;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
