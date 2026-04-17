import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/call_state.dart';
import '../services/agora_service.dart';
import '../services/call_service.dart';
import '../services/call_signaling_service.dart';
import '../services/ringtone_service.dart';

/// Provider global pour l'état de l'appel en cours.
final callProvider = NotifierProvider<CallNotifier, CallState>(() {
  return CallNotifier();
});

class CallNotifier extends Notifier<CallState> {
  final AgoraService _agoraService = AgoraService();
  final CallSignalingService _signalingService = CallSignalingService();
  final RingtoneService _ringtoneService = RingtoneService();

  Timer? _durationTimer;
  Timer? _timeoutTimer;
  // ✅ FIX BUG 5 : Timer cancellable pour éviter le double reset
  Timer? _resetTimer;

  static const Duration _callTimeout = Duration(seconds: 40);

  @override
  CallState build() {
    ref.onDispose(() {
      _cleanup();
    });
    return CallState.initial;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FLUX APPELANT (Outgoing Call)
  // ═══════════════════════════════════════════════════════════════════════════

  /// L'utilisateur A lance un appel.
  Future<bool> initiateCall({
    required String roomId,
    required bool isVideo,
    String? otherUserName,
    String? otherUserAvatar,
  }) async {
    // Vérifier qu'aucun appel n'est en cours
    if (state.phase != CallPhase.idle) {
      debugPrint('⚠️ Un appel est déjà en cours');
      return false;
    }

    // Demander les permissions
    final granted = await _requestPermissions(isVideo);
    if (!granted) {
      state = state.copyWith(
        errorMessage: 'Permissions micro/caméra refusées',
      );
      return false;
    }

    // Mettre en état "appel sortant"
    state = state.copyWith(
      phase: CallPhase.outgoingRinging,
      isVideo: isVideo,
      isCaller: true,
      roomId: roomId,
      otherUserName: otherUserName,
      otherUserAvatar: otherUserAvatar,
      clearErrorMessage: true,
    );

    // Appeler le backend pour initier l'appel
    final result = await _signalingService.initiateCall(
      roomId: roomId,
      isVideo: isVideo,
    );

    if (result == null) {
      state = state.copyWith(
        phase: CallPhase.ended,
        errorMessage: 'Impossible de lancer l\'appel',
      );
      _scheduleReset();
      return false;
    }

    // Mettre à jour avec les infos du backend
    state = state.copyWith(
      callId: result['call_id'],
      agoraToken: result['agora_token'],
      appId: result['app_id'],
      channelName: result['channel_name'],
    );

    // Jouer la tonalité d'attente (tut... tut...)
    _ringtoneService.playWaitingTone();

    // ✅ BUG FIX : L'appelant N'ENTRE PAS dans Agora ici.
    // Il attend que le destinataire décroche (événement WS call_answered)
    // pour rejoindre le canal, via onCallAnswered().

    // Timer timeout : si pas de réponse après 40s, annuler
    _timeoutTimer = Timer(_callTimeout, () {
      if (state.phase == CallPhase.outgoingRinging) {
        debugPrint('⏰ Timeout appel — annulation automatique');
        cancelCall();
      }
    });

    return true;
  }

  /// L'appelant annule l'appel (raccroche avant que B décroche).
  Future<void> cancelCall() async {
    if (state.callId != null) {
      await _signalingService.cancelCall(callId: state.callId!);
    }
    await _ringtoneService.stop();
    await _ringtoneService.playEndCallTone();
    await _endAndCleanup(phase: CallPhase.ended);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FLUX DESTINATAIRE (Incoming Call)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Un appel entrant est reçu (appelé par GlobalCallListener).
  void onIncomingCall({
    required String callId,
    required String channelName,
    required String callerName,
    String? callerAvatar,
    required String roomId,
    required bool isVideo,
  }) {
    if (state.phase != CallPhase.idle) {
      debugPrint('⚠️ Appel entrant ignoré : déjà en appel');
      _signalingService.rejectCall(callId: callId);
      return;
    }

    state = state.copyWith(
      phase: CallPhase.incomingRinging,
      callId: callId,
      channelName: channelName,
      roomId: roomId,
      isVideo: isVideo,
      isCaller: false,
      otherUserName: callerName,
      otherUserAvatar: callerAvatar,
      clearErrorMessage: true,
    );

    // ✅ FIX BUG 2 : On ne fait pas await sur playRingtone() pour éviter la
    // race condition quand CallKit accepte immédiatement après onIncomingCall().
    // Le stop() dans acceptCall() arrivera après que le player soit initialisé.
    _ringtoneService.playRingtone().ignore();
  }

  /// Le destinataire accepte l'appel.
  Future<bool> acceptCall() async {
    if (state.phase != CallPhase.incomingRinging || state.callId == null) {
      return false;
    }

    // Arrêter la sonnerie
    await _ringtoneService.stop();

    // Demander les permissions
    final granted = await _requestPermissions(state.isVideo);
    if (!granted) {
      state = state.copyWith(
        errorMessage: 'Permissions refusées',
        phase: CallPhase.ended,
      );
      _scheduleReset();
      return false;
    }

    state = state.copyWith(phase: CallPhase.connecting);

    // Appeler le backend pour accepter
    final result = await _signalingService.answerCall(
      callId: state.callId!,
      channelName: state.channelName ?? '',
    );

    if (result == null) {
      state = state.copyWith(
        phase: CallPhase.ended,
        errorMessage: 'Erreur de connexion',
      );
      _scheduleReset();
      return false;
    }

    // Mettre à jour les infos Agora
    state = state.copyWith(
      agoraToken: result['agora_token'],
      appId: result['app_id'],
      channelName: result['channel_name'],
    );

    // Initialiser Agora et rejoindre le canal
    try {
      await _initAgoraAndJoin();
    } catch (e) {
      debugPrint('❌ Erreur init Agora (receiver): $e');
      state = state.copyWith(
        phase: CallPhase.ended,
        errorMessage: 'Erreur: ${e.toString().replaceAll('Exception: ', '')}',
      );
      _scheduleReset();
      return false;
    }

    return true;
  }

  /// Le destinataire refuse l'appel.
  Future<void> rejectCall() async {
    if (state.callId != null) {
      await _signalingService.rejectCall(callId: state.callId!);
    }
    await _ringtoneService.stop();
    await _endAndCleanup(phase: CallPhase.idle); // Retour direct à idle
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ÉVÉNEMENTS REÇUS VIA WEBSOCKET GLOBAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// L'autre participant a décroché (reçu par l'appelant).
  /// ✅ BUG FIX : C'est ici que l'appelant rejoint Agora (pas dans initiateCall).
  Future<void> onCallAnswered() async {
    if (state.phase != CallPhase.outgoingRinging) return;

    debugPrint('📞 Appel accepté — rejoindre le canal Agora');
    _ringtoneService.stop();
    _timeoutTimer?.cancel();

    // Passer en mode connexion
    state = state.copyWith(phase: CallPhase.connecting);

    // Rejoindre Agora maintenant que les deux sont prêts
    try {
      await _initAgoraAndJoin();
      // La phase passe à connected via onUserJoined dans _initAgoraAndJoin()
    } catch (e) {
      debugPrint('❌ Erreur Agora (appelant après acceptation): $e');
      state = state.copyWith(
        phase: CallPhase.ended,
        errorMessage: 'Erreur: ${e.toString().replaceAll('Exception: ', '')}',
      );
      _scheduleReset();
    }
  }

  /// L'autre participant a refusé (reçu par l'appelant).
  void onCallRejected() {
    if (state.phase != CallPhase.outgoingRinging) return;

    debugPrint('📞 Appel refusé par le destinataire');
    _ringtoneService.stop();
    _timeoutTimer?.cancel();
    _endAndCleanup(phase: CallPhase.ended, error: 'Appel refusé');
  }

  /// L'autre participant a raccroché (reçu par n'importe qui).
  void onCallEnded() {
    debugPrint('📞 L\'autre participant a raccroché');
    _ringtoneService.stop();
    _ringtoneService.playEndCallTone();
    _endAndCleanup(phase: CallPhase.ended);
  }

  /// L'appelant a annulé (reçu par le destinataire).
  void onCallCancelled() {
    // ✅ FIX BUG 9 : Aussi gérer 'connecting' — l'appelant peut annuler
    // pendant que le destinataire est en train d'accepter.
    if (state.phase != CallPhase.incomingRinging && state.phase != CallPhase.connecting) return;

    debugPrint('📞 L\'appelant a annulé');
    _ringtoneService.stop();
    _endAndCleanup(phase: CallPhase.idle); // Retour silencieux à idle
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTRÔLES PENDANT L'APPEL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Raccrocher (utilisable à tout moment, quel que soit l'état).
  Future<void> hangUp() async {
    if (state.callId != null) {
      if (state.phase == CallPhase.outgoingRinging) {
        await cancelCall();
      } else if (state.phase == CallPhase.incomingRinging) {
        // ✅ FIX BUG 3 : Cas manquant — l'utilisateur raccroche depuis CallKit
        // alors que l'appel est encore en train de sonner (pas encore accepté).
        await rejectCall();
      } else if (state.phase == CallPhase.connected || state.phase == CallPhase.connecting) {
        await _signalingService.endCall(callId: state.callId!);
        await _ringtoneService.playEndCallTone();
        await _endAndCleanup(phase: CallPhase.ended);
      }
    } else {
      await _endAndCleanup(phase: CallPhase.idle);
    }
  }

  void toggleMute() {
    final newMuted = !state.isMuted;
    _agoraService.toggleMute(newMuted);
    state = state.copyWith(isMuted: newMuted);
  }

  void toggleVideo() {
    final newDisabled = !state.isVideoDisabled;
    _agoraService.toggleVideo(newDisabled);
    state = state.copyWith(isVideoDisabled: newDisabled);
  }

  void toggleSpeaker() {
    final newSpeaker = !state.isSpeakerOn;
    _agoraService.toggleSpeaker(newSpeaker);
    state = state.copyWith(isSpeakerOn: newSpeaker);
  }

  void switchCamera() {
    _agoraService.switchCamera();
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTERNALS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> _requestPermissions(bool needVideo) async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) return false;
    
    if (needVideo) {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) return false;
    }
    return true;
  }

  Future<void> _initAgoraAndJoin() async {
    if (state.appId == null || state.agoraToken == null || state.channelName == null) {
      throw Exception('Données Agora manquantes');
    }

    // Guard : ne pas ré-initialiser si déjà dans le canal
    if (AgoraService().isInChannel) {
      debugPrint('⚠️ _initAgoraAndJoin appelé alors qu\'on est déjà dans un canal — ignoré');
      return;
    }

    final engine = await AgoraService().initEngine(state.appId!);

    // Enregistrer les handlers d'événements
    engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        // ✅ FIX BLOCAGE : on passe à "connected" dès qu'on rejoint le canal,
        // sans attendre onUserJoined. L'audio/vidéo local est déjà actif.
        debugPrint('✅ Canal Agora rejoint avec succès (elapsed: ${elapsed}ms)');
        if (state.phase == CallPhase.connecting) {
          _ringtoneService.stop();
          _timeoutTimer?.cancel();
          final now = DateTime.now();
          state = state.copyWith(
            phase: CallPhase.connected,
            connectedAt: now,
          );
          _startDurationTimer();
        }
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        // Mise à jour du remoteUid quand l'autre participant arrive
        debugPrint('👤 Utilisateur distant rejoint: $remoteUid');
        state = state.copyWith(remoteUid: remoteUid);
      },
      onUserOffline: (connection, remoteUid, reason) {
        debugPrint('👤 Utilisateur distant parti: $remoteUid (reason: $reason)');
        if (state.remoteUid == remoteUid) {
          // L'autre a quitté → appel terminé
          _ringtoneService.playEndCallTone();
          _endAndCleanup(phase: CallPhase.ended);
        }
      },
      onUserMuteVideo: (connection, remoteUid, muted) {
        if (state.remoteUid == remoteUid) {
          state = state.copyWith(isRemoteVideoEnabled: !muted);
        }
      },
      onError: (err, msg) {
        debugPrint('❌ Agora error: $err - $msg');
        // Erreur critique : terminér proprement
        if (state.phase == CallPhase.connecting || state.phase == CallPhase.connected) {
          state = state.copyWith(
            phase: CallPhase.ended,
            errorMessage: 'Erreur de connexion ($err)',
          );
          _scheduleReset();
        }
      },
    ));

    // Rejoindre le canal avec le bon routage audio
    await AgoraService().joinChannel(
      token: state.agoraToken!,
      channelName: state.channelName!,
      uid: 0,
      enableVideo: state.isVideo,
      // Vidéo : haut-parleur forcé. Audio : écouteur par défaut.
      forceSpeaker: state.isVideo,
    );
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.connectedAt != null) {
        final duration = DateTime.now().difference(state.connectedAt!);
        state = state.copyWith(callDuration: duration);
      }
    });
  }

  Future<void> _endAndCleanup({required CallPhase phase, String? error}) async {
    _timeoutTimer?.cancel();
    _durationTimer?.cancel();

    // ✅ FIX BUG 6 : Enregistrer l'appel dans l'historique si une connexion a eu lieu
    if (state.connectedAt != null && state.roomId != null) {
      final endTime = DateTime.now();
      final duration = endTime.difference(state.connectedAt!).inSeconds;
      callService.logCall(
        roomId: state.roomId!,
        startTime: state.connectedAt!,
        endTime: endTime,
        duration: duration,
        status: error != null ? 'missed' : 'completed',
        callType: state.isVideo ? 'video' : 'audio',
      );
    }

    state = state.copyWith(
      phase: phase,
      errorMessage: error,
    );

    // Libérer Agora
    try {
      await _agoraService.dispose();
    } catch (e) {
      debugPrint('⚠️ Erreur cleanup Agora: $e');
    }

    if (phase == CallPhase.ended) {
      _scheduleReset();
    }
  }

  /// Réinitialise l'état après un délai (pour afficher un feedback visuel).
  void _scheduleReset() {
    // ✅ FIX BUG 5 : Timer cancellable — évite le double reset si deux fins
    // d'appel arrivent quasi-simultanément (ex: WS call_ended + onUserOffline Agora).
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (state.phase == CallPhase.ended) {
        state = CallState.initial;
      }
    });
  }

  void _cleanup() {
    _timeoutTimer?.cancel();
    _durationTimer?.cancel();
    _resetTimer?.cancel();
    _ringtoneService.stop();
  }

  /// Réinitialise l'état immédiatement (pour la navigation).
  void resetState() {
    _cleanup();
    state = CallState.initial;
  }
}
