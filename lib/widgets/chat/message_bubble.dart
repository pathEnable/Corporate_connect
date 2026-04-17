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

    final meColor = isDark ? const Color(0xFF056162) : const Color(0xFFE7FFDB);
    final notMeBgColor = isDark ? const Color(0xFF262D31) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : Colors.black87;
    final replyBorderColor = isMe ? Colors.white.withAlpha(200) : theme.colorScheme.primary;
    final bubbleColor = isMe ? meColor : notMeBgColor;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        if (onReaction != null) {
          _showReactionMenu(context);
        } else if (onReply != null) {
          onReply!();
        }
      },
      onDoubleTap: () {
        HapticFeedback.selectionClick();
        onReaction?.call('👍');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(top: 0),
                child: CustomPaint(
                  painter: TailPainter(isMe: false, color: bubbleColor),
                  size: const Size(8, 12),
                ),
              ),
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: isMe ? const Radius.circular(8) : Radius.zero,
                    topRight: isMe ? Radius.zero : const Radius.circular(8),
                    bottomLeft: const Radius.circular(8),
                    bottomRight: const Radius.circular(8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (replyToContent != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 4),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                            border: Border(left: BorderSide(color: replyBorderColor, width: 4)),
                          ),
                          child: Text(
                            replyToContent!.length > 60 ? '${replyToContent!.substring(0, 60)}...' : replyToContent!,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: textColor.withAlpha(180),
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
                          question: content,
                          metadata: metadata!,
                          isMe: isMe,
                        )
                      else if (type == 'task' && metadata != null && roomId != null && messageId != null)
                        TaskMessageWidget(
                          messageId: messageId!,
                          roomId: roomId!,
                          title: content,
                          metadata: metadata!,
                          isMe: isMe,
                        )
                      else if (type == 'meeting' && metadata != null)
                        MeetingMessageWidget(
                          title: content,
                          metadata: metadata!,
                          isMe: isMe,
                        )
                      else
                        Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0, bottom: 2.0),
                              child: Text(
                                content,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15.5,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(timestamp),
                                  style: TextStyle(
                                    color: (isDark && isMe) ? Colors.white70 : Colors.black54,
                                    fontSize: 11,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    status == 'pending' ? Icons.access_time_rounded : 
                                    (isRead ? Icons.done_all_rounded : Icons.done_rounded),
                                    size: 14,
                                    color: isRead ? Colors.blue : ((isDark && isMe) ? Colors.white70 : Colors.black54),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      if (caption != null && caption!.isNotEmpty && type != 'text')
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            caption!,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                      if (reactions != null && reactions!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: ReactionsDisplay(
                            reactions: reactions!,
                            isMe: isMe,
                            currentUserId: currentUserId,
                            onTapReaction: onReaction,
                          ),
                        ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0),
            ),
            if (isMe)
              Padding(
                padding: const EdgeInsets.only(top: 0),
                child: CustomPaint(
                  painter: TailPainter(isMe: true, color: bubbleColor),
                  size: const Size(8, 12),
                ),
              ),
          ],
        ),
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

class TailPainter extends CustomPainter {
  final bool isMe;
  final Color color;

  TailPainter({required this.isMe, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()..color = color;
    var path = Path();
    
    if (isMe) {
      path.moveTo(0, 0); 
      path.lineTo(size.width, 0); 
      path.lineTo(0, size.height); 
      path.close();
    } else {
      path.moveTo(size.width, 0); 
      path.lineTo(0, 0); 
      path.lineTo(size.width, size.height); 
      path.close();
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
