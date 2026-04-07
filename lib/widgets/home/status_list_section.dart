import 'package:flutter/material.dart';
import '../../widgets/authenticated_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';


import '../../models/status_model.dart';
import '../../providers/home_provider.dart';
import '../../screens/story_view_screen.dart';
import '../../screens/story_creator_screen.dart';
import '../ui_helpers.dart';

class StatusListSection extends ConsumerWidget {
  const StatusListSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);

    // Grouping & Sorting logic
    final Map<String, List<StatusModel>> groupedStatuses = {};
    for (var s in state.statuses) {
      groupedStatuses.putIfAbsent(s.userId, () => []).add(s);
    }

    final userList = groupedStatuses.keys.toList();
    
    // Split into read and unread groups
    final unreadUsers = <String>[];
    final readUsers = <String>[];

    for (var userId in userList) {
      final stories = groupedStatuses[userId]!;
      final allViewed = stories.every((s) => state.viewedStatusIds.contains(s.id));
      if (allViewed) {
        readUsers.add(userId);
      } else {
        unreadUsers.add(userId);
      }
    }

    final sortedUsers = [...unreadUsers, ...readUsers];
    final flatSortedStatuses = <StatusModel>[];
    for (var userId in sortedUsers) {
      flatSortedStatuses.addAll(groupedStatuses[userId]!);
    }

    return Container(
      height: 105,
      margin: const EdgeInsets.only(top: 10, bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: sortedUsers.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _AddStatusItem(ref: ref);
          
          final userId = sortedUsers[index - 1];
          final userStatuses = groupedStatuses[userId]!;
          final isViewed = readUsers.contains(userId);
          
          return _StatusCircle(
            firstStatus: userStatuses.first, 
            allStatuses: flatSortedStatuses,
            isViewed: isViewed,
          ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.2);
        },
      ),
    );
  }
}

class _AddStatusItem extends StatelessWidget {
  final WidgetRef ref;
  const _AddStatusItem({required this.ref});

  void _navigateToCreator(BuildContext context) {
    Navigator.push(
      context,
      FadeSlideRoute(page: const StoryCreatorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _navigateToCreator(context),
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 12),
        child: Column(
          children: [
            Hero(
              tag: 'story_creator',
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      child: Icon(Icons.person_outline_rounded, color: theme.colorScheme.primary, size: 30),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.surface, width: 2),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.black, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Moi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

class _StatusCircle extends StatelessWidget {
  final StatusModel firstStatus;
  final List<StatusModel> allStatuses;
  final bool isViewed;
  
  const _StatusCircle({required this.firstStatus, required this.allStatuses, required this.isViewed});

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
                border: Border.all(
                  color: isViewed ? Colors.grey.withValues(alpha: 0.5) : theme.colorScheme.primary, 
                  width: isViewed ? 1.5 : 2.5
                ),
              ),
              child: Opacity(
                opacity: isViewed ? 0.7 : 1.0,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: firstStatus.userAvatar != null ? AuthenticatedImageProvider(firstStatus.userAvatar!) : null,
                  child: firstStatus.userAvatar == null 
                    ? Icon(Icons.person_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)) 
                    : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              firstStatus.userName.split(' ')[0], 
              style: TextStyle(
                fontSize: 12, 
                fontWeight: isViewed ? FontWeight.w500 : FontWeight.w700, 
                color: theme.colorScheme.onSurface.withValues(alpha: isViewed ? 0.5 : 0.9)
              ),
            ),
          ],
        ),
      ),
    );
  }
}
