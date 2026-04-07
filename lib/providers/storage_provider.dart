import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_database.dart';
import '../services/media_cache_service.dart';

class StorageState {
  final int messageCacheSize;
  final int mediaCacheSize;
  final bool isLoading;

  StorageState({
    this.messageCacheSize = 0,
    this.mediaCacheSize = 0,
    this.isLoading = false,
  });

  StorageState copyWith({
    int? messageCacheSize,
    int? mediaCacheSize,
    bool? isLoading,
  }) {
    return StorageState(
      messageCacheSize: messageCacheSize ?? this.messageCacheSize,
      mediaCacheSize: mediaCacheSize ?? this.mediaCacheSize,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  String get formattedMessageSize => _formatSize(messageCacheSize);
  String get formattedMediaSize => _formatSize(mediaCacheSize);
  String get formattedTotalSize => _formatSize(messageCacheSize + mediaCacheSize);

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes > 0) ? (bytes.toString().length - 1) ~/ 3 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double num = bytes / (1 << (i * 10));
    return '${num.toStringAsFixed(1)} ${suffixes[i]}';
  }
}

class StorageNotifier extends StateNotifier<StorageState> {
  StorageNotifier() : super(StorageState()) {
    refreshSizes();
  }

  Future<void> refreshSizes() async {
    state = state.copyWith(isLoading: true);
    final msgSize = await LocalDatabase.instance.getCacheSize();
    final mediaSize = await MediaCacheService.instance.getTotalCacheSize();
    state = state.copyWith(
      messageCacheSize: msgSize,
      mediaCacheSize: mediaSize,
      isLoading: false,
    );
  }

  Future<void> clearMediaCache() async {
    state = state.copyWith(isLoading: true);
    await MediaCacheService.instance.clearAllCache();
    await refreshSizes();
  }

  Future<void> clearMessageCache() async {
    state = state.copyWith(isLoading: true);
    await LocalDatabase.instance.clearCache();
    await refreshSizes();
  }

  Future<void> optimizeDatabase() async {
    state = state.copyWith(isLoading: true);
    await LocalDatabase.instance.optimizeDatabase();
    await refreshSizes();
  }
}

final storageProvider = StateNotifierProvider<StorageNotifier, StorageState>((ref) {
  return StorageNotifier();
});
