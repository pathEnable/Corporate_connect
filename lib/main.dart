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
import 'providers/settings_provider.dart';
import 'providers/app_data_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/call/global_call_listener.dart';
import 'widgets/call/incoming_call_overlay.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ══ INIT FIREBASE & NOTIFICATIONS ══
  try {
    await PushNotificationService.initialize();
  } catch (e) {
    debugPrint("⚠️ Firebase non initialisé: $e");
  }
  
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

  // ══ INIT SÉQUENTIEL : DB + Cache SQLite AVANT l'UI ══
  // Ces opérations sont ultra-rapides (< 50ms total).
  // On les attend pour garantir que les données cached sont en mémoire
  // AVANT que l'UI ne se construise → affichage instantané.
  if (!kIsWeb) {
    await LocalDatabase.instance.database;
  }

  final isLoggedIn = await AuthService().isLoggedIn();
  if (isLoggedIn) {
    // Phase 1 (SQLite < 30ms) est awaité, Phase 2 (API) part en background
    await container.read(appDataProvider.notifier).initializeAfterLogin();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: AppResetter(
        child: CorporateConnectApp(isLoggedIn: isLoggedIn),
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

  // Vérifier les mises à jour une fois l'UI prête
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkUpdate();
  });
}

class CorporateConnectApp extends ConsumerWidget {
  final bool isLoggedIn;
  const CorporateConnectApp({super.key, required this.isLoggedIn});

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
      // Navigation directe : le cache est déjà en mémoire grâce au main()
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}

/// Vérifie les mises à jour disponibles après le démarrage
Future<void> _checkUpdate() async {
  try {
    final updateData = await UpdateService().checkForUpdate();
    if (updateData != null && navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (context) => UpdateDialog(
          apkUrl: updateData['apk_url'],
          versionName: updateData['version_name'],
        ),
      );
    }
  } catch (_) {}
}
