import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = "";

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _version = '${info.version} (${info.buildNumber})';
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.tealAccent : const Color(0xFF004D40);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 1,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader('Apparence', primaryColor),
          SwitchListTile(
            title: const Text('Mode sombre'),
            subtitle: const Text('Appliquer le thème sombre à l\'application'),
            value: settingsState.isDarkMode,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).toggleDarkMode(val);
            },
            secondary: const Icon(Icons.dark_mode),
            activeColor: primaryColor,
          ),
          const Divider(),

          _buildSectionHeader('Notifications', primaryColor),
          SwitchListTile(
            title: const Text('Notifications Push'),
            subtitle: const Text('Recevoir des alertes pour les nouveaux messages'),
            value: settingsState.notificationsEnabled,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).toggleNotifications(val);
            },
            secondary: const Icon(Icons.notifications),
            activeColor: primaryColor,
          ),
          const Divider(),

          _buildSectionHeader('Stockage & Données', primaryColor),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Vider le cache local'),
            subtitle: Text('Taille actuelle : ${settingsState.cacheSize} \nAttention: Cela supprimera l\'historique hors-ligne.'),
            trailing: TextButton(
              onPressed: () {
                _showClearCacheDialog(context, ref);
              },
              child: Text('VIDER', style: TextStyle(color: Colors.red[400], fontWeight: FontWeight.bold)),
            ),
          ),
          const Divider(),

          _buildSectionHeader('À propos', primaryColor),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version de l\'application'),
            subtitle: Text(_version.isEmpty ? 'Chargement...' : _version),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider le cache ?'),
        content: const Text('Cette action supprimera tous les messages stockés localement sur cet appareil. Ils seront re-téléchargés depuis le serveur à la prochaine ouverture des salons. Continuer ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ANNULER'),
          ),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).clearCache();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache vidé avec succès')),
              );
            },
            child: const Text('VIDER', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
