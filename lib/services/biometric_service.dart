import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service centralisé pour la gestion de l'authentification biométrique.
/// Gère la disponibilité matérielle, la préférence utilisateur et
/// l'authentification effective via Face ID / Empreinte digitale.
///
/// La préférence est stockée dans FlutterSecureStorage (chiffré par le
/// Keystore/Keychain de l'OS) pour empêcher un attaquant avec accès root
/// de désactiver le verrou biométrique en modifiant SharedPreferences.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const _secureKey = 'biometric_lock_enabled';
  // Ancienne clé SharedPreferences (pour migration one-shot)
  static const _legacyPrefKey = 'biometric_lock_enabled';
  bool _migrationDone = false;

  /// Vérifie si l'appareil supporte la biométrie (capteur physique présent).
  Future<bool> isDeviceSupported() async {
    try {
      final canAuth = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canAuth || isSupported;
    } catch (e) {
      debugPrint('BiometricService.isDeviceSupported error: $e');
      return false;
    }
  }

  /// Renvoie la liste des types biométriques disponibles.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('BiometricService.getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// Migration one-shot depuis SharedPreferences vers SecureStorage.
  Future<void> _migrateIfNeeded() async {
    if (_migrationDone) return;
    _migrationDone = true;

    try {
      final existing = await _secureStorage.read(key: _secureKey);
      if (existing != null) return; // Déjà migré

      final prefs = await SharedPreferences.getInstance();
      final legacyValue = prefs.getBool(_legacyPrefKey);
      if (legacyValue != null) {
        await _secureStorage.write(key: _secureKey, value: legacyValue.toString());
        await prefs.remove(_legacyPrefKey);
        debugPrint('🔐 Préférence biométrique migrée vers SecureStorage.');
      }
    } catch (e) {
      debugPrint('BiometricService._migrateIfNeeded error: $e');
    }
  }

  /// Vérifie si l'utilisateur a activé le verrouillage biométrique.
  Future<bool> isEnabled() async {
    await _migrateIfNeeded();
    final value = await _secureStorage.read(key: _secureKey);
    return value == 'true';
  }

  /// Active ou désactive le verrouillage biométrique.
  Future<void> setEnabled(bool value) async {
    await _secureStorage.write(key: _secureKey, value: value.toString());
  }

  /// Lance le challenge biométrique. Renvoie `true` si l'utilisateur s'est
  /// authentifié avec succès.
  Future<bool> authenticate(
      {String reason = 'Déverrouillez Corporate Connect'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Autoriser le PIN/Pattern en fallback
        ),
      );
    } catch (e) {
      debugPrint('BiometricService.authenticate error: $e');
      return false;
    }
  }
}
