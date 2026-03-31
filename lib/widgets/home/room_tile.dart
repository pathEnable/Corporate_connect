import 'package:flutter/material.dart';
import '../../screens/chat_screen.dart';
import '../ui_helpers.dart';

class HomeRoomTile extends StatelessWidget {
  final Map<String, dynamic> room;

  const HomeRoomTile({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFF004D40),
        child: Icon(
          (room['is_group'] == true) ? Icons.group : Icons.person,
          color: Colors.white,
          size: 24,
        ),
      ),
      title: Text(
        room['name'] ?? 'Discussion privée',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        room['last_message'] ?? 'Aucun message',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
      onTap: () {
        Navigator.push(
          context,
          FadeSlideRoute(
            page: ChatScreen(
              roomId: room['id'],
              roomName: room['name'] ?? 'Discussion',
              isGroup: room['is_group'] ?? false,
            ),
          ),
        );
      },
    );
  }
}
