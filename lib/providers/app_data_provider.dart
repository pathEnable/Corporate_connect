import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_provider.dart';
import 'profile_provider.dart';
import 'contacts_provider.dart';
import 'call_history_provider.dart';
import '../services/push_notification_service.dart';

/// État global de l'initialisation de l'application.
class AppDataState {
  final bool isInitialized; // SQLite chargé → navigation possible
  final bool isSyncing;     // API en cours en arrière-plan
  final String? errorMessage;

  const AppDataState({
    this.isInitialized = false,
    this.isSyncing = false,
    this.errorMessage,
  });

  AppDataState copyWith({
    bool? isInitialized,
    bool? isSyncing,
    String? errorMessage,
  }) {
    return AppDataState(
      isInitialized: isInitialized ?? this.isInitialized,
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: errorMessage,
    );
  }
}

final appDataProvider = NotifierProvider<AppDataNotifier, AppDataState>(() {
  return AppDataNotifier();
});

/// Orchestrateur centralisé du chargement des données de l'application.
///
/// Fonctionnement en 2 phases :
/// - Phase 1 (< 30ms) : charge le cache SQLite/local → permet une navigation immédiate
/// - Phase 2 (background) : sync avec l'API en parallèle → mise à jour silencieuse des UI
///
/// À déclencher depuis : login_screen, register_screen, et AuthGate (redémarrage)
class AppDataNotifier extends Notifier<AppDataState> {
  @override
  AppDataState build() {
    return const AppDataState();
  }

  /// Point d'entrée unique après authentification.
  /// Ne bloque JAMAIS la navigation — toujours retourner après Phase 1.
  Future<void> initializeAfterLogin() async {
    // Éviter une double initialisation
    if (state.isInitialized || state.isSyncing) return;

    state = state.copyWith(isSyncing: true);

    // ═══ PHASE 1 : Cache local instantané (SQLite / SharedPrefs) ═══
    // Ces opérations sont < 30ms et permettent une navigation immédiate.
    try {
      await Future.wait([
        ref.read(homeProvider.notifier).loadFromSQLite(),
        ref.read(profileProvider.notifier).loadFromLocal(),
        ref.read(contactsProvider.notifier).loadFromSQLite(),
        ref.read(callHistoryProvider.notifier).loadFromSQLite(),
      ]);
      // Connecter le WebSocket global après le chargement local
      ref.read(homeProvider.notifier).initServices();
    } catch (e) {
      debugPrint('⚠️ AppDataProvider Phase 1 (non bloquant): $e');
    }

    // ✅ Marquer comme initialisé → la navigation peut se faire maintenant
    state = state.copyWith(isInitialized: true);

    // ═══ PHASE 2 : Sync API en arrière-plan (non bloquant) ═══
    // Lance tout en parallèle sans attendre le résultat pour naviguer.
    _syncFromApi();
  }

  /// Sync API background — fire and forget depuis initializeAfterLogin.
  Future<void> _syncFromApi() async {
    try {
      await Future.wait([
        ref.read(homeProvider.notifier).refreshRooms(),
        ref.read(homeProvider.notifier).refreshStatus(),
        ref.read(profileProvider.notifier).refresh(),
        ref.read(contactsProvider.notifier).loadContacts(),
        ref.read(callHistoryProvider.notifier).refresh(),
      ]);

      // ══ FCM Registration ══
      // On s'assure que le token est enregistré côté backend après login
      try {
        final fcmToken = await PushNotificationService.getFcmToken();
        if (fcmToken != null) {
          await PushNotificationService.registerToken(fcmToken);
        }
      } catch (e) {
        debugPrint('⚠️ FCM registration error: $e');
      }

      debugPrint('✅ AppDataProvider : sync API complète');
    } catch (e) {
      debugPrint('⚠️ AppDataProvider Phase 2 sync: $e');
      state = state.copyWith(errorMessage: 'Synchronisation partielle');
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  /// Forcer une re-synchronisation complète (ex : pull-to-refresh global).
  Future<void> forceRefresh() async {
    state = state.copyWith(isSyncing: true, errorMessage: null);
    await _syncFromApi();
  }

  /// Réinitialiser complètement (appelé à la déconnexion).
  void reset() {
    state = const AppDataState();
  }
}
