import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'services/update_service.dart';
import 'services/offline_sync_service.dart';
import 'services/local_database.dart';
import 'widgets/update_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'providers/settings_provider.dart';
import 'providers/app_data_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/call/global_call_listener.dart';
import 'widgets/call/incoming_call_overlay.dart';
import 'dart:async';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Activer le mode edge-to-edge
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final container = ProviderContainer();

  // ══ INIT PARALLÈLE ULTRA-RAPIDE ══
  // On ne bloque pas le démarrage de l'UI. La DB et l'Auth se chargent en parallèle.
  unawaited(Future.wait([
    if (!kIsWeb) LocalDatabase.instance.database,
    AuthService().isLoggedIn().then((isLoggedIn) {
      if (isLoggedIn) {
        container.read(appDataProvider.notifier).initializeAfterLogin();
      }
    }),
  ]));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AppResetter(
        child: CorporateConnectApp(),
      ),
    ),
  );
  
  // Services secondaires (Firebase, Sync) en arrière-plan total
  _initializeBgServices(container);
}

/// Widget permettant de réinitialiser toute l'arborescence de l'application (et donc les états Riverpod locaux)
class AppResetter extends StatefulWidget {
  final Widget child;
  const AppResetter({super.key, required this.child});

  static void reset(BuildContext context) {
    context.findAncestorStateOfType<_AppResetterState>()?.reset();
  }

  @override
  State<AppResetter> createState() => _AppResetterState();
}

class _AppResetterState extends State<AppResetter> {
  Key _key = UniqueKey();

  void reset() {
    setState(() {
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}

Future<void> _initializeBgServices(ProviderContainer container) async {
  try {
    await PushNotificationService.initialize();
    debugPrint("✅ Services push initialisés");
  } catch (e) {
    debugPrint("⚠️ Erreur services arrière-plan: $e");
  }
  
  // Démarrer la synchro hors-ligne via son provider
  final syncService = container.read(offlineSyncProvider);
  syncService.startListening();
  syncService.syncPendingRooms();
}

class CorporateConnectApp extends ConsumerWidget {
  const CorporateConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Emini Connect',
      debugShowCheckedModeBanner: false,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        final MediaQueryData data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(
            textScaler: TextScaler.linear(settings.fontScale),
          ),
          child: GlobalCallListener(
            child: Stack(
              children: [
                if (child != null) child,
                const IncomingCallOverlay(),
              ],
            ),
          ),
        );
      },
      theme: AppTheme.lightTheme(settings.fontScale, accentColorValue: settings.accentColor),
      darkTheme: AppTheme.darkTheme(settings.fontScale, accentColorValue: settings.accentColor),
      navigatorKey: navigatorKey,
      home: const AuthGate(),
    );
  }
}

/// Splash screen avec animation Lottie puis redirection
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {

  @override
  void initState() {
    super.initState();
    _handleStartup();
  }

  Future<void> _handleStartup() async {
    // 1. Vérifier l'auth (très rapide)
    final isLoggedIn = await AuthService().isLoggedIn();
    
    if (!mounted) return;

    if (isLoggedIn) {
      // 2. Si connecté, on attend que AppDataProvider ait fini la Phase 1 (chargement SQLite)
      // On met un timeout de sécurité au cas où le chargement SQLite échouerait silencieusement
      final startTime = DateTime.now();
      while (true) {
        final state = ref.read(appDataProvider);
        if (state.isInitialized) break;
        
        // Timeout après 1.5 seconde
        if (DateTime.now().difference(startTime).inMilliseconds > 1500) {
          debugPrint('⚠️ AuthGate: Timeout d\'initialisation du cache');
          break;
        }
        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;
      }
    }

    // 3. Navigation
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => isLoggedIn ? const HomeScreen() : const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }

    // Vérifier les mises à jour APRES être arrivé sur l'écran final
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
    });
  }

  Future<void> _checkUpdate() async {
    try {
      final updateData = await UpdateService().checkForUpdate();
      if (updateData != null && mounted) {
        showDialog(
          context: navigatorKey.currentContext ?? context,
          barrierDismissible: false,
          builder: (context) => UpdateDialog(
            apkUrl: updateData['apk_url'],
            versionName: updateData['version_name'],
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF040301) : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo premium avec animation
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.connect_without_contact_rounded,
                size: 60,
                color: theme.colorScheme.primary,
              ),
            )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.1, 1.1),
              duration: 2.seconds,
              curve: Curves.easeInOut,
            )
            .shimmer(delay: 1.seconds, duration: 2.seconds),
            
            const SizedBox(height: 32),
            
            // Texte de chargement subtil
            Text(
              'Corporate Connect',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: isDark ? Colors.white : Colors.black87,
              ),
            )
            .animate()
            .fadeIn(delay: 200.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
