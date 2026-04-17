/// Phase du cycle de vie d'un appel.
enum CallPhase {
  /// Aucun appel en cours
  idle,
  /// Appel sortant en train de sonner chez le destinataire
  outgoingRinging,
  /// Appel entrant reçu (sonnerie côté destinataire)
  incomingRinging,
  /// En cours de connexion (après acceptation, avant que l'audio/vidéo soit établi)
  connecting,
  /// Appel actif et connecté
  connected,
  /// Appel terminé (affichage temporaire avant retour)
  ended,
}

/// État complet d'un appel.
class CallState {
  final CallPhase phase;
  final String? callId;
  final String? channelName;
  final String? agoraToken;
  final String? appId;
  final String? roomId;
  
  /// Infos sur l'autre participant
  final String? otherUserName;
  final String? otherUserAvatar;
  
  /// Type d'appel
  final bool isVideo;
  final bool isCaller; // true = émetteur, false = destinataire
  
  /// Contrôles
  final bool isMuted;
  final bool isVideoDisabled;
  final bool isSpeakerOn;
  final bool isFrontCamera;
  
  /// Connexion Agora
  final int? remoteUid;
  final bool isRemoteVideoEnabled;
  
  /// Timer
  final Duration callDuration;
  final DateTime? connectedAt; // Heure de connexion effective
  
  /// Erreurs
  final String? errorMessage;

  const CallState({
    this.phase = CallPhase.idle,
    this.callId,
    this.channelName,
    this.agoraToken,
    this.appId,
    this.roomId,
    this.otherUserName,
    this.otherUserAvatar,
    this.isVideo = false,
    this.isCaller = true,
    this.isMuted = false,
    this.isVideoDisabled = false,
    this.isSpeakerOn = false,
    this.isFrontCamera = true,
    this.remoteUid,
    this.isRemoteVideoEnabled = false,
    this.callDuration = Duration.zero,
    this.connectedAt,
    this.errorMessage,
  });

  /// CopyWith avec support explicite de la mise à null de champs optionnels.
  /// Utiliser clearErrorMessage: true pour remettre errorMessage à null.
  CallState copyWith({
    CallPhase? phase,
    String? callId,
    String? channelName,
    String? agoraToken,
    String? appId,
    String? roomId,
    String? otherUserName,
    String? otherUserAvatar,
    bool? isVideo,
    bool? isCaller,
    bool? isMuted,
    bool? isVideoDisabled,
    bool? isSpeakerOn,
    bool? isFrontCamera,
    int? remoteUid,
    bool? isRemoteVideoEnabled,
    Duration? callDuration,
    DateTime? connectedAt,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool clearRemoteUid = false,
  }) {
    return CallState(
      phase: phase ?? this.phase,
      callId: callId ?? this.callId,
      channelName: channelName ?? this.channelName,
      agoraToken: agoraToken ?? this.agoraToken,
      appId: appId ?? this.appId,
      roomId: roomId ?? this.roomId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      isVideo: isVideo ?? this.isVideo,
      isCaller: isCaller ?? this.isCaller,
      isMuted: isMuted ?? this.isMuted,
      isVideoDisabled: isVideoDisabled ?? this.isVideoDisabled,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      remoteUid: clearRemoteUid ? null : (remoteUid ?? this.remoteUid),
      isRemoteVideoEnabled: isRemoteVideoEnabled ?? this.isRemoteVideoEnabled,
      callDuration: callDuration ?? this.callDuration,
      connectedAt: connectedAt ?? this.connectedAt,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Retourne un état complètement réinitialisé.
  static const CallState initial = CallState();
}
