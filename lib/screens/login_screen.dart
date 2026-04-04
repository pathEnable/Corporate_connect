
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/premium_background.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Controllers Email
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Controllers Phone
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await _authService.loginWithEmail(_emailController.text, _passwordController.text);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await _authService.sendOtp(_phoneController.text);
      if (mounted) setState(() => _otpSent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _isLoading = true);
    try {
      await _authService.verifyOtp(_phoneController.text, _otpController.text);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: PremiumBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).viewPadding.top + 24, 24, 24 + MediaQuery.of(context).viewPadding.bottom),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Logo & Title
                Hero(
                  tag: 'app_logo',
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chat_bubble_rounded, size: 64, color: colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Corporate Connect',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Communication interne sécurisée',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 48),

              // Tab Bar
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
                  borderRadius: BorderRadius.zero, // Flat design
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.zero, // Flat design
                  ),
                  labelColor: isDark ? Colors.black : Colors.white,
                  unselectedLabelColor: theme.hintColor,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  tabs: const [
                    Tab(text: 'EMAIL PRO'),
                    Tab(text: 'TÉLÉPHONE'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Tab Views
              SizedBox(
                height: 280,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEmailTab(theme),
                    _buildPhoneTab(theme),
                  ],
                ),
              ),

                const SizedBox(height: 16),
                // Bouton d'inscription
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: Text(
                    'PAS DE COMPTE ? INSCRIVEZ-VOUS',
                    style: TextStyle(
                      color: colorScheme.primary, 
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailTab(ThemeData theme) {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email professionnel',
            prefixIcon: const Icon(Icons.email_outlined),
            filled: true,
            fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.grey[50],
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.grey[50],
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          onPressed: _isLoading ? null : _loginWithEmail,
          child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('SE CONNECTER'),
        ),
      ],
    );
  }

  Widget _buildPhoneTab(ThemeData theme) {
    return Column(
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Numéro de téléphone',
            prefixIcon: const Icon(Icons.phone_outlined),
            filled: true,
            fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.grey[50],
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
        ),
        if (_otpSent) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Code OTP',
              prefixIcon: const Icon(Icons.pin_outlined),
              filled: true,
              fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.grey[50],
              border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
            ),
          ),
        ],
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          onPressed: _isLoading ? null : (_otpSent ? _verifyOtp : _sendOtp),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_otpSent ? 'VÉRIFIER LE CODE' : 'ENVOYER LE CODE SMS'),
        ),
      ],
    );
  }
}
