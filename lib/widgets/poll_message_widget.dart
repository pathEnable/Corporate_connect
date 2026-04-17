import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_config.dart';

class PollMessageWidget extends StatefulWidget {
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
  State<PollMessageWidget> createState() => _PollMessageWidgetState();
}

class _PollMessageWidgetState extends State<PollMessageWidget> {
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
      final token = await AuthService().getToken();
      final url = '${ApiConfig.baseUrl}/rooms/${widget.roomId}/messages/${widget.messageId}/vote';
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'option_index': optionIndex}),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        final newVotes = Map<String, dynamic>.from(data['votes'] ?? {});
        if (mounted) setState(() => _meta['votes'] = newVotes);
      }
    } catch (_) {} finally {
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

  Widget _buildAvatarsStack(List<String> voters, ThemeData theme) {
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
                  border: Border.all(color: widget.isMe ? theme.colorScheme.primary.withAlpha(50) : theme.colorScheme.surface, width: 1.5),
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
                    color: widget.isMe ? Colors.teal.shade50 : theme.colorScheme.surface, 
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: _getColorForVoter(displayVoters[i]),
                  child: Text(
                     displayVoters[i].length > 1 ? displayVoters[i].substring(0, 1).toUpperCase() : "?",
                     style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
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
    final isDark = theme.brightness == Brightness.dark;

    // Couleurs WhatsApp-like
    final bubbleColor = widget.isMe
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFE2F7CB))
        : (isDark ? const Color(0xFF202C33) : Colors.white);
    
    final textColor = widget.isMe 
        ? (isDark ? Colors.white : Colors.black87) 
        : (isDark ? Colors.white : Colors.black87);

    final highlightColor = widget.isMe 
        ? (isDark ? const Color(0xFF00A884).withAlpha(60) : const Color(0xFF00A884).withAlpha(40))
        : theme.colorScheme.primary.withAlpha(isDark ? 40 : 25);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 2,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      // Jauge de progression fluide form fitting
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutQuart,
                        width: pct > 0 ? MediaQuery.of(context).size.width * 0.6 * pct : 0, 
                        // Approximation largeur dispo, on peut utiliser FractionallySizedBox avec un alignement left
                        color: highlightColor,
                      ),
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: pct > 0 ? pct : 0.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: highlightColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
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
                                  width: count > 0 ? 5 : 1.5, // Fills when selected
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
                            // Avatars & Pourcentage
                            if (count > 0) ...[
                              _buildAvatarsStack(votersForOption, theme),
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
              // Optionnel : icône "voir les détails"
              Icon(Icons.chevron_right_rounded, size: 14, color: textColor.withAlpha(100)),
            ],
          ),
        ],
      ),
    );
  }
}
