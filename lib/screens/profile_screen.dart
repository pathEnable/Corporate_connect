import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: PremiumBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ═══ SLIVER APP BAR avec photo de profil qui se réduit ═══
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                stretch: true,
                backgroundColor: isDark ? const Color(0xFF040301) : Colors.white,
                foregroundColor: Colors.white,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  titlePadding: const EdgeInsets.only(bottom: 16),
                  title: Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 12),
                      ],
                    ),
                  ),
                  background: _ProfileHeroHeader(
                    avatarUrl: avatarUrl,
                    initial: fullName[0].toUpperCase(),
                    status: status,
                    onPickAvatar: () => _pickAndUploadAvatar(context, ref),
                    primaryColor: theme.colorScheme.primary,
                  ),
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    onPressed: () => _editField(context, ref, 'full_name', fullName, 'Nom complet'),
                  ),
                ],
              ),

              // ═══ CONTENU SCROLLABLE ═══
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // --- Poste et Statut ---
                    Container(
                      width: double.infinity,
                      color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _StatusChip(status: status),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms),

                    const SizedBox(height: 8),

                    // --- À propos ---
                    _buildSectionCard(
                      context,
                      children: [
                        _buildEditableField(
                          context, ref,
                          icon: Icons.info_outline_rounded,
                          label: 'À propos',
                          value: bio,
                          onTap: () => _editField(context, ref, 'bio', bio, 'À propos'),
                        ),
                      ],
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),

                    const SizedBox(height: 8),

                    // --- Coordonnées ---
                    _buildSectionCard(
                      context,
                      children: [
                        _buildInfoRow(
                          context,
                          icon: Icons.phone_rounded,
                          label: 'Téléphone',
                          value: data['phone_number'] ?? 'Non fourni',
                        ),
                        _buildDivider(context),
                        _buildInfoRow(
                          context,
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: data['email'] ?? 'Non fourni',
                        ),
                      ],
                    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),

                    const SizedBox(height: 8),

                    // --- Statut de présence ---
                    _buildSectionCard(
                      context,
                      children: [
                        _buildStatusRow(context, ref, status),
                      ],
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),

                    const SizedBox(height: 8),

                    // --- Paramètres ---
                    _buildSectionCard(
                      context,
                      children: [
                        _buildSettingsRow(
                          context,
                          icon: Icons.lock_outline_rounded,
                          label: 'Chiffrement E2EE',
                          subtitle: state.hasE2eeKeys ? 'Clés configurées' : 'Non configuré',
                          trailing: state.hasE2eeKeys
                              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF26E9CF), size: 20)
                              : const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KeyBackupScreen())),
                        ),
                        _buildDivider(context),
                        _buildSettingsRow(
                          context,
                          icon: Icons.notifications_none_rounded,
                          label: 'Notifications',
                          subtitle: 'Alertes, sons et vibrations',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
                        ),
                        _buildDivider(context),
                        _buildSettingsRow(
                          context,
                          icon: Icons.privacy_tip_outlined,
                          label: 'Confidentialité',
                          subtitle: 'Visibilité et blocage',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySettingsScreen())),
                        ),
                        if (data['is_admin'] == true) ...[
                          _buildDivider(context),
                          _buildSettingsRow(
                            context,
                            icon: Icons.admin_panel_settings_outlined,
                            label: 'Administration',
                            subtitle: 'Gestion du système',
                            onTap: () => Navigator.push(context, FadeSlideRoute(page: const AdminDashboardScreen())),
                          ),
                        ],
                      ],
                    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05),

                    const SizedBox(height: 24),

                    // --- Déconnexion ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          _logout(context, ref);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Déconnexion',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 350.ms),

                    SizedBox(height: 20 + MediaQuery.of(context).viewPadding.bottom),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SECTION CARD CONTAINER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSectionCard(BuildContext context, {required List<Widget> children}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        border: Border.symmetric(
          horizontal: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 72,
      endIndent: 16,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
    );
  }

  Widget _buildInfoRow(BuildContext context, {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 24),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.45), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(BuildContext context, WidgetRef ref, {required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 24),
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.45), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.edit_rounded, size: 18, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, WidgetRef ref, String status) {
    final theme = Theme.of(context);
    final info = _StatusUI.fromKey(status);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _showStatusPicker(context, ref);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: info.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(info.icon, color: info.color, size: 14),
            ),
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Statut de présence', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.45), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(info.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRow(BuildContext context, {required IconData icon, required String label, String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 24),
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.45))),
                  ],
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          ],
        ),
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
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Modifier $fieldLabel', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 140,
              decoration: InputDecoration(
                hintText: 'Votre $fieldLabel...',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                      ref.read(profileProvider.notifier).updateProfile(bio: newValue);
                    }
                  }
                  Navigator.pop(context);
                },
                child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusPicker(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('Choisir votre statut', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ...['online', 'busy', 'dnd', 'meeting', 'remote'].map((key) {
              final info = _StatusUI.fromKey(key);
              return ListTile(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(profileProvider.notifier).updatePresenceStatus(key);
                  Navigator.pop(context);
                },
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: info.color.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(info.icon, color: info.color, size: 18),
                ),
                title: Text(info.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PROFILE HERO HEADER - Grand avatar centré avec gradient
// ═══════════════════════════════════════════════════════════════
class _ProfileHeroHeader extends StatelessWidget {
  final String? avatarUrl;
  final String initial;
  final String status;
  final VoidCallback onPickAvatar;
  final Color primaryColor;

  const _ProfileHeroHeader({
    required this.avatarUrl,
    required this.initial,
    required this.status,
    required this.onPickAvatar,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = _StatusUI.fromKey(status);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient de fond
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor.withValues(alpha: 0.3),
                const Color(0xFF040301),
              ],
            ),
          ),
        ),

        // Avatar au centre
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onPickAvatar();
                },
                child: Stack(
                  children: [
                    _LargeAvatar(avatarUrl: avatarUrl, initial: initial, primaryColor: primaryColor),
                    // Badge de statut
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF040301),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: statusInfo.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    // Icône caméra
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF040301), width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),

        // Gradient en bas pour la lisibilité du titre
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF040301)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STATUS CHIP - Petit badge affichant le statut sous le nom
// ═══════════════════════════════════════════════════════════════
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final info = _StatusUI.fromKey(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: info.color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: info.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            info.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: info.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  LARGE AVATAR - Utilisé dans le header
// ═══════════════════════════════════════════════════════════════
class _LargeAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initial;
  final Color primaryColor;

  const _LargeAvatar({required this.avatarUrl, required this.initial, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius: 56,
        backgroundColor: primaryColor,
        child: Text(initial, style: const TextStyle(fontSize: 48, color: Colors.black, fontWeight: FontWeight.w300)),
      );
    }

    return FutureBuilder<String>(
      future: MediaService().getDownloadUrl(avatarUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CircleAvatar(
            radius: 56,
            backgroundColor: primaryColor,
            backgroundImage: CachedNetworkImageProvider(snapshot.data!),
          );
        }
        return CircleAvatar(
          radius: 56,
          backgroundColor: primaryColor.withValues(alpha: 0.3),
          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
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

  factory _StatusUI.fromKey(String key) {
    switch (key) {
      case 'busy': return _StatusUI(Colors.amber, 'Occupé', Icons.do_not_disturb_on_rounded);
      case 'dnd': return _StatusUI(Colors.redAccent, 'Ne pas déranger', Icons.mode_night_rounded);
      case 'meeting': return _StatusUI(Colors.purpleAccent, 'En réunion', Icons.groups_rounded);
      case 'remote': return _StatusUI(Colors.lightBlueAccent, 'Télétravail', Icons.home_work_rounded);
      default: return _StatusUI(const Color(0xFF26E9CF), 'En ligne', Icons.check_circle_rounded);
    }
  }
}
