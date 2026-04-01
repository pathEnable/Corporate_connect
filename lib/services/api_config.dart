import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Toggle pour passer du mode local au mode production (Render)
  static const bool useLocalBackend = true;

  /// URL pour Render (Production)
  static const String _prodBaseUrl = 'https://corporate-connect.onrender.com';
  static const String _prodWsUrl = 'wss://corporate-connect.onrender.com';

  /// Détection automatique de l'URL locale selon la plateforme
  static String get _localHost {
    if (kIsWeb) return '127.0.0.1';
    if (Platform.isAndroid) return '10.0.2.2'; // IP spéciale pour l'émulateur Android
    return '127.0.0.1'; // Pour Windows, iOS Simulator, macOS
  }

  /// URL de base finale
  static String get baseUrl {
    if (!useLocalBackend) return _prodBaseUrl;
    return 'http://$_localHost:8000';
  }

  /// URL WebSockets finale
  static String get wsBaseUrl {
    if (!useLocalBackend) return _prodWsUrl;
    return 'ws://$_localHost:8000';
  }

  /// Headers par défaut pour le backend
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
  };
}
