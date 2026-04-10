import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/message_input.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/reply_preview.dart';
import '../widgets/chat/typing_indicator.dart';
import '../services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/premium_background.dart';
import 'room_details_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;
  final bool isGroup;
  final String? avatarUrl;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.isGroup = false,
    this.avatarUrl,
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
  
  late String _currentRoomName;
  late String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    _currentRoomName = widget.roomName;
    _currentAvatarUrl = widget.avatarUrl;
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Optimisation : On n'écoute que les propriétés nécessaires pour éviter des rebuilds inutiles
    final messages = ref.watch(chatProvider(widget.roomId).select((s) => s.messages));
    final typingUsers = ref.watch(chatProvider(widget.roomId).select((s) => s.typingUsers));
    // Liste inversée : le plus récent en bas (index 0 = dernier message)
    final reversedMessages = messages.reversed.toList();

    return PremiumBackground(
      showPattern: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: ChatAppBar(
        roomId: widget.roomId,
        roomName: _currentRoomName,
        isGroup: widget.isGroup,
        avatarUrl: _currentAvatarUrl,
        onShowInfo: _showGroupInfo,
      ),
      body: Column(
        children: [
          Expanded(
            child: _userId == null
                ? const SizedBox.shrink() // Empêche le changement de côté des bulles, attend juste 1 frame (20ms)
                : ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: reversedMessages.length,
                    itemBuilder: (context, index) {
                      final msg = reversedMessages[index];
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

  void _showGroupInfo() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomDetailsScreen(
          roomId: widget.roomId,
          roomName: _currentRoomName,
          avatarUrl: _currentAvatarUrl,
          isGroup: widget.isGroup,
          members: _members,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        if (result.containsKey('name')) _currentRoomName = result['name'];
        if (result.containsKey('avatar_url')) _currentAvatarUrl = result['avatar_url'];
      });
      _loadMembers(); // Refresh members just in case
    }
  }
}
