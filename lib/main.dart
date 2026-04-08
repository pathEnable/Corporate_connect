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
import 'package:shimmer/shimmer.dart';
import 'providers/settings_provider.dart';
import 'providers/home_provider.dart';
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

  // ══ INIT PARALLÈLE : DB locale + Firebase en même temps (gain ~200ms) ══
  final stopwatch = Stopwatch()..start();
  try {
    await Future.wait([
      if (!kIsWeb) LocalDatabase.instance.database,
      // placeholder pour d'autres inits futures
      Future.value(null),
    ]);
  } catch (e) {
    debugPrint("⚠️ Échec non bloquant lors de l'initialisation parallèle : $e");
  }
  stopwatch.stop();
  debugPrint("⚡ DB initialisée en ${stopwatch.elapsedMilliseconds}ms");

  // Container pour accéder aux providers hors arborescence (utilisé pour OfflineSyncService)
  final container = ProviderContainer();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AppResetter(
        child: CorporateConnectApp(),
      ),
    ),
  );
  
  // Services secondaires (Firebase Messaging, etc.) en arrière-plan total
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
  bool _isLoggedIn = false;
  bool _authChecked = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
    });
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService().isLoggedIn();

    // ══ PRÉ-CHAUFFAGE DU CACHE ══
    // Si l'utilisateur est connecté, on déclenche immédiatement le chargement
    // SQLite (< 30ms) EN ARRIÈRE-PLAN pendant la micro-animation de transition.
    // Quand HomeScreen apparaît, les données sont déjà en mémoire → zéro délai.
    if (loggedIn && !kIsWeb) {
      ref.read(homeProvider); // Réveille le notifier → _init() → SQLite
    }

    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _authChecked = true;
      });
      _navigate();
    }
  }

  void _navigate() {
    if (_authChecked && mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              _isLoggedIn ? const HomeScreen() : const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 250),
        ),
      );
    }
  }

  Future<void> _checkUpdate() async {
    final updateData = await UpdateService().checkForUpdate();
    if (updateData != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UpdateDialog(
          apkUrl: updateData['apk_url'],
          versionName: updateData['version_name'],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0);
    final highlightColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);

    // Shimmer de chargement : ressemble à l'écran Home pour une transition douce
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF040301) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Barre d'app fictive
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: Row(
                  children: [
                    Container(width: 160, height: 22, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const Spacer(),
                    Container(width: 36, height: 36, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Liste de conversations fictives (skeleton)
            Expanded(
              child: Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: ListView.builder(
                  itemCount: 8,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(width: 52, height: 52, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                              const SizedBox(height: 8),
                              Container(height: 12, width: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
