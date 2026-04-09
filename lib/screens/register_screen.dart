import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/premium_background.dart';
import '../services/auth_service.dart';
import '../providers/app_data_provider.dart';
import 'home_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final AuthService _authService = AuthService();
  final PageController _pageController = PageController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _currentStep = 0;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        _showError('Veuillez remplir votre email et mot de passe');
        return;
      }
    } else if (_currentStep == 1) {
      if (_fullNameController.text.isEmpty || _usernameController.text.isEmpty) {
        _showError('Veuillez remplir vos informations personnelles');
        return;
      }
    }

    if (_currentStep < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _register();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orangeAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _register() async {
    if (_phoneController.text.isEmpty) {
      _showError('Veuillez entrer votre numéro de téléphone');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.register(
        _fullNameController.text,
        _usernameController.text,
        _emailController.text,
        _passwordController.text,
        _phoneController.text,
      );
      if (mounted) {
        // Déclencher le pré-chargement global (non bloquant) 
        ref.read(appDataProvider.notifier).initializeAfterLogin();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
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
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: _prevStep,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ProgressBar
                    Row(
                      children: List.generate(3, (index) {
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(right: index < 2 ? 8.0 : 0),
                            decoration: BoxDecoration(
                              color: _currentStep >= index ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.zero, // Flat design
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    Hero(
                      tag: 'app_logo_text',
                      child: Text(
                        'Créer un compte',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rejoignez la plateforme Corporate Connect',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1(theme),
                    _buildStep2(theme),
                    _buildStep3(theme),
                  ],
                ),
              ),
  
              Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewPadding.bottom),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Flat design
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_currentStep == 2 ? "Valider l'inscription" : "Suivant"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Étape 1 sur 3", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Vos Identifiants", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email professionnel',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Étape 2 sur 3", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Vos Informations", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _fullNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nom et Prénom',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: "Nom d'utilisateur",
              prefixIcon: const Icon(Icons.alternate_email),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Étape 3 sur 3", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Contact et Sécurité", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Numéro de téléphone',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary.withAlpha(100)),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: theme.colorScheme.primary, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "Ce système utilise le chiffrement de bout en bout. Après inscription, vous pourrez générer vos clés de sécurité privées.",
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
