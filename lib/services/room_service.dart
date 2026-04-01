import 'dart:convert';
import 'auth_service.dart';
import 'api_config.dart';

class RoomService {
  static const String baseUrl = '${ApiConfig.baseUrl}/rooms';

  final AuthService _authService = AuthService();



  /// Lister les salons de l'utilisateur
  Future<List<Map<String, dynamic>>> getRooms() async {
    final response = await _authService.authenticatedRequest(
      url: baseUrl,
      method: 'GET',
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Erreur lors du chargement des conversations');
  }

  /// Créer un salon privé (1:1)
  Future<Map<String, dynamic>> createPrivateRoom(String memberId) async {
    final response = await _authService.authenticatedRequest(
      url: baseUrl,
      method: 'POST',
      body: {
        'is_group': false,
        'member_ids': [memberId],
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur lors de la création de la conversation');
  }

  /// Créer un groupe
  Future<Map<String, dynamic>> createGroup(String name, List<String> memberIds) async {
    final response = await _authService.authenticatedRequest(
      url: baseUrl,
      method: 'POST',
      body: {
        'name': name,
        'is_group': true,
        'member_ids': memberIds,
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur lors de la création du groupe');
  }

  /// Récupérer l'historique des messages
  Future<List<Map<String, dynamic>>> getMessages(String roomId, {int limit = 50}) async {
    final response = await _authService.authenticatedRequest(
      url: '$baseUrl/$roomId/messages?limit=$limit',
      method: 'GET',
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Erreur lors du chargement des messages');
  }

  /// Récupérer les membres d'un salon (pour l'E2EE)
  Future<List<Map<String, dynamic>>> getRoomMembers(String roomId) async {
    final response = await _authService.authenticatedRequest(
      url: '$baseUrl/$roomId/members',
      method: 'GET',
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Erreur lors du chargement des membres du salon');
  }

  /// Promouvoir un membre
  Future<void> promoteMember(String roomId, String userId) async {
    await _authService.authenticatedRequest(
      url: '$baseUrl/$roomId/members/promote?target_user_id=$userId',
      method: 'POST',
    );
  }

  /// Rétrograder un membre
  Future<void> demoteMember(String roomId, String userId) async {
    await _authService.authenticatedRequest(
      url: '$baseUrl/$roomId/members/demote?target_user_id=$userId',
      method: 'POST',
    );
  }

  /// Retirer un membre
  Future<void> removeMember(String roomId, String userId) async {
    await _authService.authenticatedRequest(
      url: '$baseUrl/$roomId/members/$userId',
      method: 'DELETE',
    );
  }
}
