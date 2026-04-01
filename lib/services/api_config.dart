class ApiConfig {
  /// Configuration Locale pour Navigateur (Flutter Web)
  static const String localHost = 'localhost:8000';

  /// URL de base pour les requêtes HTTP
  static const String baseUrl = 'http://$localHost';

  /// URL de base pour les WebSockets
  static const String wsBaseUrl = 'ws://$localHost';

  /// Headers par défaut (sans ngrok)
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
  };
}
