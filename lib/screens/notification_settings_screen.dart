import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _showNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _groupNotifications = true;
  bool _callNotifications = true;
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
        _showNotifications = prefs.getBool('notifications_enabled') ?? true;
        _soundEnabled = prefs.getBool('notifications_sound') ?? true;
        _vibrationEnabled = prefs.getBool('notifications_vibration') ?? true;
        _groupNotifications = prefs.getBool('notifications_groups') ?? true;
        _callNotifications = prefs.getBool('notifications_calls') ?? true;
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
        title: const Text('Notifications'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              _buildSectionHeader(theme, 'Général'),
              SwitchListTile(
                value: _showNotifications,
                onChanged: (val) {
                  setState(() => _showNotifications = val);
                  _updateSetting('notifications_enabled', val);
                },
                title: const Text('Afficher les notifications'),
                subtitle: const Text('Activer ou désactiver toutes les alertes'),
                activeThumbColor: theme.colorScheme.primary,
              ),
              const Divider(),
              
              _buildSectionHeader(theme, 'Alertes Sonores'),
              SwitchListTile(
                value: _soundEnabled,
                onChanged: _showNotifications ? (val) {
                  setState(() => _soundEnabled = val);
                  _updateSetting('notifications_sound', val);
                } : null,
                title: const Text('Sons'),
                subtitle: const Text('Jouer un son à la réception d\'un message'),
              ),
              SwitchListTile(
                value: _vibrationEnabled,
                onChanged: _showNotifications ? (val) {
                  setState(() => _vibrationEnabled = val);
                  _updateSetting('notifications_vibration', val);
                } : null,
                title: const Text('Vibrations'),
                subtitle: const Text('Vibrer lors des notifications'),
              ),
              const Divider(),

              _buildSectionHeader(theme, 'Filtres par type'),
              SwitchListTile(
                value: _groupNotifications,
                onChanged: _showNotifications ? (val) {
                  setState(() => _groupNotifications = val);
                  _updateSetting('notifications_groups', val);
                } : null,
                title: const Text('Notifications de groupe'),
                secondary: const Icon(Icons.groups_rounded),
              ),
              SwitchListTile(
                value: _callNotifications,
                onChanged: _showNotifications ? (val) {
                  setState(() => _callNotifications = val);
                  _updateSetting('notifications_calls', val);
                } : null,
                title: const Text('Appels entrants'),
                secondary: const Icon(Icons.call_rounded),
              ),
              
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Note : Les paramètres de notification peuvent également être gérés dans les paramètres système de votre téléphone.',
                  style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
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
}
