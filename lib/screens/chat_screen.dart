import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../models/chat_state.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/message_input.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/typing_indicator.dart';
import '../services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/premium_background.dart';
import 'room_details_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.isGroup = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final RoomService _roomService = RoomService();
  String? _userId;
  List<Map<String, dynamic>> _members = [];
  Map<String, dynamic>? _replyingTo;
  Map<String, dynamic>? _editingMessage;

  @override
  void initState() {
    super.initState();
    _initUser();
    _loadMembers();
  }

  Future<void> _initUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userId = prefs.getString('user_id'));
  }

  Future<void> _loadMembers() async {
    try {
      final members = await _roomService.getRoomMembers(widget.roomId);
      if (mounted) setState(() => _members = members);
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.roomId));
    final messages = chatState.messages;
    final isLoading = chatState.isLoading;
    final typingUsers = chatState.typingUsers;

    ref.listen<ChatState>(chatProvider(widget.roomId), (previous, next) {
      final messagesChanged = previous?.messages.length != next.messages.length;
      final loadingFinished = (previous?.isLoading ?? true) && !next.isLoading;
      if (messagesChanged || loadingFinished) {
        _scrollToBottom();
      }
    });

    return PremiumBackground(
      showPattern: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: ChatAppBar(
        roomId: widget.roomId,
        roomName: widget.roomName,
        isGroup: widget.isGroup,
        onShowInfo: _showGroupInfo,
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const SizedBox.shrink()
                : ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final realIndex = messages.length - 1 - index;
                      final msg = messages[realIndex];
                      final msgId = msg['message_id']?.toString() ?? msg['id']?.toString() ?? '';
                      final isMe = msg['sender_id'].toString() == _userId;

                      // Déterminer si on doit afficher une puce de date au-dessus de ce message
                      final bool showDateChip = _shouldShowDateChip(messages, realIndex);

                      final bubble = MessageBubble(
                        content: msg['content'] ?? '',
                        isMe: isMe,
                        timestamp: msg['timestamp'] ?? msg['created_at'] ?? '',
                        type: msg['message_type'] ?? 'text',
                        status: msg['status'] ?? 'sent',
                        isRead: msg['is_read'] == true || msg['is_read'] == 1,
                        isEncrypted: msg['is_encrypted'] == true,
                        replyToContent: msg['reply_to_content'] ?? msg['metadata_']?['reply_to_content'],
                        caption: msg['caption'] ?? msg['metadata_']?['caption'],
                        localPath: msg['local_path'],
                        currentUserId: _userId,
                        senderName: chatState.members[msg['sender_id'].toString()],
                        senderAvatar: chatState.memberAvatars[msg['sender_id'].toString()],
                        showSenderName: widget.isGroup && !isMe,
                        reactions: msg['reactions'] != null
                            ? Map<String, dynamic>.from(msg['reactions'] as Map)
                            : null,
                        onReaction: msgId.isNotEmpty
                            ? (emoji) => ref
                                .read(chatProvider(widget.roomId).notifier)
                                .toggleReaction(msgId, emoji)
                            : null,
                        onReply: () => setState(() => _replyingTo = msg),
                        onEdit: () => setState(() {
                          _editingMessage = {...msg, 'id': msgId};
                          _replyingTo = null;
                        }),
                        onDelete: () => ref
                            .read(chatProvider(widget.roomId).notifier)
                            .deleteMessage(msgId),
                        messageId: msgId,
                        roomId: widget.roomId,
                        metadata: msg['metadata_'] != null
                            ? Map<String, dynamic>.from(msg['metadata_'] as Map)
                            : null,
                      );

                      if (showDateChip) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDateChip(msg['timestamp'] ?? msg['created_at'] ?? ''),
                            bubble,
                          ],
                        );
                      }
                      return bubble;
                    },
                  ),
          ),
          
          if (typingUsers.isNotEmpty) const TypingIndicator(),
          

          MessageInput(
            roomId: widget.roomId,
            replyingTo: _replyingTo,
            onCancelReply: () => setState(() => _replyingTo = null),
            members: _members,
            editingMessage: _editingMessage,
            onCancelEdit: () => setState(() => _editingMessage = null),
          ),
        ],
      ),
    ),
    );
  }

  bool _shouldShowDateChip(List<Map<String, dynamic>> messages, int index) {
    if (index == 0) return true;
    
    try {
      final currentMsgDate = DateTime.parse(messages[index]['timestamp'] ?? messages[index]['created_at']).toLocal();
      final previousMsgDate = DateTime.parse(messages[index - 1]['timestamp'] ?? messages[index - 1]['created_at']).toLocal();
      
      return currentMsgDate.year != previousMsgDate.year ||
             currentMsgDate.month != previousMsgDate.month ||
             currentMsgDate.day != previousMsgDate.day;
    } catch (_) {
      return false;
    }
  }

  Widget _buildDateChip(String timestamp) {
    String dateText = '';
    try {
      final date = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final msgDate = DateTime(date.year, date.month, date.day);

      if (msgDate == today) {
        dateText = "AUJOURD'HUI";
      } else if (msgDate == yesterday) {
        dateText = "HIER";
      } else {
        final months = [
          'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 
          'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
        ];
        dateText = '${date.day} ${months[date.month - 1]} ${date.year}';
      }
    } catch (_) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF182229) 
              : const Color(0xFFE1F5FE),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          dateText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white70 
                : Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  void _showGroupInfo() {
    final chatState = ref.read(chatProvider(widget.roomId));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomDetailsScreen(
          roomId: widget.roomId,
          roomName: widget.roomName,
          isGroup: widget.isGroup,
          avatarUrl: chatState.otherUserAvatarUrl,
          members: _members,
        ),
      ),
    );
  }
}
