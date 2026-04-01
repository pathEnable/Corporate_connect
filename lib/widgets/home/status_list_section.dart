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

    final Map<String, List<StatusModel>> groupedStatuses = {};
    for (var s in state.statuses) {
      groupedStatuses.putIfAbsent(s.userId, () => []).add(s);
    }
    final userList = groupedStatuses.keys.toList();
    final flatGroupedStatuses = groupedStatuses.values.expand((list) => list).toList();

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: userList.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _AddStatusItem(ref: ref);
          
          final userId = userList[index - 1];
          final userStatuses = groupedStatuses[userId]!;
          
          return _StatusCircle(
            firstStatus: userStatuses.first, 
            allStatuses: flatGroupedStatuses,
          );
        },
      ),
    );
  }
}

class _AddStatusItem extends StatelessWidget {
  final WidgetRef ref;
  const _AddStatusItem({required this.ref});

  void _showCreateStatusDialog(BuildContext context) {
    final theme = Theme.of(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('Nouveau statut'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Quoi de neuf ?",
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          maxLength: 100,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Annuler', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150)))
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  ref.read(homeProvider.notifier).createStatus(controller.text);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Publier'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _showCreateStatusDialog(context),
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.person_outline_rounded, color: theme.colorScheme.onSurface.withAlpha(100), size: 30),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.surface, width: 2),
                    ),
                    child: Icon(Icons.add_rounded, color: theme.colorScheme.onPrimary, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Moi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withAlpha(180))),
          ],
        ),
      ),
    );
  }
}

class _StatusCircle extends StatelessWidget {
  final StatusModel firstStatus;
  final List<StatusModel> allStatuses;
  
  const _StatusCircle({required this.firstStatus, required this.allStatuses});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        final index = allStatuses.indexOf(firstStatus);
        Navigator.push(
          context,
          FadeSlideRoute(
            page: StoryViewScreen(stories: allStatuses, initialIndex: index),
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
                border: Border.all(color: theme.colorScheme.primary, width: 2),
              ),
              child: CircleAvatar(
                radius: 27,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: firstStatus.userAvatar != null ? NetworkImage(firstStatus.userAvatar!) : null,
                child: firstStatus.userAvatar == null 
                  ? Icon(Icons.person_rounded, color: theme.colorScheme.onSurface.withAlpha(100)) 
                  : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(firstStatus.userName.split(' ')[0], 
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withAlpha(180))
            ),
          ],
        ),
      ),
    );
  }
}
