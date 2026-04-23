import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';
import 'api_config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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
        final refreshed = await _authService.refreshToken();
        if (refreshed) {
          final retryResponse = await makeRequest();
          if (retryResponse.statusCode == 200) return retryResponse.data;
        }
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

  /// Télécharge un média et l'enregistre dans la galerie publique
  Future<String?> saveToGallery(
    String url, 
    String fileName, 
    String type, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    if (kIsWeb) return null;

    try {
      // 1. Demander les permissions
      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.isDenied) {
           await Permission.manageExternalStorage.request();
        }
        // Pour Android 13+
        await [Permission.photos, Permission.videos, Permission.audio].request();
      } else if (Platform.isIOS) {
        await Permission.photos.request();
      }

      // 2. Déterminer le dossier de destination public
      Directory? baseDir;
      if (Platform.isAndroid) {
        // Dossier standard pour Android (Pictures pour images, Downloads pour le reste)
        if (type == 'image') {
          baseDir = Directory('/storage/emulated/0/Pictures/CorporateConnect');
        } else {
          baseDir = Directory('/storage/emulated/0/Download/CorporateConnect');
        }
      } else {
        baseDir = await getApplicationDocumentsDirectory(); // iOS est plus restrictif
      }

      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      final String savePath = '${baseDir.path}/$fileName';
      final File file = File(savePath);

      // Si le fichier existe déjà, on ne télécharge pas
      if (await file.exists()) return savePath;

      // 3. Téléchargement via Dio
      final isCloudinary = url.contains('cloudinary.com');
      final options = isCloudinary 
          ? Options() 
          : Options(headers: {'Authorization': 'Bearer ${await _authService.getToken()}'});

      await _dio.download(
        url,
        savePath,
        options: options,
        onReceiveProgress: onReceiveProgress,
      );

      return savePath;
    } catch (e) {
      debugPrint("❌ Erreur lors de la sauvegarde en galerie: $e");
      return null;
    }
  }
}
