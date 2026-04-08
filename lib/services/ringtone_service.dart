import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class RingtoneService {
  static final RingtoneService instance = RingtoneService._internal();
  RingtoneService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playRingtone() async {
    const String assetPath = 'audio/ringtone_incoming.wav';
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Erreur RingtoneService ($assetPath): $e');
      // Fallback
      try {
        await _player.play(AssetSource('audio/ringtone.wav'));
      } catch (_) {}
    }
  }

  Future<void> playWaitingTone() async {
    const String assetPath = 'audio/ringtone_waiting.wav';
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Erreur RingtoneService Waiting ($assetPath): $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Erreur stop RingtoneService: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
