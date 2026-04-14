import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/room_service.dart';

// ─── État immutable du provider ───────────────────────────────────────────────

enum RoomDetailsStatus { idle, loading, success, error }

class RoomDetailsState {
  final RoomDetailsStatus status;
  final List<Map<String, dynamic>> members;
  final String? errorMessage;
  final String? successMessage;

  const RoomDetailsState({
    this.status = RoomDetailsStatus.idle,
    this.members = const [],
    this.errorMessage,
    this.successMessage,
  });

  RoomDetailsState copyWith({
    RoomDetailsStatus? status,
    List<Map<String, dynamic>>? members,
    String? errorMessage,
    String? successMessage,
  }) {
    return RoomDetailsState(
      status: status ?? this.status,
      members: members ?? this.members,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

// ─── Provider paramétré par roomId ────────────────────────────────────────────

final roomDetailsProvider = NotifierProviderFamily<RoomDetailsNotifier, RoomDetailsState, String>(
  () => RoomDetailsNotifier(),
);

// ─── Notifier : toute la logique métier ici, zéro UI ──────────────────────────

class RoomDetailsNotifier extends FamilyNotifier<RoomDetailsState, String> {
  final RoomService _roomService = RoomService();

  @override
  RoomDetailsState build(String roomId) {
    return const RoomDetailsState();
  }

  /// Initialise la liste des membres depuis les données passées par l'écran parent
  void initMembers(List<Map<String, dynamic>> members) {
    state = state.copyWith(members: List.from(members));
  }

  /// Ajoute plusieurs membres au salon et retourne true en cas de succès
  Future<bool> addMembers(String roomId, List<String> userIds) async {
    state = state.copyWith(status: RoomDetailsStatus.loading);
    try {
      for (final id in userIds) {
        await _roomService.addMember(roomId, id);
      }
      state = state.copyWith(
        status: RoomDetailsStatus.success,
        successMessage: '${userIds.length} membre(s) ajouté(s) avec succès !',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: RoomDetailsStatus.error,
        errorMessage: "Erreur lors de l'ajout des membres : $e",
      );
      return false;
    }
  }

  /// Quitte le salon et retourne true en cas de succès
  Future<bool> leaveRoom(String roomId, String currentUserId) async {
    state = state.copyWith(status: RoomDetailsStatus.loading);
    try {
      await _roomService.leaveRoom(roomId, currentUserId);
      state = state.copyWith(status: RoomDetailsStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: RoomDetailsStatus.error,
        errorMessage: "Erreur lors de la sortie du groupe : $e",
      );
      return false;
    }
  }

  /// Réinitialise les messages de retour pour éviter les doublons d'affichage
  void clearFeedback() {
    state = state.copyWith(
      status: RoomDetailsStatus.idle,
      errorMessage: null,
      successMessage: null,
    );
  }
}
