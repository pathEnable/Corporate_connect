import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

@immutable
class CallState {
  final bool localUserJoined;
  final Set<int> remoteUids;
  final bool isMicOn;
  final bool isCameraOn;
  final bool isScreenSharing;
  final bool isLoading;
  final String? errorMessage;
  final RtcEngine? engine;
  final bool isSpeakerOn;
  final int networkQuality;

  const CallState({
    this.localUserJoined = false,
    this.remoteUids = const {},
    this.isMicOn = true,
    this.isCameraOn = true,
    this.isScreenSharing = false,
    this.isLoading = true,
    this.errorMessage,
    this.engine,
    this.isSpeakerOn = true, // By default mostly true for video, but we toggle it
    this.networkQuality = 0, // 0 means unknown based on Agora constants
  });

  CallState copyWith({
    bool? localUserJoined,
    Set<int>? remoteUids,
    bool? isMicOn,
    bool? isCameraOn,
    bool? isScreenSharing,
    bool? isLoading,
    String? errorMessage,
    RtcEngine? engine,
    bool? isSpeakerOn,
    int? networkQuality,
  }) {
    return CallState(
      localUserJoined: localUserJoined ?? this.localUserJoined,
      remoteUids: remoteUids ?? this.remoteUids,
      isMicOn: isMicOn ?? this.isMicOn,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      engine: engine ?? this.engine,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      networkQuality: networkQuality ?? this.networkQuality,
    );
  }
  
  // Add or remote UID
  CallState addRemoteUid(int uid) {
    return copyWith(remoteUids: {...remoteUids, uid});
  }

  CallState removeRemoteUid(int uid) {
    final updated = Set<int>.from(remoteUids)..remove(uid);
    return copyWith(remoteUids: updated);
  }
}
