import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/media_service.dart';
import '../../screens/image_viewer_screen.dart';

class MessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final String timestamp;
  final String type;
  final String status;
  final bool isRead;
  final bool isEncrypted;
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
    this.isEncrypted = false,
    this.replyToContent,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final notMeBgColor = isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white;
    final notMeTextColor = isDark ? Colors.white : Colors.black87;
    final replyBorderColor = isMe ? Colors.white : theme.colorScheme.primary;

    return GestureDetector(
      onLongPress: onReply,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            gradient: isMe 
              ? LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
            color: isMe ? null : notMeBgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(24),
              topRight: const Radius.circular(24),
              bottomLeft: isMe ? const Radius.circular(24) : const Radius.circular(6),
              bottomRight: isMe ? const Radius.circular(6) : const Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: isMe 
                  ? theme.colorScheme.primary.withValues(alpha: 0.25) 
                  : Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: isMe ? null : Border.all(color: Colors.grey.withValues(alpha: 0.1), width: 1),
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
                    color: isMe ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(color: replyBorderColor, width: 4)),
                  ),
                  child: Text(
                    replyToContent!.length > 60 ? '${replyToContent!.substring(0, 60)}...' : replyToContent!,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isMe ? Colors.white.withValues(alpha: 0.85) : notMeTextColor.withValues(alpha: 0.7),
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
                    color: isMe ? Colors.white : notMeTextColor,
                    fontSize: 15.5,
                    height: 1.3,
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
                child: CachedNetworkImage(
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

    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        try {
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
                color: iconColor.withValues(alpha: 0.2),
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

  String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          _buildPlayButton(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSlider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTimerText(_printDuration(_position)),
                      _buildTimerText(_printDuration(_duration)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_isPlaying) {
            _audioPlayer.pause();
          } else {
            _audioPlayer.resume();
          }
        },
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.isMe ? Colors.white.withAlpha(51) : theme.colorScheme.primary.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: widget.isMe ? Colors.white : theme.colorScheme.primary,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildSlider() {
    final theme = Theme.of(context);
    final waveformData = [
      0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.4, 0.7, 0.5, 1.0, 
      0.6, 0.8, 0.4, 0.9, 0.6, 0.7, 0.5, 0.8, 0.4, 0.6
    ];
    
    final currentProgress = _duration.inMilliseconds > 0 
        ? _position.inMilliseconds / _duration.inMilliseconds 
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          final box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          final percent = (localPosition.dx - 40).clamp(0, 160) / 160;
          _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * percent).toInt()));
        },
        child: SizedBox(
          height: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(waveformData.length, (index) {
              final barProgress = index / waveformData.length;
              final isActive = barProgress <= currentProgress;
              
              return Container(
                width: 3,
                height: 30 * waveformData[index],
                decoration: BoxDecoration(
                  color: isActive 
                      ? (widget.isMe ? Colors.white : theme.colorScheme.primary)
                      : (widget.isMe ? Colors.white.withAlpha(77) : theme.dividerColor),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: widget.isMe ? Colors.white70 : Colors.grey[600],
        fontSize: 10,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
