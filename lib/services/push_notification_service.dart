import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Ajouté
import 'auth_service.dart';
import 'api_config.dart';
import '../main.dart';
import '../screens/chat_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return; // Pas de background handler FCM sur Web avec cette config
  
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
  
  if (message.data['type'] == 'call_offer') {
    await _showCallKitIncoming(message.data);
  }
}

Future<void> _showCallKitIncoming(Map<String, dynamic> data) async {
  if (kIsWeb) return; // CallKit non supporté sur Web

  // ✅ FIX BUG 8 : Utiliser le vrai call_id comme ID CallKit
  // (au lieu d'un UUID aléatoire) pour pouvoir l'éteindre spécifiquement.
  final callId = data['call_id']?.toString();
  if (callId == null || callId.isEmpty) return;

  final params = CallKitParams(
    id: callId,
    nameCaller: data['caller_name'] ?? 'Inconnu',
    appName: 'Corporate Connect',
    avatar: data['caller_avatar'] ?? '',
    handle: 'Appel entrant...',
    type: data['is_video'] == 'true' ? 1 : 0,
    duration: 40000,
    extra: <String, dynamic>{
      'room_id': data['room_id'] ?? '',
      'call_id': data['call_id'] ?? '',
      'channel_name': data['channel_name'] ?? '',
      'caller_name': data['caller_name'] ?? '',
      'caller_avatar': data['caller_avatar'] ?? '',
      'is_video': data['is_video'] ?? 'false',
    },
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
    try {
      if (kIsWeb) {
        // Sur Web, Firebase nécessite absolument des options (FirebaseOptions).
        // Si DefaultFirebaseOptions n'est pas généré, on ignore silencieusement 
        // ou on logue un avertissement clair pour éviter de bloquer l'UI.
        debugPrint("🌐 Initialisation Firebase Web...");
        // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); 
        // ↑ Décommenter après avoir lancé 'flutterfire configure'
        
        // Pour l'instant, on tente une init basique mais on s'attend à ce que ça échoue 
        // si les options manquent.
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp();
      }
    } catch (e) {
      debugPrint("Firebase initialization info: $e");
      debugPrint("💡 Note: Sur Web, assurez-vous d'avoir configuré Firebase avec 'flutterfire configure'.");
    }
    
    if (kIsWeb) return; // On arrête l'init FCM/Notifications ici pour le Web

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
        // ✅ FIX BUG 1 : En FOREGROUND, le WebSocket (GlobalCallListener) gère
        // déjà les call_offer via l'overlay in-app. Si on appelait aussi
        // _showCallKitIncoming ici, l'acceptation serait déclenchée DEUX FOIS
        // → double appel API answerCall() → erreur serveur + double connexion Agora.
        // CallKit n'est déclenché QUE pour les messages en BACKGROUND (handler isolé).
        debugPrint('📲 FCM call_offer en foreground : géré par WebSocket, ignoré ici.');
        return;
      }
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
    try {
      // Vérifier si Firebase est bien initialisé avant de faire quoi que ce soit
      if (Firebase.apps.isEmpty) {
        debugPrint("⚠️ FCM Registration: Firebase n'est pas initialisé. Abandon.");
        return;
      }
      
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
            validateStatus: (status) => status! < 500,
          ),
        );
      }

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
