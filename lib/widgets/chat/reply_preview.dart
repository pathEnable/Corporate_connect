import 'package:flutter/material.dart';

class ReplyPreview extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onCancel;

  const ReplyPreview({
    super.key,
    required this.message,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 4),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Répondre à',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 12, 
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.3
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message['content'] ?? (message['message_type'] == 'image' ? '📸 Image' : 'Fichier'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(180), fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: theme.colorScheme.onSurface.withAlpha(120)),
            onPressed: onCancel,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
