import '../../services/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/authenticated_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'audio_player_widget.dart';
import '../../services/media_service.dart';
import '../../screens/image_viewer_screen.dart';
import '../poll_message_widget.dart';
import '../task_message_widget.dart';
import '../meeting_message_widget.dart';
import 'reaction_picker.dart';

class MessageBubble extends StatefulWidget {
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
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Map<String, dynamic>? reactions;
  final String? currentUserId;
  final String? roomId;
  final String? messageId;
  final Map<String, dynamic>? metadata;
  final String? senderName;
  final String? senderAvatar;
  final bool showSenderName;

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
    this.onEdit,
    this.onDelete,
    this.reactions,
    this.currentUserId,
    this.roomId,
    this.messageId,
    this.metadata,
    this.senderName,
    this.senderAvatar,
    this.showSenderName = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final GlobalKey _bubbleKey = GlobalKey();
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bubbleColor = widget.isMe 
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB))
        : (isDark ? const Color(0xFF202C33) : Colors.white);
    
    final textColor = widget.isMe 
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.white : Colors.black87);

    final replyBorderColor = widget.isMe ? Colors.lightGreen : Colors.blueGrey;
    final hasReactions = widget.reactions != null && widget.reactions!.isNotEmpty &&
        widget.reactions!.entries.any((e) => (e.value as List).isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Column(
        crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isMe)
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: CustomPaint(
                    painter: TailPainter(isMe: false, color: bubbleColor),
                    size: const Size(8, 12),
                  ),
                ),

              // Miniature de la photo de profil (Groupes)
              if (widget.showSenderName && !widget.isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 2),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                    ),
                    child: widget.senderAvatar != null 
                      ? ClipOval(
                          child: AuthenticatedNetworkImage(
                            imageUrl: ApiConfig.getMediaUrl(widget.senderAvatar!),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: Text(
                                widget.senderName?[0].toUpperCase() ?? '?', 
                                style: const TextStyle(fontSize: 12, color: Colors.white)
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                widget.senderName?[0].toUpperCase() ?? '?', 
                                style: const TextStyle(fontSize: 12, color: Colors.white)
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            widget.senderName?[0].toUpperCase() ?? '?', 
                            style: const TextStyle(fontSize: 12, color: Colors.white)
                          ),
                        ),
                  ),
                ),

              Flexible(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onLongPress: () {
                        HapticFeedback.heavyImpact();
                        _showMessageOptions(context);
                      },
                      child: Container(
                        key: _bubbleKey,
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width > 600 
                              ? 450.0 
                              : MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.only(
                            topLeft: widget.isMe ? const Radius.circular(8) : Radius.zero,
                            topRight: widget.isMe ? Radius.zero : const Radius.circular(8),
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
                        child: IntrinsicWidth(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                            child: widget.type == 'text' 
                              ? Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (widget.showSenderName && widget.senderName != null)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(
                                                widget.senderName!,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.brightness == Brightness.dark ? Colors.orange[300] : Colors.orange[800],
                                                ),
                                              ),
                                            ),
                                          if (widget.replyToContent != null)
                                            _buildReplyPreview(replyBorderColor, textColor),
                                          
                                          // On ajoute des espaces insécables à la fin pour réserver la place de l'heure
                                          _buildExpandableText(
                                            "${widget.content} \u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0", 
                                            textColor, 
                                            theme
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: _buildTimestampRow(isDark),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.showSenderName && widget.senderName != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          widget.senderName!,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: theme.brightness == Brightness.dark ? Colors.orange[300] : Colors.orange[800],
                                          ),
                                        ),
                                      ),
                                    if (widget.replyToContent != null)
                                      _buildReplyPreview(replyBorderColor, textColor),
                                    
                                    // Contenu Principal
                                    _buildMainContent(context, textColor, isDark),
  
                                    // Légende (si présente pour les médias)
                                    if (widget.caption != null && widget.caption!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: _buildExpandableText(
                                          "${widget.caption!} \u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0", 
                                          textColor, 
                                          theme, 
                                          fontSize: 14.5
                                        ),
                                      ),
  
                                    const SizedBox(height: 2),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: _buildTimestampRow(isDark),
                                    ),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ),

                    // Réactions style WhatsApp : pilule chevauchant le bas de la bulle
                    if (hasReactions)
                      Positioned(
                        bottom: -8, // Moins profond pour mieux chevaucher
                        left: widget.isMe ? 2 : null,
                        right: widget.isMe ? null : 2,

                        child: ReactionsDisplay(
                          reactions: widget.reactions!,
                          isMe: widget.isMe,
                          currentUserId: widget.currentUserId,
                          onTapReaction: widget.onReaction,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.isMe)
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: CustomPaint(
                    painter: TailPainter(isMe: true, color: bubbleColor),
                    size: const Size(8, 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, Color textColor, bool isDark) {
    if (widget.type == 'deleted') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 14, color: textColor.withAlpha(150)),
          const SizedBox(width: 6),
          Text(
            widget.content,
            style: TextStyle(
              color: textColor.withAlpha(150),
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    } else if (widget.type == 'image') {
      return _ImageContent(url: widget.content, localPath: widget.localPath);
    } else if (widget.type == 'file') {
      return _FileContent(
        message: {
          'id': widget.messageId,
          'content': widget.content,
          'room_id': widget.roomId,
          'metadata_': widget.metadata,
          'local_path': widget.localPath,
          'message_type': 'file',
        },
        isMe: widget.isMe, 
        textColor: textColor,
        isDark: isDark,
      );
    } else if (widget.type == 'audio') {
      return AudioPlayerWidget(url: widget.content, isMe: widget.isMe, localPath: widget.localPath);
    } else if (widget.type == 'poll' && widget.metadata != null && widget.roomId != null && widget.messageId != null) {
      return PollMessageWidget(
        messageId: widget.messageId!,
        roomId: widget.roomId!,
        question: widget.content,
        metadata: widget.metadata!,
        isMe: widget.isMe,
      );
    } else if (widget.type == 'task' && widget.metadata != null && widget.roomId != null && widget.messageId != null) {
      return TaskMessageWidget(
        messageId: widget.messageId!,
        roomId: widget.roomId!,
        title: widget.content,
        metadata: widget.metadata!,
        isMe: widget.isMe,
      );
    } else if (widget.type == 'meeting' && widget.metadata != null) {
      return MeetingMessageWidget(
        title: widget.content,
        metadata: widget.metadata!,
        isMe: widget.isMe,
      );
    } else {
      // Pour le texte, on vérifie si c'est un lien de stockage brut qu'on devrait masquer
      final isMediaLink = widget.content.contains('firebasestorage.googleapis.com') || 
                         widget.content.contains('res.cloudinary.com');
      final lowerContent = widget.content.toLowerCase();
      
      if (isMediaLink) {
        if (lowerContent.contains('.m4a') || lowerContent.contains('.mp3') || lowerContent.contains('.wav')) {
           return AudioPlayerWidget(url: widget.content, isMe: widget.isMe, localPath: widget.localPath);
        }
        if (lowerContent.contains('.jpg') || lowerContent.contains('.jpeg') || lowerContent.contains('.png') || lowerContent.contains('.webp')) {
           return _ImageContent(url: widget.content, localPath: widget.localPath);
        }
        if (lowerContent.contains('.pdf') || lowerContent.contains('.doc') || lowerContent.contains('.docx') || lowerContent.contains('.xls') || lowerContent.contains('.xlsx')) {
           return _FileContent(
             message: {
               'id': widget.messageId,
               'content': widget.content,
               'room_id': widget.roomId,
               'metadata_': widget.metadata,
               'local_path': widget.localPath,
               'message_type': 'file',
             },
             isMe: widget.isMe, 
             textColor: textColor,
             isDark: isDark,
           );
        }
      }

      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
        child: _buildExpandableText(widget.content, textColor, theme),
      );
    }
  }

  Widget _buildReplyPreview(Color replyBorderColor, Color textColor) {
    String displayContent = widget.replyToContent!;
    
    // Si le contenu est une URL brute (Cloudinary ou Firebase), on affiche "Photo"
    if (displayContent.contains('res.cloudinary.com') || 
        displayContent.contains('firebasestorage.googleapis.com')) {
      displayContent = "📷 Photo";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 6, top: 2),
      decoration: BoxDecoration(
        color: widget.isMe 
            ? Colors.black.withValues(alpha: 0.05) 
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: replyBorderColor, width: 4)),
      ),
      child: Text(
        displayContent,
        style: TextStyle(
          fontSize: 13,
          color: textColor.withValues(alpha: 0.7),
          height: 1.2,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTimestampRow(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.metadata?['edited'] == true)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              'modifié',
              style: TextStyle(
                color: (isDark && widget.isMe) ? Colors.white54 : Colors.black45,
                fontSize: 9,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        Text(
          _formatTime(widget.timestamp),
          style: TextStyle(
            color: (isDark && widget.isMe) ? Colors.white60 : Colors.black45,
            fontSize: 9,
          ),
        ),
        if (widget.isMe) ...[
          const SizedBox(width: 3),
          Icon(
            widget.status == 'pending' 
                ? Icons.access_time_rounded 
                : Icons.done_all_rounded,
            size: 12,
            color: widget.isRead 
                ? Colors.blue 
                : ((isDark && widget.isMe) ? Colors.white60 : Colors.black45),
          ),
        ],
      ],
    );
  }

  Widget _buildExpandableText(String text, Color textColor, ThemeData theme, {double fontSize = 15.0}) {
    final bool isLong = text.length > 400;
    final String displayContent = (isLong && !_isExpanded)
        ? '${text.substring(0, 400)}...'
        : text;

    final isDark = theme.brightness == Brightness.dark;
    final linkColor = widget.isMe
        ? (isDark ? Colors.white70 : Colors.black87.withAlpha(160))
        : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayContent,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            height: 1.3,
          ),
        ),
        if (isLong)
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _isExpanded ? 'Voir moins' : 'Voir plus',
                style: TextStyle(
                  color: linkColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
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

  bool _isRecent() {
    try {
      final msgTime = DateTime.parse(widget.timestamp);
      return DateTime.now().difference(msgTime).inMinutes < 15;
    } catch (_) {
      return false;
    }
  }

  void _showMessageOptions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canModify = widget.isMe && _isRecent();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2C34) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                ),
                // Emoji reaction row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(ctx);
                          widget.onReaction?.call(emoji);
                        },
                        child: Container(
                          width: 44, height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 28)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                // Actions
                _actionTile(ctx, Icons.reply_rounded, 'Répondre', theme.colorScheme.primary, () {
                  Navigator.pop(ctx);
                  widget.onReply?.call();
                }),
                if (widget.type == 'text')
                  _actionTile(ctx, Icons.copy_rounded, 'Copier', isDark ? Colors.white70 : Colors.black87, () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: widget.content));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Message copié'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  }),
                if (canModify && widget.type == 'text')
                  _actionTile(ctx, Icons.edit_rounded, 'Modifier', Colors.blue, () {
                    Navigator.pop(ctx);
                    widget.onEdit?.call();
                  }),
                if (widget.isMe)
                  _actionTile(ctx, Icons.delete_rounded, 'Supprimer', Colors.red, () {
                    Navigator.pop(ctx);
                    _confirmDelete(context);
                  }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionTile(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  void _confirmDelete(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer le message ?'),
        content: const Text('Ce message sera supprimé pour tous les participants.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete?.call();
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
                child: (!kIsWeb && localPath != null && File(localPath!).existsSync())
                    ? Image.file(
                        File(localPath!),
                        fit: BoxFit.cover,
                        height: 200,
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

class _FileContent extends ConsumerWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final Color textColor;
  final bool isDark;

  const _FileContent({
    required this.message, 
    required this.isMe, 
    required this.textColor,
    required this.isDark,
  });

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = message['content'] as String;
    final metadata = message['metadata_'] as Map<String, dynamic>?;
    final localPath = (message['local_path'] as String?) ?? (metadata?['local_path'] as String?);
    final filename = metadata?['filename'] ?? content.split('/').last;
    final fileSize = metadata?['file_size'] as int?;
    final extension = filename.split('.').last.toLowerCase();
    
    final roomId = message['room_id'];
    final progress = roomId != null 
        ? ref.watch(chatProvider(roomId).select((s) => s.downloadProgress[message['id'].toString()]))
        : null;

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
    final isDownloading = progress != null;

    return InkWell(
      onTap: isDownloading ? null : () async {
        if (!kIsWeb && localPath != null && await File(localPath).exists()) {
          try {
            await OpenFilex.open(localPath);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Impossible d'ouvrir le fichier : $e")),
              );
            }
          }
        } else {
          // Si le chemin local est invalide ou le fichier n'existe plus, on télécharge
          ref.read(chatProvider(message['room_id']).notifier).downloadMedia(message);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withAlpha(40) : Colors.black.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône ou Progression
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                if (isDownloading)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 2,
                      color: iconColor,
                    ),
                  ),
                if (!isDownloading && localPath == null && !isMe)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_downward, size: 12, color: iconColor),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Infos fichier
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filename,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    fileSize != null ? _formatBytes(fileSize) : extension.toUpperCase(),
                    style: TextStyle(
                      color: textColor.withAlpha(150),
                      fontSize: 11,
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
    Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    Path path = Path();

    if (isMe) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.quadraticBezierTo(size.width * 0.2, size.height * 0.2, 0, size.height * 0.8);
      path.close();
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.quadraticBezierTo(size.width * 0.8, size.height * 0.2, size.width, size.height * 0.8);
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
