import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'auth_service.dart';
import 'api_config.dart';

class ChatService {
  static String get wsBaseUrl => '${ApiConfig.wsBaseUrl}/ws/chat';

  WebSocketChannel? _channel;

  final AuthService _authService = AuthService();

  /// Se connecter au salon de chat
  Future<void> connect(String roomId, String userId) async {
    final token = await _authService.getToken();
    final uri = Uri.parse('$wsBaseUrl/$roomId/$userId?token=$token');
    _channel = IOWebSocketChannel.connect(uri);
  }

  /// Écouter les messages entrants
  Stream<Map<String, dynamic>> get messageStream {
    if (_channel == null) {
      return const Stream.empty();
    }
    return _channel!.stream.map((data) {
      return jsonDecode(data as String) as Map<String, dynamic>;
    });
  }

  /// Envoyer un message (Texte, Signalisation, etc.)
  void sendMessage(String content, {String type = 'text', Map<String, dynamic>? data}) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'content': content,
      'type': type,
      'data': data,
    }));
  }

  /// Signaler qu'un message a été lu
  void markAsRead(String roomId) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'message_read',
      'room_id': roomId,
    }));
  }

  /// Signaler que l'utilisateur est en train d'écrire
  void sendTyping({bool isTyping = true}) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'typing',
      'is_typing': isTyping,
    }));
  }

  /// Se déconnecter du salon
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  /// Vérifier si connecté
  bool get isConnected => _channel != null;
}
