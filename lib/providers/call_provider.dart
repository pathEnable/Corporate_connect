import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/call_state.dart';
import '../services/agora_service.dart';

final callProvider = NotifierProvider.autoDispose<CallNotifier, CallState>(() {
  return CallNotifier();
});

class CallNotifier extends Notifier<CallState> {
  final AgoraService _agoraService = AgoraService();
  
  @override
  CallState build() {
    ref.onDispose(() {
      _agoraService.leaveChannel();
    });
    return const CallState();
  }

  Future<void> initCall(String channelId, bool isVideo) async {
    state = state.copyWith(isLoading: true);
    
    // 1. Permissions
    List<Permission> permissions = [Permission.microphone];
    if (isVideo) permissions.add(Permission.camera);
    await permissions.request();

    try {
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
