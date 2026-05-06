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
import 'services/biometric_service.dart';
import 'widgets/update_dialog.dart';
import 'widgets/lock_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/settings_provider.dart';
import 'providers/home_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/call/global_call_listener.dart';
import 'dart:async';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeDateFormatting('fr_FR', null);
  
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

  // ══ SOLUTION C — INIT PARALLÈLE AGRESSIVE ══
  // On ouvre la DB chiffrée ET on pré-instancie SharedPreferences en même temps.
  // SharedPrefs est utilisé par homeProvider._init() juste après : le pré-charger
  // ici évite une seconde attente du système et fait gagner ~150-300ms au total.
  final stopwatch = Stopwatch()..start();
  try {
    await Future.wait([
      if (!kIsWeb) LocalDatabase.instance.database,
      SharedPreferences.getInstance(), // Pré-cache SharedPrefs (utilisé par homeProvider)
    ]);
  } catch (e) {
    debugPrint("⚠️ Échec non bloquant lors de l'initialisation parallèle : $e");
  }
  
  // Vérifier le verrouillage biométrique AVANT runApp
  bool initialIsLocked = false;
  try {
    initialIsLocked = await BiometricService.instance.isEnabled();
  } catch (e) {
    debugPrint("Erreur vérification biométrique au démarrage: $e");
  }
  
  stopwatch.stop();
  debugPrint("⚡ DB initialisée en ${stopwatch.elapsedMilliseconds}ms");

  // Container pour accéder aux providers hors arborescence
  final container = ProviderContainer();

  // ══ SOLUTION A — PRÉCHAUFFAGE DU CACHE AVANT runApp ══
  // On déclenche homeProvider._init() ICI, avant même que l'arborescence
  // de widgets n'existe. Quand AuthGate demandera homeNotifier.initFuture,
  // le chargement SQLite sera déjà en cours (ou terminé), ce qui supprime
  // le flash "Aucun message" observé au premier rendu de HomeScreen.
  if (!kIsWeb) {
    container.read(homeProvider.notifier);
    debugPrint("⚡ homeProvider pré-initialisé avant runApp");
  }

  // DSN Configuration - à injecter via variables env ou config au besoin
  const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 1.0;
      },
      appRunner: () => runApp(
        UncontrolledProviderScope(
          container: container,
          child: AppResetter(
            child: CorporateConnectApp(initialIsLocked: initialIsLocked),
          ),
        ),
      ),
    );
  } else {
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: AppResetter(
          child: CorporateConnectApp(initialIsLocked: initialIsLocked),
        ),
      ),
    );
  }
  
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

class CorporateConnectApp extends ConsumerStatefulWidget {
  final bool initialIsLocked;
  
  const CorporateConnectApp({super.key, this.initialIsLocked = false});

  @override
  ConsumerState<CorporateConnectApp> createState() => _CorporateConnectAppState();
}

class _CorporateConnectAppState extends ConsumerState<CorporateConnectApp>
    with WidgetsBindingObserver {
  late bool _isLocked;
  // Horodatage de la dernière mise en pause (pour éviter les faux positifs)
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.initialIsLocked;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      // L'app passe en arrière-plan : vérifier si on doit verrouiller
      _checkAndLock();
    } else if (state == AppLifecycleState.resumed) {
      // L'app revient en premier plan : sync légère en arrière-plan.
      // On NE recharge PAS tout — juste un refresh silencieux si l'app
      // a été en pause au moins 30 secondes (pour éviter les refreshs
      // inutiles lors d'une courte interruption).
      final pausedAt = _pausedAt;
      if (pausedAt != null) {
        final elapsed = DateTime.now().difference(pausedAt);
        if (elapsed.inSeconds >= 30) {
          // Sync silencieuse : met à jour les rooms sans afficher de spinner
          ref.read(homeProvider.notifier).refreshRooms();
        }
      }
      _pausedAt = null;
    }
  }

  Future<void> _checkAndLock() async {
    final enabled = await BiometricService.instance.isEnabled();
    if (enabled && mounted) {
      setState(() => _isLocked = true);
    }
  }

  void _unlock() {
    if (mounted) setState(() => _isLocked = false);
  }

  @override
  Widget build(BuildContext context) {
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
                // Biometric lock overlay
                if (_isLocked)
                  LockScreen(onUnlocked: _unlock),
              ],
            ),
          ),
        );
      },
      theme: AppTheme.lightTheme(settings.fontScale, accentColorValue: settings.accentColor),
      darkTheme: AppTheme.darkTheme(settings.fontScale, accentColorValue: settings.accentColor),
      navigatorKey: navigatorKey,
      navigatorObservers: [
        SentryNavigatorObserver(),
      ],
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
    // ══ SOLUTION A — LANCEMENT PARALLÈLE AVEC GARDE TEMPORELLE ══
    // Le homeProvider a déjà été déclenché dans main() avant runApp.
    // Ici on récupère simplement son initFuture (déjà en cours d'exécution).
    final authFuture = AuthService().isLoggedIn();

    // Le provider est déjà en cours de chargement (pré-initialisé dans main()).
    // ref.read() retourne l'instance existante sans la recréer.
    final homeNotifier = ref.read(homeProvider.notifier);
    final cacheFuture = homeNotifier.initFuture;

    final loggedIn = await authFuture;

    if (loggedIn && !kIsWeb) {
      // On attend la fin du chargement SQLite, avec un timeout défensif de 2s.
      // Si la DB est anormalement lente, on navigue quand même pour ne pas
      // bloquer l'utilisateur — Riverpod mettra à jour l'UI dès que les
      // données arriveront.
      await cacheFuture.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint("⚠️ Cache SQLite timeout — navigation sans cache complet");
        },
      ); 
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
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF040301) : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo ou Icône simple au lieu de skeletons
            Icon(
              Icons.forum_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 24),
            Text(
              'Corporate Connect',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
