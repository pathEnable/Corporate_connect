import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_state.dart';
import '../services/room_service.dart';
import '../services/status_service.dart';
import '../services/local_database.dart';
import '../services/global_presence_service.dart';
import '../services/auth_service.dart';
import '../services/api_config.dart';
import 'migration_provider.dart';


final homeProvider = NotifierProvider<HomeNotifier, HomeState>(() {
  return HomeNotifier();
});

class HomeNotifier extends Notifier<HomeState> {
  final RoomService _roomService = RoomService();
  final StatusService _statusService = StatusService();
  final AuthService _authService = AuthService();
  bool _isDisposed = false;
  String? _currentUserId;
  StreamSubscription? _globalEventsSub;
  final Completer<void> _initCompleter = Completer<void>();

  Future<void> get initFuture => _initCompleter.future;

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
    
    // Chargement initial
    _init();
    
    return HomeState(isLoadingRooms: false); // On commence sans spinner
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
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
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    } catch (e) {
      debugPrint("❌ Erreur SQLite HomeNotifier: $e");
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
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
          updateRoomMetadata(
            roomId: roomId,
            lastMessage: content,
            lastMessageAt: timestamp,
            senderName: senderName,
            incrementUnread: true,
          );
        }
      }
    });
  }

  /// Met à jour les métadonnées d'un salon (dernier message, temps, etc.)
  /// et re-trie la liste pour faire remonter la discussion en haut (style WhatsApp).
  void updateRoomMetadata({
    required String roomId,
    required String lastMessage,
    required String lastMessageAt,
    String? senderName,
    bool incrementUnread = false,
  }) {
    if (_isDisposed) return;

    // 1. Mise à jour en base de données (persistance)
    LocalDatabase.instance.updateRoomLastMessage(
      roomId: roomId,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      lastSenderName: senderName,
      incrementUnread: incrementUnread,
    );

    // 2. Mise à jour de l'état (UI réactive)
    final rooms = List<Map<String, dynamic>>.from(state.rooms);
    final index = rooms.indexWhere((r) => r['id'] == roomId);

    if (index != -1) {
      // Salon existant : on le met à jour
      final room = rooms[index];
      rooms[index] = {
        ...room,
        'last_message': lastMessage,
        'last_message_time': lastMessageAt,
        'last_sender_name': senderName,
        'unread_count': incrementUnread ? ((room['unread_count'] ?? 0) as int) + 1 : room['unread_count'],
      };
    } else {
      // Salon manquant (ex: nouveau salon créé) : on rafraîchit tout pour être sûr
      refreshRooms();
      return;
    }

    // 3. Tri : Le plus récent en haut
    _sortRooms(rooms);

    state = state.copyWith(rooms: rooms);
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
        _sortRooms(rooms);
        // Mise à jour silencieuse : on ne remplace que si les données ont réellement changé
        state = state.copyWith(rooms: rooms, isLoadingRooms: false);
      }
      // Enrichir les avatars en arrière-plan (non bloquant)
      _enrichRoomAvatars();
    } catch (e) {
      debugPrint("⚠️ Erreur sync rooms API: $e");
      if (!_isDisposed) state = state.copyWith(isLoadingRooms: false);
    }
  }

  /// Récupère les avatars des interlocuteurs pour les conversations privées.
  /// L'API /rooms ne retourne pas d'avatar_url, donc on enrichit depuis /profiles.
  Future<void> _enrichRoomAvatars() async {
    if (_currentUserId == null || _isDisposed) return;

    final rooms = List<Map<String, dynamic>>.from(state.rooms);
    final avatarUpdates = <String, String>{}; // roomId -> avatarUrl

    for (final room in rooms) {
      if (_isDisposed) return;

      // Skip les groupes et les rooms qui ont déjà un avatar
      if (room['is_group'] == true) continue;
      final existing = room['avatar_url']?.toString() ?? '';
      if (existing.isNotEmpty) continue;

      try {
        // 1. Récupérer les membres de la room
        final members = await _roomService.getRoomMembers(room['id']);

        // 2. Trouver l'autre utilisateur
        final otherMember = members.firstWhere(
          (m) => m['id'].toString() != _currentUserId,
          orElse: () => <String, dynamic>{},
        );
        if (otherMember.isEmpty) continue;

        // 3. Récupérer son profil pour avoir l'avatar_url
        final response = await _authService.authenticatedRequest(
          url: '${ApiConfig.baseUrl}/profiles/${otherMember['id']}',
          method: 'GET',
        );

        if (response.statusCode == 200) {
          final profile = jsonDecode(response.body);
          final avatarUrl = profile['avatar_url']?.toString();
          if (avatarUrl != null && avatarUrl.isNotEmpty) {
            avatarUpdates[room['id']] = avatarUrl;
            // Persister en SQLite sur mobile
            if (!kIsWeb) {
              LocalDatabase.instance.updateRoomAvatar(room['id'], avatarUrl);
            }
          }
        }
      } catch (e) {
        debugPrint("⚠️ Avatar enrichment error for room ${room['id']}: $e");
      }
    }

    // Appliquer toutes les mises à jour en une seule fois
    if (avatarUpdates.isNotEmpty && !_isDisposed) {
      final updatedRooms = state.rooms.map((room) {
        final newAvatar = avatarUpdates[room['id']];
        if (newAvatar != null) {
          return {...room, 'avatar_url': newAvatar};
        }
        return room;
      }).toList();
      state = state.copyWith(rooms: updatedRooms);
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

  void _sortRooms(List<Map<String, dynamic>> rooms) {
    rooms.sort((a, b) {
      final aTime = (a['last_message_time'] ?? a['last_message_at'])?.toString() ?? '';
      final bTime = (b['last_message_time'] ?? b['last_message_at'])?.toString() ?? '';
      return bTime.compareTo(aTime);
    });
  }
}

