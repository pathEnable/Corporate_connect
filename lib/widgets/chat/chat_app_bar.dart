                               import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../screens/call_screen.dart';
import '../../providers/call_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api_config.dart';
import '../authenticated_image.dart';

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
              Hero(
                tag: 'room_avatar_$roomId',
                child: _buildAvatar(theme, state.otherUserOnline, state.otherUserAvatarUrl),
              ),
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

  Widget _buildAvatar(ThemeData theme, bool isOnline, String? avatarUrl) {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white24,
          ),
          child: isGroup
              ? const Icon(Icons.groups_rounded, color: Colors.white, size: 24)
              : avatarUrl != null && avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: Image(
                        image: AuthenticatedImageProvider(
                          ApiConfig.getMediaUrl(avatarUrl),
                        ),
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        errorBuilder: (_, __, ___) => _buildInitials(),
                      ),
                    )
                  : _buildInitials(),
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

  Widget _buildInitials() {
    return Center(
      child: Text(
        roomName.isNotEmpty ? roomName[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(ThemeData theme, dynamic chatState) {
    Widget statusWidget;

    // 1. Si pas connecté au WebSocket, on masque aussi (comme demandé)
    if (!chatState.isConnected) {
      statusWidget = const SizedBox.shrink(key: ValueKey('connecting_empty'));
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
    else if (isGroup) {
      final typingCount = chatState.typingUsers.length;
      if (typingCount > 0) {
        statusWidget = Text(
          key: ValueKey('group_$typingCount'),
          '$typingCount personne(s) écri(ven)t...',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        );
      } else {
        statusWidget = const SizedBox.shrink(key: ValueKey('empty_group'));
      }
    }
    // 4. Statut de présence réel (on masque le texte comme demandé, car déjà sur l'avatar)
    else {
      statusWidget = const SizedBox.shrink(key: ValueKey('empty_status'));
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

  void _startCall(BuildContext context, WidgetRef ref, {required bool isVideo}) async {
    // Utiliser le nouveau système de signalisation
    final success = await ref.read(callProvider.notifier).initiateCall(
      roomId: roomId,
      isVideo: isVideo,
      otherUserName: roomName,
    );

    if (success && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CallScreen(),
        ),
      );
    }
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
