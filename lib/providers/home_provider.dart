import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_state.dart';
import '../models/status_model.dart';
import '../services/room_service.dart';
import '../services/status_service.dart';
import '../services/local_database.dart';
import '../services/global_presence_service.dart';
import '../services/offline_sync_service.dart';
import 'migration_provider.dart';


final homeProvider = NotifierProvider<HomeNotifier, HomeState>(() {
  return HomeNotifier();
});

class HomeNotifier extends Notifier<HomeState> {
  final RoomService _roomService = RoomService();
  final StatusService _statusService = StatusService();
  bool _isDisposed = false;
  StreamSubscription? _globalEventsSub;

  @override
  HomeState build() {
    ref.listen(roomMigrationProvider, (previous, next) {
      if (next.isNotEmpty) {
        _handleRoomMigrations(next);
      }
    });

    ref.onDispose(() {
      _isDisposed = true;
      _globalEventsSub?.cancel();
    });
    
    // NE PAS appeler _init() ici.
    // AppDataProvider orchestre l'initialisation via loadFromSQLite() + initServices().
    return HomeState();
  }

  /// Phase 1 : Charge uniquement le cache SQLite (< 30ms).
  /// Appelé par AppDataProvider AVANT la navigation vers HomeScreen.
  Future<void> loadFromSQLite() async {
    final prefs = await SharedPreferences.getInstance();
    final viewedIds = prefs.getStringList('viewed_status_ids')?.toSet() ?? {};
    try {
      final cachedRooms = await LocalDatabase.instance.getRooms();
      final cachedStatuses = await LocalDatabase.instance.getStatuses();
      if (!_isDisposed) {
        state = state.copyWith(
          rooms: cachedRooms,
          statuses: cachedStatuses.map((s) => StatusModel.fromJson(s)).toList(),
          viewedStatusIds: viewedIds,
          isLoadingRooms: false, // On a chargé le cache, donc plus "chargant" au sens bloquant
          isLoadingStatus: false,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Erreur cache rooms/status SQLite: $e');
    }
  }

  /// Phase 2 (services) : Connecte le WebSocket global et écoute les événements.
  /// Appelé par AppDataProvider après la Phase 1.
  void initServices() {
    GlobalPresenceService.instance.connect();
    _listenToGlobalEvents();
  }

  // _init() supprimée : remplacée par loadFromSQLite() + initServices() + refreshRooms() + refreshStatus()
  // orchestrés par AppDataProvider.


  /// Écoute les événements globaux (nouveaux messages dans d'autres rooms)
  /// pour mettre à jour la liste de conversations en temps réel
  void _listenToGlobalEvents() {
    _globalEventsSub = GlobalPresenceService.instance.globalEventsStream.listen((event) {
      if (_isDisposed) return;

      final type = event['type'];
      if (type == 'global_new_message') {
        final roomId = event['room_id']?.toString();
        final content = event['content']?.toString() ?? '';
        final senderName = event['sender_name']?.toString();
        final timestamp = event['created_at']?.toString() ?? DateTime.now().toIso8601String();

        if (roomId != null) {
          final messageType = event['message_type']?.toString() ?? 'text';
          String displayContent = _getReadableMediaType(messageType, content);

          // Mise à jour atomique de la DB locale
          LocalDatabase.instance.updateRoomLastMessage(
            roomId: roomId,
            lastMessage: displayContent,
            lastMessageAt: timestamp,
            lastSenderName: senderName,
            incrementUnread: true,
          );

          // Mise à jour instantanée de l'UI
          _updateRoomInState(roomId, displayContent, timestamp, senderName, incrementUnread: true);
        }
      }
    });
  }

  /// Met à jour un salon dans l'état actuel et re-trie la liste par date
  void _updateRoomInState(String roomId, String lastMessage, String lastMessageAt, String? senderName, {bool incrementUnread = false}) {
    final updatedRooms = state.rooms.map((room) {
      if (room['id'] == roomId) {
        return {
          ...room,
          'last_message': lastMessage,
          'last_message_time': lastMessageAt,
          'last_sender_name': senderName,
          'unread_count': incrementUnread ? ((room['unread_count'] ?? 0) as int) + 1 : room['unread_count'],
        };
      }
      return room;
    }).toList();

    // Trier par dernier message (le plus récent en premier)
    updatedRooms.sort((a, b) {
      final aTime = a['last_message_time']?.toString() ?? '';
      final bTime = b['last_message_time']?.toString() ?? '';
      return bTime.compareTo(aTime);
    });

    if (!_isDisposed) {
      state = state.copyWith(rooms: updatedRooms);
    }
  }

  Future<void> markStatusAsRead(String id) async {
    final newViewedIds = {...state.viewedStatusIds, id};
    state = state.copyWith(viewedStatusIds: newViewedIds);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('viewed_status_ids', newViewedIds.toList());
  }

  Future<void> refreshRooms() async {
    try {
      final rooms = await _roomService.getRooms();
      
      // Sauvegarder en cache SQLite (non bloquant)
      LocalDatabase.instance.saveRooms(rooms);
      
      if (!_isDisposed) {
        // Formatter les derniers messages avec des labels lisibles
        final formattedRooms = rooms.map((room) {
          final mType = room['last_message_type']?.toString() ?? 'text';
          final mContent = room['last_message']?.toString() ?? '';
          return {
            ...room,
            'last_message': _getReadableMediaType(mType, mContent),
          };
        }).toList();

        formattedRooms.sort((a, b) {
          final aTime = a['last_message_time']?.toString() ?? '';
          final bTime = b['last_message_time']?.toString() ?? '';
          return bTime.compareTo(aTime);
        });
        // Mise à jour silencieuse : on ne remplace que si les données ont réellement changé
        state = state.copyWith(rooms: formattedRooms, isLoadingRooms: false);
      }

      // ═══ OPTIMISATION : Pré-chargement agressif des messages ═══
      // On prend les 10 salons les plus récents et on pré-charge leurs messages
      if (rooms.isNotEmpty) {
        final topRoomIds = rooms
          .take(10)
          .map((r) => r['id']?.toString())
          .whereType<String>()
          .toList();
        
        if (topRoomIds.isNotEmpty) {
          // Lancer en arrière-plan sans attendre
          ref.read(offlineSyncProvider).preFetchMessages(topRoomIds);
        }
      }
    } catch (e) {
      debugPrint("⚠️ Erreur sync rooms API: $e");
      if (!_isDisposed) state = state.copyWith(isLoadingRooms: false);
    }
  }

  /// Réinitialise le compteur de non-lus quand l'utilisateur ouvre un salon
  void markRoomAsRead(String roomId) {
    LocalDatabase.instance.resetUnreadCount(roomId);
    final updatedRooms = state.rooms.map((room) {
      if (room['id'] == roomId) {
        return {...room, 'unread_count': 0};
      }
      return room;
    }).toList();
    if (!_isDisposed) {
      state = state.copyWith(rooms: updatedRooms);
    }
  }

  Future<void> refreshStatus() async {
    try {
      final statuses = await _statusService.getStatuses();
      
      // Sauvegarder en cache SQLite
      if (!kIsWeb) {
        final jsonList = statuses.map((s) => s.toJson()).toList();
        await LocalDatabase.instance.saveStatuses(jsonList);
      }

      if (!_isDisposed) {
        state = state.copyWith(statuses: statuses, isLoadingStatus: false);
      }
    } catch (e) {
      debugPrint("⚠️ Erreur sync status API: $e");
      if (!_isDisposed) {
        state = state.copyWith(isLoadingStatus: false);
      }
    }
  }

  void _handleRoomMigrations(Map<String, String> migrations) {
    if (_isDisposed) return;
    
    bool changed = false;
    final updatedRooms = state.rooms.map((room) {
      final currentId = room['id']?.toString();
      if (currentId != null && migrations.containsKey(currentId)) {
        changed = true;
        return {
          ...room,
          'id': migrations[currentId],
        };
      }
      return room;
    }).toList();

    if (changed) {
      state = state.copyWith(rooms: updatedRooms);
    }
  }

  Future<void> createStatus({String? text, String? mediaUrl}) async {
    try {
      await _statusService.createStatus(text: text, mediaUrl: mediaUrl);
      await refreshStatus();
    } catch (e) {
      state = state.copyWith(errorMessage: "Erreur lors de la création du statut");
    }
  }

  /// Met à jour les métadonnées d'un salon localement et en base de données
  Future<void> updateRoomMetadata(String roomId, {String? name, String? avatarUrl}) async {
    // 1. Mise à jour de la DB locale
    await LocalDatabase.instance.updateRoomMetadata(roomId, name: name, avatarUrl: avatarUrl);

    // 2. Mise à jour de l'état actuel (UI réactive)
    if (_isDisposed) return;
    
    final updatedRooms = state.rooms.map((room) {
      if (room['id'] == roomId) {
        return {
          ...room,
          if (name != null) 'name': name,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        };
      }
      return room;
    }).toList();

    state = state.copyWith(rooms: updatedRooms);
  }

  String _getReadableMediaType(String type, String content) {
    if (type == 'image') return "📸 Image";
    if (type == 'file') return "📄 Fichier";
    if (type == 'audio') return "🎵 Note vocale";
    if (type == 'video') return "🎬 Vidéo";
    return content;
  }
}

