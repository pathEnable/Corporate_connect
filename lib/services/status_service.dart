import 'dart:convert';
import '../models/status_model.dart';
import 'auth_service.dart';
import 'api_config.dart';

class StatusService {
  static const String baseUrl = '${ApiConfig.baseUrl}/status';
  final AuthService _authService = AuthService();

  Future<List<StatusModel>> getStatuses() async {
    final response = await _authService.authenticatedRequest(
      url: baseUrl,
      method: 'GET',
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => StatusModel.fromJson(json)).toList();
    }
    throw Exception('Erreur lors du chargement des statuts');
  }

  Future<StatusModel> createStatus({String? mediaUrl, String? text}) async {
    final response = await _authService.authenticatedRequest(
      url: baseUrl,
      method: 'POST',
      body: {
        'media_url': mediaUrl,
        'text': text,
      },
    );

    if (response.statusCode == 200) {
      return StatusModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Erreur lors de la création du statut');
  }
}
