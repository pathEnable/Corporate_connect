import 'package:flutter/material.dart';
import '../widgets/authenticated_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/profile_provider.dart';
import '../services/media_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';
import '../providers/storage_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(profileProvider.notifier).logout();
    
    if (context.mounted) {
      AppResetter.reset(context);
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _pickAndUploadAvatar(BuildContext context, WidgetRef ref) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      await ref.read(profileProvider.notifier).updateAvatar(bytes, image.name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (state.isLoading && state.profileData == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Profil')),
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    final data = state.profileData ?? {};
    final String fullName = data['full_name'] ?? 'Utilisateur';
    final String? avatarUrl = data['avatar_url'];
    final String bio = data['bio'] ?? 'Aucune bio renseignée.';
    final String title = data['job_title'] ?? 'Poste non défini';
    final String status = data['presence_status'] ?? 'online';
    final String phone = data['phone_number'] ?? 'Non renseigné';
    final String email = data['email'] ?? 'Non renseigné';
    final bool isAdmin = data['is_admin'] == true;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Profil'),
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 16),
              
              // 1. Avatar central simplifié
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _pickAndUploadAvatar(context, ref);
                },
                child: Stack(
                  children: [
                    _LargeAvatar(
                      avatarUrl: avatarUrl,
                      initial: fullName[0].toUpperCase(),
                      primaryColor: theme.colorScheme.primary,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.scaffoldBackgroundColor, width: 3),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Nom en grand
              Text(
                fullName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              
              // Sélecteur de statut (Style Flat)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STATUT', style: _sectionTitleStyle(theme)),
                    const SizedBox(height: 12),
                    _buildStatusSelector(context, ref, theme, status),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              Divider(thickness: 8, color: isDark ? const Color(0xFF141414) : const Color(0xFFF0F3F6)),
              
              // 2. Informations de base (Listes flat style Whatsapp)
              _buildSectionTile(
                theme: theme,
                icon: Icons.person_outline_rounded,
                title: 'Nom',
                subtitle: fullName,
                onTap: () => _editField(context, ref, 'full_name', fullName, 'Nom complet'),
                showEditIcon: true,
              ),
              _buildDivider(),
              _buildSectionTile(
                theme: theme,
                icon: Icons.info_outline_rounded,
                title: 'Bio',
                subtitle: bio,
                onTap: () => _editField(context, ref, 'bio', bio, 'Bio'),
                showEditIcon: true,
                isMultiline: true,
              ),
              _buildDivider(),
              _buildSectionTile(
                theme: theme,
                icon: Icons.work_outline_rounded,
                title: 'Poste',
                subtitle: title,
                onTap: () => _editField(context, ref, 'job_title', title, 'Poste'),
                showEditIcon: true,
              ),

              Divider(thickness: 8, color: isDark ? const Color(0xFF141414) : const Color(0xFFF0F3F6)),

              // 3. Contact & Paramètres
              _buildSectionTile(
                theme: theme,
                icon: Icons.phone_android_rounded,
                title: 'Téléphone',
                subtitle: phone,
                onTap: () {}, // Ajouter modification téléphone plus tard si requis
              ),
              _buildDivider(),
              _buildSectionTile(
                theme: theme,
                icon: Icons.alternate_email_rounded,
                title: 'Email',
                subtitle: email,
                onTap: () {}, // Email généralement fixé ou géré différemment
              ),
              _buildDivider(),
              _buildSectionTile(
                theme: theme,
                icon: Icons.notifications_none_rounded,
                title: 'Paramètres système',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
              ),
              _buildDivider(),
              _buildSectionTile(
                theme: theme,
                icon: Icons.lock_outline_rounded,
                title: 'Confidentialité',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySettingsScreen())),
              ),
              
              if (isAdmin) ...[
                _buildDivider(),
                _buildSectionTile(
                  theme: theme,
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Administration',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
                ),
              ],

              Divider(thickness: 8, color: isDark ? const Color(0xFF141414) : const Color(0xFFF0F3F6)),
              
              _buildStorageSection(context, ref, theme),

              Divider(thickness: 8, color: isDark ? const Color(0xFF141414) : const Color(0xFFF0F3F6)),
              
              const SizedBox(height: 8),

              // Bouton déconnexion au format liste
              ListTile(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  _logout(context, ref);
                },
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text(
                  'Se déconnecter',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Emini Connect v1.2.0',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 80 + MediaQuery.of(context).viewPadding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _sectionTitleStyle(ThemeData theme) {
    return TextStyle(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      fontWeight: FontWeight.w600,
      fontSize: 13,
      letterSpacing: 0.5,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 72, endIndent: 0, thickness: 0.5);
  }

  Widget _buildSectionTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool showEditIcon = false,
    bool isMultiline = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 28),
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showEditIcon)
              Icon(Icons.edit_rounded, color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSelector(BuildContext context, WidgetRef ref, ThemeData theme, String currentStatus) {
    final statuses = ['online', 'busy', 'dnd', 'meeting', 'remote'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: statuses.map((statusKey) {
          final isSelected = currentStatus == statusKey;
          final info = _StatusUI.fromKey(statusKey, theme);
          
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                if (!isSelected) {
                  HapticFeedback.mediumImpact();
                  ref.read(profileProvider.notifier).updateProfile(presenceStatus: statusKey);
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? info.color.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? info.color : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(info.icon, size: 16, color: isSelected ? info.color : theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 8),
                    Text(
                      info.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? info.color : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStorageSection(BuildContext context, WidgetRef ref, ThemeData theme) {
    final storage = ref.watch(storageProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STOCKAGE ET DONNÉES', style: _sectionTitleStyle(theme)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surfaceContainer : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildStorageRow(
                  label: 'Messages & Cache DB',
                  size: storage.formattedMessageSize,
                  icon: Icons.message_outlined,
                  color: Colors.blueAccent,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                _buildStorageRow(
                  label: 'Médias (Images/Fichiers)',
                  size: storage.formattedMediaSize,
                  icon: Icons.image_outlined,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildStorageActionButton(
                        label: 'Optimiser',
                        icon: Icons.bolt_rounded,
                        onPressed: storage.isLoading ? null : () => ref.read(storageProvider.notifier).optimizeDatabase(),
                        theme: theme,
                        isPrimary: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStorageActionButton(
                        label: 'Vider',
                        icon: Icons.delete_outline_rounded,
                        onPressed: storage.isLoading 
                            ? null 
                            : () => _confirmClearCache(context, ref),
                        theme: theme,
                        isPrimary: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageRow({required String label, required String size, required IconData icon, required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ),
        Text(
          size,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildStorageActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required ThemeData theme,
    required bool isPrimary,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        foregroundColor: isPrimary ? theme.colorScheme.primary : Colors.redAccent,
        side: BorderSide(color: isPrimary ? theme.colorScheme.primary : Colors.redAccent.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _confirmClearCache(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le cache ?'),
        content: const Text('Cela supprimera les messages et médias stockés localement. Ils seront re-téléchargés si nécessaire.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              ref.read(storageProvider.notifier).clearMessageCache();
              ref.read(storageProvider.notifier).clearMediaCache();
              Navigator.pop(context);
            },
            child: const Text('Vider tout', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _editField(BuildContext context, WidgetRef ref, String fieldKey, String currentValue, String fieldLabel) {
    final controller = TextEditingController(text: currentValue);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modifier $fieldLabel', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: fieldKey == 'bio' ? 3 : 1,
              decoration: InputDecoration(
                hintText: 'Votre $fieldLabel...',
                filled: true,
                fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white, // assuming green button needs white text
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final newValue = controller.text.trim();
                  if (newValue.isNotEmpty) {
                    if (fieldKey == 'bio') {
                      ref.read(profileProvider.notifier).updateProfile(bio: newValue);
                    } else if (fieldKey == 'job_title') {
                      ref.read(profileProvider.notifier).updateProfile(jobTitle: newValue);
                    } else if (fieldKey == 'full_name') {
                      ref.read(profileProvider.notifier).updateProfile(fullName: newValue);
                    }
                  }
                  Navigator.pop(context);
                },
                child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initial;
  final Color primaryColor;

  const _LargeAvatar({required this.avatarUrl, required this.initial, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius: 70,
        backgroundColor: primaryColor.withValues(alpha: 0.1),
        child: Text(initial, style: TextStyle(fontSize: 48, color: primaryColor, fontWeight: FontWeight.w400)),
      );
    }

    return FutureBuilder<String>(
      future: MediaService().getDownloadUrl(avatarUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CircleAvatar(
            radius: 70,
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            backgroundImage: AuthenticatedImageProvider(snapshot.data!),
          );
        }
        return CircleAvatar(
          radius: 70,
          backgroundColor: primaryColor.withValues(alpha: 0.1),
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      },
    );
  }
}

class _StatusUI {
  final Color color;
  final String label;
  final IconData icon;

  _StatusUI(this.color, this.label, this.icon);

  factory _StatusUI.fromKey(String key, ThemeData theme) {
    switch (key) {
      case 'busy': return _StatusUI(Colors.amber, 'Occupé', Icons.do_not_disturb_on_rounded);
      case 'dnd': return _StatusUI(Colors.redAccent, 'Ne pas déranger', Icons.mode_night_rounded);
      case 'meeting': return _StatusUI(Colors.purpleAccent, 'En réunion', Icons.groups_rounded);
      case 'remote': return _StatusUI(Colors.lightBlueAccent, 'Télétravail', Icons.home_work_rounded);
      default: return _StatusUI(AppTheme.primaryGreen, 'En ligne', Icons.check_circle_rounded); // Fix color turquoise -> green
    }
  }
}
