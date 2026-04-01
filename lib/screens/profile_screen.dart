import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/profile_provider.dart';
import '../services/media_service.dart';
import 'login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'key_backup_screen.dart';
import '../widgets/ui_helpers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(profileProvider.notifier).logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
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

  void _showEditProfileModal(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final bioController = TextEditingController(text: data['bio']);
    final titleController = TextEditingController(text: data['job_title']);
    final avatarController = TextEditingController(text: data['avatar_url']);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('Modifier Mon Profil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Titre professionnel',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: avatarController,
                decoration: InputDecoration(
                  labelText: "URL de l'image de profil (optionnel)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(profileProvider.notifier).updateProfile(
                      bio: bioController.text,
                      jobTitle: titleController.text,
                      avatarUrl: avatarController.text.isNotEmpty ? avatarController.text : null,
                    );
                  },
                  child: const Text('Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Le module "$feature" arrive bientôt !')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileProvider);
    final theme = Theme.of(context);

    if (state.isLoading && state.profileData == null) {
      return Scaffold(backgroundColor: theme.colorScheme.surface, body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)));
    }
    if (state.errorMessage != null && state.profileData == null) {
      return Scaffold(backgroundColor: theme.colorScheme.surface, body: Center(child: Text("Erreur: ${state.errorMessage}")));
    }
    if (state.profileData == null) {
      return Scaffold(backgroundColor: theme.colorScheme.surface, body: const Center(child: Text("Erreur de chargement du profil.")));
    }

    final data = state.profileData!;
    final String fullName = data['full_name'] ?? 'Utilisateur';
    final String? avatarUrl = data['avatar_url'];
    final String bio = data['bio'] ?? 'Aucune bio renseignée.';
    final String title = data['job_title'] ?? 'Poste non défini';
    final String phone = data['phone_number'] ?? 'Aucun téléphone';
    final String email = data['email'] ?? 'Aucun email';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Mon Profil'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          if (state.isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(profileProvider.notifier).refresh(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Stack(
                children: [
                   _AvatarView(avatarUrl: avatarUrl, initial: fullName[0].toUpperCase()),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _pickAndUploadAvatar(context, ref),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primary,
                        child: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(fullName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(100), 
                  borderRadius: BorderRadius.circular(16)
                ),
                child: Text(bio, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface, fontStyle: FontStyle.italic)),
              ),
              const SizedBox(height: 32),

              _buildInfoTile(Icons.phone_rounded, 'Téléphone', phone, context),
              _buildInfoTile(Icons.email_rounded, 'Email', email, context),
              
              const Divider(height: 32),
              
              // Section E2EE Professional Setup
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: state.hasE2eeKeys ? Colors.green.withAlpha(13) : Colors.orange.withAlpha(13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: state.hasE2eeKeys ? Colors.green.withAlpha(50) : Colors.orange.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.hasE2eeKeys ? Icons.verified_user_rounded : Icons.lock_open_rounded,
                      color: state.hasE2eeKeys ? Colors.green : Colors.orange,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.hasE2eeKeys ? "Protection E2EE Activée" : "E2EE non configuré",
                            style: TextStyle(fontWeight: FontWeight.bold, color: state.hasE2eeKeys ? Colors.green[800] : Colors.orange[800]),
                          ),
                          Text(
                            state.hasE2eeKeys ? "Vos échanges sont sécurisés par mnémonique." : "Configurez la sécurité pour protéger vos messages.",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.security_rounded, color: theme.colorScheme.primary),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KeyBackupScreen())),
                    ),
                  ],
                ),
              ),

              const Divider(height: 32),

              ListTile(
                leading: Icon(Icons.edit_rounded, color: theme.colorScheme.primary),
                title: const Text('Modifier mes informations'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showEditProfileModal(context, ref, data),
              ),
              ListTile(
                leading: Icon(Icons.notifications_active_rounded, color: theme.colorScheme.primary),
                title: const Text('Notifications'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showComingSoon(context, "Notifications"),
              ),
              ListTile(
                leading: Icon(Icons.privacy_tip_rounded, color: theme.colorScheme.primary),
                title: const Text('Confidentialité'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showComingSoon(context, "Confidentialité"),
              ),
              if (data['is_admin'] == true) ...[
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFC62828)),
                  title: const Text('Dashboard Admin', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Gérer les utilisateurs et voir les stats', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(context, FadeSlideRoute(page: const AdminDashboardScreen()));
                  },
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context, ref),
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  label: const Text('Déconnexion', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarView extends StatelessWidget {
  final String? avatarUrl;
  final String initial;

  const _AvatarView({required this.avatarUrl, required this.initial});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius: 60,
        backgroundColor: theme.colorScheme.primary,
        child: Text(initial, style: const TextStyle(fontSize: 48, color: Colors.white)),
      );
    }

    return FutureBuilder<String>(
      future: MediaService().getDownloadUrl(avatarUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CircleAvatar(
            radius: 60,
            backgroundColor: theme.colorScheme.primary,
            backgroundImage: NetworkImage(snapshot.data!),
          );
        }
        return CircleAvatar(
          radius: 60,
          backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      },
    );
  }
}
