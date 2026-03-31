import 'dart:convert';
import 'auth_service.dart';

class AdminService {
  static const String baseUrl = 'https://hoselike-detrital-nola.ngrok-free.dev/admin';
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> getStats() async {
    final response = await _authService.authenticatedRequest(
      url: '$baseUrl/stats',
      method: 'GET',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur lors du chargement des stats');
  }

  Future<Map<String, dynamic>> getUsers({int skip = 0, int limit = 20}) async {
    final response = await _authService.authenticatedRequest(
      url: '$baseUrl/users?skip=$skip&limit=$limit',
      method: 'GET',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur lors du chargement des utilisateurs');
  }

  Future<void> toggleUserActive(String userId) async {
    await _authService.authenticatedRequest(
      url: '$baseUrl/users/$userId/toggle-active',
      method: 'POST',
    );
  }
}
