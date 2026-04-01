class ApiConfig {
  /// URL de base pour les requêtes HTTP (Hébergement Render)
  static const String baseUrl = 'https://corporate-connect.onrender.com';

  /// URL de base pour les WebSockets (Sécurisé)
  static const String wsBaseUrl = 'wss://corporate-connect.onrender.com';

  /// Headers par défaut pour le backend
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
  };
}
