import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/profile_provider.dart';
import '../services/media_service.dart';
import 'login_screen.dart';
import 'admin_dashboard_screen.dart';
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
      await ref.read(profileProvider.notifier).updateAvatar(File(image.path));
    }
  }

  void _showEditProfileModal(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final bioController = TextEditingController(text: data['bio']);
    final titleController = TextEditingController(text: data['job_title']);
    final avatarController = TextEditingController(text: data['avatar_url']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Modifier Mon Profil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Titre professionnel',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: avatarController,
                decoration: InputDecoration(
                  labelText: "URL de l'image de profil (optionnel)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(profileProvider.notifier).updateProfile(
                      bio: bioController.text,
                      jobTitle: titleController.text,
                      avatarUrl: avatarController.text.isNotEmpty ? avatarController.text : null,
                    );
                  },
                  child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
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

    if (state.isLoading && state.profileData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF004D40))));
    }
    if (state.errorMessage != null && state.profileData == null) {
      return Scaffold(body: Center(child: Text("Erreur: ${state.errorMessage}")));
    }
    if (state.profileData == null) {
      return const Scaffold(body: Center(child: Text("Erreur de chargement du profil.")));
    }

    final data = state.profileData!;
    final String fullName = data['full_name'] ?? 'Utilisateur';
    final String? avatarUrl = data['avatar_url'];
    final String bio = data['bio'] ?? 'Aucune bio renseignée.';
    final String title = data['job_title'] ?? 'Poste non défini';
    final String phone = data['phone_number'] ?? 'Aucun téléphone';
    final String email = data['email'] ?? 'Aucun email';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mon Profil'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        actions: [
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
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
                        backgroundColor: const Color(0xFF004D40),
                        child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
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
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: Text(bio, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[800], fontStyle: FontStyle.italic)),
              ),
              const SizedBox(height: 32),

              _buildInfoTile(Icons.phone, 'Téléphone', phone),
              _buildInfoTile(Icons.email, 'Email', email),
              
              const Divider(height: 32),
              
              // Section E2EE
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: state.hasE2eeKeys ? Colors.green.withValues(alpha: 0.05) : Colors.orange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: state.hasE2eeKeys ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.hasE2eeKeys ? Icons.lock : Icons.lock_open,
                      color: state.hasE2eeKeys ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.hasE2eeKeys ? "Chiffrement E2EE Activé" : "Clés E2EE manquantes",
                            style: TextStyle(fontWeight: FontWeight.bold, color: state.hasE2eeKeys ? Colors.green[800] : Colors.orange[800]),
                          ),
                          Text(
                            state.hasE2eeKeys ? "Vos messages sont protégés de bout-en-bout." : "Générez vos clés pour sécuriser vos échanges.",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: () => ref.read(profileProvider.notifier).regenerateE2eeKeys(),
                      tooltip: "Régénérer les clés",
                    ),
                  ],
                ),
              ),

              const Divider(height: 32),

              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF004D40)),
                title: const Text('Modifier mes informations'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEditProfileModal(context, ref, data),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined, color: Color(0xFF004D40)),
                title: const Text('Notifications'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context, "Notifications"),
              ),
              ListTile(
                leading: const Icon(Icons.security, color: Color(0xFF004D40)),
                title: const Text('Confidentialité'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context, "Confidentialité"),
              ),
              if (data['is_admin'] == true) ...[
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Color(0xFFC62828)),
                  title: const Text('Dashboard Admin', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Gérer les utilisateurs et voir les stats', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(context, FadeSlideRoute(page: const AdminDashboardScreen()));
                  },
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context, ref),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF004D40), size: 22),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16)),
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
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius: 60,
        backgroundColor: const Color(0xFF004D40),
        child: Text(initial, style: const TextStyle(fontSize: 48, color: Colors.white)),
      );
    }

    return FutureBuilder<String>(
      future: MediaService().getDownloadUrl(avatarUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CircleAvatar(
            radius: 60,
            backgroundColor: const Color(0xFF004D40),
            backgroundImage: NetworkImage(snapshot.data!),
          );
        }
        return CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey[200],
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      },
    );
  }
}
