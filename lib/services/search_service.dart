import 'dart:convert';
import 'auth_service.dart';
import 'api_config.dart';

class SearchService {
  static String get baseUrl => '${ApiConfig.baseUrl}/search';
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> globalSearch(String query) async {
    final response = await _authService.authenticatedRequest(
      url: '$baseUrl/global?q=$query',
      method: 'GET',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur lors de la recherche');
  }
}
