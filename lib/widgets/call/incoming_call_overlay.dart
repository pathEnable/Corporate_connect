import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/incoming_call_provider.dart';
import '../../screens/call_screen.dart';
import '../../widgets/authenticated_image.dart';

class IncomingCallOverlay extends ConsumerWidget {
  const IncomingCallOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(incomingCallProvider);

    if (!state.isRinging) return const SizedBox.shrink();

    return Material(
      color: Colors.black.withValues(alpha: 0.9),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Avatar de l'appelant
            _buildAvatar(state.callerAvatar)
                .animate(onPlay: (controller) => controller.repeat())
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 1.seconds,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 32),
            // Nom de l'appelant
            Text(
              state.callerName ?? 'Inconnu',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.isVideo
                  ? 'Appel vidéo entrant...'
                  : 'Appel audio entrant...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
              ),
            ),
            const Spacer(),
            // Actions
            Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Refuser
                  _buildCallAction(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: 'Refuser',
                    onTap: () {
                      ref.read(incomingCallProvider.notifier).stopRinging();
                    },
                  ),
                  // Accepter
                  _buildCallAction(
                    icon: state.isVideo ? Icons.videocam : Icons.call,
                    color: Colors.green,
                    label: 'Accepter',
                    onTap: () {
                      _handleAccept(context, state);
                      ref.read(incomingCallProvider.notifier).stopRinging();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildAvatar(String? avatar) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ClipOval(
        child: avatar != null && avatar.isNotEmpty
            ? AuthenticatedNetworkImage(imageUrl: avatar, fit: BoxFit.cover)
            : Container(
                color: Colors.blueGrey,
                child: const Icon(Icons.person, size: 80, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildCallAction({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }

  void _handleAccept(BuildContext context, IncomingCallState state) {
    if (state.roomId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          channelId: state.roomId!,
          remoteUserName: state.callerName ?? 'Appel',
          isVideo: state.isVideo,
          isOutgoing: false, // C'est une réponse, pas un appel sortant
        ),
      ),
    );
  }
}
