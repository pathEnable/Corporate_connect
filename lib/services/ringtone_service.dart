import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service de gestion des sons d'appel avec mutex pour éviter les conflits.
/// 
/// Sons gérés :
///   - Sonnerie d'appel entrant (côté destinataire)
///   - Tonalité d'attente (côté émetteur, "tut... tut...")
///   - Bip de fin d'appel
class RingtoneService {
  static final RingtoneService _instance = RingtoneService._internal();
  factory RingtoneService() => _instance;
  RingtoneService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  String? _currentSound;

  bool get isPlaying => _isPlaying;

  /// Joue la sonnerie d'appel entrant (côté destinataire).
  Future<void> playRingtone() async {
    await _playSound('audio/ringtone_incoming.wav', loop: true, tag: 'ringtone');
  }

  /// Joue la tonalité d'attente (côté émetteur, pendant que ça sonne).
  Future<void> playWaitingTone() async {
    await _playSound('audio/ringtone_waiting.wav', loop: true, tag: 'waiting');
  }

  /// Joue le bip court de fin d'appel.
  Future<void> playEndCallTone() async {
    // Utilise la ringtone courte comme bip de fin (pas de fichier dédié)
    await _playSound('audio/ringtone.wav', loop: false, tag: 'end_call');
  }

  /// Arrête tout son en cours.
  Future<void> stop() async {
    if (_isPlaying) {
      try {
        await _player.stop();
      } catch (_) {}
      _isPlaying = false;
      _currentSound = null;
      debugPrint('🔇 Son arrêté');
    }
  }

  /// Joue un son avec mutex — arrête tout son précédent avant de jouer.
  Future<void> _playSound(String asset, {bool loop = false, required String tag}) async {
    // Mutex : on arrête le son en cours avant d'en jouer un autre
    if (_isPlaying) {
      if (_currentSound == tag) {
        debugPrint('🔊 Son "$tag" déjà en cours, ignoré');
        return; // Même son déjà en cours
      }
      await stop();
    }

    try {
      if (loop) {
        await _player.setReleaseMode(ReleaseMode.loop);
      } else {
        await _player.setReleaseMode(ReleaseMode.release);
      }
      
      await _player.play(AssetSource(asset));
      _isPlaying = true;
      _currentSound = tag;
      debugPrint('🔊 Son "$tag" démarré');
    } catch (e) {
      debugPrint('⚠️ Erreur lecture son "$tag": $e');
      _isPlaying = false;
      _currentSound = null;
    }
  }

  /// Libère les ressources.
  void dispose() {
    _player.dispose();
  }
}
