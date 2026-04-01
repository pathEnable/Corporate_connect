import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_state.dart';
import '../services/chat_service.dart';
import '../services/room_service.dart';
import '../services/encryption_service.dart';
import '../services/local_database.dart';

/// Provider pour un salon de chat spécifique (Riverpod 3.0 Notifier Family)
final chatProvider = NotifierProvider.family<ChatNotifier, ChatState, String>((arg) {
  return ChatNotifier(arg);
});

class ChatNotifier extends Notifier<ChatState> {
  final String roomId;
  final ChatService _chatService = ChatService();
  final RoomService _roomService = RoomService();
  final EncryptionService _encryptionService = EncryptionService();
  
  String? _userId;
  Timer? _typingClearTimer;
  bool _isDisposed = false;

  ChatNotifier(this.roomId);

  @override
  ChatState build() {
    // Initialisation du nettoyage lors de la suppression du provider
    ref.onDispose(() => _isDisposed = true);

    // Initialisation asynchrone lancée après le build initial
    _init();

    return ChatState(
      messages: [],
      typingUsers: {},
      memberKeys: {},
      isLoading: true,
    );
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed) return;
    _userId = prefs.getString('user_id');

    // 1. Charger le cache local
    try {
      final localMsgs = await LocalDatabase.instance.getMessages(roomId);
      if (!_isDisposed) {
        state = state.copyWith(messages: localMsgs);
      }
    } catch (e) {
      // sqflite non supporté sur Web ou base corrompue : on ignore le cache
    }

    // 2. Charger les clés membres
    try {
      final members = await _roomService.getRoomMembers(roomId);
      final keys = <String, String>{};
      for (var m in members) {
        if (m['public_key'] != null) {
          keys[m['id'].toString()] = m['public_key'];
        }
      }
      if (!_isDisposed) {
        state = state.copyWith(memberKeys: keys);
      }
      
      final decryptedMsgs = List<Map<String, dynamic>>.from(state.messages);
      for (var msg in decryptedMsgs) {
        await _decryptMessage(msg);
      }
      if (!_isDisposed) {
        state = state.copyWith(messages: decryptedMsgs);
      }
    } catch (_) {}

    // 3. Charger l'historique depuis le serveur
    try {
      final history = await _roomService.getMessages(roomId);
      for (var msg in history) {
        await _decryptMessage(msg);
        try {
          await LocalDatabase.instance.saveMessage(msg);
        } catch (_) {} // Ignore cache update fails
      }
      if (!_isDisposed) {
        state = state.copyWith(messages: history, isLoading: false);
      }
    } catch (_) {
      // Ignorer l'erreur réseau et afficher ce qu'on peut
    } finally {
      // Toujours s'assurer d'éteindre le spinner
      if (!_isDisposed && state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }

    // 4. WebSocket
    if (_userId != null) {
      _connectWebSocket();
    }
  }

  void _connectWebSocket() async {
    if (_userId == null || _isDisposed) return;
    await _chatService.connect(roomId, _userId!);
    if (!_isDisposed) {
      state = state.copyWith(isConnected: true);
    }

    _chatService.messageStream.listen((message) async {
      _handleIncomingMessage(message);
    }, onDone: () {
      if (!_isDisposed) {
        state = state.copyWith(isConnected: false);
        Future.delayed(const Duration(seconds: 3), () {
          if (!_isDisposed) {
            _connectWebSocket();
          }
        });
      }
    });
  }

  Future<void> _handleIncomingMessage(Map<String, dynamic> message) async {
    if (message['type'] == 'new_message' || message['type'] == 'image' || message['type'] == 'file' || message['type'] == 'audio') {
      await _decryptMessage(message);
      try {
        await LocalDatabase.instance.saveMessage(message);
      } catch (_) {} // Ignore cache fails
      
      final newMessages = List<Map<String, dynamic>>.from(state.messages);
      final index = newMessages.indexWhere((m) => 
        m['content'] == message['content'] && 
        m['sender_id'] == message['sender_id'] && 
        (m['status'] == 'pending' || m['id'].toString().length > 15)
      );

      if (index != -1) {
        newMessages[index] = message;
      } else {
        newMessages.add(message);
      }
      if (!_isDisposed) {
        state = state.copyWith(messages: newMessages);
      }
    } else if (message['type'] == 'typing') {
      final typingUserId = message['user_id'] as String;
      final isTyping = message['is_typing'] == true;
      final newTypingUsers = Set<String>.from(state.typingUsers);
      
      if (isTyping) {
        newTypingUsers.add(typingUserId);
      } else {
        newTypingUsers.remove(typingUserId);
      }
      
      if (!_isDisposed) {
        state = state.copyWith(typingUsers: newTypingUsers);
      }

      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(const Duration(seconds: 5), () {
        if (!_isDisposed) {
          final cleared = Set<String>.from(state.typingUsers);
          cleared.remove(typingUserId);
          state = state.copyWith(typingUsers: cleared);
        }
      });
    }
  }

  Future<void> _decryptMessage(Map<String, dynamic> msg) async {
    final bool isText = msg['message_type'] == 'text';
    if (isText && msg['content'] != null && msg['is_decrypted'] != true) {
      final senderId = msg['sender_id'].toString();
      
      // On tente de déchiffrer SI on a la clé et si ça ressemble à du Base64 (chiffré)
      if (state.memberKeys.containsKey(senderId)) {
        final String content = msg['content'];
        // Heuristique simple : si c'est du Base64 long et sans espaces, c'est probablement chiffré
        if (content.length > 20 && !content.contains(' ')) {
          try {
            final decrypted = await _encryptionService.decrypt(content, state.memberKeys[senderId]!);
            if (decrypted != "[Message chiffré illisible]") {
               msg['content'] = decrypted;
               msg['is_encrypted'] = true; // Flag pour UI (icone cadenas)
            }
          } catch (e) {
            debugPrint("⚠️ Échec déchiffrement pour msg ${msg['id']}: $e");
          }
        }
        msg['is_decrypted'] = true;
      }
    }
  }

  void sendMessage(String content, String type, {Map<String, dynamic>? extraData}) async {
    String contentToSend = content;
    bool wasEncrypted = false;

    if (type == 'text' && state.memberKeys.isNotEmpty) {
      // Pour les messages directs (2 membres), on cherche la clé de l'autre
      final recipientId = state.memberKeys.keys.firstWhere(
        (id) => id != _userId, 
        orElse: () => ""
      );

      if (recipientId.isNotEmpty && state.memberKeys[recipientId] != null) {
        try {
          contentToSend = await _encryptionService.encrypt(content, state.memberKeys[recipientId]!);
          wasEncrypted = true;
          debugPrint("🔒 Message chiffré pour $recipientId");
        } catch (e) {
          debugPrint("❌ Erreur de chiffrement: $e. Envoi en clair par sécurité dégradée.");
        }
      }
    }

    final tempMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'room_id': roomId, 
      'sender_id': _userId,
      'content': content, // On garde le clair pour l'affichage local immediat
      'message_type': type,
      'status': 'pending',
      'is_encrypted': wasEncrypted,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (!_isDisposed) {
      state = state.copyWith(messages: [...state.messages, tempMsg]);
    }
    
    _chatService.sendMessage(contentToSend, type: type, data: extraData);
  }

  void sendTyping(bool isTyping) {
    _chatService.sendTyping(isTyping: isTyping);
  }
}
