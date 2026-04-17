import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../providers/call_provider.dart';
import '../../models/call_state.dart';
import '../../screens/call_screen.dart';
import '../../services/global_presence_service.dart';

/// Écoute globale de TOUS les événements d'appel :
///   - WebSocket global : call_offer, call_answered, call_rejected, call_ended, call_cancel
///   - CallKit : acceptation/refus natif (quand l'app est en arrière-plan)
class GlobalCallListener extends ConsumerStatefulWidget {
  final Widget child;
  const GlobalCallListener({super.key, required this.child});

  @override
  ConsumerState<GlobalCallListener> createState() => _GlobalCallListenerState();
}

class _GlobalCallListenerState extends ConsumerState<GlobalCallListener> {
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  StreamSubscription<dynamic>? _callKitSubscription;

  @override
  void initState() {
    super.initState();
    _listenToWebSocket();
    _listenToCallKit();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _callKitSubscription?.cancel();
    super.dispose();
  }

  /// Écoute les événements du WebSocket global (temps réel, app en foreground).
  void _listenToWebSocket() {
    _wsSubscription = GlobalPresenceService.instance.globalEventsStream.listen((event) {
      final type = event['type']?.toString() ?? '';
      debugPrint('📡 GlobalCallListener WS event: $type');

      switch (type) {
        case 'call_offer':
          _handleCallOffer(event);
          break;
        case 'call_answered':
          ref.read(callProvider.notifier).onCallAnswered();
          break;
        case 'call_rejected':
          ref.read(callProvider.notifier).onCallRejected();
          break;
        case 'call_ended':
          ref.read(callProvider.notifier).onCallEnded();
          break;
        case 'call_cancel':
          ref.read(callProvider.notifier).onCallCancelled();
          // Fermer toute UI CallKit native active
          FlutterCallkitIncoming.endAllCalls();
          break;
      }
    });
  }

  /// Gère un call_offer reçu via WS global.
  void _handleCallOffer(Map<String, dynamic> event) {
    final callId = event['call_id']?.toString() ?? '';
    final channelName = event['channel_name']?.toString() ?? '';
    final callerName = event['caller_name']?.toString() ?? 'Inconnu';
    final callerAvatar = event['caller_avatar']?.toString();
    final roomId = event['room_id']?.toString() ?? '';
    final isVideo = event['is_video'] == true || event['is_video'] == 'true';

    debugPrint('📞 Appel entrant de $callerName (call_id: $callId)');

    // Mettre à jour le CallProvider
    ref.read(callProvider.notifier).onIncomingCall(
      callId: callId,
      channelName: channelName,
      callerName: callerName,
      callerAvatar: callerAvatar,
      roomId: roomId,
      isVideo: isVideo,
    );

    // Naviguer vers l'écran d'appel entrant (overlay)
    _navigateToIncomingCall();
  }

  /// Écoute les événements CallKit (pour quand l'utilisateur interagit 
  /// avec la notification native en arrière-plan).
  void _listenToCallKit() {
    _callKitSubscription = FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      debugPrint('📱 CallKit event: ${event.event}');

      final extra = event.body['extra'] as Map<String, dynamic>? ?? {};

      switch (event.event) {
        case Event.actionCallAccept:
          _handleCallKitAccept(extra);
          break;
        case Event.actionCallDecline:
          _handleCallKitDecline(extra);
          break;
        case Event.actionCallEnded:
          // L'utilisateur a terminé l'appel via l'interface native
          ref.read(callProvider.notifier).hangUp();
          break;
        default:
          break;
      }
    });
  }

  /// L'utilisateur a accepté via CallKit (interface iOS/Android native).
  void _handleCallKitAccept(Map<String, dynamic> extra) {
    final callId = extra['call_id']?.toString() ?? '';
    final channelName = extra['channel_name']?.toString() ?? '';
    final callerName = extra['caller_name']?.toString() ?? 'Inconnu';
    final callerAvatar = extra['caller_avatar']?.toString();
    final roomId = extra['room_id']?.toString() ?? '';
    final isVideo = extra['is_video'] == 'true';

    // Si l'appel n'a pas encore été enregistré (app ouverte depuis background)
    final currentState = ref.read(callProvider);
    if (currentState.phase == CallPhase.idle) {
      ref.read(callProvider.notifier).onIncomingCall(
        callId: callId,
        channelName: channelName,
        callerName: callerName,
        callerAvatar: callerAvatar,
        roomId: roomId,
        isVideo: isVideo,
      );
    }

    // Accepter l'appel et naviguer
    ref.read(callProvider.notifier).acceptCall().then((success) {
      if (success) {
        _navigateToCallScreen();
      }
    });
  }

  /// L'utilisateur a refusé via CallKit.
  void _handleCallKitDecline(Map<String, dynamic> extra) {
    final currentState = ref.read(callProvider);
    if (currentState.phase == CallPhase.incomingRinging || currentState.callId != null) {
      ref.read(callProvider.notifier).rejectCall();
    } else {
      // L'appel n'a pas encore été traité — rejeter directement via API
      final callId = extra['call_id']?.toString() ?? '';
      if (callId.isNotEmpty) {
        ref.read(callProvider.notifier).onIncomingCall(
          callId: callId,
          channelName: '',
          callerName: '',
          roomId: '',
          isVideo: false,
        );
        ref.read(callProvider.notifier).rejectCall();
      }
    }
  }

  /// Naviguer vers l'écran d'appel entrant (IncomingCallOverlay).
  void _navigateToIncomingCall() {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => const _IncomingCallScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  /// Naviguer vers le CallScreen (après acceptation).
  void _navigateToCallScreen() {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CallScreen()),
        (route) => route.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}


/// Écran d'appel entrant (overlay semi-transparent) avec effet Glassmorphism.
class _IncomingCallScreen extends ConsumerWidget {
  const _IncomingCallScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callProvider);

    // Si l'appel n'est plus en sonnerie entrante, fermer l'overlay
    if (callState.phase != CallPhase.incomingRinging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    final hasAvatar = callState.otherUserAvatar != null && callState.otherUserAvatar!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent, // Background transparent pour voir l'effet
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Arrière-plan flouté
          if (hasAvatar)
            Image.network(
              callState.otherUserAvatar!,
              fit: BoxFit.cover,
            )
          else
            Container(color: const Color(0xFF1E293B)), // Fallback dark gradient base

          // Couche d'assombrissement et de flou (Glassmorphism)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: Colors.black.withValues(alpha: 0.65), // Assombrir fortement l'arrière-plan
            ),
          ),

          // Contenu principal
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                
                // Avatar avec effet de lueur
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.2),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: CircleAvatar(
                      radius: 65,
                      backgroundColor: const Color(0xFF2A2A4A),
                      backgroundImage: hasAvatar ? NetworkImage(callState.otherUserAvatar!) : null,
                      child: !hasAvatar
                          ? const Icon(Icons.person, size: 65, color: Colors.white70)
                          : null,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Nom de l'appelant
                Text(
                  callState.otherUserName ?? 'Inconnu',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                // Type d'appel avec animation organique
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      callState.isVideo ? Icons.videocam : Icons.phone,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      callState.isVideo ? 'Appel vidéo entrant' : 'Appel audio entrant',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const _AnimatedRippleDots(), // Animation améliorée
                  ],
                ),
                
                const Spacer(flex: 3),
                
                // Boutons d'action (Accepter / Refuser) en mode premium
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Refuser
                      _PremiumCallActionButton(
                        icon: Icons.call_end,
                        color: Colors.redAccent.shade400,
                        label: 'Refuser',
                        onTap: () async {
                          await ref.read(callProvider.notifier).rejectCall();
                          if (context.mounted && Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      
                      // Accepter (Plus grand et animé)
                      _PremiumCallActionButton(
                        icon: Icons.call,
                        color: const Color(0xFF00C853), // Vert vibrant
                        label: 'Accepter',
                        isPulse: true, // Faire pulser le bouton d'acceptation
                        onTap: () async {
                          final success = await ref.read(callProvider.notifier).acceptCall();
                          if (success && context.mounted) {
                            // Remplacer l'overlay par le CallScreen
                            navigatorKey.currentState?.pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const CallScreen()),
                              (route) => route.isFirst,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton d'action Premium (Style Verre / iOS)
class _PremiumCallActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool isPulse;

  const _PremiumCallActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.isPulse = false,
  });

  @override
  State<_PremiumCallActionButton> createState() => _PremiumCallActionButtonState();
}

class _PremiumCallActionButtonState extends State<_PremiumCallActionButton> with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.isPulse) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat(reverse: true);
      _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget buttonWidget = GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.9), // Lame légèrement transcendante
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(widget.icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (widget.isPulse && _pulseAnimation != null) {
      return AnimatedBuilder(
        animation: _pulseAnimation!,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation!.value,
            child: child,
          );
        },
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }
}

/// Animation organique des 3 petits points
class _AnimatedRippleDots extends StatefulWidget {
  const _AnimatedRippleDots();

  @override
  State<_AnimatedRippleDots> createState() => _AnimatedRippleDotsState();
}

class _AnimatedRippleDotsState extends State<_AnimatedRippleDots> {
  int _dotCount = 0;
  late final StreamSubscription<int> _timer;

  @override
  void initState() {
    super.initState();
    _timer = Stream.periodic(
      const Duration(milliseconds: 600),
      (i) => (i % 4),
    ).listen((count) {
      if (mounted) setState(() => _dotCount = count);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    // On fixe la taille avec un SizedBox pour éviter que le texte tressaute
    return SizedBox(
      width: 24,
      child: Text(
        dots,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 18,
          fontWeight: FontWeight.w400,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
