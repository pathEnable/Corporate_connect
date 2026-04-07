import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'auth_service.dart';
import 'api_config.dart';
import '../main.dart';
import '../screens/chat_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
  
  // Si c'est un appel, on déclenche CallKit immédiatement en arrière-plan
  if (message.data['type'] == 'call_offer') {
    await _showCallKitIncoming(message.data);
  }
}

Future<void> _showCallKitIncoming(Map<String, dynamic> data) async {
  final uuid = const Uuid().v4();
  final params = CallKitParams(
    id: uuid,
    nameCaller: data['caller_name'] ?? 'Inconnu',
    appName: 'Corporate Connect',
    avatar: data['caller_avatar'] ?? '',
    handle: 'Appel entrant...',
    type: data['is_video'] == 'true' ? 1 : 0,
    duration: 30000,
    extra: <String, dynamic>{'room_id': data['room_id']},
    android: AndroidParams(
      isCustomNotification: true,
      isShowLogo: false,
      ringtonePath: data['is_video'] == 'true' ? 'ringtone_video' : 'ringtone_audio',
      backgroundColor: '#040301',
      actionColor: '#4CAF50',
    ),
    ios: const IOSParams(
      iconName: 'AppIcon',
      handleType: 'generic',
      supportsVideo: true,
    ),
  );
  await FlutterCallkitIncoming.showCallkitIncoming(params);
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
      if (message.data['type'] == 'call_offer') {
        // En avant-plan, on laisse l'Overlay interne gérer la sonnerie si possible,
        // mais on affiche quand même CallKit pour la cohérence OS.
        _showCallKitIncoming(message.data);
      } else {
        _showLocalNotification(message);
      }
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
    if (authToken == null) {
      debugPrint("FCM Registration: Aucun token d'authentification trouvé. Abandon.");
      return;
    }

    Future<Response> makeRequest(String token) async {
      return await _dio.post(
        '${ApiConfig.baseUrl}/notifications/register-token',
        data: {'fcm_token': fcmToken},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status! < 500, // On gère les 401 nous-mêmes
        ),
      );
    }

    try {
      var response = await makeRequest(authToken);
      
      if (response.statusCode == 401) {
        debugPrint("FCM Registration: Token expiré (401). Tentative de rafraîchissement...");
        final refreshed = await _authService.refreshToken();
        
        if (refreshed) {
          final newToken = await _authService.getToken();
          if (newToken != null) {
            response = await makeRequest(newToken);
            if (response.statusCode == 200) {
              debugPrint("FCM Registration: Succès après rafraîchissement.");
              return;
            }
          }
        }
        
        debugPrint("FCM Registration: Échec critique après tentative de rafraîchissement (Status: ${response.statusCode}).");
        if (response.statusCode == 401) {
          debugPrint("FCM Registration: La session semble totalement expirée. Reconnexion requise.");
        }
      } else if (response.statusCode == 200) {
        debugPrint("FCM Registration: Succès.");
      } else {
        debugPrint("FCM Registration: Erreur inattendue (Status: ${response.statusCode}, Body: ${response.data})");
      }
    } catch (e) {
      debugPrint("FCM Registration: Exception lors de l'appel API: $e");
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
