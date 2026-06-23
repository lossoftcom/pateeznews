import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../shared/icons/symbols.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_whatsapp_repository.dart';
import 'whatsapp_mobile_chrome.dart';
import 'whatsapp_models.dart';
import 'whatsapp_template_models.dart';

class WhatsappMessagingScreen extends StatefulWidget {
  const WhatsappMessagingScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminWhatsappRepository(),
  });

  final AdminSession session;
  final AdminWhatsappRepository repository;

  @override
  State<WhatsappMessagingScreen> createState() =>
      _WhatsappMessagingScreenState();
}

class _WhatsappMessagingScreenState extends State<WhatsappMessagingScreen> {
  var _chats = <WhatsappChat>[];
  var _templates = <AdminWhatsappTemplate>[];
  int? _selectedChatId;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _isSendingMessage = false;
  bool _isSendingTemplate = false;
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
          chat.phone.toLowerCase().contains(query) ||
          chat.lastMessage.toLowerCase().contains(query);
    }).toList();
  }

  List<AdminWhatsappTemplate> get _readyTemplates => _templates
      .where((template) => template.active && template.ready)
      .toList(growable: false);

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
      final results = await Future.wait([
        widget.repository.fetchChats(widget.session),
        widget.repository.fetchTemplates(widget.session),
      ]);
      final chats = results[0] as List<WhatsappChat>;
      final templates = results[1] as List<AdminWhatsappTemplate>;
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _templates = templates;
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
    AdminToast.show(
      context,
      message: error.toString(),
      tone: AdminToastTone.error,
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

  void _replaceChat(WhatsappChat updated) {
    setState(() {
      final exists = _chats.any((chat) => chat.id == updated.id);
      _chats = [
        updated,
        for (final chat in _chats)
          if (chat.id != updated.id) chat,
      ];
      if (!exists) {
        _searchQuery = '';
      }
      _selectedChatId = updated.id;
      _showAiHelper = false;
    });
    _scrollToBottom();
  }

  Future<void> _openManualChatDialog() async {
    final request = await showWhatsappSideDrawer<_ManualWhatsappChatRequest>(
      context: context,
      minWidth: 380,
      maxWidth: 540,
      child: _ManualWhatsappChatDialog(templates: _readyTemplates),
    );
    if (request == null || !mounted) return;

    try {
      var chat = await widget.repository.startChat(
        widget.session,
        phone: request.phone,
        name: request.name,
      );
      if (request.templateId != null) {
        chat = await widget.repository.sendTemplate(
          widget.session,
          chatId: chat.id,
          templateId: request.templateId!,
          languageCode: request.languageCode,
        );
      }
      if (!mounted) return;
      _replaceChat(chat);
    } catch (error) {
      if (mounted) _showWhatsappError(error);
    }
  }

  Future<void> _sendTemplate(
    WhatsappChat chat,
    AdminWhatsappTemplate template,
  ) async {
    if (_isSendingTemplate) return;
    setState(() {
      _isSendingTemplate = true;
      _showAiHelper = false;
    });
    try {
      final updated = await widget.repository.sendTemplate(
        widget.session,
        chatId: chat.id,
        templateId: template.id,
        languageCode: _defaultLanguageForTemplate(template),
      );
      if (!mounted) return;
      _replaceChat(updated);
    } catch (error) {
      if (mounted) _showWhatsappError(error);
    } finally {
      if (mounted) setState(() => _isSendingTemplate = false);
    }
  }

  String _defaultLanguageForTemplate(AdminWhatsappTemplate template) {
    return template.nameKey.trim() == 'hello_world' ? 'en_US' : 'tr';
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
    if (!currentChat.canSendFreeform) {
      AdminToast.show(
        context,
        message: context.t('whatsapp.messaging.templateRequiredToast'),
        tone: AdminToastTone.info,
      );
      return;
    }
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 360;

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('nav.whatsapp.messaging'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: context.t('whatsapp.messaging.newChat'),
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 34,
                          height: 34,
                        ),
                        onPressed: _openManualChatDialog,
                        mouseCursor: SystemMouseCursors.click,
                        icon: const Icon(
                          Symbols.add,
                          color: AppColors.deepOcean,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildApiStatusBadge(compact: compactHeader),
                ],
              );
            },
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

  Widget _buildApiStatusBadge({required bool compact}) {
    return Tooltip(
      message: 'API AKTİF',
      child: SizedBox(
        width: compact ? 34 : 86,
        height: 28,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 9),
          decoration: BoxDecoration(
            color: const Color(0xFF25D366).withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF25D366).withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Symbols.check_circle,
                color: Color(0xFF25D366),
                size: 13,
              ),
              if (!compact) ...[
                const SizedBox(width: 5),
                const Flexible(
                  child: Text(
                    'API AKTİF',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF25D366),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
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

  Widget _buildChatWindow(WhatsappChat chat, {required bool isCompact}) {
    final canSendFreeform = chat.canSendFreeform;
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
                    Symbols.arrow_back,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: !canSendFreeform
                                ? AppColors.warmHorizon
                                : _isSendingMessage
                                ? Colors.amber
                                : chat.isOnline
                                ? const Color(0xFF25D366)
                                : AppColors.support,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            !canSendFreeform
                                ? context.t(
                                    'whatsapp.messaging.templateRequired',
                                  )
                                : _isSendingMessage
                                ? context.t('whatsapp.typing')
                                : chat.isOnline
                                ? context.t('whatsapp.online')
                                : 'Çevrim dışı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: !canSendFreeform
                                  ? AppColors.warmHorizon
                                  : _isSendingMessage
                                  ? Colors.amber[800]
                                  : chat.isOnline
                                  ? const Color(0xFF25D366)
                                  : AppColors.support,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0,
                            ),
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
                  Symbols.search,
                  size: 20,
                  color: AppColors.iconMuted,
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(
                  Symbols.more_vert,
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
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFFEAF2EA)),
            child: CustomPaint(
              painter: const _WhatsappWallpaperPainter(),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
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
        ),

        // AI replies panel popup overlay (if active)
        if (_showAiHelper) _buildAiHelperPanel(chat),

        if (!canSendFreeform) _buildTemplateGate(chat),

        _buildComposerBar(canSendFreeform),
      ],
    );
  }

  Widget _buildComposerBar(bool canSendFreeform) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F0E8),
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          final aiActive = canSendFreeform && _showAiHelper;
          final aiButton = SizedBox(
            width: compact ? 40 : 128,
            height: 40,
            child: TextButton(
              onPressed: canSendFreeform
                  ? () => setState(() => _showAiHelper = !_showAiHelper)
                  : null,
              style: TextButton.styleFrom(
                backgroundColor: aiActive
                    ? AppColors.deepOcean
                    : canSendFreeform
                    ? Colors.white
                    : AppColors.softLine,
                foregroundColor: aiActive
                    ? Colors.white
                    : canSendFreeform
                    ? AppColors.deepOcean
                    : AppColors.support,
                disabledForegroundColor: AppColors.placeholder,
                padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: aiActive
                        ? AppColors.deepOcean
                        : AppColors.line.withValues(alpha: 0.88),
                  ),
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              child: compact
                  ? const Icon(Symbols.auto_awesome, size: 16)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Symbols.auto_awesome, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            context.t('whatsapp.aiWriter'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Symbols.attach_file,
                    color: canSendFreeform
                        ? AppColors.iconMuted
                        : AppColors.placeholder,
                    size: 20,
                  ),
                  onPressed: canSendFreeform ? () {} : null,
                  mouseCursor: SystemMouseCursors.click,
                ),
              ),
              if (!compact) ...[aiButton, const SizedBox(width: 8)],
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.025),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _messageController,
                    enabled: canSendFreeform,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.deepOcean,
                      height: 1.35,
                      letterSpacing: 0,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      hintText: canSendFreeform
                          ? context.t('whatsapp.placeholder')
                          : context.t(
                              'whatsapp.messaging.templateRequiredInput',
                            ),
                      hintStyle: const TextStyle(
                        color: AppColors.placeholder,
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
              if (compact) ...[const SizedBox(width: 7), aiButton],
              const SizedBox(width: 7),
              SizedBox(
                width: 42,
                height: 42,
                child: TextButton(
                  onPressed: canSendFreeform ? _sendMessage : null,
                  style: TextButton.styleFrom(
                    backgroundColor: canSendFreeform
                        ? AppColors.actionRed
                        : AppColors.softLine,
                    foregroundColor: canSendFreeform
                        ? Colors.white
                        : AppColors.placeholder,
                    disabledForegroundColor: AppColors.placeholder,
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Symbols.send, size: 20),
                ),
              ),
            ],
          );
        },
      ),
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
                Symbols.chat_bubble_outline,
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

  Widget _buildTemplateGate(WhatsappChat chat) {
    final templates = _readyTemplates;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBEB),
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final action = templates.isEmpty
              ? Text(
                  context.t('whatsapp.messaging.noReadyTemplate'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.support,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : PopupMenuButton<AdminWhatsappTemplate>(
                  tooltip: context.t('whatsapp.messaging.sendTemplate'),
                  enabled: !_isSendingTemplate,
                  onSelected: (template) => _sendTemplate(chat, template),
                  itemBuilder: (context) => [
                    for (final template in templates)
                      PopupMenuItem<AdminWhatsappTemplate>(
                        value: template,
                        child: Text(
                          template.nameKey,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _isSendingTemplate
                          ? AppColors.softLine
                          : AppColors.deepOcean,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.verified,
                          color: _isSendingTemplate
                              ? AppColors.support
                              : Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 7),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: compact ? 108 : 128,
                          ),
                          child: Text(
                            _isSendingTemplate
                                ? context.t(
                                    'whatsapp.messaging.sendingTemplate',
                                  )
                                : context.t('whatsapp.messaging.sendTemplate'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _isSendingTemplate
                                  ? AppColors.support
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

          final note = Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.warmHorizon.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: const Icon(
                  Symbols.lock,
                  color: AppColors.warmHorizon,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t('whatsapp.messaging.templateGate'),
                  maxLines: compact ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                note,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: note),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: action,
              ),
            ],
          );
        },
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
    final outgoing = message.isOutgoing;
    final bubbleColor = outgoing ? const Color(0xFFE1FFC7) : Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth < 540
            ? constraints.maxWidth * 0.82
            : 430.0;

        return Align(
          alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 2,
                right: outgoing ? 2 : null,
                left: outgoing ? null : 2,
                child: _BubbleTail(outgoing: outgoing, color: bubbleColor),
              ),
              Container(
                margin: EdgeInsets.only(
                  left: outgoing ? 0 : 8,
                  right: outgoing ? 8 : 0,
                  bottom: 7,
                ),
                constraints: BoxConstraints(maxWidth: maxWidth),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(outgoing ? 17 : 4),
                    topRight: Radius.circular(outgoing ? 4 : 17),
                    bottomLeft: const Radius.circular(17),
                    bottomRight: const Radius.circular(17),
                  ),
                  border: Border.all(
                    color: outgoing
                        ? const Color(0xFFCDEDBB)
                        : AppColors.line.withValues(alpha: 0.78),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.045),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 13,
                        height: 1.36,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.timestamp),
                            style: const TextStyle(
                              color: AppColors.placeholder,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                          if (outgoing) ...[
                            const SizedBox(width: 4),
                            Icon(
                              message.isRead ? Symbols.done_all : Symbols.done,
                              size: 13,
                              color: message.isRead
                                  ? const Color(0xFF34B7F1)
                                  : AppColors.placeholder,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicatorBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 8, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(17),
            bottomLeft: Radius.circular(17),
            bottomRight: Radius.circular(17),
          ),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.78)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                Symbols.auto_awesome,
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
                  Symbols.close,
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

class _BubbleTail extends StatelessWidget {
  const _BubbleTail({required this.outgoing, required this.color});

  final bool outgoing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(10, 12),
      painter: _BubbleTailPainter(outgoing: outgoing, color: color),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.outgoing, required this.color});

  final bool outgoing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();

    if (outgoing) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, 0)
        ..lineTo(size.width, size.height)
        ..close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.outgoing != outgoing || oldDelegate.color != color;
  }
}

class _WhatsappWallpaperPainter extends CustomPainter {
  const _WhatsappWallpaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final mutedPaint = Paint()
      ..color = const Color(0xFF7FA38E).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var y = 28.0; y < size.height; y += 76) {
      for (var x = 22.0; x < size.width; x += 92) {
        canvas.drawCircle(Offset(x, y), 7, paint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 34, y + 12, 18, 10),
            const Radius.circular(5),
          ),
          mutedPaint,
        );
        canvas.drawLine(
          Offset(x + 10, y + 36),
          Offset(x + 28, y + 50),
          mutedPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WhatsappWallpaperPainter oldDelegate) => false;
}

class _ManualWhatsappChatRequest {
  const _ManualWhatsappChatRequest({
    required this.phone,
    required this.name,
    required this.languageCode,
    this.templateId,
  });

  final String phone;
  final String name;
  final String languageCode;
  final int? templateId;
}

class _ManualWhatsappChatDialog extends StatefulWidget {
  const _ManualWhatsappChatDialog({required this.templates});

  final List<AdminWhatsappTemplate> templates;

  @override
  State<_ManualWhatsappChatDialog> createState() =>
      _ManualWhatsappChatDialogState();
}

class _ManualWhatsappChatDialogState extends State<_ManualWhatsappChatDialog> {
  late final TextEditingController _phoneController;
  late final TextEditingController _nameController;
  late final TextEditingController _languageController;
  int? _templateId;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _nameController = TextEditingController();
    _languageController = TextEditingController(text: 'tr');
    _phoneController.addListener(_refresh);
    _nameController.addListener(_refresh);
    if (widget.templates.length == 1) {
      _templateId = widget.templates.first.id;
      _languageController.text = _defaultLanguage(widget.templates.first);
    }
  }

  @override
  void dispose() {
    _phoneController
      ..removeListener(_refresh)
      ..dispose();
    _nameController
      ..removeListener(_refresh)
      ..dispose();
    _languageController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _canSubmit {
    final phone = _normalizedPhone(_phoneController.text);
    return phone.length >= 7;
  }

  AdminWhatsappTemplate? get _selectedTemplate {
    for (final template in widget.templates) {
      if (template.id == _templateId) return template;
    }
    return null;
  }

  void _changeTemplate(int? id) {
    setState(() {
      _templateId = id;
      final template = _selectedTemplate;
      if (template != null) {
        _languageController.text = _defaultLanguage(template);
      }
    });
  }

  String _defaultLanguage(AdminWhatsappTemplate template) {
    return template.nameKey.trim() == 'hello_world' ? 'en_US' : 'tr';
  }

  String _normalizedPhone(String value) {
    return value.replaceAll(RegExp(r'[^\d+]'), '').trim();
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(
      _ManualWhatsappChatRequest(
        phone: _normalizedPhone(_phoneController.text),
        name: _nameController.text.trim(),
        templateId: _templateId,
        languageCode: _languageController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.t('whatsapp.messaging.newChatTitle'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  mouseCursor: SystemMouseCursors.click,
                  icon: const Icon(
                    Symbols.close,
                    color: AppColors.deepOcean,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ManualChatField(
                    label: context.t('whatsapp.messaging.phone'),
                    hint: context.t('whatsapp.messaging.phoneHint'),
                    controller: _phoneController,
                    icon: Symbols.phone_outlined,
                    requiredField: true,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  _ManualChatField(
                    label: context.t('whatsapp.messaging.name'),
                    hint: context.t('whatsapp.messaging.nameHint'),
                    controller: _nameController,
                    icon: Symbols.person_outline,
                    requiredField: false,
                  ),
                  const SizedBox(height: 14),
                  _ManualTemplateSelect(
                    templates: widget.templates,
                    value: _templateId,
                    onChanged: _changeTemplate,
                  ),
                  if (_templateId != null) ...[
                    const SizedBox(height: 14),
                    _ManualChatField(
                      label: context.t('whatsapp.messaging.languageCode'),
                      hint: 'tr',
                      controller: _languageController,
                      icon: Symbols.language,
                      requiredField: true,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _ManualComplianceNote(
                    hasTemplate: _templateId != null,
                    hasReadyTemplates: widget.templates.isNotEmpty,
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cancel = TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.t('common.cancel')),
                );
                final create = SizedBox(
                  height: 38,
                  child: TextButton.icon(
                    onPressed: _canSubmit ? _submit : null,
                    icon: const Icon(Symbols.add, size: 16),
                    label: Text(context.t('whatsapp.messaging.createChat')),
                    style: TextButton.styleFrom(
                      backgroundColor: _canSubmit
                          ? AppColors.deepOcean
                          : AppColors.softLine,
                      foregroundColor: _canSubmit
                          ? Colors.white
                          : AppColors.support,
                      disabledForegroundColor: AppColors.support,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.value),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );

                if (constraints.maxWidth < 420) {
                  return Row(
                    children: [
                      Expanded(child: cancel),
                      const SizedBox(width: 10),
                      Expanded(child: create),
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [cancel, const SizedBox(width: 10), create],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualTemplateSelect extends StatelessWidget {
  const _ManualTemplateSelect({
    required this.templates,
    required this.value,
    required this.onChanged,
  });

  final List<AdminWhatsappTemplate> templates;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('whatsapp.messaging.startTemplate'),
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Symbols.keyboard_arrow_down,
                color: AppColors.iconMuted,
                size: 18,
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    templates.isEmpty
                        ? context.t('whatsapp.messaging.noReadyTemplate')
                        : context.t('whatsapp.messaging.templateLater'),
                  ),
                ),
                for (final template in templates)
                  DropdownMenuItem<int?>(
                    value: template.id,
                    child: Text(template.nameKey),
                  ),
              ],
              onChanged: templates.isEmpty ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _ManualChatField extends StatelessWidget {
  const _ManualChatField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    required this.requiredField,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool requiredField;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (requiredField)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.actionRed),
                ),
            ],
          ),
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: Icon(icon, color: AppColors.support, size: 17),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 38,
            ),
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.placeholder,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: AppColors.surface,
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
      ],
    );
  }
}

class _ManualComplianceNote extends StatelessWidget {
  const _ManualComplianceNote({
    required this.hasTemplate,
    required this.hasReadyTemplates,
  });

  final bool hasTemplate;
  final bool hasReadyTemplates;

  @override
  Widget build(BuildContext context) {
    final text = !hasReadyTemplates
        ? 'whatsapp.messaging.manualNoTemplateNote'
        : hasTemplate
        ? 'whatsapp.messaging.manualTemplateNote'
        : 'whatsapp.messaging.manualNoSendNote';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: const Color(0xFFF5D48A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.verified, color: AppColors.warmHorizon, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.t(text),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
