import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';
import 'api_config.dart';

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
    final token = await _authService.getToken();
    // Nettoyer l'URL relative pour éviter les doubles slashes ou les préfixes redondants
    String path = relativeUrl.replaceFirst("/media", "");
    if (!path.startsWith('/')) path = '/$path';
    
    // S'assurer que le baseUrl ne se termine pas par un slash pour éviter les conflits
    String base = baseUrl;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    
    return '$base$path?token=$token';
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1048576).toStringAsFixed(1)}MB';
  }
}
