import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/global_presence_service.dart';
import '../../providers/incoming_call_provider.dart';

class GlobalCallListener extends ConsumerStatefulWidget {
  final Widget child;
  const GlobalCallListener({super.key, required this.child});

  @override
  ConsumerState<GlobalCallListener> createState() => _GlobalCallListenerState();
}

class _GlobalCallListenerState extends ConsumerState<GlobalCallListener> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _subscription = GlobalPresenceService.instance.globalEventsStream.listen((event) {
      if (event['type'] == 'call_offer') {
        final String name = event['caller_name'] ?? 'Inconnu';
        final String avatar = event['caller_avatar'] ?? '';
        // Support défensif : accepter room_id ET channel_id (rétrocompatibilité)
        final String roomId = event['room_id'] ?? event['channel_id'] ?? '';
        final bool isVideo = event['is_video'] == true || event['is_video'] == 'true';

        if (roomId.isNotEmpty) {
          ref.read(incomingCallProvider.notifier).showIncomingCall(
            name: name,
            avatar: avatar,
            roomId: roomId,
            isVideo: isVideo,
          );
        }
      } else if (event['type'] == 'call_cancel' || event['type'] == 'call_reject') {
        ref.read(incomingCallProvider.notifier).stopRinging();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
