import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Toggle pour passer du mode local au mode production (Render)
  static const bool useLocalBackend = false;

  /// URL pour Render (Production)
  static const String _prodBaseUrl = 'https://corporate-connect.onrender.com';
  static const String _prodWsUrl = 'wss://corporate-connect.onrender.com';

  /// Adresse IP de votre PC détectée (192.168.2.5)
  /// Pour permettre la connexion depuis un TÉLÉPHONE PHYSIQUE sur le même Wi-Fi
  static const String _detectedLocalIP = '192.168.2.5';

  /// Détection automatique de l'URL locale selon la plateforme
  static String get _localHost {
    if (kIsWeb) {
      // Sur le web, le navigateur accède au backend sur la même machine (localhost)
      return '127.0.0.1';
    }
    
    try {
      // Détection de l'émulateur Android (toujours 10.0.2.2)
      if (Platform.isAndroid) {
        // Note: On pourrait utiliser package:device_info_plus pour être 100% sûr 
        // qu'on est sur un émulateur, mais 10.0.2.2 fonctionne généralement bien.
        // Si vous êtes sur un TÉLÉPHONE PHYSIQUE Android, nous utilisons l'IP Wi-Fi.
        
        // Pour l'instant, on privilégie l'IP Wi-Fi car c'est votre cas d'usage actuel.
        return _detectedLocalIP;
      }
    } catch (_) {
      // Fallback si Platform n'est pas disponible (ex: desktop)
    }

    return _detectedLocalIP;
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

  /// Construit une URL complète pour afficher un média (avatar, image, etc.)
  /// Ne passe AUCUN jeton dans l'URL pour des raisons de sécurité.
  /// Les requêtes doivent utiliser AuthenticatedNetworkImage pour fournir les Headers.
  static String getMediaUrl(String relativeUrl) {
    if (relativeUrl.startsWith('http')) {
      return relativeUrl;
    }
    String path = relativeUrl.replaceFirst("/media", "");
    if (!path.startsWith('/')) path = '/$path';
    return '$baseUrl/media$path';
  }

  /// Vérifie si une URL pointe vers notre propre backend
  static bool isInternalUrl(String url) {
    if (!url.startsWith('http')) return true; // URLs relatives sont internes
    final String domain = baseUrl.replaceAll('https://', '').replaceAll('http://', '');
    return url.contains(domain);
  }
}

