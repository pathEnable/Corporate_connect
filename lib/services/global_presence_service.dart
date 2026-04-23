import 'dart:async';
import 'dart:math' show min, max, pow, Random;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_config.dart';
import 'auth_service.dart';

class GlobalPresenceService {
  static final GlobalPresenceService instance = GlobalPresenceService._internal();
  GlobalPresenceService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _heartbeatTimer;
  StreamSubscription? _wsSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 120; // secondes
  
  // Stream to broadcast global notifications (like new messages in other rooms)
  final _globalEventsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get globalEventsStream => _globalEventsController.stream;

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    // Annuler toute souscription et timer précédents
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _wsSubscription?.cancel();
    _wsSubscription = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final token = await AuthService().getToken();

      if (userId == null || token == null) {
        _isConnecting = false;
        return;
      }

      final wsUrl = '${ApiConfig.wsBaseUrl}/ws/global/$userId';
      debugPrint("🌐 Tentative de connexion WS Global: $wsUrl");

      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: [token],
      );

      _wsSubscription = _channel!.stream.listen(
        (message) {
          if (!_isConnected) {
            _isConnected = true;
            _isConnecting = false;
            _reconnectAttempts = 0; // Connexion réussie : reset backoff
            debugPrint("🟢 Global Presence WS Connecté");
            _startHeartbeat();
          }
          
          try {
            final data = json.decode(message);
            _globalEventsController.add(data);
          } catch (e) {
            debugPrint("Erreur décodage message global: $e");
          }
        },
        onDone: () {
          final wasConnected = _isConnected;
          _isConnected = false;
          _isConnecting = false;
          _stopHeartbeat();
          debugPrint("🔴 Global Presence WS Déconnecté (wasConnected: $wasConnected)");
          _scheduleReconnect();
        },
        onError: (error) {
          _isConnected = false;
          _isConnecting = false;
          _stopHeartbeat();
          debugPrint("⚠️ Global Presence WS Erreur: $error");
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint("⚠️ Global Presence WS Exception: $e");
      _isConnected = false;
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    // Envoie un ping toutes le 45 secondes pour éviter le timeout de Render (55s)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(json.encode({'type': 'ping'}));
        } catch (e) {
          debugPrint("❌ Erreur heartbeat: $e");
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Programme une reconnexion avec backoff exponentiel + jitter
  void _scheduleReconnect() {
    // Annuler tout timer existant pour éviter les doublons
    _reconnectTimer?.cancel();
    
    // Backoff exponentiel : 5s, 10s, 20s, 40s, 80s, plafonné à 120s
    final baseDelay = min(5 * pow(2, _reconnectAttempts).toInt(), _maxReconnectDelay);
    // Jitter : ±30%
    final jitter = (baseDelay * 0.3 * (Random().nextDouble() * 2 - 1)).toInt();
    final delay = max(5, baseDelay + jitter);
    
    _reconnectAttempts++;
    debugPrint("⏳ Global WS reconnexion dans ${delay}s (tentative #$_reconnectAttempts)");
    
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      connect();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _stopHeartbeat();
    _channel?.sink.close();
    _isConnected = false;
    _isConnecting = false;
    _reconnectAttempts = 0;
  }
}
