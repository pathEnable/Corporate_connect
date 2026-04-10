import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'api_config.dart';

// Fonctions top-level pour pouvoir les passer à compute() (Isolates)
List<Map<String, dynamic>> _parseRoomList(String responseBody) {
  return List<Map<String, dynamic>>.from(jsonDecode(responseBody));
}

List<Map<String, dynamic>> _parseMessageList(String responseBody) {
  return List<Map<String, dynamic>>.from(jsonDecode(responseBody));
}

Map<String, dynamic> _parseMap(String responseBody) {
  return Map<String, dynamic>.from(jsonDecode(responseBody));
}

class RoomService {
  static String get baseUrl => '${ApiConfig.baseUrl}/rooms';

  final AuthService _authService = AuthService();



  /// Lister les salons de l'utilisateur
  Future<List<Map<String, dynamic>>> getRooms() async {
    final response = await _authService.authenticatedRequest(
      url: baseUrl,
      method: 'GET',
    );

    if (response.statusCode == 200) {
      // Parsing dans un Isolate pour ne pas bloquer le thread UI
      return await compute(_parseRoomList, response.body);
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

    if (response.statusCode == 200 || response.statusCode == 201) {
      return await compute(_parseMap, response.body);
    }
    throw Exception('Erreur lors de la création de la conversation (code: ${response.statusCode})');
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
      // Parsing dans un Isolate (les historiques peuvent être volumineux)
      return await compute(_parseMessageList, response.body);
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
      return await compute(_parseRoomList, response.body);
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

  /// Retirer un membre (Kicker ou Quitter)
  Future<void> removeMember(String roomId, String userId) async {
    await _authService.authenticatedRequest(
      url: '$baseUrl/$roomId/members/$userId',
      method: 'DELETE',
    );
  }

  /// Ajouter un membre
  Future<void> addMember(String roomId, String userId) async {
    await _authService.authenticatedRequest(
      url: '$baseUrl/$roomId/members?target_user_id=$userId',
      method: 'POST',
    );
  }

  /// Quitter un salon
  Future<void> leaveRoom(String roomId, String currentUserId) async {
    await removeMember(roomId, currentUserId);
  }

  /// Mettre à jour les informations du salon (Nom, etc.)
  Future<void> updateRoom(String roomId, {String? name, String? description}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;

    final response = await _authService.authenticatedRequest(
      url: '$baseUrl/$roomId',
      method: 'PUT',
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la mise à jour du salon');
    }
  }

  /// Mettre à jour l'avatar du salon
  Future<void> updateRoomAvatar(String roomId, String avatarUrl) async {
    final response = await _authService.authenticatedRequest(
      url: '$baseUrl/$roomId',
      method: 'PUT',
      body: {'avatar_url': avatarUrl},
    );

    if (response.statusCode != 200) {
      throw Exception("Erreur lors de la mise à jour de l'avatar : ${response.statusCode} - ${response.body}");
    }
  }
}
