import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MeetingMessageWidget extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final bool isMe;

  const MeetingMessageWidget({
    super.key,
    required this.metadata,
    required this.isMe,
  });

  Future<void> _addToCalendar(BuildContext context) async {
    final Event event = Event(
      title: metadata['title'] ?? 'Nouvelle réunion',
      description: metadata['description'] ?? '',
      location: metadata['location'] ?? '',
      startDate: DateTime.parse(metadata['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(metadata['end_date'] ?? DateTime.now().add(const Duration(hours: 1)).toIso8601String()),
    );

    final success = await Add2Calendar.addEvent2Cal(event);
    if (!context.mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Événement ajouté à votre calendrier natif !"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = metadata['title'] ?? 'Réunion';
    final description = metadata['description'] ?? '';
    final startDateStr = metadata['start_date'];
    final endDateStr = metadata['end_date'];

    DateTime? start;
    DateTime? end;
    if (startDateStr != null) start = DateTime.tryParse(startDateStr);
    if (endDateStr != null) end = DateTime.tryParse(endDateStr);

    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm', 'fr_FR');
    final timeFormatter = DateFormat('HH:mm', 'fr_FR');

    final Color bgColor = isMe 
        ? Colors.white.withAlpha(40) 
        : theme.colorScheme.primary.withAlpha(20);
    final Color textColor = isMe ? Colors.white : theme.colorScheme.onSurface;

    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMe ? Colors.white.withAlpha(50) : theme.colorScheme.primary.withAlpha(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? Colors.black.withAlpha(30) : theme.colorScheme.primary.withAlpha(15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  color: isMe ? Colors.white : theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Invitation à une réunion",
                    style: TextStyle(
                      color: isMe ? Colors.white70 : theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      color: textColor.withAlpha(180),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                
                // Date & Time
                if (start != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.black.withAlpha(20) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: isMe ? Colors.white70 : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${dateFormatter.format(start)}${end != null ? ' - ${timeFormatter.format(end)}' : ''}",
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Add to Calendar Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _addToCalendar(context),
                    icon: const Icon(Icons.add_alarm_rounded, size: 18),
                    label: const Text("Ajouter à l'agenda"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMe ? Colors.white : theme.colorScheme.primary,
                      foregroundColor: isMe ? theme.colorScheme.primary : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }
}
