import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import 'api_config.dart';
import 'package:flutter/foundation.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Vérifie si une mise à jour est disponible
  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final response =
          await http.get(Uri.parse('${ApiConfig.baseUrl}/version'));
      if (response.statusCode == 200) {
        final serverData = jsonDecode(response.body);
        final int serverVersion = serverData['version_code'];

        final packageInfo = await PackageInfo.fromPlatform();
        final int currentVersion = int.parse(packageInfo.buildNumber);

        if (serverVersion > currentVersion) {
          return serverData;
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la vérification de mise à jour: $e');
    }
    return null;
  }

  /// Démarre le processus de mise à jour OTA
  Stream<OtaEvent> startUpdate(String url) {
    try {
      return OtaUpdate().execute(
        url,
        destinationFilename: 'app-release.apk',
      );
    } catch (e) {
      debugPrint('Échec du lancement de la mise à jour OTA: $e');
      rethrow;
    }
  }
}
