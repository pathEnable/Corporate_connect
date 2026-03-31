import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/media_service.dart';
import 'login_screen.dart';
import 'admin_dashboard_screen.dart';
import '../widgets/ui_helpers.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final MediaService _mediaService = MediaService();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getCurrentProfile();
      setState(() {
        _profileData = profile;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isLoading = true);
      try {
        final result = await _mediaService.uploadFile(File(image.path));
        final String newAvatarUrl = result['url'];
        await _authService.updateProfile(avatarUrl: newAvatarUrl);
        await _loadProfile();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur d'upload: $e")));
        }
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEditProfileModal() {
    final bioController = TextEditingController(text: _profileData?['bio']);
    final titleController = TextEditingController(text: _profileData?['job_title']);
    final avatarController = TextEditingController(text: _profileData?['avatar_url']);

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
                    setState(() => _isLoading = true);
                    try {
                      await _authService.updateProfile(
                        bio: bioController.text,
                        jobTitle: titleController.text,
                        avatarUrl: avatarController.text.isNotEmpty ? avatarController.text : null,
                      );
                      _loadProfile();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        setState(() => _isLoading = false);
                      }
                    }
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

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Le module "$feature" arrive bientôt !')));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF004D40))));
    }
    if (_profileData == null) {
      return const Scaffold(body: Center(child: Text("Erreur de chargement du profil.")));
    }

    final String fullName = _profileData!['full_name'] ?? 'Utilisateur';
    final String? avatarUrl = _profileData!['avatar_url'];
    final String bio = _profileData!['bio'] ?? 'Aucune bio renseignée.';
    final String title = _profileData!['job_title'] ?? 'Poste non défini';
    final String phone = _profileData!['phone_number'] ?? 'Aucun téléphone';
    final String email = _profileData!['email'] ?? 'Aucun email';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mon Profil'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              children: [
                FutureBuilder<Widget>(
                  future: _buildAvatarWidget(avatarUrl, fullName[0].toUpperCase()),
                  builder: (context, snapshot) {
                     if (snapshot.hasData) return snapshot.data!;
                     return const CircleAvatar(radius: 60, backgroundColor: Colors.grey);
                  }
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickAndUploadAvatar,
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

            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF004D40)),
              title: const Text('Modifier mes informations'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showEditProfileModal,
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined, color: Color(0xFF004D40)),
              title: const Text('Notifications'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showComingSoon("Notifications"),
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Color(0xFF004D40)),
              title: const Text('Confidentialité'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showComingSoon("Confidentialité"),
            ),
            // Section Admin (visible uniquement si admin)
            if (_profileData!['is_admin'] == true) ...[
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
                onPressed: _logout,
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

  Future<Widget> _buildAvatarWidget(String? url, String initial) async {
    if (url != null && url.isNotEmpty) {
      try {
        final downloadUrl = await _mediaService.getDownloadUrl(url);
        return CircleAvatar(
          radius: 60,
          backgroundColor: const Color(0xFF004D40),
          backgroundImage: NetworkImage(downloadUrl),
        );
      } catch (_) {
        // Fallback
      }
    }
    return CircleAvatar(
      radius: 60,
      backgroundColor: const Color(0xFF004D40),
      child: Text(initial, style: const TextStyle(fontSize: 48, color: Colors.white)),
    );
  }
}
