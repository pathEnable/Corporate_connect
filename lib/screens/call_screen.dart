import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import '../models/call_state.dart';
import '../providers/call_provider.dart';
import '../services/call_service.dart';

import '../services/ringtone_service.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String remoteUserName;
  final String channelId;
  final bool isVideo;

  const CallScreen({
    super.key, 
    required this.remoteUserName, 
    required this.channelId,
    this.isVideo = true
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final DateTime _startTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // On initialise l'appel au lancement via le provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(callProvider.notifier).initCall(widget.channelId, widget.isVideo);
      RingtoneService.instance.playRingtone();
    });
  }

  @override
  void dispose() {
    RingtoneService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callProvider);

    // Écouter le changement de remoteUid pour arrêter la sonnerie
    ref.listen(callProvider, (previous, next) {
      if (next.remoteUid != null && previous?.remoteUid == null) {
        RingtoneService.instance.stop();
      }
    });

    return PipWidget(
      onPipEntered: () => debugPrint("Entrée en PIP"),
      onPipExited: () => debugPrint("Sortie du PIP"),
      pipChild: _buildPipUI(state, Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _buildFullUI(state),
      ),
    );
  }

  /// Interface réduite pour le mode Picture-in-Picture
  Widget _buildPipUI(CallState state, ThemeData theme) {
    return _buildRemoteVideo(state, theme);
  }

  /// Interface complète
  Widget _buildFullUI(CallState state) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Background dynamique (Avatar flouté ou Vidéo)
        _buildRemoteVideo(state, theme),

        // Gradient overlay pour lisibilité
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(180),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withAlpha(200),
              ],
              stops: const [0.0, 0.2, 0.8, 1.0],
            ),
          ),
        ),

        // Local Video (Overlay)
        if (widget.isVideo && state.localUserJoined && state.engine != null)
          Positioned(
            right: 20,
            top: 60,
            child: Hero(
              tag: 'localVideo',
              child: Container(
                width: 110,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(80),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withAlpha(50), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: state.isCameraOn 
                    ? AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: state.engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      )
                    : Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.videocam_off_rounded, color: Colors.white54),
                      ),
                ),
              ),
            ),
          ),

        // Header
        Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 36),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.remoteUserName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: state.remoteUid != null ? Colors.greenAccent : Colors.orangeAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (state.remoteUid != null ? Colors.greenAccent : Colors.orangeAccent).withAlpha(100),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ]
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.remoteUid != null ? "En communication" : "Appel en cours...",
                          style: TextStyle(
                            color: Colors.white.withAlpha(180),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    color: Colors.white.withAlpha(30),
                    child: IconButton(
                      icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 24),
                      onPressed: () => SimplePip().enterPipMode(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Controls (Premium Glassmorphism)
        Positioned(
          bottom: 40,
          left: 24,
          right: 24,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(color: Colors.white.withAlpha(40)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCallAction(
                      theme: theme,
                      icon: state.isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                      isActive: state.isMicOn,
                      onPressed: () => ref.read(callProvider.notifier).toggleMic(),
                    ),
                    _buildCallAction(
                      theme: theme,
                      icon: Icons.call_end_rounded,
                      isEnd: true,
                      onPressed: () async {
                        final duration = DateTime.now().difference(_startTime).inSeconds;
                        final status = state.remoteUid != null ? "completed" : "missed";
                        
                        try {
                          await callService.logCall(
                            roomId: widget.channelId,
                            startTime: _startTime,
                            endTime: DateTime.now(),
                            duration: duration,
                            status: status,
                            callType: widget.isVideo ? "video" : "audio",
                          );
                        } catch (e) {
                          debugPrint("Erreur logCall in CallScreen: $e");
                        }
                        
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                    if (widget.isVideo)
                      _buildCallAction(
                        theme: theme,
                        icon: state.isCameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                        isActive: state.isCameraOn,
                        onPressed: () => ref.read(callProvider.notifier).toggleCamera(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (state.isLoading)
          const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
        
        if (state.errorMessage != null)
          Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.redAccent.withAlpha(200), borderRadius: BorderRadius.circular(12)),
              child: Text(state.errorMessage!, style: const TextStyle(color: Colors.white)),
            ),
          ),
      ],
    );
  }

  Widget _buildRemoteVideo(CallState state, ThemeData theme) {
    if (state.remoteUid != null && widget.isVideo && state.engine != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: state.engine!,
          canvas: VideoCanvas(uid: state.remoteUid),
          connection: RtcConnection(channelId: widget.channelId),
        ),
      );
    } else {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Background flouté
          const Center(
            child: Icon(Icons.person_rounded, size: 240, color: Colors.white10),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.black.withAlpha(120)),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(40), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 75,
                    backgroundColor: theme.colorScheme.primary.withAlpha(200),
                    child: const Icon(Icons.person_rounded, size: 90, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  widget.remoteUserName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                if (state.remoteUid == null)
                  Text(
                    "Appel vocal en cours...",
                    style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 16),
                  ),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildCallAction({
    required ThemeData theme,
    required IconData icon, 
    bool isActive = false, 
    bool isEnd = false, 
    required VoidCallback onPressed
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isEnd 
            ? Colors.redAccent.withAlpha(230) 
            : (isActive ? Colors.white.withAlpha(40) : Colors.black.withAlpha(100)),
          shape: BoxShape.circle,
          boxShadow: [
            if (isEnd) 
              BoxShadow(color: Colors.redAccent.withAlpha(80), blurRadius: 20, spreadRadius: 2)
            else if (isActive)
              BoxShadow(color: Colors.white.withAlpha(20), blurRadius: 10)
          ],
          border: Border.all(
            color: isEnd ? Colors.transparent : Colors.white.withAlpha(isActive ? 60 : 20),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}
