import '../models/status_model.dart';

class HomeState {
  final List<Map<String, dynamic>> rooms;
  final List<StatusModel> statuses;
  final Set<String> viewedStatusIds;
  final bool isLoadingRooms;
  final bool isLoadingStatus;
  final String? errorMessage;

  HomeState({
    this.rooms = const [],
    this.statuses = const [],
    this.viewedStatusIds = const {},
    this.isLoadingRooms = true,
    this.isLoadingStatus = true,
    this.errorMessage,
  });

  HomeState copyWith({
    List<Map<String, dynamic>>? rooms,
    List<StatusModel>? statuses,
    Set<String>? viewedStatusIds,
    bool? isLoadingRooms,
    bool? isLoadingStatus,
    String? errorMessage,
  }) {
    return HomeState(
      rooms: rooms ?? this.rooms,
      statuses: statuses ?? this.statuses,
      viewedStatusIds: viewedStatusIds ?? this.viewedStatusIds,
      isLoadingRooms: isLoadingRooms ?? this.isLoadingRooms,
      isLoadingStatus: isLoadingStatus ?? this.isLoadingStatus,
      errorMessage: errorMessage,
    );
  }
}
