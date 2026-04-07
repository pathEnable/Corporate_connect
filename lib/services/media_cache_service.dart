import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'api_config.dart';
import 'auth_service.dart';

/// Service de cache médias haute performance.
/// - Stocke dans le dossier privé de l'app (plus rapide que la galerie)
/// - Vérifie l'existence avant tout téléchargement (évite les requêtes inutiles)
/// - Supporte le pré-chargement en masse (batch prefetch)
class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  static MediaCacheService get instance => _instance;

  final AuthService _authService = AuthService();
  final Dio _dio = Dio();
  
  // Cache mémoire pour les chemins locaux (évite les I/O disque répétés)
  final Map<String, String> _memoryPathCache = {};

  Directory? _cacheDir;

  /// Initialise le répertoire de cache de l'application
  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/media_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    return _cacheDir!;
  }

  /// Retourne le chemin local si le fichier est en cache, null sinon.
  Future<String?> getCachePath(String remoteUrl) async {
    final fileName = _urlToFilename(remoteUrl);
    
    // 1. Vérifier le cache mémoire (O(1), zéro I/O)
    if (_memoryPathCache.containsKey(fileName)) {
      return _memoryPathCache[fileName];
    }
    
    // 2. Vérifier le cache disque
    if (kIsWeb) return null;
    final dir = await _getCacheDir();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      _memoryPathCache[fileName] = file.path;
      return file.path;
    }
    return null;
  }

  /// Télécharge et met en cache un fichier. Retourne le chemin local.
  Future<String?> downloadAndCache(String relativeUrl) async {
    if (kIsWeb) return null;
    
    final remoteUrl = ApiConfig.getMediaUrl(relativeUrl);
    final fileName = _urlToFilename(remoteUrl);

    // Vérifier si déjà en cache
    final cached = await getCachePath(remoteUrl);
    if (cached != null) return cached;

    try {
      final dir = await _getCacheDir();
      final savePath = '${dir.path}/$fileName';
      final token = await _authService.getToken();
      
      await _dio.download(
        remoteUrl,
        savePath,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      _memoryPathCache[fileName] = savePath;
      return savePath;
    } catch (e) {
      debugPrint('❌ Erreur cache média ($relativeUrl): $e');
      return null;
    }
  }

  /// Pré-charge une liste d'URLs en arrière-plan (fire-and-forget).
  /// Typiquement utilisé pour les dernières images d'une conversation.
  void prefetchBatch(List<String> relativeUrls) {
    for (final url in relativeUrls) {
      // Lance chaque téléchargement en parallèle sans bloquer
      downloadAndCache(url).ignore();
    }
    debugPrint('🚀 Prefetch lancé pour ${relativeUrls.length} médias');
  }

  /// Nettoie les fichiers de cache de plus de 30 jours.
  Future<void> cleanOldCache() async {
    if (kIsWeb) return;
    try {
      final dir = await _getCacheDir();
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        }
      }
      debugPrint('🧹 Nettoyage cache médias terminé');
    } catch (e) {
      debugPrint('⚠️ Erreur nettoyage cache: $e');
    }
  }

  /// Calcule la taille totale du dossier media_cache en octets.
  Future<int> getTotalCacheSize() async {
    if (kIsWeb) return 0;
    int totalSize = 0;
    try {
      final dir = await _getCacheDir();
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur calcul taille cache: $e');
    }
    return totalSize;
  }

  /// Vide complètement le dossier media_cache.
  Future<void> clearAllCache() async {
    if (kIsWeb) return;
    try {
      final dir = await _getCacheDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(); // Le recréer pour les futurs téléchargements
        _memoryPathCache.clear();
      }
      debugPrint('🗑️ Cache média vidé intégralement.');
    } catch (e) {
      debugPrint('❌ Erreur vidage cache média: $e');
    }
  }

  /// Retaille les grandes images pour adapter la résolution à l'usage UI
  String _urlToFilename(String url) {
    // Utiliser un hash simple basé sur l'URL pour le nom de fichier
    return url.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}
