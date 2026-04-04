import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class RingtoneService {
  static final RingtoneService instance = RingtoneService._internal();
  RingtoneService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playRingtone() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      // Utilisation du son local généré ou téléchargé
      await _player.play(AssetSource('audio/ringtone.wav'));
    } catch (e) {
      debugPrint('Erreur RingtoneService: $e');
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
