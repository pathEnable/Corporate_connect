import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_state.dart';
import '../services/room_service.dart';
import '../services/status_service.dart';
import '../services/local_database.dart';

final homeProvider = NotifierProvider<HomeNotifier, HomeState>(() {
  return HomeNotifier();
});

class HomeNotifier extends Notifier<HomeState> {
  final RoomService _roomService = RoomService();
  final StatusService _statusService = StatusService();
  bool _isDisposed = false;

  @override
  HomeState build() {
    ref.onDispose(() => _isDisposed = true);
    
    // Chargement initial
    _init();
    
    return HomeState();
  }

  Future<void> _init() async {
    // 1. Charger tout le cache local en parallèle
    final futures = await Future.wait([
      LocalDatabase.instance.getRooms(),
      _statusService.getStatuses(), // Les statuts sont légers
    ]);

    if (_isDisposed) return;

    state = state.copyWith(
      rooms: futures[0] as List<Map<String, dynamic>>,
      statuses: futures[1] as dynamic,
      isLoadingRooms: (futures[0] as List).isEmpty,
      isLoadingStatus: false,
    );

    // 2. Refresh API en arrière-plan
    refreshRooms();
    refreshStatus();
  }

  Future<void> refreshRooms() async {
    try {
      final rooms = await _roomService.getRooms();
      await LocalDatabase.instance.saveRooms(rooms);
      
      if (!_isDisposed) {
        state = state.copyWith(rooms: rooms, isLoadingRooms: false);
      }
    } catch (_) {
      if (!_isDisposed) {
        state = state.copyWith(isLoadingRooms: false);
      }
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

  Future<void> createStatus(String text) async {
    try {
      await _statusService.createStatus(text: text);
      await refreshStatus();
    } catch (e) {
      state = state.copyWith(errorMessage: "Erreur lors de la création du statut");
    }
  }
}
