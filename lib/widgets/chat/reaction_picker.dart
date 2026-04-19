import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Menu flottant de réactions emoji qui apparaît au-dessus d'un message.
/// Comportement WhatsApp : positionné juste au-dessus de la bulle, fond assombri.
class ReactionPicker extends StatelessWidget {
  final VoidCallback onDismiss;
  final Function(String emoji) onReactionSelected;
  final Offset anchorPosition; // Position du message sur l'écran
  final double anchorWidth;    // Largeur de la bulle
  final bool isMe;

  const ReactionPicker({
    super.key,
    required this.onDismiss,
    required this.onReactionSelected,
    required this.anchorPosition,
    required this.anchorWidth,
    required this.isMe,
  });

  static const List<String> reactions = ['👍', '❤️', '😂', '😮', '😢', '🙏', '➕'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calcul de la position horizontale : aligner avec la bulle
    const pickerWidth = 310.0;
    double left;
    if (isMe) {
      // Bulle à droite → aligner le picker à droite
      left = (anchorPosition.dx + anchorWidth - pickerWidth).clamp(8.0, screenWidth - pickerWidth - 8);
    } else {
      // Bulle à gauche → aligner le picker à gauche
      left = anchorPosition.dx.clamp(8.0, screenWidth - pickerWidth - 8);
    }

    // Position verticale : juste au-dessus de la bulle
    final top = (anchorPosition.dy - 60).clamp(40.0, double.infinity);

    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.translucent,
      child: Material(
        color: Colors.black.withAlpha(80), // Fond assombri comme WhatsApp
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: reactions.map((emoji) {
                    if (emoji == '➕') {
                      // Bouton "+" pour ouvrir plus d'emojis (style WhatsApp)
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onDismiss();
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(20) : Colors.grey.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add,
                            size: 20,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      );
                    }
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onReactionSelected(emoji);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget compact affichant les réactions sous un message.
/// Style WhatsApp : petite pilule chevauchant le bas de la bulle.
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

    // Compter le total de réactions et construire la liste d'emojis
    final activeReactions = reactions.entries
        .where((e) => (e.value as List).isNotEmpty)
        .toList();
    if (activeReactions.isEmpty) return const SizedBox.shrink();

    final totalCount = activeReactions.fold<int>(0, (sum, e) => sum + (e.value as List).length);
    final iReacted = activeReactions.any(
      (e) => currentUserId != null && (e.value as List).contains(currentUserId),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2C25).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Afficher les emojis (max 3, puis on groupe)
          ...activeReactions.take(3).map((entry) {
            return GestureDetector(
              onTap: () => onTapReaction?.call(entry.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Text(entry.key, style: const TextStyle(fontSize: 14)),
              ),
            );
          }),
          if (totalCount > 1) ...[
            const SizedBox(width: 2),
            Text(
              '$totalCount',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: iReacted
                    ? theme.colorScheme.primary
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
