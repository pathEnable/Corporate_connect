import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_state.dart';
import '../services/room_service.dart';
import '../services/status_service.dart';
import '../services/local_database.dart';
import '../services/global_presence_service.dart';
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
    // Empêche la destruction/recréation du provider lors des rebuilds
    // de l'arborescence (ex. changement de thème, verrouillage biométrique).
    // Sans keepAlive, _init() serait rappelé à chaque retour en foreground.
    ref.keepAlive();

    ref.listen(roomMigrationProvider, (previous, next) {
      if (next.isNotEmpty) {
        _handleRoomMigrations(next);
      }
    });

    ref.onDispose(() {
      _isDisposed = true;
      _globalEventsSub?.cancel();
    });
    
    // Chargement initial (appelé une seule fois grâce à keepAlive)
    _init();
    
    return HomeState();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final viewedIds = prefs.getStringList('viewed_status_ids')?.toSet() ?? {};

    // ═══ PHASE 1 : Cache INSTANTANÉ depuis SQLite (< 30ms) ═══
    try {
      final cachedRooms = await LocalDatabase.instance.getRooms();
      if (!_isDisposed) {
        state = state.copyWith(
          rooms: cachedRooms,
          viewedStatusIds: viewedIds,
          // Spinner uniquement au tout premier démarrage (cache vide)
          isLoadingRooms: cachedRooms.isEmpty,
          isLoadingStatus: true,
        );
      }
    } catch (e) {
      debugPrint("⚠️ Erreur cache rooms SQLite: $e");
    }

    // ═══ PHASE 2 : WS Global + Sync API en arrière-plan (non bloquant) ═══
    GlobalPresenceService.instance.connect();
    _listenToGlobalEvents();
    
    // Les deux syncs API partent en parallèle, sans attendre
    refreshRooms();
    refreshStatus();
  }


  /// Écoute les événements globaux (nouveaux messages dans d'autres rooms)
  /// pour mettre à jour la liste de conversations en temps réel
  void _listenToGlobalEvents() {
    _globalEventsSub = GlobalPresenceService.instance.globalEventsStream.listen((event) {
      if (_isDisposed) return;

      final type = event['type'];
      if (type == 'new_message_notification') {
        final roomId = event['room_id']?.toString();
        final content = event['content']?.toString() ?? '';
        final senderName = event['sender_name']?.toString();
        final timestamp = event['created_at']?.toString() ?? DateTime.now().toIso8601String();

        if (roomId != null) {
          // Mise à jour atomique de la DB locale
          LocalDatabase.instance.updateRoomLastMessage(
            roomId: roomId,
            lastMessage: content,
            lastMessageAt: timestamp,
            lastSenderName: senderName,
            incrementUnread: true,
          );

          // Mise à jour instantanée de l'UI
          _updateRoomInState(roomId, content, timestamp, senderName, incrementUnread: true);
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
        rooms.sort((a, b) {
          final aTime = a['last_message_time']?.toString() ?? '';
          final bTime = b['last_message_time']?.toString() ?? '';
          return bTime.compareTo(aTime);
        });
        // Mise à jour silencieuse : on ne remplace que si les données ont réellement changé
        state = state.copyWith(rooms: rooms, isLoadingRooms: false);
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
      if (!_isDisposed) {
        state = state.copyWith(statuses: statuses, isLoadingStatus: false);
      }
    } catch (_) {
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
}

