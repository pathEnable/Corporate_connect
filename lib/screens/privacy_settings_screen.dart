import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _lastSeen = true;
  bool _readReceipts = true;
  bool _groupPrivacy = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _lastSeen = prefs.getBool('privacy_last_seen') ?? true;
        _readReceipts = prefs.getBool('privacy_read_receipts') ?? true;
        _groupPrivacy = prefs.getBool('privacy_groups') ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Confidentialité'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              _buildSectionHeader(theme, 'Qui peut voir mes infos'),
              _buildModernTile(
                icon: Icons.visibility_rounded,
                title: 'Présence en ligne',
                subtitle: 'Afficher votre dernière connexion',
                value: _lastSeen,
                onChanged: (val) {
                  setState(() => _lastSeen = val);
                  _updateSetting('privacy_last_seen', val);
                },
                theme: theme,
              ),
              _buildModernTile(
                icon: Icons.done_all_rounded,
                title: 'Confirmations de lecture',
                subtitle: 'Si désactivé, vous ne verrez pas non plus les confirmations des autres.',
                value: _readReceipts,
                onChanged: (val) {
                  setState(() => _readReceipts = val);
                  _updateSetting('privacy_read_receipts', val);
                },
                theme: theme,
              ),
              const Divider(),
              
              _buildSectionHeader(theme, 'Groupes'),
              _buildModernTile(
                icon: Icons.group_add_rounded,
                title: 'Ajout aux groupes',
                subtitle: 'Autoriser tout le monde à vous ajouter',
                value: _groupPrivacy,
                onChanged: (val) {
                  setState(() => _groupPrivacy = val);
                  _updateSetting('privacy_groups', val);
                },
                theme: theme,
              ),
              const Divider(),

              ListTile(
                leading: const Icon(Icons.block_rounded, color: Colors.red),
                title: const Text('Utilisateurs bloqués'),
                subtitle: const Text('Gérer la liste des contacts bloqués'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Liste des bloqués - fonctionnalité à venir.'))
                  );
                },
              ),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildModernTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title),
      subtitle: Text(subtitle),
      activeThumbColor: theme.colorScheme.primary,
      secondary: Icon(icon, color: theme.colorScheme.primary),
    );
  }
}
