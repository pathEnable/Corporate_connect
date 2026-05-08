import 'package:flutter/material.dart';
import '../../widgets/authenticated_image.dart';
import 'package:flutter/services.dart';
import '../../screens/chat_screen.dart';
import '../../services/api_config.dart';
import '../ui_helpers.dart';

class HomeRoomTile extends StatelessWidget {
  final Map<String, dynamic> room;

  const HomeRoomTile({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isGroup = room['is_group'] == true;
    final String? avatarPath = room['avatar_url'] ?? room['avatar'];
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
                          _formatMessageSummary(room['last_message']),
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
                          ),
                          child: Text(
                            '${room['unread_count']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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

  String _formatMessageSummary(String? message) {
    if (message == null || message.isEmpty) return 'Aucun message';
    
    final lowerMessage = message.toLowerCase();
    final isMediaUrl = lowerMessage.contains('firebasestorage.googleapis.com') || 
                       lowerMessage.contains('res.cloudinary.com');
    
    if (isMediaUrl) {
      if (lowerMessage.contains('.m4a') || lowerMessage.contains('.mp3') || lowerMessage.contains('.wav')) {
        return '🎵 Message vocal';
      }
      if (lowerMessage.contains('.jpg') || lowerMessage.contains('.jpeg') || lowerMessage.contains('.png') || lowerMessage.contains('.webp')) {
        return '📷 Image';
      }
      if (lowerMessage.contains('.pdf') || lowerMessage.contains('.doc') || lowerMessage.contains('.docx') || lowerMessage.contains('.xls') || lowerMessage.contains('.xlsx')) {
        return '📁 Document';
      }
      return '📎 Fichier';
    }
    
    return message;
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
    
    final bool hasAvatar = avatarPath != null && avatarPath!.isNotEmpty;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary.withAlpha(30),
      ),
      child: hasAvatar
          ? ClipOval(
              child: AuthenticatedNetworkImage(
                imageUrl: ApiConfig.getMediaUrl(avatarPath!),
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildFallback(theme),
                errorWidget: (context, url, error) => _buildFallback(theme),
              ),
            )
          : _buildFallback(theme),
    );
  }

  Widget _buildFallback(ThemeData theme) {
    return Center(
      child: isGroup
          ? Icon(Icons.groups_rounded, color: theme.colorScheme.primary, size: 28)
          : Text(
              initial,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
