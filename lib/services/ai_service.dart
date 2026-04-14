import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

class AIService {
  static String get baseUrl => '${ApiConfig.baseUrl}/ai';
  final AuthService _authService = AuthService();

  /// Récupérer le résumé de la discussion
  Future<Map<String, dynamic>> getSummary(String roomId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/rooms/$roomId/summarize'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur lors de la génération du résumé : ${response.body}');
      }
    } catch (e) {
      return {
        'summary': 'Impossible de générer le résumé pour le moment.',
        'error': e.toString()
      };
    }
  }

  /// Récupérer les tâches suggérées (Action Items)
  Future<List<dynamic>> getActionItems(String roomId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/rooms/$roomId/extract-tasks'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['tasks'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
