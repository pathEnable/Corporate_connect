import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

class MeetingMessageWidget extends StatelessWidget {
  final String title; // Ajouté
  final Map<String, dynamic> metadata;
  final bool isMe;

  const MeetingMessageWidget({
    super.key,
    required this.title, // Ajouté
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
        SnackBar(
          content: const Text("Événement ajouté à votre agenda"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.teal.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final meetingTitle = title.isNotEmpty ? title : (metadata['title'] ?? 'Réunion');
    final description = metadata['description'] ?? '';
    final startDateStr = metadata['start_date'];
    
    DateTime? start;
    if (startDateStr != null) start = DateTime.tryParse(startDateStr);

    final dateFormatter = DateFormat('EEEE d MMM', 'fr_FR');
    final timeFormatter = DateFormat('HH:mm', 'fr_FR');

    final textColor = isMe 
        ? (isDark ? Colors.white : Colors.black87) 
        : (isDark ? Colors.white : Colors.black87);
        
    final mutedTextColor = textColor.withAlpha(160);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // En-tête : icône + info
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isMe 
                  ? (isDark ? Colors.white.withAlpha(20) : Colors.teal.withAlpha(30))
                  : theme.colorScheme.primary.withAlpha(isDark ? 30 : 20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_rounded,
                color: isMe ? (isDark ? Colors.white : Colors.teal.shade700) : theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meetingTitle,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (start != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      "${dateFormatter.format(start).replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase())} à ${timeFormatter.format(start)}",
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: mutedTextColor,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        
        // Séparateur fin
        const SizedBox(height: 8),
        Divider(
          height: 1, 
          thickness: 0.5, 
          color: textColor.withAlpha(30)
        ),
        
        // Bouton "Ajouter à l'agenda"
        GestureDetector(
          onTap: () => _addToCalendar(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            child: Text(
              "Ajouter à l'agenda",
              style: TextStyle(
                color: isMe ? (isDark ? Colors.tealAccent.shade100 : Colors.teal.shade800) : theme.colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

