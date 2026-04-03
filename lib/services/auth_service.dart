import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'push_notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthService {

  /// Connexion par Email et mot de passe
  Future<Map<String, dynamic>> loginWithEmail(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: ApiConfig.defaultHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveToken(data['access_token'], data['refresh_token'], data['user_id'], data['full_name']);
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Erreur de connexion');
    }
  }

  /// Inscription
  Future<Map<String, dynamic>> register(
    String fullName,
    String username,
    String email,
    String password,
    String phoneNumber,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register'),
      headers: ApiConfig.defaultHeaders,
      body: jsonEncode({
        'full_name': fullName,
        'username': username,
        'email': email,
        'password': password,
        'phone_number': phoneNumber,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveToken(data['access_token'], data['refresh_token'], data['user_id'], data['full_name']);
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Erreur lors de l\'inscription');
    }
  }

  /// Envoyer un OTP par SMS
  Future<void> sendOtp(String phoneNumber) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/otp/send'),
      headers: ApiConfig.defaultHeaders,
      body: jsonEncode({'phone_number': phoneNumber}),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l\'envoi du code OTP');
    }
  }

  /// Vérifier le code OTP
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otpCode) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/otp/verify'),
      headers: ApiConfig.defaultHeaders,
      body: jsonEncode({'phone_number': phoneNumber, 'otp_code': otpCode}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveToken(data['access_token'], data['refresh_token'], data['user_id'], data['full_name']);
      return data;
    } else {
      throw Exception('Code OTP invalide');
    }
  }

  /// Sauvegarder le token JWT en local
  Future<void> _saveToken(String token, String refreshToken, String userId, String fullName, {bool registerFcm = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('refresh_token', refreshToken);
    await prefs.setString('user_id', userId);
    await prefs.setString('full_name', fullName);

    // Enregistrer le token FCM s'il est disponible et demandé
    if (registerFcm) {
      try {
        final fcmToken = await PushNotificationService.getFcmToken();
        if (fcmToken != null) {
          await PushNotificationService.registerToken(fcmToken);
        }
      } catch (e) {
        debugPrint("Erreur enregistrement FCM: $e");
      }
    }
  }

  /// Vérifier si l'utilisateur est connecté
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('access_token');
  }

  /// Récupérer le token (Restauré)
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Récupérer le refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  /// Tenter un rafraîchissement du token
  Future<bool> refreshToken() async {
    final rt = await getRefreshToken();
    if (rt == null) return false;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode({'refresh_token': rt}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // On ne ré-enregistre pas FCM ici car refreshToken est souvent appelé PAR PushNotificationService
        await _saveToken(data['access_token'], data['refresh_token'], data['user_id'], data['full_name'], registerFcm: false);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Déconnexion
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Récupérer le profil complet de l'API avec gestion du rafraîchissement
  Future<Map<String, dynamic>> getCurrentProfile() async {
    final response = await authenticatedRequest(
      url: '${ApiConfig.baseUrl}/auth/me',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors du chargement du profil API');
    }
  }

  /// Mettre à jour le profil avec gestion du rafraîchissement
  Future<void> updateProfile({String? bio, String? jobTitle, String? avatarUrl, String? publicKey, String? presenceStatus}) async {
    final response = await authenticatedRequest(
      url: '${ApiConfig.baseUrl}/profiles/me',
      method: 'PUT',
      body: {
        'bio': bio,
        'job_title': jobTitle,
        'avatar_url': avatarUrl,
        'public_key': publicKey,
        'presence_status': presenceStatus,
      }..removeWhere((key, value) => value == null),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la mise à jour du profil');
    }
  }

  /// Helper pour les requêtes authentifiées avec auto-refresh
  Future<http.Response> authenticatedRequest({
    required String url,
    required String method,
    Map<String, dynamic>? body,
  }) async {
    String? token = await getToken();
    
    Future<http.Response> makeRequest() async {
      final headers = Map<String, String>.from(ApiConfig.defaultHeaders)
        ..addAll({'Authorization': 'Bearer $token'});
      final uri = Uri.parse(url);
      
      switch (method) {
        case 'GET': return await http.get(uri, headers: headers);
        case 'POST': return await http.post(uri, headers: headers, body: jsonEncode(body));
        case 'PUT': return await http.put(uri, headers: headers, body: jsonEncode(body));
        case 'DELETE': return await http.delete(uri, headers: headers);
        default: throw Exception('Méthode HTTP non supportée');
      }
    }

    var response = await makeRequest();

    // Si 401, on tente de rafraîchir le token
    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (refreshed) {
        token = await getToken(); // Récupérer le nouveau token
        response = await makeRequest(); // Réessayer
      }
    }

    return response;
  }
}
