import 'dart:io';
import 'package:dio/dio.dart';
import 'auth_service.dart';

class MediaService {
  static const String baseUrl = 'https://hoselike-detrital-nola.ngrok-free.dev/media';
  final AuthService _authService = AuthService();
  final Dio _dio = Dio();

  Future<Map<String, dynamic>> uploadFile(File file) async {
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
    });

    Future<Response> makeRequest() async {
      final token = await _authService.getToken();
      return await _dio.post(
        '$baseUrl/upload',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
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
    return '$baseUrl${relativeUrl.replaceFirst("/media", "")}?token=$token';
  }
}
