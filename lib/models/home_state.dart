import '../models/status_model.dart';

class HomeState {
  final List<Map<String, dynamic>> rooms;
  final List<StatusModel> statuses;
  final bool isLoadingRooms;
  final bool isLoadingStatus;
  final String? errorMessage;

  HomeState({
    this.rooms = const [],
    this.statuses = const [],
    this.isLoadingRooms = true,
    this.isLoadingStatus = true,
    this.errorMessage,
  });

  HomeState copyWith({
    List<Map<String, dynamic>>? rooms,
    List<StatusModel>? statuses,
    bool? isLoadingRooms,
    bool? isLoadingStatus,
    String? errorMessage,
  }) {
    return HomeState(
      rooms: rooms ?? this.rooms,
      statuses: statuses ?? this.statuses,
      isLoadingRooms: isLoadingRooms ?? this.isLoadingRooms,
      isLoadingStatus: isLoadingStatus ?? this.isLoadingStatus,
      errorMessage: errorMessage,
    );
  }
}
