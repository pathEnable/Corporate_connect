
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
  double? _localVideoX;
  double? _localVideoY;

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

    // Écouter le changement de remoteUids pour arrêter la sonnerie
    ref.listen(callProvider, (previous, next) {
      if (next.remoteUids.isNotEmpty && (previous == null || previous.remoteUids.isEmpty)) {
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
            left: _localVideoX,
            top: _localVideoY ?? 60,
            right: _localVideoX == null ? 20 : null,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _localVideoX = (_localVideoX ?? (MediaQuery.of(context).size.width - 130)) + details.delta.dx;
                  _localVideoY = (_localVideoY ?? 60) + details.delta.dy;
                  
                  // Clamp to screen bounds roughly
                  if (_localVideoX! < 0) _localVideoX = 0;
                  if (_localVideoY! < 0) _localVideoY = 0;
                });
              },
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
                    child: state.isScreenSharing
                      ? Container(
                          color: Colors.blueAccent.withAlpha(200),
                          child: const Center(
                            child: Icon(Icons.screen_share_rounded, color: Colors.white, size: 40),
                          ),
                        )
                      : (state.isCameraOn 
                          ? AgoraVideoView(
                              controller: VideoViewController(
                                rtcEngine: state.engine!,
                                canvas: const VideoCanvas(uid: 0),
                              ),
                            )
                          : Container(
                              color: Colors.grey[900],
                              child: const Icon(Icons.videocam_off_rounded, color: Colors.white54),
                            )),
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
                    Row(
                      children: [
                        Text(
                          widget.remoteUserName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildNetworkIndicator(state.networkQuality),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: state.remoteUids.isNotEmpty ? Colors.greenAccent : Colors.orangeAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (state.remoteUids.isNotEmpty ? Colors.greenAccent : Colors.orangeAccent).withAlpha(100),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ]
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.remoteUids.isNotEmpty 
                              ? "${state.remoteUids.length} participant(s)" 
                              : "Appel en cours...",
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
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(100),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 24),
                  onPressed: () => SimplePip().enterPipMode(),
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
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(150),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Speaker toggle
                    _buildCallAction(
                      theme: theme,
                      icon: state.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                      isActive: state.isSpeakerOn,
                      onPressed: () => ref.read(callProvider.notifier).toggleSpeaker(),
                    ),
                    // Mic toggle
                    _buildCallAction(
                      theme: theme,
                      icon: state.isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                      isActive: state.isMicOn,
                      onPressed: () => ref.read(callProvider.notifier).toggleMic(),
                    ),
                    // End Call
                    _buildCallAction(
                      theme: theme,
                      icon: Icons.call_end_rounded,
                      isEnd: true,
                      onPressed: () async {
                        final duration = DateTime.now().difference(_startTime).inSeconds;
                        final status = state.remoteUids.isNotEmpty ? "completed" : "missed";
                        
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
                      // Screen Share
                      _buildCallAction(
                        theme: theme,
                        icon: state.isScreenSharing ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                        isActive: state.isScreenSharing,
                        onPressed: () => ref.read(callProvider.notifier).toggleScreenShare(),
                      ),
                      // Camera toggle
                      _buildCallAction(
                        theme: theme,
                        icon: state.isCameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                        isActive: state.isCameraOn,
                        onPressed: () => ref.read(callProvider.notifier).toggleCamera(),
                      ),
                      // Camera flip
                      _buildCallAction(
                        theme: theme,
                        icon: Icons.flip_camera_ios_rounded,
                        isActive: false,
                        onPressed: () => ref.read(callProvider.notifier).switchCamera(),
                      ),
                    ],
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
    if (state.remoteUids.isNotEmpty && widget.isVideo && state.engine != null) {
      if (state.remoteUids.length == 1) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: state.engine!,
            canvas: VideoCanvas(uid: state.remoteUids.first),
            connection: RtcConnection(channelId: widget.channelId),
          ),
        );
      } else {
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: state.remoteUids.length > 2 ? 2 : 1,
            childAspectRatio: state.remoteUids.length > 2 ? 1.0 : 0.8,
          ),
          itemCount: state.remoteUids.length,
          itemBuilder: (context, index) {
            final uid = state.remoteUids.elementAt(index);
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: state.engine!,
                    canvas: VideoCanvas(uid: uid),
                    connection: RtcConnection(channelId: widget.channelId),
                  ),
                ),
              ),
            );
          },
        );
      }
    } else {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Background flouté
          const Center(
            child: Icon(Icons.person_rounded, size: 240, color: Colors.white10),
          ),
          Container(color: Colors.black.withAlpha(200)),
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
                if (state.remoteUids.isEmpty)
                  Text(
                    "En attente des autres participants...",
                    style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 16),
                  ),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildNetworkIndicator(int quality) {
    Color color = Colors.grey;
    IconData icon = Icons.signal_cellular_alt_rounded;
    
    // 0: Unknown, 1: Excellent, 2: Good, 3: Poor, 4: Bad, 5: VBad, 6: Down
    if (quality == 1 || quality == 2) {
      color = Colors.greenAccent;
    } else if (quality == 3) {
      color = Colors.orangeAccent;
    } else if (quality >= 4 && quality <= 6) {
      color = Colors.redAccent;
      icon = Icons.signal_cellular_connected_no_internet_0_bar_rounded;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            quality == 0 ? "Calcul..." : (quality <= 2 ? "Excellente" : (quality == 3 ? "Moyenne" : "Faible")),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
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
