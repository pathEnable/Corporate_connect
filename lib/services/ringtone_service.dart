import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class RingtoneService {
  static final RingtoneService instance = RingtoneService._internal();
  RingtoneService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playRingtone() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      // URL générique d'une sonnerie de téléphone
      await _player.play(UrlSource('https://www.soundjay.com/phone/telephone-ring-01a.mp3'));
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
