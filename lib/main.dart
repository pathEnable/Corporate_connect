import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'package:lottie/lottie.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Préchauffage de la base de données locale pour un accès instantané au cache
  if (!kIsWeb) {
    await LocalDatabase.instance.database;
  }
  
  final stopwatch = Stopwatch()..start();
  runApp(const ProviderScope(child: CorporateConnectApp()));
  unawaited(_initializeBgServices(stopwatch));
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
      theme: AppTheme.lightTheme(settings.fontScale),
      darkTheme: AppTheme.darkTheme(settings.fontScale),
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

class _AuthGateState extends State<AuthGate> with TickerProviderStateMixin {
  late final AnimationController _lottieController;
  bool _isLoggedIn = false;
  bool _authChecked = false;
  bool _animationComplete = false;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    _checkAuth();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
    });
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService().isLoggedIn();
    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _authChecked = true;
      });
      _navigateIfReady();
    }
  }

  void _navigateIfReady() {
    if (_authChecked && _animationComplete && mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              _isLoggedIn ? const HomeScreen() : const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
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
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedOpacity(
        opacity: _animationComplete ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 400),
        child: Center(
          child: SizedBox(
            width: size.width * 0.85,
            child: Lottie.asset(
              'assets/images/logo_animation.json',
              controller: _lottieController,
              fit: BoxFit.contain,
              onLoaded: (composition) {
                _lottieController
                  ..duration = composition.duration
                  ..forward().whenComplete(() {
                    setState(() => _animationComplete = true);
                    // Petit délai pour laisser le fade-out se jouer
                    Future.delayed(const Duration(milliseconds: 500), () {
                      _navigateIfReady();
                    });
                  });
              },
            ),
          ),
        ),
      ),
    );
  }
}
