import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../shared/icons/symbols.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_whatsapp_repository.dart';
import 'whatsapp_models.dart';

class WhatsappMessagingScreen extends StatefulWidget {
  const WhatsappMessagingScreen({
    super.key,
    required this.session,
    this.repository = const NeonAdminWhatsappRepository(),
  });

  final AdminSession session;
  final AdminWhatsappRepository repository;

  @override
  State<WhatsappMessagingScreen> createState() =>
      _WhatsappMessagingScreenState();
}

class _WhatsappMessagingScreenState extends State<WhatsappMessagingScreen> {
  var _chats = <WhatsappChat>[];
  int? _selectedChatId;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _isSendingMessage = false;
  bool _showAiHelper = false;
  bool _loading = true;

  WhatsappChat? get _selectedChat {
    if (_selectedChatId == null) return null;
    for (final chat in _chats) {
      if (chat.id == _selectedChatId) return chat;
    }
    return null;
  }

  List<WhatsappChat> get _filteredChats {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _chats;
    return _chats.where((chat) {
      return chat.name.toLowerCase().contains(query) ||
          chat.lastMessage.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadChats());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() => _loading = true);
    try {
      final chats = await widget.repository.fetchChats(widget.session);
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _selectedChatId = chats.any((chat) => chat.id == _selectedChatId)
            ? _selectedChatId
            : chats.firstOrNull?.id;
        _loading = false;
      });
      if (_selectedChatId != null) unawaited(_markSelectedChatAsRead());
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showWhatsappError(error);
    }
  }

  void _showWhatsappError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _markSelectedChatAsRead() async {
    final selectedId = _selectedChatId;
    if (selectedId == null) return;
    final index = _chats.indexWhere((chat) => chat.id == selectedId);
    if (index != -1 && _chats[index].unreadCount > 0) {
      List<WhatsappMessage>? liveMessages;
      try {
        liveMessages = await widget.repository.markChatRead(
          widget.session,
          selectedId,
        );
      } catch (error) {
        if (mounted) _showWhatsappError(error);
      }
      if (!mounted) return;
      setState(() {
        final currentChat = _chats[index];
        final updatedMessages =
            liveMessages ??
            currentChat.messages.map((msg) {
              return msg.isOutgoing ? msg : msg.copyWith(isRead: true);
            }).toList();

        _chats[index] = currentChat.copyWith(
          unreadCount: 0,
          messages: updatedMessages,
        );
      });
    }
  }

  void _selectChat(int id) {
    setState(() {
      _selectedChatId = id;
      _showAiHelper = false;
    });
    unawaited(_markSelectedChatAsRead());
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedChatId == null) return;

    final chatIndex = _chats.indexWhere((chat) => chat.id == _selectedChatId);
    if (chatIndex == -1) return;

    final currentChat = _chats[chatIndex];
    setState(() {
      _messageController.clear();
      _showAiHelper = false;
      _isSendingMessage = true;
    });

    try {
      final updated = await widget.repository.sendMessage(
        widget.session,
        chatId: currentChat.id,
        text: text,
      );
      if (!mounted) return;
      setState(() {
        _chats = [
          for (final chat in _chats)
            if (chat.id == updated.id) updated else chat,
        ];
        _isSendingMessage = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messageController.text = text;
        _isSendingMessage = false;
      });
      _showWhatsappError(error);
    }
  }

  void _applyAiSuggestion(String text) {
    setState(() {
      _messageController.text = text;
      _showAiHelper = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;
        final selectedChat = _selectedChat;

        if (isCompact && selectedChat != null) {
          return _buildChatWindow(selectedChat, isCompact: true);
        }

        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value * 2),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: isCompact ? constraints.maxWidth : 340,
                child: _buildChatListPanel(),
              ),

              if (!isCompact) Container(width: 1, color: AppColors.line),

              if (!isCompact)
                Expanded(
                  child: selectedChat == null
                      ? _buildEmptyState()
                      : _buildChatWindow(selectedChat, isCompact: false),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatListPanel() {
    final filtered = _filteredChats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title and Info
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                context.t('nav.whatsapp.messaging'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Color(0xFF25D366),
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'API AKTİF',
                      style: TextStyle(
                        color: Color(0xFF25D366),
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(fontSize: 13, color: AppColors.deepOcean),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              fillColor: AppColors.surface,
              filled: true,
              hintText: context.t('whatsapp.search'),
              hintStyle: const TextStyle(
                color: AppColors.placeholder,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Symbols.search,
                size: 18,
                color: AppColors.placeholder,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                borderSide: const BorderSide(color: AppColors.deepOcean),
              ),
            ),
          ),
        ),

        const Divider(color: AppColors.softLine),

        // Chat List View
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Sohbet bulunamadı',
                    style: TextStyle(color: AppColors.support, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    color: AppColors.softLine,
                    indent: 64,
                  ),
                  itemBuilder: (context, index) {
                    final chat = filtered[index];
                    final isSelected = chat.id == _selectedChatId;

                    return InkWell(
                      onTap: () => _selectChat(chat.id),
                      mouseCursor: SystemMouseCursors.click,
                      child: Container(
                        color: isSelected
                            ? AppColors.surface
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            _buildAvatar(chat),
                            const SizedBox(width: 12),

                            // Text details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          chat.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppColors.deepOcean,
                                            fontWeight: chat.unreadCount > 0
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTime(chat.time),
                                        style: TextStyle(
                                          color: chat.unreadCount > 0
                                              ? AppColors.actionRed
                                              : AppColors.placeholder,
                                          fontSize: 10,
                                          fontWeight: chat.unreadCount > 0
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          chat.lastMessage,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: chat.unreadCount > 0
                                                ? AppColors.deepOcean
                                                : AppColors.support,
                                            fontSize: 11,
                                            fontWeight: chat.unreadCount > 0
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (chat.unreadCount > 0) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: AppColors.actionRed,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${chat.unreadCount}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChatWindow(WhatsappChat chat, {required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              // Back Button on Compact View
              if (isCompact) ...[
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.deepOcean,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedChatId = null;
                    });
                  },
                ),
                const SizedBox(width: 4),
              ],

              _buildAvatar(chat),
              const SizedBox(width: 12),

              // User Info details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.name,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _isSendingMessage
                                ? Colors.amber
                                : chat.isOnline
                                ? const Color(0xFF25D366)
                                : AppColors.support,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isSendingMessage
                              ? context.t('whatsapp.typing')
                              : chat.isOnline
                              ? context.t('whatsapp.online')
                              : 'Çevrim dışı',
                          style: TextStyle(
                            color: _isSendingMessage
                                ? Colors.amber[800]
                                : chat.isOnline
                                ? const Color(0xFF25D366)
                                : AppColors.support,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Header actions stubs
              IconButton(
                icon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.iconMuted,
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  size: 20,
                  color: AppColors.iconMuted,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ),

        // Message stream Area
        Expanded(
          child: Container(
            color: AppColors.surface,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chat.messages.length + (_isSendingMessage ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == chat.messages.length && _isSendingMessage) {
                  return _buildTypingIndicatorBubble();
                }

                final message = chat.messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
        ),

        // AI replies panel popup overlay (if active)
        if (_showAiHelper) _buildAiHelperPanel(chat),

        // Bottom Input typing bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              // Attach button
              IconButton(
                icon: const Icon(Icons.attach_file, color: AppColors.iconMuted),
                onPressed: () {},
              ),

              // AI Assist button
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showAiHelper = !_showAiHelper;
                  });
                },
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: Text(context.t('whatsapp.aiWriter')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepOcean,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Text Field Input
              Expanded(
                child: TextField(
                  controller: _messageController,
                  onSubmitted: (_) => _sendMessage(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.deepOcean,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    fillColor: AppColors.surface,
                    filled: true,
                    hintText: context.t('whatsapp.placeholder'),
                    hintStyle: const TextStyle(
                      color: AppColors.placeholder,
                      fontSize: 13,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.value),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.value),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send button
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.actionRed),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line, width: 2),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: AppColors.placeholder,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.t('whatsapp.emptyState'),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 420,
              child: Text(
                context.t('whatsapp.emptyStateSubtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.support,
                  height: 1.5,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(WhatsappChat chat) {
    // Generate simple dynamic gradient or color block for the contact initials
    final initials = chat.name
        .split(' ')
        .take(2)
        .map((s) => s.substring(0, 1))
        .join('')
        .toUpperCase();
    final hash = chat.name.hashCode;
    final color = Colors.primaries[hash % Colors.primaries.length];

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(WhatsappMessage message) {
    return Align(
      alignment: message.isOutgoing
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: message.isOutgoing ? Colors.white : AppColors.softLine,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: Radius.circular(message.isOutgoing ? 8 : 0),
            bottomRight: Radius.circular(message.isOutgoing ? 0 : 8),
          ),
          border: Border.all(
            color: message.isOutgoing ? AppColors.line : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(
                    color: AppColors.placeholder,
                    fontSize: 9,
                  ),
                ),
                if (message.isOutgoing) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 13,
                    color: message.isRead ? Colors.blue : AppColors.placeholder,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicatorBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.softLine,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 3),
            _buildDot(1),
            const SizedBox(width: 3),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.support,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildAiHelperPanel(WhatsappChat chat) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F4),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: const Color(0xFFC7E3D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: Color(0xFF2E7D32),
              ),
              const SizedBox(width: 6),
              const Text(
                'Yapay Zeka Destekli Akıllı Yanıtlar',
                style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _showAiHelper = false),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Sohbet akışına göre önerilen yapay zeka taslakları:',
            style: TextStyle(
              color: Color(0xFF388E3C),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...chat.aiReplies.map((reply) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => _applyAiSuggestion(reply),
                mouseCursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.value),
                    border: Border.all(color: const Color(0xFFD0E6DF)),
                  ),
                  child: Text(
                    reply,
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hours = dt.hour.toString().padLeft(2, '0');
    final minutes = dt.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}
