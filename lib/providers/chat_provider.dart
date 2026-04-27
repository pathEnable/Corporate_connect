import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_state.dart';
import '../services/chat_service.dart';
import '../services/room_service.dart';
import '../services/encryption_service.dart';
import '../services/local_database.dart';
import '../services/media_service.dart';
import '../services/media_cache_service.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import 'home_provider.dart';
import 'migration_provider.dart';

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
  final AuthService _authService = AuthService();
  
  String? _userId;
  Timer? _typingClearTimer;
  Timer? _presenceTimer;
  bool _isDisposed = false;
  bool _isConnecting = false;
  StreamSubscription? _wsSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 60; // secondes

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
      _reconnectTimer?.cancel();
      _wsSubscription?.cancel();
      _chatService.disconnect();
      _presenceTimer?.cancel();
      _typingClearTimer?.cancel();
    });
    _init();

    return ChatState(
      messages: const [],
      typingUsers: const {},
      members: const {},
      memberKeys: const {},
      isLoading: false,
    );
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed) return;
    
    final currentUserId = prefs.getString('user_id');
    if (currentUserId == null) return;
    _userId = currentUserId;

    // ═══ PHASE 1 : Cache Instantané (< 20ms) ═══
    try {
      final localMsgs = await LocalDatabase.instance.getMessages(roomId);
      if (!_isDisposed && localMsgs.isNotEmpty) {
        state = state.copyWith(messages: localMsgs, isLoading: false);
      }
    } catch (e) {
      debugPrint("❌ Erreur cache DB: $e");
    }

    // ═══ PHASE 2 : Clés de chiffrement (en parallèle) ═══
    try {
      final members = await _roomService.getRoomMembers(roomId);
      final keys = <String, String>{};
      final names = <String, String>{};
      for (var m in members) {
        final id = m['id'].toString();
        if (m['public_key'] != null) {
          keys[id] = m['public_key'];
        }
        names[id] = m['username'] ?? m['full_name'] ?? 'Inconnu';
      }
      if (!_isDisposed) {
        state = state.copyWith(memberKeys: keys, members: names);
      }
      
      // Déchiffrement du cache local dès qu'on a les clés
      if (state.messages.isNotEmpty) {
        final decrypted = await _decryptBulk(state.messages);
        if (!_isDisposed) state = state.copyWith(messages: decrypted);
      }
    } catch (e) {
      debugPrint("❌ Erreur clés membres: $e");
    }

    // ═══ PHASE 3 : Sync API en arrière-plan (Merge intelligent, sans clignotement) ═══
    try {
      final history = await _roomService.getMessages(roomId);
      final decryptedHistory = await _decryptBulk(history);
      
      // MERGE : On fusionne API + messages pending locaux pour ne perdre aucun message
      final merged = _mergeMessages(decryptedHistory, state.messages);
      
      // Sauvegarder en cache (en arrière-plan, non bloquant)
      _saveHistoryToCache(decryptedHistory); // fire-and-forget (void async)
      
      if (!_isDisposed) {
        state = state.copyWith(messages: merged, isLoading: false);
      }
      
      // Pré-chargement des médias récents en arrière-plan
      _prefetchRecentMedia(decryptedHistory);
    } catch (e) {
      debugPrint("❌ Erreur sync API messages: $e");
      if (!_isDisposed) state = state.copyWith(isLoading: false);
    }

    // WS + Présence
    if (_userId != null && !_isDisposed) {
      _connectWebSocket();
      _fetchOtherUserPresence();
      _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchOtherUserPresence());
      
      // Marquer la conversation comme lue dès l'ouverture
      markRoomAsRead();
    }

    try { ref.read(homeProvider.notifier).markRoomAsRead(roomId); } catch (_) {}
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
      final response = await _authService.authenticatedRequest(
        url: '${ApiConfig.baseUrl}/profiles/$otherUserId',
        method: 'GET',
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
      try { await LocalDatabase.instance.saveMessage(msg); } catch (_) {}
    }
  }

  /// Fusionne les messages de l'API avec ceux en mémoire (locaux).
  /// Priorité à l'API pour les messages existants, mais conserve les
  /// messages locaux "pending" ou "failed" qui ne sont pas encore confirmés.
  List<Map<String, dynamic>> _mergeMessages(
    List<Map<String, dynamic>> fromApi,
    List<Map<String, dynamic>> fromCache,
  ) {
    // Indexer le cache local par ID pour une recherche rapide
    final cacheMap = {for (var m in fromCache) m['id'].toString(): m};
    
    // 1. Transformer fromApi pour inclure les données locales (comme local_path)
    final enrichedApi = fromApi.map((apiMsg) {
      final id = apiMsg['id'].toString();
      if (cacheMap.containsKey(id)) {
        final localMsg = cacheMap[id]!;
        final localPath = localMsg['local_path'] ?? (localMsg['metadata_'] != null ? localMsg['metadata_']['local_path'] : null);
        
        if (localPath != null) {
          final enriched = Map<String, dynamic>.from(apiMsg);
          enriched['local_path'] = localPath;
          
          // Injecter aussi dans metadata pour plus de robustesse
          final metadata = Map<String, dynamic>.from(enriched['metadata_'] ?? {});
          metadata['local_path'] = localPath;
          enriched['metadata_'] = metadata;
          
          return enriched;
        }
      }
      return apiMsg;
    }).toList();

    final apiIds = enrichedApi.map((m) => m['id'].toString()).toSet();
    
    // 2. Conserver les messages locaux qui sont EN COURS (pending/failed) et pas encore dans l'API
    final pendingOrFailed = fromCache.where((m) {
      final status = m['status']?.toString() ?? 'sent';
      final id = m['id'].toString();
      return (status == 'pending' || status == 'failed') && !apiIds.contains(id);
    }).toList();
    
    // 3. Fusionner : messages API enrichis + messages locaux non confirmés
    final merged = [...enrichedApi, ...pendingOrFailed];
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
        .where((m) => m['message_type'] == 'image' || m['message_type'] == 'audio' || m['message_type'] == 'file')
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
    if (_userId == null || _isDisposed || _isConnecting) return;
    
    _isConnecting = true;
    
    // ═══ ÉTAPE CRITIQUE : Annuler toute souscription et timer précédents ═══
    // Ceci empêche les anciens onDone/onError de programmer des reconnexions parasites.
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    
    try {
      await _chatService.connect(roomId, _userId!);
      if (_isDisposed) {
        _isConnecting = false;
        return;
      }
      
      // Connexion réussie : réinitialiser le compteur de backoff
      _reconnectAttempts = 0;
      state = state.copyWith(isConnected: true);

      _wsSubscription = _chatService.messageStream.listen((message) async {
        _handleIncomingMessage(message);
      }, onDone: () {
        if (!_isDisposed) {
          state = state.copyWith(isConnected: false);
          _isConnecting = false;
          _scheduleReconnect();
        }
      }, onError: (err) {
        debugPrint("❌ Chat WS Erreur: $err");
        if (!_isDisposed) {
          state = state.copyWith(isConnected: false);
          _isConnecting = false;
          _scheduleReconnect();
        }
      });
      
      _isConnecting = false;
    } catch (e) {
      debugPrint("❌ Chat WS Exception: $e");
      _isConnecting = false;
      if (!_isDisposed) {
        _scheduleReconnect();
      }
    }
  }

  /// Programme une reconnexion avec backoff exponentiel + jitter
  void _scheduleReconnect() {
    if (_isDisposed) return;
    
    // Annuler tout timer existant pour éviter les doublons
    _reconnectTimer?.cancel();
    
    // Backoff exponentiel : 3s, 6s, 12s, 24s, 48s, plafonné à 60s
    final baseDelay = min(3 * pow(2, _reconnectAttempts).toInt(), _maxReconnectDelay);
    // Jitter : ±30% pour éviter la synchronisation entre clients
    final jitter = (baseDelay * 0.3 * (Random().nextDouble() * 2 - 1)).toInt();
    final delay = max(3, baseDelay + jitter);
    
    _reconnectAttempts++;
    debugPrint("⏳ Chat WS reconnexion dans ${delay}s (tentative #$_reconnectAttempts)");
    
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (!_isDisposed) {
        _connectWebSocket();
      }
    });
  }

  void markRoomAsRead() {
    _chatService.markAsRead(roomId);
    
    // Mettre à jour localement les messages non lus de l'autre
    if (!_isDisposed) {
      bool changed = false;
      final updated = state.messages.map((m) {
        if (m['sender_id'] != _userId && (m['is_read'] == false || m['is_read'] == 0)) {
          changed = true;
          return {...m, 'is_read': true};
        }
        return m;
      }).toList();
      
      if (changed) {
        state = state.copyWith(messages: updated);
      }
    }
  }

  Future<void> _handleIncomingMessage(Map<String, dynamic> message) async {
    // Ignorer les messages de type 'reaction' (ils sont gérés par reaction_update)
    if (message['message_type'] == 'reaction' || message['type'] == 'reaction') {
      return;
    }

    if (message['type'] == 'new_message' || message['type'] == 'image' || message['type'] == 'file' || message['type'] == 'audio') {

      // Déchiffrer le message entrant (singulier)
      final decrypted = await _decryptBulk([message]);
      final finalMsg = Map<String, dynamic>.from(decrypted.first);

      final newMessages = List<Map<String, dynamic>>.from(state.messages);
      final index = newMessages.indexWhere((m) {
        // Logique de remplacement pour les messages "pending"
        final bool isSameContent = m['content'] == finalMsg['content'];
        final bool isSameSender = m['sender_id'] == finalMsg['sender_id'];
        final bool isTemporary = m['status'] == 'pending' || m['id'].toString().startsWith('temp_');
        return isSameContent && isSameSender && isTemporary;
      });

      if (index != -1) {
        // RÉCUPÉRATION DU CHEMIN LOCAL : Très important pour le style WhatsApp
        // On récupère le chemin local du message temporaire avant qu'il ne soit écrasé
        final oldMsg = newMessages[index];
        final oldLocalPath = oldMsg['local_path'] ?? (oldMsg['metadata_'] != null ? oldMsg['metadata_']['local_path'] : null);
        
        if (oldLocalPath != null) {
          finalMsg['local_path'] = oldLocalPath;
          // Assurer aussi dans metadata pour la compatibilité
          final metadata = Map<String, dynamic>.from(finalMsg['metadata_'] ?? {});
          metadata['local_path'] = oldLocalPath;
          finalMsg['metadata_'] = metadata;
        }

        // Mettre à jour aussi la DB : remplacer le message pending par le vrai
        try {
          await LocalDatabase.instance.updateMessageStatus(
            newMessages[index]['id'].toString(),
            'sent',
            newId: finalMsg['id'].toString(),
          );
          // On sauve le message final (qui contient maintenant le local_path)
          await LocalDatabase.instance.saveMessage(finalMsg);
        } catch (_) {}
        newMessages[index] = finalMsg;
      } else {
        try {
          await LocalDatabase.instance.saveMessage(finalMsg);
        } catch (_) {}
        newMessages.add(finalMsg);
      }

      if (!_isDisposed) {
        state = state.copyWith(messages: newMessages);
      }

      // Marquer comme lu si on reçoit le message de quelqu'un d'autre
      if (finalMsg['sender_id'] != _userId) {
        markRoomAsRead();
      }

      // 3. Téléchargement auto en arrière-plan (désactivé pour les fichiers 'file' pour économiser les données)
      if (finalMsg['message_type'] == 'image') {
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
    } else if (message['type'] == 'user_joined') {
      if (!_isDisposed) state = state.copyWith(otherUserOnline: true);
    } else if (message['type'] == 'user_left') {
      final leftUserId = message['user_id'];
      if (leftUserId != _userId && !_isDisposed) {
        state = state.copyWith(otherUserOnline: false);
      }
    } else if (message['type'] == 'reaction_update') {
      // Mise à jour des réactions d'un message reçue via WebSocket
      final msgId = message['message_id']?.toString();
      final reactions = message['reactions'];
      if (msgId != null && reactions != null && !_isDisposed) {
        // Mettre à jour en mémoire
        final updated = state.messages.map((m) {
          final currentId = m['id']?.toString();
          final currentMsgId = m['message_id']?.toString();
          if (currentId == msgId || currentMsgId == msgId) {
            return {...m, 'reactions': reactions};
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
        
        // Persister localement
        LocalDatabase.instance.updateReactions(msgId, reactions);
      }
    } else if (message['type'] == 'message_read') {
      final readerId = message['reader_id'];
      if (readerId != _userId && !_isDisposed) {
        // L'autre utilisateur a lu la conversation
        // On marque TOUS nos messages envoyés comme lus
        final updated = state.messages.map((m) {
          if (m['sender_id'] == _userId) {
            return {...m, 'is_read': true};
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
      }
    } else if (message['type'] == 'message_updated') {
      final msgId = message['message_id']?.toString();
      final metadata = message['metadata_'];
      if (msgId != null && metadata is Map<String, dynamic>) {
        _updateMessageMetadata(msgId, metadata);
      }
    } else if (message['type'] == 'message_deleted') {
      final msgId = message['message_id']?.toString();
      if (msgId != null && !_isDisposed) {
        final updated = state.messages.map((m) {
          final currentId = m['id']?.toString();
          final currentMsgId = m['message_id']?.toString();
          if (currentId == msgId || currentMsgId == msgId) {
             return {...m, 'content': '🚫 Ce message a été supprimé', 'message_type': 'deleted', 'is_encrypted': false};
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
        LocalDatabase.instance.updateMessage(msgId, {
          'content': '🚫 Ce message a été supprimé',
          'message_type': 'deleted',
        });
      }
    } else if (message['type'] == 'message_edited') {
      final msgId = message['message_id']?.toString();
      String newContent = message['content']?.toString() ?? "";
      
      if (msgId != null && !_isDisposed) {
        // Déchiffrer si nécessaire
        final decrypted = await _decryptBulk([message]);
        newContent = decrypted.first['content']?.toString() ?? newContent;

        Map<String, dynamic> updatedMeta = {'edited': true};
        final updated = state.messages.map((m) {
          final currentId = m['id']?.toString();
          final currentMsgId = m['message_id']?.toString();
          if (currentId == msgId || currentMsgId == msgId) {
            final meta = Map<String, dynamic>.from((m['metadata_'] as Map?) ?? {});
            meta['edited'] = true;
            updatedMeta = meta;
            return {...m, 'content': newContent, 'metadata_': meta};
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
        LocalDatabase.instance.updateMessage(msgId, {
          'content': newContent,
          'metadata_': updatedMeta,
        });
      }
    }
  }

  /// Bascule une réaction emoji sur un message (optimiste + WebSocket).
  void toggleReaction(String messageId, String emoji) {
    if (_userId == null) return;

    // 1. Mise à jour optimiste locale immédiate
    final updatedMessages = state.messages.map((m) {
      if (m['id'].toString() != messageId) return m;

      final reactions = Map<String, dynamic>.from(
        (m['reactions'] as Map<String, dynamic>?) ?? {},
      );
      final users = List<String>.from((reactions[emoji] as List?) ?? []);

      if (users.contains(_userId)) {
        users.remove(_userId);
      } else {
        users.add(_userId!);
      }
      reactions[emoji] = users;
      return {...m, 'reactions': reactions};
    }).toList();

    if (!_isDisposed) state = state.copyWith(messages: updatedMessages);

    // 2. Envoyer via WebSocket pour persistance serveur
    _chatService.sendMessage(
      '', // Content vide pour éviter d'être traité comme un nouveau message
      type: 'reaction',
      data: {'message_id': messageId, 'emoji': emoji},
    );
  }

  /// Voter pour un sondage (optimiste + API)
  Future<void> votePoll(String messageId, int optionIndex) async {
    if (_userId == null) return;

    // 1. Mise à jour optimiste locale
    final updatedMessages = state.messages.map((m) {
      final currentId = m['id']?.toString();
      final currentMsgId = m['message_id']?.toString();
      if (currentId == messageId || currentMsgId == messageId) {
        final meta = Map<String, dynamic>.from((m['metadata_'] as Map?) ?? {});
        final votes = Map<String, dynamic>.from((meta['votes'] as Map?) ?? {});
        
        votes[_userId!] = optionIndex;
        meta['votes'] = votes;
        
        // Recalculer le total des votes
        meta['total_votes'] = votes.length;
        
        return {...m, 'metadata_': meta};
      }
      return m;
    }).toList();

    if (!_isDisposed) state = state.copyWith(messages: updatedMessages);

    // 2. Appel API pour persistance
    try {
      final response = await _authService.authenticatedRequest(
        url: '${ApiConfig.baseUrl}/rooms/$roomId/messages/$messageId/vote',
        method: 'POST',
        body: {'option_index': optionIndex},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final newVotes = Map<String, dynamic>.from(data['votes'] ?? {});
        
        // Mettre à jour avec les données réelles du serveur si nécessaire
        // (Bien que le broadcast message_updated s'en chargera aussi)
        _updateMessageMetadata(messageId, {'votes': newVotes, 'total_votes': newVotes.length});
      }
    } catch (e) {
      debugPrint("❌ Erreur lors du vote: $e");
    }
  }

  /// Met à jour les métadonnées d'un message spécifique en mémoire et en DB
  void _updateMessageMetadata(String messageId, Map<String, dynamic> metadataUpdates) {
    if (_isDisposed) return;
    
    final updated = state.messages.map((m) {
      final currentId = m['id']?.toString();
      final currentMsgId = m['message_id']?.toString();
      if (currentId == messageId || currentMsgId == messageId) {
        final meta = Map<String, dynamic>.from((m['metadata_'] as Map?) ?? {});
        meta.addAll(metadataUpdates);
        
        // Persister en DB
        LocalDatabase.instance.updateMetadata(messageId, meta);
        
        return {...m, 'metadata_': meta};
      }
      return m;
    }).toList();
    
    state = state.copyWith(messages: updated);
  }

  /// Supprimer un message (optimiste + WebSocket)
  void deleteMessage(String messageId) {
    if (_userId == null) return;
    final updated = state.messages.map((m) {
      final currentId = m['id']?.toString();
      final currentMsgId = m['message_id']?.toString();
      if (currentId == messageId || currentMsgId == messageId) {
         return {...m, 'content': '🚫 Ce message a été supprimé', 'message_type': 'deleted', 'is_encrypted': false};
      }
      return m;
    }).toList();
    if (!_isDisposed) state = state.copyWith(messages: updated);
    LocalDatabase.instance.updateMessage(messageId, {
      'content': '🚫 Ce message a été supprimé',
      'message_type': 'deleted',
    });
    _chatService.sendMessage('', type: 'delete_message', data: {'message_id': messageId});
  }

  /// Modifier un message (optimiste + WebSocket)
  void editMessage(String messageId, String newContent) async {
    if (_userId == null) return;

    // Mise à jour optimiste
    final updated = state.messages.map((m) {
      final currentId = m['id']?.toString();
      final currentMsgId = m['message_id']?.toString();
      if (currentId == messageId || currentMsgId == messageId) {
        final meta = Map<String, dynamic>.from((m['metadata_'] as Map?) ?? {});
        meta['edited'] = true;
        return {...m, 'content': newContent, 'metadata_': meta};
      }
      return m;
    }).toList();
    if (!_isDisposed) state = state.copyWith(messages: updated);

    // Chiffrer si E2EE actif
    String contentToSend = newContent;
    bool wasEncrypted = false;
    if (state.memberKeys.isNotEmpty) {
      final recipientId = state.memberKeys.keys.firstWhere(
        (id) => id != _userId, orElse: () => "",
      );
      if (recipientId.isNotEmpty && state.memberKeys[recipientId] != null) {
        try {
          contentToSend = await _encryptionService.encrypt(newContent, state.memberKeys[recipientId]!);
          wasEncrypted = true;
        } catch (_) {}
      }
    }

    _chatService.sendMessage('', type: 'edit_message', data: {
      'message_id': messageId,
      'content': contentToSend,
      'is_encrypted': wasEncrypted,
    });
  }

  void sendMessage(String content, String type, {Map<String, dynamic>? extraData, String? localPath}) async {
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

    // Préparer les métadonnées : si extraData est fourni sans la clé 'metadata_',
    // on l'enveloppe automatiquement pour respecter la structure attendue par l'app et le backend.
    final Map<String, dynamic>? finalExtraData = (extraData != null && !extraData.containsKey('metadata_'))
        ? {'metadata_': extraData}
        : extraData;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id': tempId,
      'room_id': roomId, 
      'sender_id': currentUserId,
      'content': content, 
      'message_type': type,
      'status': 'pending',
      'is_encrypted': wasEncrypted,
      'created_at': DateTime.now().toIso8601String(),
      'local_path': localPath,
      if (finalExtraData != null && finalExtraData.containsKey('metadata_'))
        'metadata_': finalExtraData['metadata_'],
    };

    if (!_isDisposed) {
      state = state.copyWith(messages: [...state.messages, tempMsg]);
    }
    
    _chatService.sendMessage(contentToSend, type: type, data: finalExtraData);

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

  /// Télécharge un média en arrière-plan avec suivi de progression
  Future<void> _downloadMediaInBackground(Map<String, dynamic> message) async {
    if (kIsWeb) return;
    
    final messageId = message['id'].toString();
    final url = ApiConfig.getMediaUrl(message['content']);
    
    if (url.isEmpty) return;

    // Initialiser l'état de téléchargement pour afficher le spinner immédiatement
    if (!_isDisposed) {
      final newProgress = Map<String, double>.from(state.downloadProgress);
      newProgress[messageId] = 0.0; // Indeterminate ou début à 0
      state = state.copyWith(downloadProgress: newProgress);
    }
    
    // Récupérer le nom de fichier original s'il existe
    String fileName = message['content'].split('/').last;
    if (message.containsKey('metadata_') && message['metadata_'] is Map) {
      final meta = message['metadata_'] as Map;
      if (meta.containsKey('filename')) {
        fileName = meta['filename'];
      }
    }
    
    try {
      debugPrint("📥 Téléchargement média: $url (type: ${message['message_type']})");
      final localPath = await _mediaService.saveToGallery(
        url, 
        fileName, 
        message['message_type'],
        onReceiveProgress: (received, total) {
          if (total > 0 && !_isDisposed) {
            final progress = received / total;
            state = state.copyWith(
              downloadProgress: {
                ...state.downloadProgress,
                messageId: progress,
              },
            );
          }
        },
      );

      if (!_isDisposed) {
        final newProgress = Map<String, double>.from(state.downloadProgress);
        newProgress.remove(messageId);

        if (localPath != null) {
          // Mettre à jour UNIQUEMENT le local_path
          await LocalDatabase.instance.updateLocalPath(messageId, localPath);

          // Mettre à jour l'état UI
          final updatedMessages = state.messages.map((msg) {
            final currentId = msg['id']?.toString();
            final currentMsgId = msg['message_id']?.toString();
            if (currentId == messageId || currentMsgId == messageId) {
              return {...msg, 'local_path': localPath};
            }
            return msg;
          }).toList();

          state = state.copyWith(
            messages: updatedMessages,
            downloadProgress: newProgress,
          );
        } else {
          // Si localPath est null, le téléchargement a échoué (silencieusement)
          state = state.copyWith(downloadProgress: newProgress);
        }
      }
    } catch (e) {
      debugPrint("❌ Erreur téléchargement arrière-plan : $e");
      if (!_isDisposed) {
        final newProgress = Map<String, double>.from(state.downloadProgress);
        newProgress.remove(messageId);
        state = state.copyWith(downloadProgress: newProgress);
      }
    }
  }

  /// Déclencher manuellement le téléchargement (ex: pour les documents)
  Future<void> downloadMedia(Map<String, dynamic> message) async {
    await _downloadMediaInBackground(message);
  }
}
