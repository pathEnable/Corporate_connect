import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import '../providers/chat_provider.dart';

class AISummaryPanel extends StatefulWidget {
  final String roomId;

  const AISummaryPanel({super.key, required this.roomId});

  @override
  State<AISummaryPanel> createState() => _AISummaryPanelState();
}

class _AISummaryPanelState extends State<AISummaryPanel> {
  final AIService _aiService = AIService();
  bool _isLoading = true;
  String _summary = "";
  List<dynamic> _tasks = [];
  bool _isMock = false;

  @override
  void initState() {
    super.initState();
    _fetchAIData();
  }

  Future<void> _fetchAIData() async {
    setState(() => _isLoading = true);
    try {
      final summaryData = await _aiService.getSummary(widget.roomId);
      final tasksData = await _aiService.getActionItems(widget.roomId);
      
      if (mounted) {
        setState(() {
          _summary = summaryData['summary'] ?? "Aucun résumé disponible.";
          _tasks = tasksData;
          _isMock = summaryData['is_mock'] == true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(180),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withAlpha(50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      "Assistant IA 'Elite'",
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (_isMock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text("SIMULATION", style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  Text(
                    "Résumé Récent",
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _summary,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  if (_tasks.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      "Actions suggérées",
                      style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ..._tasks.map((task) => _TaskSuggestionCard(
                          title: task['title'] ?? "Tâche",
                          assignee: task['suggested_assignee'] ?? "Tout le monde",
                          roomId: widget.roomId,
                        )),
                  ],
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskSuggestionCard extends ConsumerWidget {
  final String title;
  final String assignee;
  final String roomId;

  const _TaskSuggestionCard({
    required this.title,
    required this.assignee,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text("Assigné : $assignee", style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(chatProvider(roomId).notifier).sendMessage(
                title,
                'task',
                extraData: {
                  'title': title,
                  'assignee_name': assignee,
                  'is_done': false,
                },
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Tâche créée !")),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Créer", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
