import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/chat_state.dart';
import '../services/chat_service.dart';
import '../services/room_service.dart';
import '../services/encryption_service.dart';
import '../services/local_database.dart';
import '../services/media_cache_service.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import 'home_provider.dart';
import 'migration_provider.dart';
import 'incoming_call_provider.dart';

/// Provider pour un salon de chat spécifique (Riverpod 2.0 Notifier Family)
final chatProvider = NotifierProvider.family<ChatNotifier, ChatState, String>(() {
  return ChatNotifier();
});

class ChatNotifier extends FamilyNotifier<ChatState, String> {
  late String roomId;
  final ChatService _chatService = ChatService();
  final RoomService _roomService = RoomService();
  final EncryptionService _encryptionService = EncryptionService();
  final AuthService _authService = AuthService();
  
  String? _userId;
  Timer? _typingClearTimer;
  Timer? _presenceTimer;
  bool _isDisposed = false;

  ChatNotifier();

  @override
  ChatState build(String arg) {
    roomId = arg;
    
    // Écouter les migrations d'identifiant (draft -> real)
    ref.listen(roomMigrationProvider, (previous, next) {
      if (next.containsKey(roomId)) {
        final newId = next[roomId];
        if (newId != null && newId != roomId) {
          debugPrint("🔀 Migration ChatNotifier: $roomId -> $newId");
          roomId = newId;
          // Re-connecter et re-fetch avec le nouvel ID
          _chatService.disconnect();
          _init();
        }
      }
    });

    ref.onDispose(() {
      _isDisposed = true;
      _chatService.disconnect();
      _presenceTimer?.cancel();
      _typingClearTimer?.cancel();
    });
    _init();

    return ChatState(
      messages: const [],
      typingUsers: const {},
      memberKeys: const {},
      isLoading: true, // On commence par true, Phase 1 le passera à false si cache présent
    );
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed) return;
    
    final currentUserId = prefs.getString('user_id');
    if (currentUserId == null) return;
    _userId = currentUserId;

    // ═══ PHASE 1 : Cache SQLite instantané (< 20ms) ═══
    // Chargement synchrone du cache & démarrage WebSocket immédiat
    List<Map<String, dynamic>> localMsgs = [];
    try {
      localMsgs = await LocalDatabase.instance.getMessages(roomId);
      if (!_isDisposed && localMsgs.isNotEmpty) {
        // On a du cache → plus besoin de spinner/skeleton
        state = state.copyWith(messages: localMsgs, isLoading: false);
        debugPrint("✅ Chat: Cache SQLite chargé (${localMsgs.length} messages)");
      } else {
        debugPrint("ℹ️ Chat: Pas de cache SQLite, attente API...");
      }
    } catch (e) {
      debugPrint("❌ Erreur cache DB: $e");
    }

    // ═══ PHASE 2 : Parallélisation totale ═══
    // WebSocket + clés membres + historique API → tout en même temps
    // Résultat : "Connexion..." part en moins d'une seconde
    if (!_isDisposed && _userId != null) {
      // Le WebSocket se connecte IMMÉDIATEMENT, sans attendre l'API
      _connectWebSocket();
      _fetchOtherUserPresence();
      _presenceTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _fetchOtherUserPresence(),
      );
    }

    // Récupérer les clés membres et l'historique en parallèle
    await Future.wait([
      _fetchMemberKeysAndDecryptCache(localMsgs),
      _syncHistoryFromApi(),
    ]);

    try { ref.read(homeProvider.notifier).markRoomAsRead(roomId); } catch (_) {}
  }

  /// Récupère les clés de chiffrement des membres et déchiffre le cache déjà affiché.
  Future<void> _fetchMemberKeysAndDecryptCache(List<Map<String, dynamic>> cachedMsgs) async {
    try {
      final members = await _roomService.getRoomMembers(roomId);
      final keys = <String, String>{};
      for (var m in members) {
        if (m['public_key'] != null) {
          keys[m['id'].toString()] = m['public_key'];
        }
      }
      if (_isDisposed) return;
      state = state.copyWith(memberKeys: keys);

      // Déchiffrer le cache affiché dès qu'on a les clés
      if (cachedMsgs.isNotEmpty) {
        final decrypted = await _decryptBulk(cachedMsgs);
        if (!_isDisposed) state = state.copyWith(messages: decrypted);
      }
    } catch (e) {
      debugPrint("❌ Erreur clés membres: $e");
    }
  }

  /// Synchronise l'historique complet depuis l'API et le fusionne silencieusement.
  Future<void> _syncHistoryFromApi() async {
    try {
      final history = await _roomService.getMessages(roomId);
      if (_isDisposed) return;

      final decryptedHistory = await _decryptBulk(history);
      if (_isDisposed) return;

      // MERGE : API prime, mais on conserve les messages pending/failed locaux
      final merged = _mergeMessages(decryptedHistory, state.messages);

      // Persistance en arrière-plan (fire-and-forget)
      _saveHistoryToCache(decryptedHistory);

      if (!_isDisposed) {
        state = state.copyWith(messages: merged, isLoading: false);
      }

      // Pré-chargement des médias récents en arrière-plan
      _prefetchRecentMedia(decryptedHistory);
    } catch (e) {
      debugPrint("❌ Erreur sync API messages: $e");
      if (!_isDisposed) state = state.copyWith(isLoading: false);
    }
  }

  /// Récupère le statut de présence de l'autre utilisateur dans un chat privé
  Future<void> _fetchOtherUserPresence() async {
    if (_isDisposed || _userId == null) return;
    
    // Trouver l'ID de l'autre membre
    final otherUserId = state.memberKeys.keys.firstWhere(
      (id) => id != _userId,
      orElse: () => "",
    );
    if (otherUserId.isEmpty) return;

    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/profiles/$otherUserId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && !_isDisposed) {
        final data = jsonDecode(response.body);
        state = state.copyWith(
          otherUserOnline: data['is_online'] == true,
          otherUserStatus: data['presence_status'] ?? 'online',
        );
      }
    } catch (e) {
      debugPrint("❌ Erreur fetch présence: $e");
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
      // L'API ne retourne pas room_id dans chaque message, on l'injecte
      try { await LocalDatabase.instance.saveMessage({...msg, 'room_id': roomId}); } catch (_) {}
    }
  }

  /// Fusionne les messages de l'API avec ceux en mémoire (locaux).
  /// Priorité à l'API pour les messages existants, mais conserve les
  /// messages locaux "pending" ou "failed" qui ne sont pas encore confirmés.
  List<Map<String, dynamic>> _mergeMessages(
    List<Map<String, dynamic>> fromApi,
    List<Map<String, dynamic>> fromCache,
  ) {
    // Index des messages API par ID pour une recherche O(1)
    final apiIds = fromApi.map((m) => m['id'].toString()).toSet();
    
    // Conserver les messages locaux qui sont EN COURS (pending/failed) et pas encore dans l'API
    final pendingOrFailed = fromCache.where((m) {
      final status = m['status']?.toString() ?? 'sent';
      final id = m['id'].toString();
      return (status == 'pending' || status == 'failed') && !apiIds.contains(id);
    }).toList();
    
    // Fusionner : messages API + messages locaux non confirmés
    final merged = [...fromApi, ...pendingOrFailed];
    merged.sort((a, b) {
      final aTime = a['created_at']?.toString() ?? '';
      final bTime = b['created_at']?.toString() ?? '';
      return aTime.compareTo(bTime);
    });
    return merged;
  }

  /// Pré-charge en arri\u00e8re-plan les m\u00e9dias r\u00e9cents de la conversation.
  /// Prend les 20 derniers messages contenant des m\u00e9dias pour les mettre en cache.
  void _prefetchRecentMedia(List<Map<String, dynamic>> messages) {
    // Prendre les 20 derniers messages avec un media
    final mediaMessages = messages
        .where((m) => ['image', 'audio', 'file', 'video'].contains(m['message_type']))
        .toList();
    
    final recentMedia = mediaMessages.length > 20
        ? mediaMessages.sublist(mediaMessages.length - 20)
        : mediaMessages;
    
    final urls = recentMedia
        .map((m) => m['content']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .toList();
    
    if (urls.isNotEmpty) {
      MediaCacheService.instance.prefetchBatch(urls);
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
        // Extract caption if buried in data
        final caption = finalMsg['caption'] ?? (finalMsg['data'] != null ? finalMsg['data']['caption'] : null);
        await LocalDatabase.instance.saveMessage({
          ...finalMsg, 
          'room_id': roomId,
          'caption': caption,
        });
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
        // Mettre à jour aussi la DB : remplacer le message pending par le vrai
        try {
          await LocalDatabase.instance.updateMessageStatus(
            newMessages[index]['id'].toString(),
            'sent',
            newId: finalMsg['id'].toString(),
          );
        } catch (_) {}
        newMessages[index] = finalMsg;
      } else {
        newMessages.add(finalMsg);
      }
      if (!_isDisposed) {
        state = state.copyWith(messages: newMessages);
      }

      // 3. Téléchargement auto en arrière-plan pour les médias (Coffre-fort privé)
      if (['image', 'file', 'audio', 'video'].contains(finalMsg['message_type'])) {
        _downloadMediaInBackground(finalMsg);
      }
    } else if (message['type'] == 'call_offer') {
      // L'utilisateur est dans le chat et reçoit un appel entrant
      // On extrait les infos du signal et on déclenche la UI d'appel entrant
      final data = message['data'] as Map<String, dynamic>? ?? {};
      final String incomingRoomId = data['room_id'] ?? data['channel_id'] ?? roomId;
      final bool isVideo = data['is_video'] == true || data['is_video'] == 'true';
      final String callerName = message['sender_name'] ?? message['sender_id']?.toString() ?? 'Inconnu';
      final String callerAvatar = message['sender_avatar'] ?? '';

      // Ne pas déclencher si c'est nous qui avons envoyé l'appel
      if (message['sender_id']?.toString() != _userId) {
        ref.read(incomingCallProvider.notifier).showIncomingCall(
          name: callerName,
          avatar: callerAvatar,
          roomId: incomingRoomId,
          isVideo: isVideo,
        );
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
    } else if (message['type'] == 'user_joined') {
      // Quelqu'un a rejoint le salon → mettre à jour la présence
      if (!_isDisposed) {
        state = state.copyWith(otherUserOnline: true);
      }
    } else if (message['type'] == 'user_left') {
      // Quelqu'un a quitté le salon → mettre à jour la présence
      final leftUserId = message['user_id'];
      if (leftUserId != _userId && !_isDisposed) {
        state = state.copyWith(otherUserOnline: false);
      }
    }
  }

  void sendMessage(String content, String type, {Map<String, dynamic>? extraData}) async {
    String contentToSend = content;
    bool wasEncrypted = false;

    // S'assurer d'utiliser l'ID utilisateur le plus récent
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('user_id') ?? _userId;
    
    if (currentUserId == null) {
      debugPrint("❌ Impossible d'envoyer le message : ID utilisateur manquant");
      return;
    }

    if (type == 'text' && state.memberKeys.isNotEmpty) {
      final recipientId = state.memberKeys.keys.firstWhere(
        (id) => id != currentUserId, 
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

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id': tempId,
      'room_id': roomId, 
      'sender_id': currentUserId,
      'content': content, 
      'message_type': type,
      'status': 'pending',
      'is_encrypted': wasEncrypted,
      'caption': extraData?['caption'],
      'created_at': DateTime.now().toIso8601String(),
    };

    if (!_isDisposed) {
      state = state.copyWith(messages: [...state.messages, tempMsg]);
    }
    
    _chatService.sendMessage(contentToSend, type: type, data: extraData);

    // Timeout : marquer comme échoué après 10 secondes si pas confirmé
    Future.delayed(const Duration(seconds: 10), () {
      if (_isDisposed) return;
      final currentMessages = state.messages;
      final pendingIdx = currentMessages.indexWhere(
        (m) => m['id'] == tempId && m['status'] == 'pending',
      );
      if (pendingIdx != -1) {
        final updated = List<Map<String, dynamic>>.from(currentMessages);
        updated[pendingIdx] = {...updated[pendingIdx], 'status': 'failed'};
        state = state.copyWith(messages: updated);
        // Persister l'échec en DB
        LocalDatabase.instance.updateMessageStatus(tempId, 'failed');
      }
    });
  }

  /// Renvoyer un message échoué
  void resendMessage(String messageId) {
    final msg = state.messages.firstWhere(
      (m) => m['id'] == messageId,
      orElse: () => {},
    );
    if (msg.isEmpty) return;

    // Remettre en pending
    final updated = state.messages.map((m) {
      if (m['id'] == messageId) {
        return {...m, 'status': 'pending'};
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);

    // Renvoyer
    _chatService.sendMessage(
      msg['content'] ?? '',
      type: msg['message_type'] ?? 'text',
    );
  }

  void sendTyping(bool isTyping) {
    _chatService.sendTyping(isTyping: isTyping);
  }

  Future<void> _downloadMediaInBackground(Map<String, dynamic> message) async {
    if (kIsWeb || message['content'] == null) return;
    
    final relativeUrl = message['content'].toString();
    
    // Utiliser MediaCacheService pour enregistrer dans le cache privé (pas la galerie publique)
    final localPath = await MediaCacheService.instance.downloadAndCache(relativeUrl);

    if (localPath != null && !_isDisposed) {
      // Mettre à jour la DB
      await LocalDatabase.instance.saveMessage({...message, 'room_id': roomId, 'local_path': localPath});
      
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
