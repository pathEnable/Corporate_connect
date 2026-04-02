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
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      roomName, 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)
                    ),
                  ],
                ),
                if (isGroup)
                  Row(
                    children: [
                      Text(
                        state.isConnected ? 'Connecté' : 'Déconnecté',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimary.withAlpha(200), fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_rounded),
          onPressed: () => _startCall(context, ref, isVideo: true),
        ),
        IconButton(
          icon: const Icon(Icons.call_rounded),
          onPressed: () => _startCall(context, ref, isVideo: false),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
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
