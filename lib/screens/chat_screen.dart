import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../models/chat_state.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/message_input.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/reply_preview.dart';
import '../widgets/chat/typing_indicator.dart';
import '../widgets/chat/skeleton_message.dart';
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
          _scrollController.position.maxScrollExtent,
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
    // Optimisation : On n'écoute que les propriétés nécessaires pour éviter des rebuilds inutiles
    final messages = ref.watch(chatProvider(widget.roomId).select((s) => s.messages));
    final isLoading = ref.watch(chatProvider(widget.roomId).select((s) => s.isLoading));
    final typingUsers = ref.watch(chatProvider(widget.roomId).select((s) => s.typingUsers));

    // Auto-scroll on new messages
    ref.listen<ChatState>(chatProvider(widget.roomId), (previous, next) {
      if (previous?.messages.length != next.messages.length) {
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
                ? ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: 8,
                    itemBuilder: (context, index) => SkeletonMessage(isMe: index % 2 == 0),
                  )
                : ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return MessageBubble(
                        content: msg['content'] ?? '',
                        isMe: msg['sender_id'].toString() == _userId,
                        timestamp: msg['timestamp'] ?? msg['created_at'] ?? '',
                        type: msg['message_type'] ?? 'text',
                        status: msg['status'] ?? 'sent',
                        isRead: msg['is_read'] == true || msg['is_read'] == 1,
                        isEncrypted: msg['is_encrypted'] == true,
                        replyToContent: msg['reply_to_content'],
                        caption: msg['caption'],
                        localPath: msg['local_path'],
                        onReply: () => setState(() => _replyingTo = msg),
                      );
                    },
                  ),
          ),
          
          if (typingUsers.isNotEmpty) const TypingIndicator(),
          
          if (_replyingTo != null)
            ReplyPreview(
              message: _replyingTo!,
              onCancel: () => setState(() => _replyingTo = null),
            ),

          MessageInput(
            roomId: widget.roomId,
            replyingTo: _replyingTo,
            onCancelReply: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    ),
    );
  }

  void _showGroupInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomDetailsScreen(
          roomId: widget.roomId,
          roomName: widget.roomName,
          isGroup: widget.isGroup,
          members: _members,
        ),
      ),
    );
  }
}
