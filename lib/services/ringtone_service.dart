import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class RingtoneService {
  static final RingtoneService instance = RingtoneService._internal();
  RingtoneService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playRingtone({bool isVideo = false}) async {
    final String assetPath = isVideo ? 'audio/ringtone_video.wav' : 'audio/ringtone_audio.wav';
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Erreur RingtoneService ($assetPath): $e');
      // Fallback de sécurité
      try {
        await _player.play(AssetSource('audio/ringtone.wav'));
      } catch (_) {}
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
