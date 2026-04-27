import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';
import 'api_config.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class MediaService {
  static String get baseUrl => '${ApiConfig.baseUrl}/media';
  final AuthService _authService = AuthService();
  final Dio _dio = Dio();

  String _getMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'gif':  return 'image/gif';
      case 'webp': return 'image/webp';
      case 'pdf':  return 'application/pdf';
      case 'doc':
      case 'docx': return 'application/msword';
      case 'txt':  return 'text/plain';
      default:     return 'application/octet-stream';
    }
  }

  /// Upload avec callback de progression — compatible Web et Mobile
  Future<Map<String, dynamic>> uploadFile(
    Uint8List bytes, {
    required String filename,
    void Function(int sent, int total)? onProgress,
  }) async {
    final mimeType = _getMimeType(filename);
    
    FormData formData = FormData.fromMap({
      "file": MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ),
    });

    Future<Response> makeRequest() async {
      final token = await _authService.getToken();
      return await _dio.post(
        '$baseUrl/upload',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
        onSendProgress: onProgress,
      );
    }

    try {
      final response = await makeRequest();
      if (response.statusCode == 200) return response.data;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        debugPrint("⚠️ 401 Unauthorized lors de l'upload : Éjection forcée");
        await _authService.logout();
        _authService.forceGlobalLogout();
      }
      throw Exception('Erreur lors du téléchargement du fichier: $e');
    }
    throw Exception('Erreur lors du téléchargement du fichier');
  }

  Future<String> getDownloadUrl(String relativeUrl) async {
    return ApiConfig.getMediaUrl(relativeUrl);
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1048576).toStringAsFixed(1)}MB';
  }

  /// Télécharge un média et l'enregistre localement
  Future<String?> saveToGallery(
    String url, 
    String fileName, 
    String type, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    if (kIsWeb) return null;

    try {
      // 1. Déterminer le dossier de destination (Stockage interne de l'app pour fiabilité)
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String subFolder = type == 'image' ? 'images' : 'documents';
      final Directory targetDir = Directory('${appDocDir.path}/CorporateConnect/$subFolder');

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Nettoyer le nom du fichier pour éviter les caractères spéciaux
      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final String savePath = '${targetDir.path}/$safeFileName';
      final File file = File(savePath);

      // Si le fichier existe déjà, on ne télécharge pas
      if (await file.exists()) {
        debugPrint("📄 Fichier déjà présent localement: $savePath");
        return savePath;
      }

      // 2. Téléchargement via Dio
      final isCloudinary = url.contains('cloudinary.com');
      debugPrint("📥 Téléchargement: URL=$url | isCloudinary=$isCloudinary");
      
      Future<void> makeDownload(String downloadUrl, bool useAuth) async {
        final options = useAuth 
            ? Options(headers: {'Authorization': 'Bearer ${await _authService.getToken()}'})
            : Options();

        await _dio.download(
          downloadUrl,
          savePath,
          options: options,
          onReceiveProgress: (received, total) {
            if (onReceiveProgress != null) onReceiveProgress(received, total);
          },
        );
      }

      try {
        // Tentative directe
        await makeDownload(url, !isCloudinary);
      } catch (e) {
        // Fallback pour Cloudinary (401/404)
        if (isCloudinary && e is DioException) {
          debugPrint("🔄 Erreur Cloudinary (${e.response?.statusCode}), tentative via proxy backend...");
          
          final proxyUrl = '${ApiConfig.baseUrl}/media/proxy?url=${Uri.encodeComponent(url)}';
          debugPrint("📡 Proxy URL: $proxyUrl");
          
          try {
            await makeDownload(proxyUrl, true);
            debugPrint("✅ Téléchargement réussi via proxy backend");
          } catch (proxyError) {
            debugPrint("❌ Échec du proxy backend: $proxyError");
            // Si le proxy échoue, on tente une dernière fois sans auth (au cas où)
            try {
              await makeDownload(url, false);
            } catch (_) {
              rethrow;
            }
          }
        } else {
          rethrow;
        }
      }

      // 3. Optionnel : Si c'est une image, on peut AUSSI l'ajouter à la galerie publique
      // Note: On importe pas Gal ici pour éviter les dépendances circulaires ou inutiles si non utilisé
      /*
      if (type == 'image' && Platform.isAndroid) {
        try {
          // Utilisation de gal si disponible
          // await Gal.putImage(savePath);
        } catch (e) {
          debugPrint("⚠️ Impossible d'ajouter à la galerie publique: $e");
        }
      }
      */

      return savePath;
    } catch (e) {
      debugPrint("❌ Erreur lors du téléchargement/sauvegarde: $e");
      return null;
    }
  }
}
