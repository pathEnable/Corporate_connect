import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
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

    // Auto-pop si l'appel est terminé à distance (géré par le notifier qui met de remoteUid à null)
    // Note: Dans une app réelle, on pourrait vouloir un timeout ou une confirmation.
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote Video ou Avatar
          _buildRemoteVideo(state),

          // Local Video (Overlay)
          if (widget.isVideo && state.localUserJoined && state.engine != null)
            Positioned(
              right: 20,
              top: 40,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: state.isCameraOn 
                    ? AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: state.engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      )
                    : const Center(child: Icon(Icons.videocam_off, color: Colors.white)),
                ),
              ),
            ),

          // Loading indicator
          if (state.isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF004D40)),
            ),

          // Error handling
          if (state.errorMessage != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                child: Text(state.errorMessage!, style: const TextStyle(color: Colors.white)),
              ),
            ),

          // Header (Nom du correspondant)
          Positioned(
            top: 50,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.remoteUserName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  state.remoteUid != null ? "En communication" : "Appel en cours...",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          // Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallAction(
                  icon: state.isMicOn ? Icons.mic : Icons.mic_off,
                  color: state.isMicOn ? Colors.white24 : Colors.redAccent,
                  onPressed: () => ref.read(callProvider.notifier).toggleMic(),
                ),
                _buildCallAction(
                  icon: Icons.call_end,
                  color: Colors.red,
                  onPressed: () => Navigator.pop(context),
                ),
                if (widget.isVideo)
                  _buildCallAction(
                    icon: state.isCameraOn ? Icons.videocam : Icons.videocam_off,
                    color: state.isCameraOn ? Colors.white24 : Colors.redAccent,
                    onPressed: () => ref.read(callProvider.notifier).toggleCamera(),
                  ),
              ],
            ),
          ),
        ],
      ),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Color(0xFF004D40),
              child: Icon(Icons.person, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              widget.remoteUserName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildCallAction({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: color,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: onPressed,
      ),
    );
  }
}
