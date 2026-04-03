import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/profile_provider.dart';
import '../services/media_service.dart';
import '../widgets/premium_background.dart';
import '../widgets/ui_helpers.dart';
import 'login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'key_backup_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileProvider);
    final theme = Theme.of(context);

    if (state.isLoading && state.profileData == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    final data = state.profileData ?? {};
    final String fullName = data['full_name'] ?? 'Utilisateur';
    final String? avatarUrl = data['avatar_url'];
    final String bio = data['bio'] ?? 'Aucune bio renseignée.';
    final String title = data['job_title'] ?? 'Poste non défini';
    final String status = data['presence_status'] ?? 'online';

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: RefreshIndicator(
          onRefresh: () => ref.read(profileProvider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              _buildLargeHeader(context, ref, fullName, avatarUrl, title, status),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 10),
                    _buildBioCard(theme, bio).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                    const SizedBox(height: 20),
                    _buildSectionHeader(theme, 'Statut & Présence'),
                    _buildStatusCard(context, ref, status).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),
                    const SizedBox(height: 20),
                    _buildSectionHeader(theme, 'Coordonnées'),
                    _buildInfoCard(context, data).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                    const SizedBox(height: 20),
                    _buildSectionHeader(theme, 'Sécurité & Paramètres'),
                    _buildSettingsCard(context, ref, data, state).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 32),
                    _buildLogoutButton(context, ref).animate().fadeIn(delay: 500.ms),
                    const SizedBox(height: 100), 
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeHeader(BuildContext context, WidgetRef ref, String name, String? avatarUrl, String title, String status) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 340,
      collapsedHeight: 100,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [theme.colorScheme.primary.withValues(alpha: 0.15), Colors.transparent],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Stack(
                  children: [
                    _AvatarView(avatarUrl: avatarUrl, initial: name[0].toUpperCase()),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: _buildStatusBadge(status, theme),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _pickAndUploadAvatar(context, ref);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.colorScheme.primary,
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().scale(curve: Curves.easeOutBack, duration: 600.ms),
                const SizedBox(height: 20),
                Text(
                  name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, ThemeData theme) {
    final info = _StatusUI.fromKey(status);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(color: info.color, shape: BoxShape.circle),
        child: status == 'dnd' ? const Icon(Icons.mode_night_rounded, size: 10, color: Colors.white) : 
               status == 'remote' ? const Icon(Icons.home_rounded, size: 10, color: Colors.white) : null,
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
     .shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.3));
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary.withValues(alpha: 0.8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildBioCard(ThemeData theme, String bio) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.format_quote_rounded, color: theme.colorScheme.primary.withValues(alpha: 0.3), size: 32),
            Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, WidgetRef ref, String status) {
    final info = _StatusUI.fromKey(status);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap: () {
          HapticFeedback.heavyImpact();
          _showStatusPicker(context, ref);
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: info.color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(info.icon, color: info.color, size: 24),
        ),
        title: const Text('Mon Statut', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        subtitle: Text(info.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, Map<String, dynamic> data) {
    return Card(
      child: Column(
        children: [
          _buildInfoTile(Icons.phone_iphone_rounded, 'Téléphone', data['phone_number'] ?? 'Non fourni', context),
          _buildInfoTile(Icons.alternate_email_rounded, 'Email', data['email'] ?? 'Non fourni', context, showDivider: false),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, WidgetRef ref, Map<String, dynamic> data, dynamic state) {
    return Card(
      child: Column(
        children: [
          _buildInfoTile(
            Icons.verified_user_outlined, 
            'Sécurité E2EE', 
            state.hasE2eeKeys ? 'Configuré' : 'Non configuré', 
            context,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KeyBackupScreen())),
            trailing: state.hasE2eeKeys 
                ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)
                : const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          ),
          _buildInfoTile(
            Icons.notifications_none_rounded, 
            'Notifications', 
            'Alertes et sons', 
            context,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
          ),
          _buildInfoTile(
            Icons.privacy_tip_outlined, 
            'Confidentialité', 
            'Visibilité et blocage', 
            context,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySettingsScreen())),
          ),
          if (data['is_admin'] == true)
            _buildInfoTile(
              Icons.admin_panel_settings_outlined, 
              'Dashboard Admin', 
              'Gestion du système', 
              context,
              onTap: () => Navigator.push(context, FadeSlideRoute(page: const AdminDashboardScreen())),
              showDivider: false,
            ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.redAccent, width: 1.2),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: () {
        HapticFeedback.heavyImpact();
        _logout(context, ref);
      },
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, BuildContext context, {VoidCallback? onTap, bool showDivider = true, Widget? trailing}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                trailing ?? const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
              ],
            ),
          ),
          if (showDivider)
            Divider(height: 1, indent: 64, endIndent: 16, color: theme.dividerColor.withValues(alpha: 0.1)),
        ],
      ),
    );
  }

  void _showStatusPicker(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                const Text('Choisir votre statut', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),
                ...['online', 'busy', 'dnd', 'meeting', 'remote'].map((key) {
                  final info = _StatusUI.fromKey(key);
                  return ListTile(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(profileProvider.notifier).updatePresenceStatus(key);
                      Navigator.pop(context);
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: info.color.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(info.icon, color: info.color, size: 20),
                    ),
                    title: Text(info.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.add_rounded, size: 18, color: Colors.grey),
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusUI {
  final Color color;
  final String label;
  final IconData icon;

  _StatusUI(this.color, this.label, this.icon);

  factory _StatusUI.fromKey(String key) {
    switch (key) {
      case 'busy': return _StatusUI(Colors.amber, 'Occupé', Icons.do_not_disturb_on_rounded);
      case 'dnd': return _StatusUI(Colors.redAccent, 'Ne pas déranger', Icons.mode_night_rounded);
      case 'meeting': return _StatusUI(Colors.purpleAccent, 'En réunion', Icons.groups_rounded);
      case 'remote': return _StatusUI(Colors.lightBlueAccent, 'Télétravail', Icons.home_work_rounded);
      default: return _StatusUI(const Color(0xFF00D2C1), 'En ligne', Icons.check_circle_rounded);
    }
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
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: -10),
          ],
        ),
        child: CircleAvatar(
          radius: 64,
          backgroundColor: theme.colorScheme.primary,
          child: Text(initial, style: const TextStyle(fontSize: 54, color: Colors.white, fontWeight: FontWeight.w200)),
        ),
      );
    }

    return FutureBuilder<String>(
      future: MediaService().getDownloadUrl(avatarUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: -10),
              ],
            ),
            child: CircleAvatar(
              radius: 64,
              backgroundColor: theme.colorScheme.primary,
              backgroundImage: NetworkImage(snapshot.data!),
            ),
          );
        }
        return CircleAvatar(
          radius: 64,
          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      },
    );
  }
}
