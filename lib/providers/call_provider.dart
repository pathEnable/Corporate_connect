import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/call_state.dart';
import '../services/agora_service.dart';
import '../services/ringtone_service.dart';

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

      // 2. Play waiting tone
      RingtoneService.instance.playWaitingTone();

      // 3. Token & Engine
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
            RingtoneService.instance.stop();
            state = state.addRemoteUid(remoteUid);
          },
          onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
            if (remoteUid == 0 || state.remoteUids.contains(remoteUid)) {
              state = state.copyWith(networkQuality: txQuality.index);
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            state = state.removeRemoteUid(remoteUid);
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            state = state.copyWith(localUserJoined: false, remoteUids: const {});
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
  
  Future<void> toggleSpeaker() async {
    final newState = !state.isSpeakerOn;
    await state.engine?.setEnableSpeakerphone(newState);
    state = state.copyWith(isSpeakerOn: newState);
  }

  Future<void> switchCamera() async {
    await state.engine?.switchCamera();
  }

  Future<void> toggleScreenShare() async {
    if (state.engine == null) return;
    
    final newState = !state.isScreenSharing;
    if (newState) {
      await state.engine?.startScreenCapture(const ScreenCaptureParameters2(captureAudio: true, captureVideo: true));
    } else {
      await state.engine?.stopScreenCapture();
    }
    state = state.copyWith(isScreenSharing: newState);
  }

  Future<void> leaveChannel() async {
    RingtoneService.instance.stop();
    await _agoraService.leaveChannel();
    state = const CallState(isLoading: false);
  }
}
