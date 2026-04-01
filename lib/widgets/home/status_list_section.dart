import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/status_model.dart';
import '../../providers/home_provider.dart';
import '../../screens/story_view_screen.dart';
import '../ui_helpers.dart';

class StatusListSection extends ConsumerWidget {
  const StatusListSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: state.statuses.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _AddStatusItem(ref: ref);
          final status = state.statuses[index - 1];
          return _StatusCircle(status: status);
        },
      ),
    );
  }
}

class _AddStatusItem extends StatelessWidget {
  final WidgetRef ref;
  const _AddStatusItem({required this.ref});

  void _showCreateStatusDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau statut'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Quoi de neuf ?"),
          maxLength: 100,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(homeProvider.notifier).createStatus(controller.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004D40),
              foregroundColor: Colors.white,
            ),
            child: const Text('Publier'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCreateStatusDialog(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            Stack(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFFE0E0E0),
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF004D40),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Mon statut', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _StatusCircle extends StatelessWidget {
  final StatusModel status;
  const _StatusCircle({required this.status});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Redirection vers la vue story (nécessite l'accès à la liste complète)
        final state = ProviderScope.containerOf(context).read(homeProvider);
        final index = state.statuses.indexOf(status);
        Navigator.push(
          context,
          FadeSlideRoute(
            page: StoryViewScreen(stories: state.statuses, initialIndex: index),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF004D40), width: 2),
              ),
              child: CircleAvatar(
                radius: 27,
                backgroundColor: const Color(0xFF004D40),
                backgroundImage: status.userAvatar != null ? NetworkImage(status.userAvatar!) : null,
                child: status.userAvatar == null ? const Icon(Icons.person, color: Colors.white) : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(status.userName.split(' ')[0], style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
