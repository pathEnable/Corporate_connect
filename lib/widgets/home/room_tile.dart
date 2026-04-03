import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../screens/chat_screen.dart';
import '../../services/media_service.dart';
import '../ui_helpers.dart';

class HomeRoomTile extends StatelessWidget {
  final Map<String, dynamic> room;

  const HomeRoomTile({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isGroup = room['is_group'] == true;
    final String? avatarPath = room['avatar_url'];
    final bool hasUnread = (room['unread_count'] ?? 0) > 0;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          FadeSlideRoute(
            page: ChatScreen(
              roomId: room['id'],
              roomName: room['name'] ?? 'Discussion',
              isGroup: isGroup,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Hero(
              tag: 'room_avatar_${room['id']}',
              child: _RoomAvatar(
                avatarPath: avatarPath,
                isGroup: isGroup,
                initial: (room['name'] ?? 'D')[0].toUpperCase(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          room['name'] ?? 'Discussion privée',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(room['last_message_time']),
                        style: TextStyle(
                          color: hasUnread ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 12,
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room['last_message'] ?? 'Aucun message',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${room['unread_count']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ).animate().scale(curve: Curves.easeOutBack),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}

class _RoomAvatar extends StatelessWidget {
  final String? avatarPath;
  final bool isGroup;
  final String initial;

  const _RoomAvatar({this.avatarPath, required this.isGroup, required this.initial});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: avatarPath == null || avatarPath!.isEmpty
          ? CircleAvatar(
              radius: 28,
              backgroundColor: isGroup ? theme.colorScheme.primary : theme.colorScheme.primaryContainer,
              child: Icon(
                isGroup ? Icons.groups_rounded : Icons.person_rounded,
                color: isGroup ? Colors.white : theme.colorScheme.primary,
                size: 28,
              ),
            )
          : FutureBuilder<String>(
              future: MediaService().getDownloadUrl(avatarPath!),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primary.withAlpha(40),
                    backgroundImage: NetworkImage(snapshot.data!),
                  );
                }
                return CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withAlpha(40),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                );
              },
            ),
    );
  }
}
