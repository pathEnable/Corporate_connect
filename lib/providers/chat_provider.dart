import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_state.dart';
import '../services/chat_service.dart';
import '../services/room_service.dart';
import '../services/encryption_service.dart';
import '../services/local_database.dart';
import '../services/media_service.dart';
import '../services/api_config.dart';

/// Provider pour un salon de chat spécifique (Riverpod 2.0 Notifier Family)
final chatProvider = NotifierProvider.family<ChatNotifier, ChatState, String>(() {
  return ChatNotifier();
});

class ChatNotifier extends FamilyNotifier<ChatState, String> {
  late String roomId;
  final ChatService _chatService = ChatService();
  final RoomService _roomService = RoomService();
  final EncryptionService _encryptionService = EncryptionService();
  final MediaService _mediaService = MediaService();
  
  String? _userId;
  Timer? _typingClearTimer;
  bool _isDisposed = false;

  ChatNotifier();

  @override
  ChatState build(String arg) {
    roomId = arg;
    ref.onDispose(() => _isDisposed = true);
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
      debugPrint("❌ Erreur chargement cache DB: $e");
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
      
      // Déchiffrement en masse du cache local
      if (state.messages.isNotEmpty) {
        final decryptedLocal = await _decryptBulk(state.messages);
        if (!_isDisposed) {
          state = state.copyWith(messages: decryptedLocal);
        }
      }
    } catch (e) {
      debugPrint("❌ Erreur chargement membres/clés: $e");
    }

    // 3. Charger l'historique depuis le serveur
    try {
      final history = await _roomService.getMessages(roomId);
      final decryptedHistory = await _decryptBulk(history);
      
      // Sauvegarder en cache (sans attendre, en tâche de fond)
      _saveHistoryToCache(decryptedHistory);
      
      if (!_isDisposed) {
        state = state.copyWith(messages: decryptedHistory, isLoading: false);
      }
    } catch (e) {
      debugPrint("❌ Erreur historique serveur: $e");
    } finally {
      if (!_isDisposed && state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }

    // 4. WebSocket
    if (_userId != null) {
      _connectWebSocket();
    }
  }

  /// Déchiffre une liste de messages en arrière-plan (Isolate/Compute)
  Future<List<Map<String, dynamic>>> _decryptBulk(List<Map<String, dynamic>> messages) async {
    if (messages.isEmpty || state.memberKeys.isEmpty) return messages;
    
    final privateKeyBytes = await _encryptionService.getPrivateKeyBytes();
    if (privateKeyBytes == null) return messages;

    final stopwatch = Stopwatch()..start();
    
    // Déplacement du calcul lourd vers un Isolate séparé
    final result = await compute(EncryptionService.decryptBulk, {
      'messages': messages,
      'memberKeys': state.memberKeys,
      'privateKeyBytes': privateKeyBytes,
    });
    
    stopwatch.stop();
    debugPrint("🚀 Déchiffrement de ${messages.length} messages terminé en ${stopwatch.elapsedMilliseconds}ms");
    
    return result;
  }

  void _saveHistoryToCache(List<Map<String, dynamic>> history) async {
    for (var msg in history) {
      if (_isDisposed) break;
      try {
        await LocalDatabase.instance.saveMessage(msg);
      } catch (_) {}
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
      
      // Déchiffrer le message entrant (singulier)
      final decrypted = await _decryptBulk([message]);
      final finalMsg = decrypted.first;

      try {
        await LocalDatabase.instance.saveMessage(finalMsg);
      } catch (_) {}
      
      final newMessages = List<Map<String, dynamic>>.from(state.messages);
      final index = newMessages.indexWhere((m) {
        // Logique de remplacement pour les messages "pending"
        final bool isSameContent = m['content'] == finalMsg['content'];
        final bool isSameSender = m['sender_id'] == finalMsg['sender_id'];
        final bool isTemporary = m['status'] == 'pending' || m['id'].toString().startsWith('temp_');
        return isSameContent && isSameSender && isTemporary;
      });

      if (index != -1) {
        newMessages[index] = finalMsg;
      } else {
        newMessages.add(finalMsg);
      }
      if (!_isDisposed) {
        state = state.copyWith(messages: newMessages);
      }

      // 3. Téléchargement auto en arrière-plan pour les médias
      if (finalMsg['message_type'] == 'image' || finalMsg['message_type'] == 'file') {
        _downloadMediaInBackground(finalMsg);
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

  void sendMessage(String content, String type, {Map<String, dynamic>? extraData}) async {
    String contentToSend = content;
    bool wasEncrypted = false;

    if (type == 'text' && state.memberKeys.isNotEmpty) {
      final recipientId = state.memberKeys.keys.firstWhere(
        (id) => id != _userId, 
        orElse: () => ""
      );

      if (recipientId.isNotEmpty && state.memberKeys[recipientId] != null) {
        try {
          contentToSend = await _encryptionService.encrypt(content, state.memberKeys[recipientId]!);
          wasEncrypted = true;
        } catch (e) {
          debugPrint("❌ Erreur de chiffrement: $e");
        }
      }
    }

    final tempMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'room_id': roomId, 
      'sender_id': _userId,
      'content': content, 
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

  Future<void> _downloadMediaInBackground(Map<String, dynamic> message) async {
    if (kIsWeb) return;
    
    final url = await ApiConfig.getAuthenticatedMediaUrl(message['content']);
    final fileName = message['content'].split('/').last;
    
    final localPath = await _mediaService.saveToGallery(
      url, 
      fileName, 
      message['message_type']
    );

    if (localPath != null && !_isDisposed) {
      // Mettre à jour la DB
      await LocalDatabase.instance.updateLocalPath(message['id'].toString(), localPath);
      
      // Mettre à jour l'état UI
      final newMessages = state.messages.map((m) {
        if (m['id'].toString() == message['id'].toString()) {
          return {...m, 'local_path': localPath};
        }
        return m;
      }).toList();
      
      state = state.copyWith(messages: newMessages);
    }
  }
}
