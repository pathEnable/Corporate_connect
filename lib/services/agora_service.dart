import 'dart:convert';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'auth_service.dart';

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  RtcEngine? _engine;
  final AuthService _authService = AuthService();

  // URL de base pour les requêtes API (doit correspondre au backend)
  static const String _apiBaseUrl = 'https://hoselike-detrital-nola.ngrok-free.dev/agora';

  Future<void> initAgora() async {
    // On récupère d'abord un token de test ou l'App ID via le backend si nécessaire
    // Mais ici on initialise le moteur avec l'App ID qu'on recevra du backend
  }

  Future<RtcEngine> getEngine(String appId, {bool isVideo = true}) async {
    if (_engine != null) return _engine!;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    if (isVideo) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.enableAudio();
    }
    
    return _engine!;
  }

  Future<Map<String, dynamic>> fetchToken(String channelName, {int uid = 0}) async {
    final response = await _authService.authenticatedRequest(
      url: '$_apiBaseUrl/token?channel_name=$channelName&uid=$uid',
      method: 'GET',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la récupération du token Agora');
    }
  }

  Future<void> joinChannel(String token, String channelName, int uid, {bool isVideo = true}) async {
    if (_engine == null) throw Exception("Engine non initialisé");
    
    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: isVideo,
        publishMicrophoneTrack: true,
      ),
    );
  }

  Future<void> leaveChannel() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
    }
  }
}
