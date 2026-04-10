import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import 'package:flutter/foundation.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Vérifie si une mise à jour est disponible
  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      // Interroge directement l'API publique de GitHub pour la dernière "Release"
      final response = await http.get(Uri.parse('https://api.github.com/repos/pathEnable/Corporate_connect/releases/latest'));
      
      if (response.statusCode == 200) {
        final githubData = jsonDecode(response.body);
        final String tagName = githubData['tag_name'] ?? ''; // ex: "v2" ou "1.0.0+2"
        
        final packageInfo = await PackageInfo.fromPlatform();
        final int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

        // Extraction du numéro de build (version_code) à partir du tag GitHub.
        // Gère les formats comme "v2", "Release-3", ou "1.0.0+2" (qui est standard).
        int? serverBuildNumber;
        final standardBuildMatch = RegExp(r'\+(\d+)$').firstMatch(tagName);
        if (standardBuildMatch != null) {
          serverBuildNumber = int.tryParse(standardBuildMatch.group(1)!);
        } else {
          final fallbackMatch = RegExp(r'\d+').firstMatch(tagName.split('.').last);
          if (fallbackMatch != null) {
            serverBuildNumber = int.tryParse(fallbackMatch.group(0)!);
          }
        }

        if (serverBuildNumber != null && serverBuildNumber > currentBuildNumber) {
          // Cherche un fichier .apk attaché à la release
          final List assets = githubData['assets'] ?? [];
          String? apkUrl;
          for (var asset in assets) {
            final String name = asset['name'].toString().toLowerCase();
            if (name.endsWith('.apk')) {
              apkUrl = asset['browser_download_url'];
              break;
            }
          }

          if (apkUrl != null) {
            return {
              'version_code': serverBuildNumber,
              'version_name': githubData['name'] ?? tagName, // Titre de la release
              'apk_url': apkUrl,
            };
          }
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
