import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Menu flottant de réactions emoji qui apparaît au-dessus d'un message.
/// Utilise un OverlayEntry positionné dynamiquement par rapport au message source.
class ReactionPicker extends StatelessWidget {
  final VoidCallback onDismiss;
  final Function(String emoji) onReactionSelected;

  const ReactionPicker({
    super.key,
    required this.onDismiss,
    required this.onReactionSelected,
  });

  static const List<String> reactions = ['👍', '❤️', '😂', '😮', '😢', '👀'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.primary.withAlpha(30),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: reactions.asMap().entries.map((entry) {
                final index = entry.key;
                final emoji = entry.value;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onReactionSelected(emoji);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ).animate(delay: (index * 40).ms).fadeIn(duration: 200.ms).scale(
                      begin: const Offset(0.5, 0.5),
                      curve: Curves.elasticOut,
                      duration: 400.ms,
                    );
              }).toList(),
            ),
          ).animate().fadeIn(duration: 150.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }
}

/// Widget compact affichant les réactions sous un message.
class ReactionsDisplay extends StatelessWidget {
  final Map<String, dynamic> reactions; // { "👍": ["user1", "user2"], "❤️": ["user3"] }
  final bool isMe;
  final String? currentUserId;
  final Function(String emoji)? onTapReaction;

  const ReactionsDisplay({
    super.key,
    required this.reactions,
    required this.isMe,
    this.currentUserId,
    this.onTapReaction,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: reactions.entries.where((e) => (e.value as List).isNotEmpty).map((entry) {
          final emoji = entry.key;
          final users = entry.value as List;
          final iReacted = currentUserId != null && users.contains(currentUserId);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onTapReaction?.call(emoji);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: iReacted
                    ? theme.colorScheme.primary.withAlpha(40)
                    : (isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10)),
                borderRadius: BorderRadius.circular(12),
                border: iReacted
                    ? Border.all(color: theme.colorScheme.primary.withAlpha(100), width: 1)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  if (users.length > 1) ...[
                    const SizedBox(width: 4),
                    Text(
                      '${users.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white70 : theme.colorScheme.onSurface.withAlpha(180),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
