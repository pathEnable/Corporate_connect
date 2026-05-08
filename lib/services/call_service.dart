import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_config.dart';
import '../models/call_log.dart';

import 'auth_service.dart';

class CallService {
  Future<String?> _getToken() async {
    return await AuthService().getToken();
  }

  Future<void> logCall({
    String? receiverId,
    String? roomId,
    required DateTime startTime,
    DateTime? endTime,
    int duration = 0,
    String status = "completed",
    String callType = "audio",
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception("Non authentifié");

    try {
      final body = <String, dynamic>{
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime?.toUtc().toIso8601String(),
        'duration': duration,
        'status': status,
        'call_type': callType,
      };
      if (receiverId != null) body['receiver_id'] = receiverId;
      if (roomId != null) body['room_id'] = roomId;

      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/calls/log'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

    } catch (e) {
      debugPrint("Erreur logCall: $e");
    }
  }

  Future<List<CallLogModel>> getCallHistory() async {
    final token = await _getToken();
    if (token == null) throw Exception("Non authentifié");

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/calls/history'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CallLogModel.fromJson(json)).toList();
      } else {
        debugPrint("Erreur de récupération de l'historique: ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint("Erreur getCallHistory: $e");
      return [];
    }
  }

  Future<bool> clearCallHistory() async {
    try {
      final response = await AuthService().authenticatedRequest(
        url: '${ApiConfig.baseUrl}/calls/history',
        method: 'DELETE',
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint("Erreur clearCallHistory: $e");
      return false;
    }
  }
}

final callService = CallService();
