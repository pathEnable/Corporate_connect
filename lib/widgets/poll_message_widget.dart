import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_config.dart';
import '../widgets/authenticated_image.dart';
import '../../providers/chat_provider.dart';

class PollMessageWidget extends ConsumerStatefulWidget {
  final String messageId;
  final String roomId;
  final String question; // Ajouté
  final Map<String, dynamic> metadata;
  final bool isMe;

  const PollMessageWidget({
    super.key,
    required this.messageId,
    required this.roomId,
    required this.question, // Ajouté
    required this.metadata,
    required this.isMe,
  });

  @override
  ConsumerState<PollMessageWidget> createState() => _PollMessageWidgetState();
}

class _PollMessageWidgetState extends ConsumerState<PollMessageWidget> {
  bool _isVoting = false;
  Map<String, dynamic> _meta = {};

  @override
  void initState() {
    super.initState();
    _meta = Map<String, dynamic>.from(widget.metadata);
  }

  @override
  void didUpdateWidget(covariant PollMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.metadata != oldWidget.metadata) {
      setState(() {
        _meta = Map<String, dynamic>.from(widget.metadata);
      });
    }
  }

  List<Map<String, dynamic>> get _options {
    final rawOptions = _meta['options'];
    if (rawOptions is! List) return [];
    
    return rawOptions.map((opt) {
      if (opt is Map) {
        return Map<String, dynamic>.from(opt);
      } else {
        // Fallback pour le format List<String>
        return {'text': opt.toString()};
      }
    }).toList();
  }
  
  Map<String, dynamic> get _votes {
    final rawVotes = _meta['votes'];
    if (rawVotes is Map) {
      return Map<String, dynamic>.from(rawVotes);
    }
    return {};
  }
  
  String get _question => widget.question.isNotEmpty ? widget.question : (_meta['question'] ?? 'Sondage');
  int get _totalVotes => _votes.length;

  int _getVoteCount(int index) {
    return _votes.values.where((v) {
      // Gérer le cas où l'index est stocké comme String ou int
      return v.toString() == index.toString();
    }).length;
  }

  Future<void> _vote(int optionIndex) async {
    if (_isVoting) return;
    setState(() => _isVoting = true);
    try {
      await ref.read(chatProvider(widget.roomId).notifier).votePoll(widget.messageId, optionIndex);
    } catch (e) {
      debugPrint("Error voting: $e");
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  Color _getColorForVoter(String id) {
    final colors = [
      Colors.blue.shade400,
      Colors.red.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.teal.shade400
    ];
    return colors[id.hashCode % colors.length];
  }

  Widget _buildAvatarsStack(List<String> voters, ThemeData theme, Map<String, String?> memberAvatars, Map<String, String> members) {
    final displayVoters = voters.take(3).toList();
    final remaining = voters.length - displayVoters.length;
    
    return SizedBox(
      width: (displayVoters.length * 16.0) + (remaining > 0 ? 18.0 : 0) + 4,
      height: 24,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          if (remaining > 0)
            Positioned(
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                  border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                ),
                child: Text(
                  '+$remaining', 
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
              ),
            ),
          for (int i = 0; i < displayVoters.length; i++)
            Positioned(
              right: (remaining > 0 ? 18.0 : 0) + (displayVoters.length - 1 - i) * 14.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface, 
                    width: 1.5,
                  ),
                ),
                child: Builder(
                  builder: (context) {
                    final voterId = displayVoters[i];
                    final avatarUrl = memberAvatars[voterId];
                    final name = members[voterId] ?? "Utilisateur";
                    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?";
                    
                    return CircleAvatar(
                      radius: 10,
                      backgroundColor: _getColorForVoter(voterId),
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) 
                        ? AuthenticatedImageProvider(ApiConfig.getMediaUrl(avatarUrl)) 
                        : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty) 
                        ? Text(
                            initial,
                            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                    );
                  }
                ),
              ),
            )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatState = ref.watch(chatProvider(widget.roomId));
    final isDark = theme.brightness == Brightness.dark;


    final textColor = widget.isMe 
        ? (isDark ? Colors.white : Colors.black87) 
        : (isDark ? Colors.white : Colors.black87);

    final highlightColor = widget.isMe 
        ? (isDark ? const Color(0xFF00A884).withAlpha(40) : const Color(0xFF00A884).withAlpha(30))
        : theme.colorScheme.primary.withAlpha(isDark ? 30 : 20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // En-tête minimalist
        Row(
          children: [
            Icon(Icons.poll_rounded, color: theme.colorScheme.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              'Sondage',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Question
        Text(
          _question,
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            fontSize: 15,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        
        // Options
        ..._options.asMap().entries.map((entry) {
          final i = entry.key;
          final option = entry.value;
          final label = option['text']?.toString() ?? 'Option';
          final count = _getVoteCount(i);
          final pct = _totalVotes > 0 ? count / _totalVotes : 0.0;
          final votersForOption = _votes.entries.where((e) => e.value == i).map((e) => e.key).toList();

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () => _vote(i),
              child: Container(
                height: 42,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    // Jauge de progression fluide
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutQuart,
                              width: constraints.maxWidth * (pct > 0 ? pct : 0.0),
                              decoration: BoxDecoration(
                                color: highlightColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Contenu
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          // Radio button discret
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: count > 0 ? theme.colorScheme.primary : textColor.withAlpha(100),
                                width: count > 0 ? 5 : 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Label
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: textColor,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Avatars
                          if (count > 0) ...[
                            _buildAvatarsStack(votersForOption, theme, chatState.memberAvatars, chatState.members),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        
        // Pied de sondage
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                '$_totalVotes participant${_totalVotes > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 11, 
                  color: textColor.withAlpha(150),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 14, color: textColor.withAlpha(100)),
          ],
        ),
      ],
    );
  }
}
