import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

@immutable
class CallState {
  final bool localUserJoined;
  final int? remoteUid;
  final bool isMicOn;
  final bool isCameraOn;
  final bool isLoading;
  final String? errorMessage;
  final RtcEngine? engine;
  final bool isOutgoing;

  const CallState({
    this.localUserJoined = false,
    this.remoteUid,
    this.isMicOn = true,
    this.isCameraOn = true,
    this.isLoading = true,
    this.errorMessage,
    this.engine,
    this.isOutgoing = false,
  });

  CallState copyWith({
    bool? localUserJoined,
    int? remoteUid,
    bool? isMicOn,
    bool? isCameraOn,
    bool? isLoading,
    String? errorMessage,
    RtcEngine? engine,
    bool? isOutgoing,
  }) {
    return CallState(
      localUserJoined: localUserJoined ?? this.localUserJoined,
      remoteUid: remoteUid ?? this.remoteUid, // Allow nulling
      isMicOn: isMicOn ?? this.isMicOn,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      engine: engine ?? this.engine,
      isOutgoing: isOutgoing ?? this.isOutgoing,
    );
  }
  
  // Custom copyWith to specifically handle nulling remoteUid
  CallState updateRemoteUid(int? uid) {
    return CallState(
      localUserJoined: localUserJoined,
      remoteUid: uid,
      isMicOn: isMicOn,
      isCameraOn: isCameraOn,
      isLoading: isLoading,
      errorMessage: errorMessage,
      engine: engine,
      isOutgoing: isOutgoing,
    );
  }
}
