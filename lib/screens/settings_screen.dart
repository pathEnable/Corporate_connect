import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:audioplayers/audioplayers.dart';

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
    final theme = Theme.of(context);
    final settingsState = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          _buildSectionHeader('Apparence'),
          SwitchListTile(
            title: const Text('Mode sombre', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Applique le thème sombre à l\'application', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150))),
            value: settingsState.isDarkMode,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).toggleDarkMode(val);
            },
            secondary: Icon(Icons.dark_mode_rounded, color: theme.colorScheme.primary),
            activeThumbColor: theme.colorScheme.primary,
          ),
          Divider(indent: 72, color: theme.dividerColor.withAlpha(30)),

          _buildSectionHeader('Personnalisation'),
          ListTile(
            leading: Icon(Icons.palette_rounded, color: theme.colorScheme.primary),
            title: const Text('Couleur d\'accentuation', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildColorDot(0xFF26E9CF, settingsState.accentColor), // Turquoise (Emini)
                  _buildColorDot(0xFF00695C, settingsState.accentColor), // Midnight
                  _buildColorDot(0xFF2E7D32, settingsState.accentColor), // Emerald
                  _buildColorDot(0xFF1565C0, settingsState.accentColor), // Ocean
                  _buildColorDot(0xFF6A1B9A, settingsState.accentColor), // Amethyst
                  _buildColorDot(0xFF455A64, settingsState.accentColor), // Slate
                ],
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.text_fields_rounded, color: theme.colorScheme.primary),
            title: const Text('Taille du texte', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: settingsState.fontScale,
                  min: 0.8,
                  max: 1.3,
                  divisions: 5,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateFontScale(val);
                  },
                ),
                Text(
                  'Ajuste la taille de la police pour une meilleure lisibilité',
                  style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150), fontSize: 13),
                ),
              ],
            ),
          ),
          Divider(indent: 72, color: theme.dividerColor.withAlpha(30)),

          _buildSectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Notifications Push', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Recevoir des alertes pour les nouveaux messages', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150))),
            value: settingsState.notificationsEnabled,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).toggleNotifications(val);
            },
            activeThumbColor: theme.colorScheme.primary,
          ),
          ListTile(
            leading: Icon(Icons.music_note_rounded, color: theme.colorScheme.primary),
            title: const Text('Sonnerie', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(settingsState.ringtoneName, style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150))),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showRingtonePicker(context, ref, settingsState.ringtoneName),
          ),
          Divider(indent: 72, color: theme.dividerColor.withAlpha(30)),

          _buildSectionHeader('Stockage & Données'),
          ListTile(
            leading: Icon(Icons.storage_rounded, color: theme.colorScheme.primary),
            title: const Text('Vider le cache local', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Taille actuelle : ${settingsState.cacheSize} \nSupprime l\'historique hors-ligne de cet appareil.',
              style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150), fontSize: 13),
            ),
            trailing: TextButton(
              onPressed: () {
                _showClearCacheDialog(context, ref);
              },
              child: Text('VIDER', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
            ),
          ),
          Divider(indent: 72, color: theme.dividerColor.withAlpha(30)),

          _buildSectionHeader('À propos'),
          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
            title: const Text('Version de l\'application', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_version.isEmpty ? 'Chargement...' : _version, style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150))),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildColorDot(int colorValue, int selectedColor) {
    final isSelected = colorValue == selectedColor;
    return GestureDetector(
      onTap: () {
        ref.read(settingsProvider.notifier).updateAccentColor(colorValue);
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2) : null,
          boxShadow: [if (isSelected) BoxShadow(color: Color(colorValue).withAlpha(100), blurRadius: 8)],
        ),
        child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('Vider le cache ?'),
        content: const Text('Cette action supprimera tous les messages stockés localement sur cet appareil. Ils seront re-téléchargés depuis le serveur à la prochaine ouverture des salons. Continuer ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ANNULER', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150))),
          ),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).clearCache();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache vidé avec succès')),
              );
            },
            child: Text('VIDER LE CACHE', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRingtonePicker(BuildContext context, WidgetRef ref, String current) {
    final theme = Theme.of(context);
    final ringtones = ['Défaut', 'Emini Connect', 'Digital Sky', 'Smooth Wave', 'Minimalist'];
    final AudioPlayer previewPlayer = AudioPlayer();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Choisir une sonnerie', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          ...ringtones.map((name) => ListTile(
            title: Text(name),
            leading: Icon(Icons.music_note_rounded, color: theme.colorScheme.primary.withAlpha(current == name ? 255 : 100)),
            trailing: current == name ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) : null,
            onTap: () {
              ref.read(settingsProvider.notifier).updateRingtone(name);
              Navigator.pop(context);
            },
          )),
          const SizedBox(height: 24),
        ],
      ),
    ).then((_) => previewPlayer.dispose());
  }
}
