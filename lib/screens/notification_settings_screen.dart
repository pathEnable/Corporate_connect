import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/premium_background.dart';

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
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewPadding = MediaQuery.of(context).padding;

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    floating: true,
                    pinned: true,
                    title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w900)),
                    backgroundColor: Colors.black.withValues(alpha: 0.8),
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    centerTitle: false,
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildSectionHeader(theme, 'Interrupteur Général'),
                          _buildGroupCard(
                            theme,
                            [
                              _buildSettingTile(
                                theme,
                                title: 'Afficher les notifications',
                                subtitle: 'Activer ou désactiver toutes les alertes',
                                value: _showNotifications,
                                icon: Icons.notifications_active_rounded,
                                iconColor: theme.colorScheme.primary,
                                onChanged: (val) {
                                  setState(() => _showNotifications = val);
                                  _updateSetting('notifications_enabled', val);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          _buildSectionHeader(theme, 'Alertes Sonores & Vibrations'),
                          _buildGroupCard(
                            theme,
                            [
                              _buildSettingTile(
                                theme,
                                title: 'Sons',
                                subtitle: 'Jouer un son à la réception d\'un message',
                                value: _soundEnabled,
                                icon: Icons.volume_up_rounded,
                                enabled: _showNotifications,
                                onChanged: (val) {
                                  setState(() => _soundEnabled = val);
                                  _updateSetting('notifications_sound', val);
                                },
                              ),
                              _buildDivider(theme),
                              _buildSettingTile(
                                theme,
                                title: 'Vibrations',
                                subtitle: 'Vibrer lors des notifications',
                                value: _vibrationEnabled,
                                icon: Icons.vibration_rounded,
                                enabled: _showNotifications,
                                onChanged: (val) {
                                  setState(() => _vibrationEnabled = val);
                                  _updateSetting('notifications_vibration', val);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          _buildSectionHeader(theme, 'Canaux de notification'),
                          _buildGroupCard(
                            theme,
                            [
                              _buildSettingTile(
                                theme,
                                title: 'Notifications de groupe',
                                subtitle: 'Messages reçus dans les salons',
                                value: _groupNotifications,
                                icon: Icons.groups_rounded,
                                enabled: _showNotifications,
                                onChanged: (val) {
                                  setState(() => _groupNotifications = val);
                                  _updateSetting('notifications_groups', val);
                                },
                              ),
                              _buildDivider(theme),
                              _buildSettingTile(
                                theme,
                                title: 'Appels entrants',
                                subtitle: 'Notifications pour les appels',
                                value: _callNotifications,
                                icon: Icons.call_rounded,
                                enabled: _showNotifications,
                                onChanged: (val) {
                                  setState(() => _callNotifications = val);
                                  _updateSetting('notifications_calls', val);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'Les paramètres système de votre appareil peuvent primer sur ces préférences.',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // Padding de sécurité pour la navigation bar
                          SizedBox(height: 120 + viewPadding.bottom),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.colorScheme.primary.withValues(alpha: 0.8),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
    );
  }

  Widget _buildGroupCard(ThemeData theme, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    Color? iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      enabled: enabled,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: enabled ? (iconColor ?? theme.colorScheme.primary) : Colors.grey,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeThumbColor: theme.colorScheme.primary,
        activeTrackColor: theme.colorScheme.primary.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      indent: 72,
      endIndent: 20,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
    );
  }
}
