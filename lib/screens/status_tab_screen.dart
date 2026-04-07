import 'package:flutter/material.dart';
import '../widgets/authenticated_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';


import '../providers/home_provider.dart';
import '../models/status_model.dart';
import '../widgets/premium_background.dart';
import '../widgets/ui_helpers.dart';
import 'story_view_screen.dart';
import 'story_creator_screen.dart';

class StatusTabScreen extends ConsumerWidget {
  const StatusTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);
    final theme = Theme.of(context);

    // Grouping logic
    final Map<String, List<StatusModel>> groupedStatuses = {};
    for (var s in state.statuses) {
      groupedStatuses.putIfAbsent(s.userId, () => []).add(s);
    }

    final recentStatuses = <List<StatusModel>>[];
    final viewedStatuses = <List<StatusModel>>[];

    for (var userId in groupedStatuses.keys) {
      final userStories = groupedStatuses[userId]!;
      // Simple logic: if the LAST story of the user is viewed, consider the group viewed. 
      // (Better logic: if ALL stories are viewed, but let's keep it simple for now)
      final allViewed = userStories.every((s) => state.viewedStatusIds.contains(s.id));
      if (allViewed) {
        viewedStatuses.add(userStories);
      } else {
        recentStatuses.add(userStories);
      }
    }

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Stories', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF040301) : Colors.white,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          centerTitle: false,
          shape: Border(
            bottom: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _buildMyStatusTile(context, theme),
            if (recentStatuses.isNotEmpty) ...[
              _buildSectionHeader(theme, 'RÉCENTES'),
              ...recentStatuses.map((list) => _buildStatusTile(context, ref, list, false)),
            ],
            if (viewedStatuses.isNotEmpty) ...[
              _buildSectionHeader(theme, 'VUES'),
              ...viewedStatuses.map((list) => _buildStatusTile(context, ref, list, true)),
            ],
            const SizedBox(height: 20), 
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildMyStatusTile(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.05), width: 0.5)),
      ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.person_outline_rounded, color: theme.colorScheme.primary),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.add_rounded, color: Colors.black, size: 18),
                  ),
                ),
              ],
            ),
            title: const Text('Mon Statut', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Appuyez pour ajouter une mise à jour'),
            onTap: () {
              Navigator.push(
                context,
                FadeSlideRoute(page: const StoryCreatorScreen()),
              );
            },
          ),
    );
  }

  Widget _buildStatusTile(BuildContext context, WidgetRef ref, List<StatusModel> stories, bool isViewed) {
    final theme = Theme.of(context);
    final first = stories.first;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.05), width: 0.5)),
      ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () {
              final allStatuses = ref.read(homeProvider).statuses;
              final index = allStatuses.indexOf(first);
              Navigator.push(
                context,
                FadeSlideRoute(page: StoryViewScreen(stories: allStatuses, initialIndex: index)),
              );
            },
            leading: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isViewed ? Colors.grey : theme.colorScheme.primary,
                  width: 2.5,
                ),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundImage: first.userAvatar != null ? AuthenticatedImageProvider(first.userAvatar!) : null,
                child: first.userAvatar == null ? const Icon(Icons.person) : null,
              ),
            ),
            title: Text(first.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${DateTime.now().difference(first.createdAt).inHours}h ago',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }
}
