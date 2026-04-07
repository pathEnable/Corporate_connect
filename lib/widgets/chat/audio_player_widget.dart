import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../theme/app_theme.dart';
import '../../services/media_service.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  final String? localPath;
  final bool isMe;

  const AudioPlayerWidget({
    super.key,
    required this.url,
    this.localPath,
    required this.isMe,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  late StreamSubscription _durationSubscription;
  late StreamSubscription _positionSubscription;
  late StreamSubscription _playerStateSubscription;

  // Mock waveform for visualization
  final List<double> _waveformData = [
    0.3, 0.5, 0.4, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.5, 
    0.3, 0.6, 0.4, 0.7, 0.5, 1.0, 0.6, 0.4, 0.8, 0.5,
    0.3, 0.5, 0.4, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.5,
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
  }

  @override
  void dispose() {
    _durationSubscription.cancel();
    _positionSubscription.cancel();
    _playerStateSubscription.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      Source source;
      if (widget.localPath != null && File(widget.localPath!).existsSync()) {
        source = DeviceFileSource(widget.localPath!);
      } else {
        try {
          final fullUrl = await MediaService().getDownloadUrl(widget.url);
          source = UrlSource(fullUrl);
        } catch (e) {
          source = UrlSource(widget.url);
        }
      }
      await _audioPlayer.play(source);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isMe ? Colors.white : AppTheme.primaryGreen;
    final secondaryColor = widget.isMe ? Colors.white70 : Colors.black54;

    double progress = _duration.inMilliseconds > 0 
        ? _position.inMilliseconds / _duration.inMilliseconds 
        : 0.0;

    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playerState == PlayerState.playing 
                    ? Icons.pause_rounded 
                    : Icons.play_arrow_rounded,
                color: primaryColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox;
                    final localPosition = box.globalToLocal(details.globalPosition);
                    // Estimate position based on width (width is approx 180 after padding)
                    final percent = (localPosition.dx - 40).clamp(0, 180) / 180;
                    _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * percent).toInt()));
                  },
                  child: Container(
                    height: 30,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_waveformData.length, (index) {
                        final barProgress = index / _waveformData.length;
                        final isActive = barProgress <= progress;
                        return Container(
                          width: 3,
                          height: 30 * _waveformData[index],
                          decoration: BoxDecoration(
                            color: isActive ? primaryColor : primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: secondaryColor, fontSize: 10),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(color: secondaryColor, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
