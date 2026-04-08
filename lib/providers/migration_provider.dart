import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Un simple provider pour suivre les migrations d'IDs de salons (draft -> real)
/// Cela permet aux ChatNotifiers de savoir s'ils doivent changer leur ID interne 
/// et se reconnecter au WebSocket correct après une synchronisation réussie.
final roomMigrationProvider = StateProvider<Map<String, String>>((ref) => {});

class MigrationManager {
  static void notifyMigration(WidgetRef ref, String oldId, String newId) {
    ref.read(roomMigrationProvider.notifier).update((state) => {
      ...state,
      oldId: newId,
    });
  }
  
  static void notifyMigrationWithRef(Ref ref, String oldId, String newId) {
    ref.read(roomMigrationProvider.notifier).update((state) => {
      ...state,
      oldId: newId,
    });
  }
}
