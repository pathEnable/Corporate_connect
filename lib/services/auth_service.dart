import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_notification_service.dart';
import 'global_presence_service.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AuthService {
  /// Stockage sécurisé (Keystore Android / Keychain iOS)
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Cache en mémoire pour un accès synchrone (utilisé par AuthenticatedImage)
  static String? _cachedToken;

  /// Récupérer le token en cache de manière synchrone
  static String? get cachedToken => _cachedToken;

  // ═══════════════════════════════════════════════════════════
  //  AUTHENTIFICATION
  // ═══════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════
  //  STOCKAGE SÉCURISÉ DES TOKENS
  // ═══════════════════════════════════════════════════════════

  /// Sauvegarder les tokens dans le Keystore sécurisé (pas SharedPreferences)
  Future<void> _saveToken(String token, String refreshToken, String userId, String fullName, {bool registerFcm = true}) async {
    // Tokens sensibles → Keystore chiffré
    await _secureStorage.write(key: 'access_token', value: token);
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    
    // Mettre à jour le cache en mémoire
    _cachedToken = token;

    // Données non sensibles → SharedPreferences (pour accès rapide par Riverpod/UI)
    final prefs = await SharedPreferences.getInstance();
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

  /// Vérifier si l'utilisateur est connecté ET si le token est encore valide
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null) return false;

    // Vérifier l'expiration locale du JWT (sans appel réseau)
    if (_isTokenExpired(token)) {
      // Tenter un refresh silencieux
      final refreshed = await refreshToken();
      return refreshed;
    }
    return true;
  }

  /// Décoder le JWT localement pour vérifier l'expiration
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      // Décoder le payload (base64url)
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final data = jsonDecode(decoded) as Map<String, dynamic>;

      final exp = data['exp'] as int?;
      if (exp == null) return true;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      // Ajouter une marge de 30 secondes pour éviter les races conditions
      return expiryDate.isBefore(DateTime.now().add(const Duration(seconds: 30)));
    } catch (_) {
      return true; // En cas de doute, considérer comme expiré
    }
  }

  /// Récupérer le token depuis le stockage sécurisé
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    _cachedToken = await _secureStorage.read(key: 'access_token');
    return _cachedToken;
  }

  /// Récupérer le refresh token depuis le stockage sécurisé
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: 'refresh_token');
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
        await _saveToken(data['access_token'], data['refresh_token'], data['user_id'], data['full_name'], registerFcm: false);
        return true;
      }
    } catch (e) {
      debugPrint("⚠️ Erreur refresh token: $e");
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════════
  //  DÉCONNEXION SÉCURISÉE
  // ═══════════════════════════════════════════════════════════

  /// Déconnexion complète et propre
  Future<void> logout() async {
    // 1. Fermer le WebSocket global AVANT de supprimer les tokens
    GlobalPresenceService.instance.disconnect();

    // 2. Révoquer le Refresh Token côté backend (empêche la réutilisation)
    try {
      final rt = await getRefreshToken();
      if (rt != null) {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
          headers: ApiConfig.defaultHeaders,
          body: jsonEncode({'refresh_token': rt}),
        );
      }
    } catch (e) {
      debugPrint("⚠️ Révocation backend échouée (non bloquant): $e");
    }

    // 3. Supprimer les tokens sécurisés et vider le cache
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    _cachedToken = null;

    // 4. Supprimer UNIQUEMENT les données de session (pas les préférences utilisateur !)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('full_name');
    // Les clés isDarkMode, fontScale, accentColor, ringtoneName restent intactes
  }

  // ═══════════════════════════════════════════════════════════
  //  PROFIL & REQUÊTES AUTHENTIFIÉES
  // ═══════════════════════════════════════════════════════════

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
  Future<void> updateProfile({String? fullName, String? bio, String? jobTitle, String? avatarUrl, String? publicKey, String? presenceStatus}) async {
    final response = await authenticatedRequest(
      url: '${ApiConfig.baseUrl}/profiles/me',
      method: 'PUT',
      body: {
        'full_name': fullName,
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
        token = await getToken();
        response = await makeRequest();
      }
    }

    return response;
  }
}
