import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_log.dart';
import '../services/call_service.dart';
import '../services/auth_service.dart';
import '../services/api_config.dart';
import '../widgets/authenticated_image.dart';
import '../providers/call_provider.dart';

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key});

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _GroupedCall {
  final List<CallLogModel> calls;
  final String otherId;
  final String otherName;
  final String? otherAvatar;
  final bool isOutgoing;
  final bool isMissed;
  final String dateKey;

  _GroupedCall({
    required this.calls,
    required this.otherId,
    required this.otherName,
    this.otherAvatar,
    required this.isOutgoing,
    required this.isMissed,
    required this.dateKey,
  });

  CallLogModel get latest => calls.first;
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
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (mounted) {
        setState(() {
          _currentUserId = userId;
        });
      }
      
      // Optionnel : Rafraîchir depuis l'API si nécessaire
      if (_currentUserId == null) {
        final currentUser = await AuthService().getCurrentProfile();
        if (mounted) {
          setState(() {
            _currentUserId = currentUser['id']?.toString();
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur récupération user_id: $e");
    }
    
    final calls = await callService.getCallHistory();
    if (mounted) {
      setState(() {
        _calls = calls;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le journal ?'),
        content: const Text('Voulez-vous vraiment supprimer tout votre historique d\'appels ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vider', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await callService.clearCallHistory();
      if (success) {
        setState(() => _calls = []);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de la suppression de l\'historique')),
          );
        }
      }
    }
  }

  Future<void> _callBack(CallLogModel call) async {
    if (call.roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de rappeler : Room ID manquant')),
      );
      return;
    }
    
    final isOutgoing = call.callerId == _currentUserId;
    final otherName = isOutgoing ? call.receiverName : call.callerName;
    final otherAvatar = isOutgoing ? call.receiverAvatar : call.callerAvatar;

    final success = await ref.read(callProvider.notifier).initiateCall(
      roomId: call.roomId!,
      isVideo: call.callType == 'video',
      otherUserName: otherName,
      otherUserAvatar: otherAvatar,
    );

    if (!success && mounted) {
      final error = ref.read(callProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Échec de l\'appel')),
      );
    }
  }

  List<_GroupedCall> _getGroupedCalls() {
    final List<_GroupedCall> grouped = [];
    
    for (var call in _calls) {
      final isOutgoing = call.callerId == _currentUserId;
      final isMissed = call.status == 'missed' || call.status == 'rejected' || call.duration == 0;
      final otherId = isOutgoing ? call.receiverId : call.callerId;
      final otherName = (isOutgoing ? call.receiverName : call.callerName) ?? 'Utilisateur inconnu';
      final otherAvatar = isOutgoing ? call.receiverAvatar : call.callerAvatar;
      
      final date = DateTime.parse(call.startTime).toLocal();
      final dateKey = "${date.year}-${date.month}-${date.day}";

      bool found = false;
      for (var group in grouped) {
        if (group.otherId == otherId && 
            group.isOutgoing == isOutgoing && 
            group.isMissed == isMissed && 
            group.dateKey == dateKey) {
          group.calls.add(call);
          found = true;
          break;
        }
      }
      
      if (!found) {
        grouped.add(_GroupedCall(
          calls: [call],
          otherId: otherId,
          otherName: otherName,
          otherAvatar: otherAvatar,
          isOutgoing: isOutgoing,
          isMissed: isMissed,
          dateKey: dateKey,
        ));
      }
    }
    return grouped;
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
    final groupedCalls = _getGroupedCalls();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Appels', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF040301) : Colors.white,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_calls.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Vider le journal',
              onPressed: _clearHistory,
            ),
        ],
        shape: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
        : groupedCalls.isEmpty
          ? Center(
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
            )
          : RefreshIndicator(
              color: theme.colorScheme.primary,
              onRefresh: _loadHistory,
              child: ListView.builder(
                itemCount: groupedCalls.length,
                itemBuilder: (context, index) {
                  final group = groupedCalls[index];
                  final call = group.latest;
                  final isOutgoing = group.isOutgoing;
                  final isMissed = group.isMissed;
                  
                  final iconColor = isMissed 
                      ? theme.colorScheme.error 
                      : (isOutgoing ? theme.colorScheme.secondary : Colors.green);
                      
                  final iconData = isOutgoing 
                      ? Icons.call_made_rounded 
                      : (isMissed ? Icons.call_missed_rounded : Icons.call_received_rounded);

                  final otherAvatar = group.otherAvatar;
                  final initial = (group.otherName)[0].toUpperCase();

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primary.withAlpha(30),
                      backgroundImage: otherAvatar != null 
                          ? AuthenticatedImageProvider(ApiConfig.getMediaUrl(otherAvatar)) 
                          : null,
                      child: otherAvatar == null 
                          ? Text(initial, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.otherName,
                            style: TextStyle(
                              fontWeight: isMissed ? FontWeight.bold : FontWeight.w500,
                              color: isMissed ? theme.colorScheme.error : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (group.calls.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${group.calls.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Icon(iconData, size: 14, color: iconColor),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(call.startTime),
                          style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(180), fontSize: 13),
                        ),
                        if (!isMissed)
                          Text(
                            ' • ${_formatDuration(call.duration)}',
                            style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120), fontSize: 13),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        call.callType == 'video' ? Icons.videocam_outlined : Icons.call_outlined, 
                        color: theme.colorScheme.primary
                      ),
                      onPressed: () => _callBack(call),
                    ),
                    onTap: () {
                      // Optionnel : Afficher les détails du groupe
                    },
                  );
                },
              ),
            ),
    );
  }
}
