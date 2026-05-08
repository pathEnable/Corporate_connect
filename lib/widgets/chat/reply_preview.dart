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
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        // Glassmorphism effect
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Colored indicator
              Container(
                width: 4,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              // Icon
              Icon(
                Icons.reply_rounded, 
                color: theme.colorScheme.primary, 
                size: 18
              ),
              const SizedBox(width: 10),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'En réponse à',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 12, 
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message['content'] ?? (message['message_type'] == 'image' ? '📸 Image' : 'Fichier'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7), 
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Close button
              IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                onPressed: onCancel,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
