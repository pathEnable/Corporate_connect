import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/api_config.dart';
import '../providers/chat_provider.dart';

class TaskMessageWidget extends ConsumerStatefulWidget {
  final String messageId;
  final String roomId;
  final Map<String, dynamic> metadata;
  final bool isMe;

  const TaskMessageWidget({
    super.key,
    required this.messageId,
    required this.roomId,
    required this.metadata,
    required this.isMe,
  });

  @override
  ConsumerState<TaskMessageWidget> createState() => _TaskMessageWidgetState();
}

class _TaskMessageWidgetState extends ConsumerState<TaskMessageWidget>
    with SingleTickerProviderStateMixin {
  bool _isUpdating = false;
  Map<String, dynamic> _meta = {};
  late AnimationController _checkController;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _meta = Map<String, dynamic>.from(widget.metadata);
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: _isDone ? 1.0 : 0.0,
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  bool get _isDone => _meta['is_done'] == true;
  String get _title => _meta['title'] ?? 'Tâche assignée';
  String get _description => _meta['description'] ?? '';
  String get _assigneeName => _meta['assignee_name'] ?? '';
  String get _deadline => _meta['deadline'] ?? '';

  Future<void> _toggleDone() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    final newStatus = !_isDone;
    try {
      final token = await AuthService().getToken();
      final url = '${ApiConfig.baseUrl}/rooms/${widget.roomId}/messages/${widget.messageId}/task';
      final resp = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'is_done': newStatus}),
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) && mounted) {
        final data = jsonDecode(resp.body);
        setState(() => _meta = Map<String, dynamic>.from(data['metadata_'] ?? _meta));
        if (newStatus) {
          _checkController.forward();
        } else {
          _checkController.reverse();
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _pingAssignee() {
    if (_isDone) return;
    
    final reminder = _assigneeName.isNotEmpty 
        ? "🔔 Rappel : @$_assigneeName, n'oublie pas la tâche : '$_title'"
        : "🔔 Rappel général pour la tâche : '$_title'";
        
    ref.read(chatProvider(widget.roomId).notifier).sendMessage(
      reminder, 
      'text',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Relance envoyée !"), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doneColor = Colors.green.shade400;
    final cardColor = widget.isMe
        ? theme.colorScheme.primary.withAlpha(25)
        : theme.colorScheme.surfaceContainerHighest.withAlpha(80);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDone ? doneColor.withAlpha(20) : cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isDone ? doneColor.withAlpha(100) : theme.colorScheme.primary.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.task_alt_rounded,
                color: _isDone ? doneColor : theme.colorScheme.secondary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'TÂCHE',
                style: TextStyle(
                  color: _isDone ? doneColor : theme.colorScheme.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              // Bouton Ping (Uniquement pour le créateur si pas fini)
              if (widget.isMe && !_isDone)
                IconButton(
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  onPressed: _pingAssignee,
                  tooltip: "Relancer",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(width: 8),
              // Checkbox
              GestureDetector(
                onTap: _toggleDone,
                child: AnimatedBuilder(
                  animation: _checkAnimation,
                  builder: (_, __) => Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isDone
                          ? doneColor.withAlpha((255 * _checkAnimation.value).toInt())
                          : Colors.transparent,
                      border: Border.all(
                        color: _isDone ? doneColor : Colors.grey.withAlpha(150),
                        width: 2,
                      ),
                    ),
                    child: _isUpdating
                        ? const Padding(
                            padding: EdgeInsets.all(4),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white.withAlpha(
                              (255 * _checkAnimation.value).toInt(),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              decoration: _isDone ? TextDecoration.lineThrough : null,
              color: _isDone ? theme.colorScheme.onSurface.withAlpha(130) : null,
            ),
          ),
          if (_description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _description,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (_assigneeName.isNotEmpty)
                _InfoChip(
                  icon: Icons.person_rounded,
                  label: _assigneeName,
                  color: theme.colorScheme.primary,
                ),
              if (_deadline.isNotEmpty)
                _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: _deadline,
                  color: Colors.orange,
                ),
              if (_isDone)
                _InfoChip(
                  icon: Icons.check_circle_rounded,
                  label: 'Terminée',
                  color: doneColor,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
