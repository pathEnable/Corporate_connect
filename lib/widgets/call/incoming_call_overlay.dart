import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/incoming_call_provider.dart';
import '../../screens/call_screen.dart';
import '../../widgets/authenticated_image.dart';
import 'slide_to_answer.dart';

class IncomingCallOverlay extends ConsumerWidget {
  const IncomingCallOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(incomingCallProvider);

    if (!state.isRinging) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent, // Transparent to allow background bleed if any
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background image (caller avatar acting as full screen bg)
          if (state.callerAvatar != null && state.callerAvatar!.isNotEmpty)
            AuthenticatedNetworkImage(
              imageUrl: state.callerAvatar!,
              fit: BoxFit.cover,
            )
          else
            Container(color: Colors.black87), // Fallback
          
          // 2. Glassmorphism blur effect
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
            child: Container(
              color: Colors.black.withValues(alpha: 0.6), // Darken the blur
            ),
          ),
          
          // 3. Foreground Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                // Caller Avatar
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
              state.isVideo ? 'Appel vidéo entrant...' : 'Appel audio entrant...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
              ),
            ),
                const Spacer(),
                // Actions using the new SlideToAnswer
                Padding(
                  padding: const EdgeInsets.only(bottom: 64),
                  child: SlideToAnswer(
                    isVideo: state.isVideo,
                    onAnswer: () {
                      _handleAccept(context, state);
                      ref.read(incomingCallProvider.notifier).stopRinging();
                    },
                    onDecline: () {
                      ref.read(incomingCallProvider.notifier).stopRinging();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
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

  void _handleAccept(BuildContext context, IncomingCallState state) {
    if (state.roomId == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          channelId: state.roomId!,
          remoteUserName: state.callerName ?? 'Appel',
          isVideo: state.isVideo,
        ),
      ),
    );
  }
}
