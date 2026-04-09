import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/profile_state.dart';
import '../services/auth_service.dart';
import '../services/media_service.dart';
import '../services/encryption_service.dart';
import '../services/local_database.dart';
import '../services/global_presence_service.dart';

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(() {
  return ProfileNotifier();
});

class ProfileNotifier extends Notifier<ProfileState> {
  final AuthService _authService = AuthService();
  final MediaService _mediaService = MediaService();
  final EncryptionService _encryptionService = EncryptionService();
  final _secureStorage = const FlutterSecureStorage();

  @override
  ProfileState build() {
    // NE PAS appeler _loadProfile() ici.
    // AppDataProvider orchestre l'initialisation via loadFromLocal() puis refresh().
    return const ProfileState(isLoading: false);
  }

  /// Phase 1 : Charge le profil depuis SharedPreferences (< 5ms, sans réseau).
  /// Appelé par AppDataProvider avant la navigation.
  Future<void> loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final fullName = prefs.getString('full_name');
      bool hasKeys = await _secureStorage.containsKey(key: 'e2ee_private_key');
      if (!hasKeys) {
        hasKeys = prefs.containsKey('e2ee_private_key');
      }
      if (userId != null) {
        state = state.copyWith(
          profileData: {'id': userId, 'full_name': fullName ?? ''},
          isLoading: false,
          hasE2eeKeys: hasKeys,
        );
      }
    } catch (e) {
      debugPrint('⚠️ loadFromLocal profile: $e');
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getCurrentProfile();
      
      // Vérifier d'abord dans le stockage sécurisé
      bool hasKeys = await _secureStorage.containsKey(key: 'e2ee_private_key');
      
      // Si absent, vérifier SharedPreferences (pour compatibilité transitoire)
      if (!hasKeys) {
        final prefs = await SharedPreferences.getInstance();
        hasKeys = prefs.containsKey('e2ee_private_key');
      }
      
      state = state.copyWith(
        profileData: profile,
        isLoading: false,
        hasE2eeKeys: hasKeys,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadProfile();
  }

  Future<void> updateAvatar(Uint8List bytes, String filename) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _mediaService.uploadFile(bytes, filename: filename);
      final String newAvatarUrl = result['url'];
      await _authService.updateProfile(avatarUrl: newAvatarUrl);
      await _loadProfile();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Erreur upload: $e");
    }
  }

  Future<void> updatePresenceStatus(String status) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.updateProfile(presenceStatus: status);
      await _loadProfile();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateProfile({String? fullName, String? bio, String? jobTitle, String? avatarUrl, String? presenceStatus}) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.updateProfile(
        fullName: fullName,
        bio: bio,
        jobTitle: jobTitle,
        avatarUrl: avatarUrl,
        presenceStatus: presenceStatus,
      );
      await _loadProfile();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> regenerateE2eeKeys() async {
    state = state.copyWith(isLoading: true);
    try {
      // Supprimer des deux endroits pour forcer la régénération
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('e2ee_private_key');
      await _secureStorage.delete(key: 'e2ee_private_key');
      
      await _encryptionService.getLocalKeyPair();
      state = state.copyWith(isLoading: false, hasE2eeKeys: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Erreur E2EE: $e");
    }
  }

  /// Déconnexion complète : vider tokens, cache, clés E2EE, présence
  Future<void> logout() async {
    try {
      // 1. Déconnecter le WebSocket global de présence
      GlobalPresenceService.instance.disconnect();
      
      // 2. Vider le cache SQLite (messages, rooms, profils)
      if (!kIsWeb) {
        try {
          await LocalDatabase.instance.clearCache();
        } catch (_) {}
      }

      // 3. Vider le stockage sécurisé (clés E2EE)
      try {
        await _secureStorage.deleteAll();
      } catch (_) {}

      // 4. Vider SharedPreferences (tokens, user_id, etc.)
      await _authService.logout();
    } catch (_) {}
    
    // 5. Réinitialiser l'état du provider
    state = const ProfileState(isLoading: false);
  }
}
