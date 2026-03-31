import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/media_service.dart';

class MessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final String timestamp;
  final String type;
  final String status;
  final bool isRead;
  final String? replyToContent;
  final VoidCallback? onReply;

  const MessageBubble({
    super.key,
    required this.content,
    required this.isMe,
    required this.timestamp,
    this.type = 'text',
    this.status = 'sent',
    this.isRead = false,
    this.replyToContent,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onReply,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF004D40) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
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
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: isMe ? Colors.white : const Color(0xFF004D40), width: 4)),
                  ),
                  child: Text(
                    replyToContent!.length > 60 ? '${replyToContent!.substring(0, 60)}...' : replyToContent!,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isMe ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              if (type == 'image')
                _ImageContent(url: content)
              else if (type == 'file')
                _FileContent(content: content, isMe: isMe)
              else if (type == 'audio')
                AudioBubbleContent(url: content, isMe: isMe)
              else
                Text(
                  content,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      status == 'pending' ? Icons.access_time : 
                      (isRead ? Icons.done_all : Icons.done),
                      size: 14,
                      color: isRead ? Colors.blueAccent : Colors.white60,
                    ),
                  ],
                ],
              ),
            ],
          ),
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
}

class _ImageContent extends StatelessWidget {
  final String url;
  const _ImageContent({required this.url});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: MediaService().getDownloadUrl(url),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
            ),
          );
        }
        return const SizedBox(height: 100, width: 100, child: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class _FileContent extends StatelessWidget {
  final String content;
  final bool isMe;
  const _FileContent({required this.content, required this.isMe});

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

    return InkWell(
      onTap: () {
        // Logique pour ouvrir ou télécharger le fichier
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              filename,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                decoration: TextDecoration.underline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class AudioBubbleContent extends StatefulWidget {
  final String url;
  final bool isMe;

  const AudioBubbleContent({super.key, required this.url, required this.isMe});

  @override
  State<AudioBubbleContent> createState() => _AudioBubbleContentState();
}

class _AudioBubbleContentState extends State<AudioBubbleContent> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      final fullUrl = await MediaService().getDownloadUrl(widget.url);
      await _audioPlayer.setSourceUrl(fullUrl);
      
      _audioPlayer.onDurationChanged.listen((d) { 
        if (mounted) setState(() => _duration = d); 
      });
      _audioPlayer.onPositionChanged.listen((p) { 
        if (mounted) setState(() => _position = p); 
      });
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: widget.isMe ? Colors.white : Colors.black87),
          onPressed: () {
            if (_isPlaying) {
              _audioPlayer.pause();
            } else {
              _audioPlayer.resume();
            }
          },
        ),
        SizedBox(
          width: 100,
          child: Slider(
            value: _position.inSeconds.toDouble(),
            max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
            onChanged: (val) => _audioPlayer.seek(Duration(seconds: val.toInt())),
            activeColor: widget.isMe ? Colors.white : const Color(0xFF004D40),
            inactiveColor: widget.isMe ? Colors.white54 : Colors.grey,
          ),
        ),
      ],
    );
  }
}
