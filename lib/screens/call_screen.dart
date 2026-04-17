import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart' show navigatorKey;
import '../models/call_state.dart';
import '../providers/call_provider.dart';
import '../screens/home_screen.dart';
import '../services/agora_service.dart';

/// Écran d'appel principal avec états visuels dynamiques.
/// 
/// Phases visuelles :
///   - outgoingRinging: Avatar + "Appel en cours..." + animation + bouton raccrocher
///   - connecting: Indicateur de chargement
///   - connected: Vidéo + timer + contrôles complets
///   - ended: Feedback "Appel terminé" avec durée
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);

    // Si l'appel est revenu à idle ou ended, quitter l'écran
    if (callState.phase == CallPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final nav = navigatorKey.currentState;
        if (nav == null) return;
        if (nav.canPop()) {
          nav.pop();
        } else {
          // CallScreen est la route racine (lancé depuis CallKit background)
          nav.pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      });
    }

    return PopScope(
      canPop: false, // Empêcher le swipe back
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showHangUpConfirmation(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Fond avec gradient
            _buildBackground(callState),

            // Contenu principal basé sur la phase
            SafeArea(
              child: _buildPhaseContent(callState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(CallState callState) {
    if (callState.phase == CallPhase.connected && callState.isVideo && callState.remoteUid != null) {
      // Afficher la vidéo distante en plein écran
      final engine = AgoraService().engine;
      if (engine != null) {
        return Container(
          color: Colors.black,
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: engine,
              canvas: VideoCanvas(uid: callState.remoteUid!),
              connection: RtcConnection(channelId: callState.channelName ?? ''),
            ),
          ),
        );
      }
    }

    // Si on a un avatar, on l'affiche en fond avec un gros flou
    final hasAvatar = callState.otherUserAvatar != null && callState.otherUserAvatar!.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasAvatar)
          Image.network(
            callState.otherUserAvatar!,
            fit: BoxFit.cover,
          )
        else
          Container(color: const Color(0xFF0F172A)), // Deep slate fallback

        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
          child: Container(
            color: Colors.black.withValues(alpha: 0.75), // Assombrir forttement
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseContent(CallState callState) {
    switch (callState.phase) {
      case CallPhase.outgoingRinging:
        return _buildOutgoingRinging(callState);
      case CallPhase.incomingRinging:
        return _buildConnecting(callState); // Ne devrait pas arriver ici
      case CallPhase.connecting:
        return _buildConnecting(callState);
      case CallPhase.connected:
        return _buildConnected(callState);
      case CallPhase.ended:
        return _buildEnded(callState);
      case CallPhase.idle:
        return const SizedBox.shrink();
    }
  }

  // ═══ ÉTAT : Appel sortant en sonnerie ═══
  Widget _buildOutgoingRinging(CallState callState) {
    return Column(
      children: [
        const SizedBox(height: 80),
        // Animation de pulsation sur l'avatar
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (_, __) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: _buildAvatar(callState, radius: 65),
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          callState.otherUserName ?? 'Inconnu',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        // Texte "Appel en cours..." avec animation
        _AnimatedDots(
          text: callState.isVideo ? 'Appel vidéo en cours' : 'Appel en cours',
        ),
        const SizedBox(height: 40),
        // Ondes visuelles
        _buildPulseRings(),
        const Spacer(),
        // Bouton raccrocher
        _buildHangUpButton(
          onTap: () => ref.read(callProvider.notifier).cancelCall().then((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  // ═══ ÉTAT : Connexion en cours ═══
  Widget _buildConnecting(CallState callState) {
    return Column(
      children: [
        const SizedBox(height: 80),
        _buildAvatar(callState, radius: 55),
        const SizedBox(height: 28),
        Text(
          callState.otherUserName ?? 'Inconnu',
          style: const TextStyle(
            color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white54),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Connexion...',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
        const Spacer(),
        _buildHangUpButton(
          onTap: () => ref.read(callProvider.notifier).hangUp().then((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  // ═══ ÉTAT : Appel connecté ═══
  Widget _buildConnected(CallState callState) {
    final engine = AgoraService().engine;
    final hasRemote = callState.remoteUid != null;

    return Column(
      children: [
        const SizedBox(height: 16),
        // Header : nom + timer
        Text(
          callState.otherUserName ?? 'Inconnu',
          style: const TextStyle(
            color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        // Timer de durée
        Text(
          _formatDuration(callState.callDuration),
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),

        // Si l'autre n'est pas encore arrivé dans le canal Agora,
        // afficher un indicateur discret (sans bloquer l'interface)
        if (!hasRemote) ...[
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white38),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'En attente de la connexion…',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],

        const Spacer(),

        // Appel audio sans vidéo : afficher l'avatar au centre
        if (!callState.isVideo)
          _buildAvatar(callState, radius: 55),

        // Vidéo locale (petit rectangle en bas à droite)
        if (callState.isVideo && !callState.isVideoDisabled && engine != null)
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 120,
              height: 160,
              margin: const EdgeInsets.only(right: 16, bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: engine,
                  canvas: const VideoCanvas(uid: 0),
                ),
              ),
            ),
          ),

        const Spacer(),

        // Contrôles
        _buildCallControls(callState),
        const SizedBox(height: 16),

        // Bouton raccrocher
        _buildHangUpButton(
          onTap: () => ref.read(callProvider.notifier).hangUp().then((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ═══ ÉTAT : Appel terminé ═══
  Widget _buildEnded(CallState callState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.call_end_rounded, size: 64, color: Colors.red),
        const SizedBox(height: 24),
        Text(
          callState.errorMessage ?? 'Appel terminé',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (callState.callDuration.inSeconds > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Durée : ${_formatDuration(callState.callDuration)}',
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ],
    );
  }

  // ═══ WIDGETS RÉUTILISABLES ═══

  Widget _buildAvatar(CallState callState, {double radius = 55}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.15),
            blurRadius: 50,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF2A2A4A),
          backgroundImage: callState.otherUserAvatar != null && callState.otherUserAvatar!.isNotEmpty
              ? NetworkImage(callState.otherUserAvatar!)
              : null,
          child: callState.otherUserAvatar == null || callState.otherUserAvatar!.isEmpty
              ? Icon(Icons.person, size: radius, color: Colors.white54)
              : null,
        ),
      ),
    );
  }

  Widget _buildPulseRings() {
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) {
              final delay = i * 0.33;
              final t = ((_pulseController.value + delay) % 1.0);
              // Lissage organic avec easeOut
              final curvedT = Curves.easeOut.transform(t);
              return Opacity(
                opacity: (1.0 - curvedT).clamp(0.0, 0.5),
                child: Container(
                  width: 80 + (curvedT * 140),
                  height: 80 + (curvedT * 140),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00C853).withValues(alpha: 0.8), // Vert plus visible
                      width: 2.0 - (curvedT * 1.5), // S'affine en grandissant
                    ),
                    color: const Color(0xFF00C853).withValues(alpha: 0.1), // Remplissage léger
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildCallControls(CallState callState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ControlButton(
                  icon: callState.isMuted ? Icons.mic_off : Icons.mic,
                  label: callState.isMuted ? 'Muet' : 'Micro',
                  isActive: callState.isMuted,
                  activeColor: Colors.white,
                  iconActiveColor: Colors.black87,
                  onTap: () => ref.read(callProvider.notifier).toggleMute(),
                ),
                if (callState.isVideo)
                  _ControlButton(
                    icon: callState.isVideoDisabled ? Icons.videocam_off : Icons.videocam,
                    label: callState.isVideoDisabled ? 'Vidéo off' : 'Vidéo',
                    isActive: callState.isVideoDisabled,
                    activeColor: Colors.white,
                    iconActiveColor: Colors.black87,
                    onTap: () => ref.read(callProvider.notifier).toggleVideo(),
                  ),
                _ControlButton(
                  icon: callState.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                  label: 'H-P',
                  isActive: callState.isSpeakerOn,
                  activeColor: Colors.white,
                  iconActiveColor: Colors.black87,
                  onTap: () => ref.read(callProvider.notifier).toggleSpeaker(),
                ),
                if (callState.isVideo)
                  _ControlButton(
                    icon: Icons.cameraswitch,
                    label: 'Retourner',
                    onTap: () => ref.read(callProvider.notifier).switchCamera(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHangUpButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          color: Colors.redAccent.shade400,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.5),
              blurRadius: 25,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.call_end,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showHangUpConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E).withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Raccrocher ?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Voulez-vous terminer cet appel ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Non', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(callProvider.notifier).hangUp();
            },
            child: const Text('Raccrocher', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ═══ Widgets auxiliaires ═══

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color iconActiveColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.activeColor = Colors.white,
    this.iconActiveColor = Colors.black87,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive ? activeColor : Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              boxShadow: isActive ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.4),
                  blurRadius: 15,
                  spreadRadius: 1,
                )
              ] : null,
            ),
            child: Icon(
              icon,
              color: isActive ? iconActiveColor : Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  final String text;
  const _AnimatedDots({required this.text});

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> {
  int _dotCount = 0;
  late final _timer = Stream.periodic(
    const Duration(milliseconds: 500),
    (i) => (i % 4),
  ).listen((count) {
    if (mounted) setState(() => _dotCount = count);
  });

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    return Text(
      '${widget.text}$dots',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 16,
        letterSpacing: 1,
      ),
    );
  }
}
