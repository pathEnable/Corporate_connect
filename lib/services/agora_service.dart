import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

/// Service Agora RTC — Singleton avec réinitialisation propre entre les appels.
/// 
/// Cycle de vie :
///   1. initEngine(appId) — crée le moteur (une seule fois par appel)
///   2. joinChannel(token, channelName) — rejoint le canal
///   3. leaveChannel() — quitte le canal (sans détruire le moteur)
///   4. dispose() — détruit le moteur (à la fin de l'appel complet)
class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isInChannel = false;

  /// Retourne le moteur Agora (ou null si non initialisé).
  RtcEngine? get engine => _engine;
  
  /// Vrai si le moteur est initialisé et prêt.
  bool get isInitialized => _isInitialized;
  
  /// Vrai si on est actuellement dans un canal.
  bool get isInChannel => _isInChannel;

  /// Initialise le moteur Agora. Peut être appelé plusieurs fois sans risque.
  Future<RtcEngine> initEngine(String appId) async {
    // Si déjà initialisé, réutiliser
    if (_engine != null && _isInitialized) {
      debugPrint('🎙️ Agora engine déjà initialisé, réutilisation');
      return _engine!;
    }

    // Nettoyer si dans un état sale
    if (_engine != null) {
      try {
        await _engine!.release();
      } catch (_) {}
      _engine = null;
      _isInitialized = false;
    }

    debugPrint('🎙️ Création nouveau moteur Agora');
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
      logConfig: const LogConfig(level: LogLevel.logLevelWarn),
    ));

    _isInitialized = true;
    return _engine!;
  }

  /// Rejoint un canal Agora.
  /// [forceSpeaker] : true = haut-parleur (vidéo), false = écouteur (audio vocal).
  Future<void> joinChannel({
    required String token,
    required String channelName,
    required int uid,
    bool enableVideo = true,
    bool forceSpeaker = false,
  }) async {
    if (_engine == null || !_isInitialized) {
      throw Exception('Agora engine non initialisé. Appeler initEngine() d\'abord.');
    }

    bool actuallyEnableVideo = enableVideo;
    if (enableVideo) {
      try {
        await _engine!.enableVideo();
      } catch (e) {
        debugPrint('⚠️ Échec activation vidéo (permissions ?): $e. Repli vers audio seul.');
        actuallyEnableVideo = false;
        await _engine!.disableVideo();
        await _engine!.enableAudio();
      }
    } else {
      await _engine!.disableVideo();
      await _engine!.enableAudio();
    }

    // Routage audio : haut-parleur pour vidéo, écouteur pour appel vocal (Mobile uniquement)
    if (!kIsWeb) {
      try {
        await _engine!.setEnableSpeakerphone(forceSpeaker || actuallyEnableVideo);
        debugPrint('🔊 Routage audio : ${(forceSpeaker || actuallyEnableVideo) ? "haut-parleur" : "écouteur"}');
      } catch (e) {
        debugPrint('⚠️ Erreur lors du réglage du haut-parleur: $e');
      }
    } else {
      debugPrint('🔊 Routage audio ignoré sur Web');
    }

    if (actuallyEnableVideo) {
      try {
        await _engine!.startPreview();
      } catch (e) {
        debugPrint('⚠️ Échec startPreview: $e');
      }
    }

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: actuallyEnableVideo,
        publishMicrophoneTrack: true,
        publishCameraTrack: actuallyEnableVideo,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );

    _isInChannel = true;
    debugPrint('🎙️ Rejoint canal: $channelName (video effectif: $actuallyEnableVideo)');
  }

  /// Quitte le canal (sans détruire le moteur).
  Future<void> leaveChannel() async {
    if (_engine != null && _isInChannel) {
      try {
        await _engine!.leaveChannel();
        debugPrint('🎙️ Canal quitté');
      } catch (e) {
        debugPrint('⚠️ Erreur leaveChannel: $e');
      }
      _isInChannel = false;
    }
  }

  /// Libère complètement le moteur. Doit être appelé à la fin de chaque appel.
  Future<void> dispose() async {
    debugPrint('🎙️ Destruction moteur Agora');
    
    if (_isInChannel) {
      await leaveChannel();
    }

    if (_engine != null) {
      try {
        await _engine!.stopPreview();
      } catch (_) {}
      try {
        await _engine!.release();
      } catch (_) {}
      _engine = null;
    }

    _isInitialized = false;
    _isInChannel = false;
  }

  // ═══ Contrôles pendant l'appel ═══

  Future<void> toggleMute(bool mute) async {
    await _engine?.muteLocalAudioStream(mute);
  }

  Future<void> toggleVideo(bool disable) async {
    await _engine?.muteLocalVideoStream(disable);
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> toggleSpeaker(bool enable) async {
    await _engine?.setEnableSpeakerphone(enable);
  }
}
