import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_notification_service.dart';
import 'global_presence_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'api_config.dart';
import '../main.dart';
import '../screens/login_screen.dart';

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
      await _saveToken(data['access_token'], null, data['user_id'], data['full_name']);
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
      await _saveToken(data['access_token'], null, data['user_id'], data['full_name']);
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
      await _saveToken(data['access_token'], null, data['user_id'], data['full_name']);
      return data;
    } else {
      throw Exception('Code OTP invalide');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  STOCKAGE SÉCURISÉ DES TOKENS
  // ═══════════════════════════════════════════════════════════

  /// Sauvegarder le token dans le Keystore sécurisé
  Future<void> _saveToken(String token, String? refreshToken, String userId, String fullName, {bool registerFcm = true}) async {
    // Token sensible → Keystore chiffré
    await _secureStorage.write(key: 'access_token', value: token);
    
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

  /// Vérifier si l'utilisateur est connecté
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  /// Récupérer le token depuis le stockage sécurisé
  Future<String?> getToken() async {
    String? token = _cachedToken;
    token ??= await _secureStorage.read(key: 'access_token');
    
    _cachedToken = token;
    return token;
  }

  // ═══════════════════════════════════════════════════════════
  //  DÉCONNEXION SÉCURISÉE
  // ═══════════════════════════════════════════════════════════

  /// Déconnexion complète et propre
  Future<void> logout() async {
    // 1. Fermer le WebSocket global AVANT de supprimer les tokens
    GlobalPresenceService.instance.disconnect();

    // 2. Supprimer les tokens sécurisés et vider le cache
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token'); // On nettoie l'ancien résidu
    _cachedToken = null;

    // 3. Supprimer UNIQUEMENT les données de session (pas les préférences utilisateur !)
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

  /// Helper pour les requêtes authentifiées avec éjection sur 401
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

    // Si 401, le token a été révoqué par le serveur (token_version incrémenté)
    if (response.statusCode == 401) {
      debugPrint("⚠️ 401 Unauthorized détecté : Éjection forcée de l'utilisateur.");
      await logout();
      
      // On importe main.dart dynamiquement pour éviter les dépendances circulaires
      // Mais on ne peut pas importer ici, donc on doit notifier l'application autrement.
      // Dans Flutter, la façon propre est d'utiliser le navigateur global.
      forceGlobalLogout();
    }

    return response;
  }

  void forceGlobalLogout() {
    // Éjection immédiate vers l'écran de connexion via la clé globale
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
