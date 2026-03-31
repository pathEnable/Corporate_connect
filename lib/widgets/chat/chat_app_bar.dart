import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../screens/call_screen.dart';
import '../../providers/chat_provider.dart';

class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String roomId;
  final String roomName;
  final bool isGroup;
  final VoidCallback onShowInfo;

  const ChatAppBar({
    super.key,
    required this.roomId,
    required this.roomName,
    this.isGroup = false,
    required this.onShowInfo,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider(roomId));

    return AppBar(
      backgroundColor: const Color(0xFF004D40),
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(roomName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(
            state.isConnected ? 'En ligne' : 'Déconnecté',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam),
          onPressed: () => _startCall(context, ref, isVideo: true),
        ),
        IconButton(
          icon: const Icon(Icons.call),
          onPressed: () => _startCall(context, ref, isVideo: false),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: onShowInfo,
        ),
      ],
    );
  }

  void _startCall(BuildContext context, WidgetRef ref, {required bool isVideo}) {
    // 1. Envoyer le signal via le provider
    ref.read(chatProvider(roomId).notifier).sendMessage(
      isVideo ? 'Appel vidéo' : 'Appel audio',
      'call_offer',
      extraData: {
        'channel_id': roomId,
        'is_video': isVideo,
      },
    );

    // 2. Naviguer vers l'écran d'appel
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          remoteUserName: roomName,
          channelId: roomId,
          isVideo: isVideo,
        ),
      ),
    );
  }
}
