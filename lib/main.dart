import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'services/update_service.dart';
import 'services/local_database.dart';
import 'widgets/update_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/settings_provider.dart';
import 'theme/app_theme.dart';
import 'dart:async';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Activer le mode edge-to-edge (plein écran)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    statusBarIconBrightness: Brightness.light, // Souvent blanc sur le splash
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Préchauffage de la base de données locale pour un accès instantané au cache
  if (!kIsWeb) {
    await LocalDatabase.instance.database;
  }
  
  final stopwatch = Stopwatch()..start();
  runApp(
    const ProviderScope(
      child: AppResetter(
        child: CorporateConnectApp(),
      ),
    ),
  );
  unawaited(_initializeBgServices(stopwatch));
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

Future<void> _initializeBgServices(Stopwatch stopwatch) async {
  try {
    await PushNotificationService.initialize();
    stopwatch.stop();
    debugPrint("⏱️ Services initialisés et UI prête en ${stopwatch.elapsedMilliseconds}ms");
  } catch (e) {
    debugPrint("⚠️ Erreur services arrière-plan: $e");
  }
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
          child: child!,
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
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
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
          transitionDuration: const Duration(milliseconds: 300),
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
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(), // Simple loader
      ),
    );
  }
}
