import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import '../providers/call_provider.dart';

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

  @override
  void initState() {
    super.initState();
    // On initialise l'appel au lancement via le provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(callProvider.notifier).initCall(widget.channelId, widget.isVideo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callProvider);

    return PipWidget(
      onPipEntered: () => debugPrint("Entrée en PIP"),
      onPipExited: () => debugPrint("Sortie du PIP"),
      pipChild: _buildPipUI(state),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _buildFullUI(state),
      ),
    );
  }

  /// Interface réduite pour le mode Picture-in-Picture
  Widget _buildPipUI(dynamic state) {
    return _buildRemoteVideo(state);
  }

  /// Interface complète
  Widget _buildFullUI(dynamic state) {
    return Stack(
      children: [
        // Background dynamique (Avatar flouté ou Vidéo)
        _buildRemoteVideo(state),

        // Gradient overlay pour lisibilité
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.6),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.7),
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
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: state.isCameraOn 
                    ? AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: state.engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      )
                    : Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.videocam_off, color: Colors.white54),
                      ),
                ),
              ),
            ),
          ),

        // Header
        Positioned(
          top: 60,
          left: 24,
          right: 24,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.remoteUserName,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          state.remoteUid != null ? "En communication" : "Appel en cours...",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.1),
                    child: IconButton(
                      icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white, size: 24),
                      onPressed: () => SimplePip().enterPipMode(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Controls (Glassmorphism)
        Positioned(
          bottom: 50,
          left: 30,
          right: 30,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCallAction(
                      icon: state.isMicOn ? Icons.mic : Icons.mic_off,
                      isActive: state.isMicOn,
                      onPressed: () => ref.read(callProvider.notifier).toggleMic(),
                    ),
                    _buildCallAction(
                      icon: Icons.call_end,
                      isEnd: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                    if (widget.isVideo)
                      _buildCallAction(
                        icon: state.isCameraOn ? Icons.videocam : Icons.videocam_off,
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
          const Center(child: CircularProgressIndicator(color: Colors.white70)),
      ],
    );
  }

  Widget _buildRemoteVideo(dynamic state) {
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
          // Avatar flouté en fond
          const Center(
            child: Icon(Icons.person, size: 200, color: Colors.white10),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: const CircleAvatar(
                    radius: 70,
                    backgroundColor: Color(0xFF00695C),
                    child: Icon(Icons.person, size: 90, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  widget.remoteUserName,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildCallAction({required IconData icon, bool isActive = false, bool isEnd = false, required VoidCallback onPressed}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isEnd ? Colors.redAccent : (isActive ? Colors.white.withValues(alpha: 0.15) : Colors.black38),
              shape: BoxShape.circle,
              boxShadow: [
                if (isEnd) 
                  BoxShadow(color: Colors.redAccent.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2)
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }
}
