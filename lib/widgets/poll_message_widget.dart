import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_config.dart';

class PollMessageWidget extends StatefulWidget {
  final String messageId;
  final String roomId;
  final Map<String, dynamic> metadata;
  final bool isMe;

  const PollMessageWidget({
    super.key,
    required this.messageId,
    required this.roomId,
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

  List<String> get _options => List<String>.from(_meta['options'] ?? []);
  Map<String, dynamic> get _votes => Map<String, dynamic>.from(_meta['votes'] ?? {});
  String get _question => _meta['question'] ?? 'Sondage';

  int _getVoteCount(int index) =>
      _votes.values.where((v) => v == index).length;

  int get _totalVotes => _votes.length;

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
        setState(() => _meta['votes'] = newVotes);
      } else if (resp.statusCode == 409 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous avez déjà voté à ce sondage.')),
        );
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = widget.isMe
        ? theme.colorScheme.primary.withAlpha(30)
        : theme.colorScheme.surfaceContainerHighest.withAlpha(80);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(60),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête sondage
          Row(
            children: [
              Icon(Icons.poll_rounded, color: theme.colorScheme.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                'SONDAGE',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Question
          Text(
            _question,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 12),
          // Options
          ..._options.asMap().entries.map((entry) {
            final i = entry.key;
            final label = entry.value;
            final count = _getVoteCount(i);
            final pct = _totalVotes > 0 ? count / _totalVotes : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _vote(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withAlpha(40),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            '$count vote${count > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor: theme.colorScheme.primary.withAlpha(20),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            '$_totalVotes participant${_totalVotes > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(120)),
          ),
        ],
      ),
    );
  }
}
