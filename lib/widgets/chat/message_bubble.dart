import 'package:flutter/material.dart';
import '../../widgets/authenticated_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'audio_player_widget.dart';
import '../../services/media_service.dart';
import '../../screens/image_viewer_screen.dart';
import '../poll_message_widget.dart';
import '../task_message_widget.dart';
import '../meeting_message_widget.dart';
import 'reaction_picker.dart';

class MessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final String timestamp;
  final String type;
  final String status;
  final bool isRead;
  final bool isEncrypted;
  final String? replyToContent;
  final String? caption;
  final String? localPath;
  final VoidCallback? onReply;
  final Function(String emoji)? onReaction;
  final Map<String, dynamic>? reactions;
  final String? currentUserId;

  const MessageBubble({
    super.key,
    required this.content,
    required this.isMe,
    required this.timestamp,
    this.type = 'text',
    this.status = 'sent',
    this.isRead = false,
    this.isEncrypted = false,
    this.replyToContent,
    this.caption,
    this.localPath,
    this.onReply,
    this.onReaction,
    this.reactions,
    this.currentUserId,
    this.metadata,
    this.roomId,
    this.messageId,
  });

  final Map<String, dynamic>? metadata;
  final String? roomId;
  final String? messageId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final notMeBgColor = isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white;
    final notMeTextColor = isDark ? Colors.white : Colors.black87;
    final replyBorderColor = isMe ? Colors.white : theme.colorScheme.primary;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        // Show reaction picker first, fallback to reply
        if (onReaction != null) {
          _showReactionMenu(context);
        } else if (onReply != null) {
          onReply!();
        }
      },
      onDoubleTap: () {
        // Quick reaction with 👍 on double tap
        HapticFeedback.selectionClick();
        onReaction?.call('👍');
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF26E9CF) : notMeBgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            border: Border.all(
              color: isMe 
                ? const Color(0xFF1AA18E).withValues(alpha: 0.2)
                : theme.colorScheme.onSurface.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (replyToContent != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 6),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white.withAlpha(40) : Colors.black.withAlpha(13),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(color: replyBorderColor, width: 4)),
                  ),
                  child: Text(
                    replyToContent!.length > 60 ? '${replyToContent!.substring(0, 60)}...' : replyToContent!,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isMe ? Colors.white.withAlpha(220) : notMeTextColor.withAlpha(180),
                    ),
                  ),
                ),
              if (type == 'image')
                _ImageContent(url: content, localPath: localPath)
              else if (type == 'file')
                _FileContent(content: content, isMe: isMe, localPath: localPath)
              else if (type == 'audio')
                AudioPlayerWidget(url: content, isMe: isMe, localPath: localPath)
              else if (type == 'poll' && metadata != null && roomId != null && messageId != null)
                PollMessageWidget(
                  messageId: messageId!,
                  roomId: roomId!,
                  metadata: metadata!,
                  isMe: isMe,
                )
              else if (type == 'task' && metadata != null && roomId != null && messageId != null)
                TaskMessageWidget(
                  messageId: messageId!,
                  roomId: roomId!,
                  metadata: metadata!,
                  isMe: isMe,
                )
              else if (type == 'meeting' && metadata != null)
                MeetingMessageWidget(
                  metadata: metadata!,
                  isMe: isMe,
                )
              else
                Text(
                  content,
                  style: TextStyle(
                    color: isMe ? Colors.white : notMeTextColor,
                    fontSize: 15.5,
                    height: 1.3,
                  ),
                ),
              if (caption != null && caption!.isNotEmpty && type != 'text')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                  child: Text(
                    caption!,
                    style: TextStyle(
                      color: isMe ? Colors.white : notMeTextColor,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white60 : Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      status == 'pending' ? Icons.access_time_rounded : 
                      (isRead ? Icons.done_all_rounded : Icons.done_rounded),
                      size: 14,
                      color: isRead ? Colors.blueAccent : Colors.white60,
                    ),
                  ],
                ],
              ),
              // Réactions sous le message
              if (reactions != null && reactions!.isNotEmpty)
                ReactionsDisplay(
                  reactions: reactions!,
                  isMe: isMe,
                  currentUserId: currentUserId,
                  onTapReaction: onReaction,
                ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack).slideX(begin: isMe ? 0.2 : -0.2, end: 0),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _showReactionMenu(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => ReactionPicker(
        onDismiss: () => entry.remove(),
        onReactionSelected: (emoji) {
          entry.remove();
          onReaction?.call(emoji);
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _ImageContent extends StatelessWidget {
  final String url;
  final String? localPath;
  const _ImageContent({required this.url, this.localPath});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: MediaService().getDownloadUrl(url),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final imageUrl = snapshot.data!;
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageViewerScreen(imageUrl: imageUrl),
                ),
              );
            },
            child: Hero(
              tag: imageUrl,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (localPath != null && File(localPath!).existsSync())
                    ? Image.file(
                        File(localPath!),
                        fit: BoxFit.cover,
                        height: 200,
                        width: double.infinity,
                      )
                    : AuthenticatedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 150,
                          width: 200,
                          color: Colors.grey.withAlpha(30),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 100,
                          width: 100,
                          color: Colors.grey.withAlpha(20),
                          child: const Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                        ),
                      ),
              ),
            ),
          );
        }
        return Container(
          height: 150,
          width: 200,
          decoration: BoxDecoration(
            color: Colors.grey.withAlpha(10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }
}

class _FileContent extends StatelessWidget {
  final String content;
  final bool isMe;
  final String? localPath;
  const _FileContent({required this.content, required this.isMe, this.localPath});

  @override
  Widget build(BuildContext context) {
    final filename = content.split('/').last;
    final extension = filename.split('.').last.toLowerCase();
    
    IconData icon = Icons.insert_drive_file;
    Color iconColor = Colors.blue;

    if (['pdf'].contains(extension)) {
      icon = Icons.picture_as_pdf;
      iconColor = Colors.red;
    } else if (['doc', 'docx'].contains(extension)) {
      icon = Icons.description;
      iconColor = Colors.blue;
    } else if (['xls', 'xlsx'].contains(extension)) {
      icon = Icons.table_chart;
      iconColor = Colors.green;
    } else if (['zip', 'rar', '7z'].contains(extension)) {
      icon = Icons.archive;
      iconColor = Colors.orange;
    }

    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        try {
          if (localPath != null && await File(localPath!).exists()) {
            final uri = Uri.file(localPath!);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return;
            }
          }
          
          final url = await MediaService().getDownloadUrl(content);
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          debugPrint("Error launching file: $e");
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withAlpha(25) : theme.colorScheme.onSurface.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filename,
                    style: TextStyle(
                      color: isMe ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    extension.toUpperCase(),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
