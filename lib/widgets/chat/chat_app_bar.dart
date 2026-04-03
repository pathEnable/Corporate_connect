import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider(roomId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 110, // Adjusted for safe area
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF0D1B1E).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: InkWell(
              onTap: onShowInfo,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    _buildAvatar(theme),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            roomName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          _buildStatusIndicator(theme, state.isConnected),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              _buildActionButton(
                icon: Icons.videocam_rounded,
                onPressed: () => _startCall(context, ref, isVideo: true),
              ),
              _buildActionButton(
                icon: Icons.call_rounded,
                onPressed: () => _startCall(context, ref, isVideo: false),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)],
        ),
      ),
      child: Center(
        child: Text(
          roomName[0].toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(ThemeData theme, bool isOnline) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFF26E9CF) : Colors.grey,
            shape: BoxShape.circle,
            boxShadow: isOnline ? [
              BoxShadow(
                color: const Color(0xFF26E9CF).withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              )
            ] : null,
          ),
        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
         .scale(end: const Offset(1.2, 1.2), duration: 1000.ms, curve: Curves.easeInOut),
        const SizedBox(width: 6),
        Text(
          isOnline ? 'En ligne' : 'Hors ligne',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, size: 22),
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
    );
  }

  void _startCall(BuildContext context, WidgetRef ref, {required bool isVideo}) {
    ref.read(chatProvider(roomId).notifier).sendMessage(
      isVideo ? 'Appel vidéo' : 'Appel audio',
      'call_offer',
      extraData: {'channel_id': roomId, 'is_video': isVideo},
    );

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
