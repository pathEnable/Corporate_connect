import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

/// Service centralisé pour la signalisation d'appel via API REST.
/// Gère tout le cycle de vie : initier, répondre, refuser, terminer, annuler.
class CallSignalingService {
  final AuthService _authService = AuthService();

  /// Initie un appel vers les membres de la room.
  /// Retourne {call_id, agora_token, app_id, channel_name}.
  Future<Map<String, dynamic>?> initiateCall({
    required String roomId,
    bool isVideo = false,
  }) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/calls/initiate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'room_id': roomId,
          'is_video': isVideo,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('📞 Appel initié: call_id=${data['call_id']}');
        return data;
      } else {
        debugPrint('❌ Erreur initiation appel: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Exception initiation appel: $e');
      return null;
    }
  }

  /// Le destinataire accepte l'appel.
  /// Retourne {agora_token, app_id, channel_name, call_type}.
  Future<Map<String, dynamic>?> answerCall({
    required String callId,
    required String channelName,
  }) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/calls/$callId/answer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'channel_name': channelName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('📞 Appel accepté: channel=${data['channel_name']}');
        return data;
      } else {
        debugPrint('❌ Erreur réponse appel: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Exception réponse appel: $e');
      return null;
    }
  }

  /// Le destinataire refuse l'appel.
  Future<bool> rejectCall({required String callId}) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/calls/$callId/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      debugPrint('📞 Appel refusé: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Exception refus appel: $e');
      return false;
    }
  }

  /// Un participant raccroche pendant un appel actif.
  Future<bool> endCall({required String callId}) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/calls/$callId/end'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      debugPrint('📞 Appel terminé: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Exception fin appel: $e');
      return false;
    }
  }

  /// L'appelant annule avant que le destinataire décroche.
  Future<bool> cancelCall({required String callId}) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/calls/$callId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      debugPrint('📞 Appel annulé: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Exception annulation appel: $e');
      return false;
    }
  }
}
