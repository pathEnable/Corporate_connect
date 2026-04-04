import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/call_log.dart';
import '../services/call_service.dart';
import '../services/auth_service.dart';

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key});

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  List<CallLogModel> _calls = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    
    // Pour savoir si l'appel est entrant ou sortant
    try {
      final currentUser = await AuthService().getCurrentProfile();
      if (mounted) {
        setState(() {
          _currentUserId = currentUser['id']?.toString();
        });
      }
    } catch (_) {}
    
    final calls = await callService.getCallHistory();
    if (mounted) {
      setState(() {
        _calls = calls;
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return 'Manqué';
    final d = Duration(seconds: seconds);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) {
      return '$m min ${s.toString().padLeft(2, '0')} s';
    }
    return '$s s';
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays == 0 && now.day == date.day) {
        return "Auj à ${DateFormat('HH:mm').format(date)}";
      } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != date.day)) {
        return "Hier à ${DateFormat('HH:mm').format(date)}";
      } else {
        return DateFormat('dd/MM HH:mm').format(date);
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }

    if (_calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call_end_rounded, size: 64, color: theme.colorScheme.primary.withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              'Aucun appel récent',
              style: TextStyle(
                fontSize: 18,
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Appels', style: TextStyle(fontWeight: FontWeight.bold)),
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
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: _loadHistory,
        child: ListView.builder(
          itemCount: _calls.length,
          itemBuilder: (context, index) {
            final call = _calls[index];
            final isOutgoing = call.callerId == _currentUserId;
            final isMissed = call.status == 'missed' || call.status == 'rejected' || call.duration == 0;
            
            final otherName = isOutgoing ? call.receiverName : call.callerName;
            final iconColor = isMissed 
                ? theme.colorScheme.error 
                : (isOutgoing ? theme.colorScheme.secondary : Colors.green);
                
            final iconData = isOutgoing 
                ? Icons.call_made_rounded 
                : (isMissed ? Icons.call_missed_rounded : Icons.call_received_rounded);

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  call.callType == 'video' ? Icons.videocam_rounded : Icons.call_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: Text(
                otherName ?? 'Utilisateur inconnu',
                style: TextStyle(
                  fontWeight: isMissed ? FontWeight.bold : FontWeight.w500,
                  color: isMissed ? theme.colorScheme.error : theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Row(
                children: [
                  Icon(iconData, size: 14, color: iconColor),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(call.startTime),
                    style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(180), fontSize: 13),
                  ),
                  Text(
                    ' • ${_formatDuration(call.duration)}',
                    style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120), fontSize: 13),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.info_outline, color: theme.colorScheme.primary.withAlpha(150)),
                    onPressed: () {
                      // Actions on this call history
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
