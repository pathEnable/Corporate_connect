import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Vérifie si une mise à jour est disponible
  Future<Map<String, dynamic>?> checkForUpdate() async {
    final String url = '${ApiConfig.baseUrl}/version';
    try {
      debugPrint('Vérification de mise à jour sur: $url');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Délai d\'attente dépassé (10s) pour: $url');
          throw http.ClientException('Timeout');
        },
      );

      debugPrint('Réponse mise à jour: Status ${response.statusCode}');

      if (response.statusCode == 200) {
        final serverData = jsonDecode(response.body);
        final int serverVersion = serverData['version_code'];
        
        final packageInfo = await PackageInfo.fromPlatform();
        final int currentVersion = int.tryParse(packageInfo.buildNumber) ?? 1;

        debugPrint('Comparaison versions: App=$currentVersion vs Server=$serverVersion');

        if (serverVersion > currentVersion) {
          debugPrint('Nouveauté détectée !');
          return serverData;
        } else {
          debugPrint('L\'application est à jour ou plus récente.');
        }
      } else {
        debugPrint('Erreur serveur lors du check version: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erreur lors de la vérification de mise à jour sur $url: $e');
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
