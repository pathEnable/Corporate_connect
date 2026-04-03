import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'auth_service.dart';
import 'api_config.dart';
import '../main.dart';
import '../screens/chat_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final AuthService _authService = AuthService();
  static final Dio _dio = Dio();

  // Stocke les données de routage si l'app a été démarrée par une notification
  static Map<String, dynamic>? initialRouteData;

  static Future<String?> getFcmToken() async {
    return await _fcm.getToken();
  }

  static Future<void> initialize() async {
    // 1. Initialiser Firebase
    await Firebase.initializeApp();
    
    // Configurer le handler d'arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Demander la permission (iOS/Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Configuration des notifications locales pour l'avant-plan
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            handleNotificationClick(data);
          } catch (_) {}
        }
      },
    );

    // 4. Écouter les messages en avant-plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // 5. Gérer le clic sur une notification en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleNotificationClick(message.data);
    });

    // 5.5 Gérer l'ouverture depuis une app fermée
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      initialRouteData = initialMessage.data;
    }

    // 6. Récupérer et enregistrer le token si l'utilisateur est déjà connecté
    final token = await _fcm.getToken();
    if (token != null) {
      await registerToken(token);
    }
  }

  static Future<void> registerToken(String fcmToken) async {
    final authToken = await _authService.getToken();
    if (authToken == null) return;

    Future<Response> makeRequest(String token) async {
      return await _dio.post(
        '${ApiConfig.baseUrl}/notifications/register-token',
        data: {'fcm_token': fcmToken},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
    }

    try {
      await makeRequest(authToken);
      debugPrint("Token FCM enregistré sur le backend.");
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        debugPrint("Token expiré lors de l'enregistrement FCM. Tentative de refresh...");
        final refreshed = await _authService.refreshToken();
        if (refreshed) {
          final newToken = await _authService.getToken();
          if (newToken != null) {
            try {
              await makeRequest(newToken);
              debugPrint("Token FCM enregistré après refresh.");
              return;
            } catch (_) {}
          }
        }
      }
      debugPrint("Erreur initialisation notifications: $e");
    }
  }

  static void _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _localNotifications.show(
      0,
      message.notification?.title ?? "Nouveau message",
      message.notification?.body ?? "",
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  static void handleNotificationClick(Map<String, dynamic> data) {
    if (data['type'] == 'new_message' && data['room_id'] != null) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              roomId: data['room_id'] as String,
              roomName: data['room_name'] as String? ?? 'Discussion',
              isGroup: data['is_group'] == 'true',
            ),
          ),
        );
      } else {
        // Si le contexte n'est pas prêt, on sauvegarde l'intention pour HomeScreen
        initialRouteData = data;
      }
    }
  }
}
