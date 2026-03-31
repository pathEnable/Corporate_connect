import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/home_provider.dart';
import '../ui_helpers.dart';
import 'room_tile.dart';
import 'status_list_section.dart';

class HomeChatsTab extends ConsumerWidget {
  const HomeChatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);

    if (state.isLoadingRooms) {
      return const ShimmerLoading();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(homeProvider.notifier).refreshRooms(),
      color: const Color(0xFF004D40),
      child: state.rooms.isEmpty
          ? _EmptyRoomView()
          : Column(
              children: [
                const StatusListSection(),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: state.rooms.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const StatusListSection(),
        const Divider(height: 1),
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'Aucune conversation',
                style: TextStyle(fontSize: 18, color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              Text(
                'Commencez via l\'annuaire !',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
