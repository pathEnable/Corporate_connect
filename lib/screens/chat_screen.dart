import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../models/chat_state.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/message_input.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/reply_preview.dart';
import '../widgets/chat/typing_indicator.dart';
import '../services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final state = ref.watch(chatProvider(widget.roomId));

    // Auto-scroll on new messages
    ref.listen<ChatState>(chatProvider(widget.roomId), (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: ChatAppBar(
        roomId: widget.roomId,
        roomName: widget.roomName,
        isGroup: widget.isGroup,
        onShowInfo: _showGroupInfo,
      ),
      body: Column(
        children: [
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final msg = state.messages[index];
                      return MessageBubble(
                        content: msg['content'] ?? '',
                        isMe: msg['sender_id'].toString() == _userId,
                        timestamp: msg['timestamp'] ?? msg['created_at'] ?? '',
                        type: msg['message_type'] ?? 'text',
                        status: msg['status'] ?? 'sent',
                        isRead: msg['is_read'] == true || msg['is_read'] == 1,
                        replyToContent: msg['reply_to_content'],
                        onReply: () => setState(() => _replyingTo = msg),
                      );
                    },
                  ),
          ),
          
          if (state.typingUsers.isNotEmpty) const TypingIndicator(),
          
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
    );
  }

  void _showGroupInfo() {
     showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _GroupInfoModal(
        roomName: widget.roomName,
        members: _members,
        isGroup: widget.isGroup,
        roomId: widget.roomId,
      ),
    );
  }
}

class _GroupInfoModal extends StatelessWidget {
  final String roomName;
  final List<Map<String, dynamic>> members;
  final bool isGroup;
  final String roomId;

  const _GroupInfoModal({
    required this.roomName,
    required this.members,
    required this.isGroup,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(roomName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(isGroup ? "Groupe · ${members.length} membres" : "Conversation privée", style: const TextStyle(color: Colors.grey)),
          const Divider(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text("Membres", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF004D40),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(member['full_name'] ?? "Inconnu"),
                  subtitle: member['is_admin_member'] == true ? const Text("Administrateur") : null,
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
