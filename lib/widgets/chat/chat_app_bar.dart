                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../screens/call_screen.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';

class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String roomId;
  final String roomName;
  final bool isGroup;
  final VoidCallback onShowInfo;
  final VoidCallback onShowAI;

  const ChatAppBar({
    super.key,
    required this.roomId,
    required this.roomName,
    this.isGroup = false,
    required this.onShowInfo,
    required this.onShowAI,
  });

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider(roomId));
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: AppTheme.primaryGreen,
      foregroundColor: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      elevation: 4,
      leadingWidth: 40,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: InkWell(
        onTap: onShowInfo,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _buildAvatar(theme, state.otherUserOnline),
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
                        height: 1.2,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildStatusIndicator(theme, state),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        _buildActionButton(
          icon: Icons.auto_awesome_rounded,
          color: Colors.white70,
          onPressed: onShowAI,
        ),
        _buildActionButton(
          icon: Icons.videocam_rounded,
          color: Colors.white,
          onPressed: () => _startCall(context, ref, isVideo: true),
        ),
        const SizedBox(width: 4),
        _buildActionButton(
          icon: Icons.call_rounded,
          color: Colors.white,
          onPressed: () => _startCall(context, ref, isVideo: false),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAvatar(ThemeData theme, bool isOnline) {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white24,
          ),
          child: Center(
            child: Text(
              roomName[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
        // Petit indicateur de présence en bas à droite de l'avatar
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFF4CAF50) : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryGreen,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(ThemeData theme, dynamic chatState) {
    Widget statusWidget;

    // 1. Si pas connecté au WebSocket, afficher "Connexion..."
    if (!chatState.isConnected) {
      statusWidget = const Row(
        key: ValueKey('connecting'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.white70,
            ),
          ),
          SizedBox(width: 6),
          Text(
            'Connexion...',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ],
      );
    }
    // 2. En train d'écrire (priorité haute)
    else if (chatState.typingUsers.isNotEmpty && !isGroup) {
      statusWidget = const Row(
        key: ValueKey('typing'),
        mainAxisSize: MainAxisSize.min,
        children: [
          _TypingDots(color: Colors.white),
          SizedBox(width: 6),
          Text(
            'Écrit...',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      );
    }
    // 3. Groupe
    else if (isGroup) {
      final typingCount = chatState.typingUsers.length;
      statusWidget = Text(
        key: ValueKey('group_$typingCount'),
        typingCount > 0 ? '$typingCount personne(s) écri(ven)t...' : 'Groupe',
        style: TextStyle(
          fontSize: 11,
          fontWeight: typingCount > 0 ? FontWeight.w600 : FontWeight.w500,
          color: typingCount > 0 ? Colors.white : Colors.white70,
        ),
      );
    }
    // 4. Statut de présence réel
    else {
      final bool isOnline = chatState.otherUserOnline;
      final String? presenceStatus = chatState.otherUserStatus;

      String statusText;
      Color statusColor;

      if (!isOnline) {
        statusText = 'Hors ligne';
        statusColor = Colors.grey;
      } else {
        switch (presenceStatus) {
          case 'busy':
            statusText = 'Occupé';
            statusColor = Colors.amber;
            break;
          case 'dnd':
            statusText = 'Ne pas déranger';
            statusColor = Colors.redAccent;
            break;
          case 'meeting':
            statusText = 'En réunion';
            statusColor = Colors.purpleAccent;
            break;
          case 'remote':
            statusText = 'Télétravail';
            statusColor = Colors.lightBlueAccent;
            break;
          default:
            statusText = 'En ligne';
            statusColor = const Color(0xFF4CAF50);
        }
      }

      statusWidget = Row(
        key: ValueKey('status_$statusText'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ],
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: statusWidget,
    );
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onPressed, Color? color}) {
    return IconButton(
      icon: Icon(icon, size: 22, color: color),
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

/// Widget d'animation des 3 points (écriture en cours)
class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final offset = (_controller.value * 3 - index).clamp(0.0, 1.0);
              final bounce = (offset < 0.5) ? offset * 2 : 2 - offset * 2;
              return Transform.translate(
                offset: Offset(0, -bounce * 4),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.4 + bounce * 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
