
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'chat_service.dart';

class WebRTCService {
  final ChatService _chatService = ChatService();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  Function(MediaStream)? onRemoteStream;

  static const _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  Future<void> init() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });
    
    _peerConnection = await createPeerConnection(_configuration);
    
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onIceCandidate = (candidate) {
      _chatService.sendMessage(
        '', // content
        type: 'ice_candidate',
        // data as payload
      );
      // Note: We need to adapt ChatService.sendMessage to accept extra data
    };

    _peerConnection!.onAddStream = (stream) {
      onRemoteStream?.call(stream);
    };
  }

  Future<void> makeOffer() async {
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    // Send offer via signaling
  }

  // ... Logic for answer and candidates will follow
  // For Day 10, we focus on the UI and basic setup.
}
