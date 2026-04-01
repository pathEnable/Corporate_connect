import 'package:flutter/material.dart';
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Hero(
        tag: 'room_avatar_${room['id']}',
        child: _RoomAvatar(
          avatarPath: avatarPath,
          isGroup: isGroup,
          initial: (room['name'] ?? 'D')[0].toUpperCase(),
        ),
      ),
      title: Text(
        room['name'] ?? 'Discussion privée',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          room['last_message'] ?? 'Aucun message',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: theme.dividerColor.withAlpha(100), size: 20),
      onTap: () {
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
    );
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
    
    if (avatarPath == null || avatarPath!.isEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: theme.colorScheme.primary.withAlpha(isGroup ? 255 : 40),
        child: Icon(
          isGroup ? Icons.groups_rounded : Icons.person_rounded,
          color: isGroup ? Colors.white : theme.colorScheme.primary,
          size: 28,
        ),
      );
    }

    return FutureBuilder<String>(
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
    );
  }
}
