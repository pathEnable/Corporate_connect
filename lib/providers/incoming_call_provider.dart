import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart' as ck;
import 'package:uuid/uuid.dart';
import '../services/ringtone_service.dart';
import 'dart:async';

class IncomingCallState {
  final bool isRinging;
  final String? callerName;
  final String? callerAvatar;
  final String? roomId;
  final String? callId;
  final bool isVideo;

  IncomingCallState({
    this.isRinging = false,
    this.callerName,
    this.callerAvatar,
    this.roomId,
    this.callId,
    this.isVideo = false,
  });

  IncomingCallState copyWith({
    bool? isRinging,
    String? callerName,
    String? callerAvatar,
    String? roomId,
    String? callId,
    bool? isVideo,
  }) {
    return IncomingCallState(
      isRinging: isRinging ?? this.isRinging,
      callerName: callerName ?? this.callerName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      roomId: roomId ?? this.roomId,
      callId: callId ?? this.callId,
      isVideo: isVideo ?? this.isVideo,
    );
  }
}

class IncomingCallNotifier extends StateNotifier<IncomingCallState> {
  IncomingCallNotifier() : super(IncomingCallState()) {
    _listenToCallEvents();
  }

  StreamSubscription? _callStreamSubscription;

  void _listenToCallEvents() {
    _callStreamSubscription = FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;
      
      switch (event.event) {
        case ck.Event.actionCallAccept:
          _handleAccept();
          break;
        case ck.Event.actionCallDecline:
          _handleDecline();
          break;
        default:
          break;
      }
    });
  }

  Future<void> showIncomingCall({
    required String name,
    required String avatar,
    required String roomId,
    bool isVideo = false,
  }) async {
    final uuid = const Uuid().v4();
    state = state.copyWith(
      isRinging: true,
      callerName: name,
      callerAvatar: avatar,
      roomId: roomId,
      callId: uuid,
      isVideo: isVideo,
    );

    RingtoneService.instance.playRingtone();

    final params = CallKitParams(
      id: uuid,
      nameCaller: name,
      appName: 'Corporate Connect',
      avatar: avatar,
      handle: 'Appel entrant...',
      type: isVideo ? 1 : 0,
      duration: 30000,
      extra: <String, dynamic>{'room_id': roomId},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'ringtone_incoming',
        backgroundColor: '#040301',
        actionColor: '#4CAF50',
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        supportsGrouping: false,
        supportsUngrouping: false,
        supportsHolding: false,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  void _handleAccept() {
    state = state.copyWith(isRinging: false);
    RingtoneService.instance.stop();
  }

  void _handleDecline() {
    state = state.copyWith(isRinging: false);
    RingtoneService.instance.stop();
    FlutterCallkitIncoming.endAllCalls();
  }

  void stopRinging() {
    state = state.copyWith(isRinging: false);
    RingtoneService.instance.stop();
    FlutterCallkitIncoming.endAllCalls();
  }

  @override
  void dispose() {
    _callStreamSubscription?.cancel();
    super.dispose();
  }
}

final incomingCallProvider = StateNotifierProvider<IncomingCallNotifier, IncomingCallState>((ref) {
  return IncomingCallNotifier();
});
