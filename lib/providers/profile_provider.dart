import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  ProfileState build() {
    _loadProfile();
    return const ProfileState(isLoading: true);
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getCurrentProfile();
      final prefs = await SharedPreferences.getInstance();
      final hasKeys = prefs.containsKey('e2ee_private_key');
      
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

  Future<void> updateAvatar(File file) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _mediaService.uploadFile(file);
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
      // Pour forcer la régénération, on devrait idéalement vider la clé existante
      // Mais EncryptionService.getLocalKeyPair() génère s'il n'y en a pas.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('e2ee_private_key');
      
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
