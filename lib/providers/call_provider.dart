import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/call_state.dart';
import '../services/agora_service.dart';

final callProvider = NotifierProvider.autoDispose<CallNotifier, CallState>(() {
  return CallNotifier();
});

class CallNotifier extends AutoDisposeNotifier<CallState> {
  final AgoraService _agoraService = AgoraService();
  
  @override
  CallState build() {
    ref.onDispose(() {
      _agoraService.leaveChannel();
    });
    return const CallState();
  }

  Future<void> _requestPermissions(bool isVideo) async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      if (isVideo) Permission.camera,
    ].request();

    if (statuses[Permission.microphone] != PermissionStatus.granted) {
      throw 'Accès au microphone requis pour l\'appel';
    }
    if (isVideo && statuses[Permission.camera] != PermissionStatus.granted) {
      throw 'Accès à la caméra requis pour la vidéo';
    }
  }

  Future<void> initCall(String channelId, bool isVideo) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      // 1. Permissions Guard
      await _requestPermissions(isVideo);

      // 2. Token & Engine
      final tokenData = await _agoraService.fetchToken(channelId);
      final String token = tokenData['token'];
      final String appId = tokenData['app_id'];

      final engine = await _agoraService.getEngine(appId, isVideo: isVideo);
      
      // 3. Handlers
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            state = state.copyWith(localUserJoined: true, isLoading: false);
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            state = state.copyWith(remoteUid: remoteUid);
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            state = state.updateRemoteUid(null);
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            state = state.copyWith(localUserJoined: false, remoteUid: null);
          },
          onError: (ErrorCodeType err, String msg) {
            state = state.copyWith(errorMessage: "Erreur Agora: $msg", isLoading: false);
          },
        ),
      );

      state = state.copyWith(engine: engine);

      // 4. Join
      await _agoraService.joinChannel(token, channelId, 0, isVideo: isVideo);

    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> toggleMic() async {
    final newState = !state.isMicOn;
    await state.engine?.muteLocalAudioStream(state.isMicOn); // Agora use "mute" so if mic was ON (true), we send true to mute it.
    state = state.copyWith(isMicOn: newState);
  }

  Future<void> toggleCamera() async {
    final newState = !state.isCameraOn;
    await state.engine?.muteLocalVideoStream(state.isCameraOn);
    state = state.copyWith(isCameraOn: newState);
  }

  Future<void> leaveChannel() async {
    await _agoraService.leaveChannel();
    state = const CallState(isLoading: false);
  }
}
