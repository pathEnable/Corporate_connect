import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service centralisé pour la gestion de l'authentification biométrique.
/// Gère la disponibilité matérielle, la préférence utilisateur et
/// l'authentification effective via Face ID / Empreinte digitale.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  static const _prefKey = 'biometric_lock_enabled';

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

  /// Vérifie si l'utilisateur a activé le verrouillage biométrique.
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Active ou désactive le verrouillage biométrique.
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  /// Lance le challenge biométrique. Renvoie `true` si l'utilisateur s'est
  /// authentifié avec succès.
  Future<bool> authenticate({String reason = 'Déverrouillez Corporate Connect'}) async {
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
