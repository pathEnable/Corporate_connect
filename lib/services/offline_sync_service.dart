import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_database.dart';
import 'room_service.dart';
import '../providers/migration_provider.dart';

/// Provider pour accéder au service de synchronisation
final offlineSyncProvider = Provider((ref) => OfflineSyncService(ref));

/// Service qui surveille la connectivité et synchronise automatiquement
/// les salons créés hors-ligne dès que la connexion revient.
class OfflineSyncService {
  final Ref _ref;
  final RoomService _roomService = RoomService();
  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  OfflineSyncService(this._ref);

  /// À appeler une seule fois au démarrage de l'application (dans main.dart)
  void startListening() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        syncPendingRooms();
      }
    });
  }

  void stopListening() => _connectivitySub?.cancel();

  /// Tente de synchroniser tous les salons en attente (draft_*)
  Future<void> syncPendingRooms() async {
    if (_isSyncing || kIsWeb) return;
    _isSyncing = true;

    try {
      final pending = await LocalDatabase.instance.getPendingRooms();
      if (pending.isEmpty) return;

      debugPrint("🔄 Synchronisation de ${pending.length} salon(s) hors-ligne...");

      for (final pendingRoom in pending) {
        final tempId = pendingRoom['temp_id'] as String;
        final name = pendingRoom['name'] as String;
        final isGroup = pendingRoom['is_group'] == 1;
        final memberIdsList = (pendingRoom['member_ids'] as String).split(',');

        try {
          Map<String, dynamic> realRoom;
          if (isGroup) {
            realRoom = await _roomService.createGroup(name, memberIdsList);
          } else {
            realRoom = await _roomService.createPrivateRoom(memberIdsList.first);
          }

          final realId = realRoom['id'].toString();

          // 1. Mises à jour SQL locales
          await LocalDatabase.instance.confirmPendingRoom(tempId, realId);
          
          // 2. Notifier les migrations d'ID via Riverpod
          MigrationManager.notifyMigrationWithRef(_ref, tempId, realId);
          
          debugPrint("✅ Salon '$name' synchronisé: $tempId -> $realId");
        } catch (e) {
          debugPrint("⚠️ Impossible de synchroniser le salon '$name': $e");
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Pré-charge les messages pour les salons spécifiés afin qu'ils soient
  /// déjà présents en base locale lors de l'ouverture du chat.
  Future<void> preFetchMessages(List<String> roomIds) async {
    if (kIsWeb) return;
    
    debugPrint("🚀 Pré-chargement des messages pour ${roomIds.length} salon(s)...");
    
    for (final roomId in roomIds) {
      try {
        // Récupérer les 20 derniers messages
        final messages = await _roomService.getMessages(roomId, limit: 20);
        
        // Sauvegarder massivement en DB locale
        // Note: La DB gère déjà les doublons via l'ID
        for (final msg in messages) {
          await LocalDatabase.instance.saveMessage(msg);
        }
        
        debugPrint("✅ ${messages.length} messages pré-chargés pour le salon $roomId");
      } catch (e) {
        debugPrint("⚠️ Échec du pré-chargement pour le salon $roomId: $e");
      }
    }
  }
}
