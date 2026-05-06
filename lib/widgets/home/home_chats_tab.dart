import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/home_provider.dart';
import 'room_tile.dart';
import 'status_list_section.dart';

class HomeChatsTab extends ConsumerWidget {
  const HomeChatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(homeProvider);

    // On ne montre plus de skeleton/shimmer. Si le cache est vide, 
    // l'UI montrera la vue vide propre après un délai imperceptible.

    return RefreshIndicator(
      onRefresh: () => ref.read(homeProvider.notifier).refreshRooms(),
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      child: state.rooms.isEmpty
          ? _EmptyRoomView()
          : Column(
              children: [
                const StatusListSection(),
                Divider(height: 1, color: theme.dividerColor.withAlpha(30)),
                Expanded(
                  child: ListView.separated(
                    itemCount: state.rooms.length,
                    padding: const EdgeInsets.only(bottom: 20), 
                    separatorBuilder: (context, index) => Divider(height: 1, indent: 83, color: theme.dividerColor.withAlpha(30)),
                    itemBuilder: (context, index) {
                      final room = state.rooms[index];
                      return HomeRoomTile(room: room);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyRoomView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const StatusListSection(),
        Divider(height: 1, color: theme.dividerColor.withAlpha(30)),
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.forum_rounded, size: 64, color: theme.colorScheme.primary.withAlpha(100)),
              ),
              const SizedBox(height: 24),
              Text(
                'Pas encore de conversations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Explorez l\'annuaire pour chatter ou collaborez en équipe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withAlpha(150)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
