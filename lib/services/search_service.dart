import 'dart:convert';
import 'auth_service.dart';

class SearchService {
  static const String baseUrl = 'https://hoselike-detrital-nola.ngrok-free.dev/search';
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
