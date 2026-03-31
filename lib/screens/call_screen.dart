import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/agora_service.dart';

class CallScreen extends StatefulWidget {
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
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final AgoraService _agoraService = AgoraService();
  RtcEngine? _engine;
  
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _isMicOn = true;
  bool _isCameraOn = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // 1. Demander les permissions
    List<Permission> permissions = [Permission.microphone];
    if (widget.isVideo) {
      permissions.add(Permission.camera);
    }
    await permissions.request();

    try {
      // 2. Récupérer le token et l'App ID depuis le backend
      final tokenData = await _agoraService.fetchToken(widget.channelId);
      final String token = tokenData['token'];
      final String appId = tokenData['app_id'];

      // 3. Initialiser le moteur
      _engine = await _agoraService.getEngine(appId, isVideo: widget.isVideo);

      // 4. Définir les handlers d'événements
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("Local user joined: ${connection.localUid}");
            setState(() {
              _localUserJoined = true;
              _isLoading = false;
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("Remote user joined: $remoteUid");
            setState(() {
              _remoteUid = remoteUid;
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint("Remote user offline: $remoteUid");
            setState(() {
              _remoteUid = null;
            });
            // Si c'est un appel 1:1, on peut fermer l'écran si l'autre part
            Navigator.pop(context);
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            debugPrint("Local user left channel");
            setState(() {
              _localUserJoined = false;
              _remoteUid = null;
            });
          },
        ),
      );

      // 5. Rejoindre le canal
      await _agoraService.joinChannel(token, widget.channelId, 0, isVideo: widget.isVideo);

    } catch (e) {
      debugPrint("Erreur initialisation Agora: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur d'appel: $e")),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _agoraService.leaveChannel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote Video ou Avatar
          _buildRemoteVideo(),

          // Local Video (Overlay)
          if (widget.isVideo && _localUserJoined)
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
                  child: _isCameraOn 
                    ? AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      )
                    : const Center(child: Icon(Icons.videocam_off, color: Colors.white)),
                ),
              ),
            ),

          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF004D40)),
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
                  _remoteUid != null ? "En communication" : "Appel en cours...",
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
                  icon: _isMicOn ? Icons.mic : Icons.mic_off,
                  color: _isMicOn ? Colors.white24 : Colors.redAccent,
                  onPressed: () {
                    _engine?.muteLocalAudioStream(_isMicOn);
                    setState(() => _isMicOn = !_isMicOn);
                  },
                ),
                _buildCallAction(
                  icon: Icons.call_end,
                  color: Colors.red,
                  onPressed: () => Navigator.pop(context),
                ),
                if (widget.isVideo)
                  _buildCallAction(
                    icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                    color: _isCameraOn ? Colors.white24 : Colors.redAccent,
                    onPressed: () {
                      _engine?.muteLocalVideoStream(_isCameraOn);
                      setState(() => _isCameraOn = !_isCameraOn);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (_remoteUid != null && widget.isVideo) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
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
