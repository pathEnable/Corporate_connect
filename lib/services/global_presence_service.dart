import 'dart:async';
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
  
  // Stream to broadcast global notifications (like new messages in other rooms)
  final _globalEventsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get globalEventsStream => _globalEventsController.stream;

  Future<void> connect() async {
    if (_isConnected) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final token = await AuthService().getToken();

    if (userId == null || token == null) return;

    final wsUrl = '${ApiConfig.wsBaseUrl}/ws/global/$userId?token=$token';
    debugPrint("🌐 Connexion au WS Global: $wsUrl");

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      debugPrint("🟢 Global Presence WS Connecté");

      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            _globalEventsController.add(data);
          } catch (e) {
            debugPrint("Erreur décodage message global: $e");
          }
        },
        onDone: () {
          debugPrint("🔴 Global Presence WS Déconnecté");
          _isConnected = false;
          _reconnect();
        },
        onError: (error) {
          debugPrint("⚠️ Global Presence WS Erreur: $error");
          _isConnected = false;
        },
      );
    } catch (e) {
      debugPrint("⚠️ Global Presence WS Connexion échouée: $e");
      _isConnected = false;
      _reconnect();
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) connect();
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }
}
