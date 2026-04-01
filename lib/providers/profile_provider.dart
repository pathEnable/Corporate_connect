import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/profile_state.dart';
import '../services/auth_service.dart';
import '../services/media_service.dart';
import '../services/encryption_service.dart';

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
    _loadProfile();
    return const ProfileState(isLoading: true);
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

  Future<void> updateProfile({String? bio, String? jobTitle, String? avatarUrl}) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.updateProfile(
        bio: bio,
        jobTitle: jobTitle,
        avatarUrl: avatarUrl,
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

  Future<void> logout() async {
    await _authService.logout();
  }
}
