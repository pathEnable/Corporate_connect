import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call_log.dart';
import '../services/call_service.dart';
import '../services/local_database.dart';

class CallHistoryState {
  final List<CallLogModel> calls;
  final bool isLoading;
  final String? errorMessage;

  const CallHistoryState({
    this.calls = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  CallHistoryState copyWith({
    List<CallLogModel>? calls,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CallHistoryState(
      calls: calls ?? this.calls,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final callHistoryProvider = NotifierProvider<CallHistoryNotifier, CallHistoryState>(() {
  return CallHistoryNotifier();
});

class CallHistoryNotifier extends Notifier<CallHistoryState> {
  @override
  CallHistoryState build() {
    return const CallHistoryState();
  }

  /// Phase 1 : Charger depuis le cache SQLite
  Future<void> loadFromSQLite() async {
    if (kIsWeb) {
      state = state.copyWith(isLoading: false);
      return;
    }
    try {
      final cached = await LocalDatabase.instance.getCallHistory();
      if (cached.isNotEmpty) {
        final models = cached.map((c) => CallLogModel.fromJson(c)).toList();
        state = state.copyWith(calls: models, isLoading: false);
        debugPrint('✅ Appels chargés depuis SQLite: ${models.length}');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur cache appels SQLite: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Phase 2 : Synchroniser avec l'API
  Future<void> refresh() async {
    try {
      final history = await callService.getCallHistory();
      
      // Sauvegarder en cache SQLite
      if (!kIsWeb) {
        final jsonList = history.map((h) => h.toJson()).toList();
        await LocalDatabase.instance.saveCallHistory(jsonList);
      }

      state = state.copyWith(calls: history, isLoading: false);
      debugPrint('✅ Appels synchronisés depuis API: ${history.length}');
    } catch (e) {
      debugPrint('⚠️ Erreur sync appels API: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
