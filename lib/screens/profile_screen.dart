import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/profile_provider.dart';
import '../services/media_service.dart';
import '../widgets/premium_background.dart';
import '../main.dart';
import 'login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'notification_settings_screen.dart';

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
      // 1. Réinitialisation globale de l'état (Riverpod providers + UI Tree)
      AppResetter.reset(context);
      
      // 2. Redirection vers l'écran de connexion
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
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                stretch: true,
                backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.white,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
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

              // ═══ CONTENU SCROLLABLE (DESIGN PREMIUM) ═══
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF040301) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(theme, 'MON STATUT'),
                        const SizedBox(height: 12),
                        _buildStatusSelector(context, ref, theme, status),
                        
                        const SizedBox(height: 24),
                        _buildSectionTitle(theme, 'À PROPOS'),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          theme,
                          child: Column(
                            children: [
                              _buildInfoRow(
                                theme,
                                icon: Icons.person_outline_rounded,
                                label: 'Nom complet',
                                value: fullName,
                              ),
                              _buildDivider(theme),
                              _buildInfoRow(
                                theme,
                                icon: Icons.work_outline_rounded,
                                label: 'Poste',
                                value: title,
                              ),
                              _buildDivider(theme),
                              _buildInfoRow(
                                theme,
                                icon: Icons.info_outline_rounded,
                                label: 'Bio',
                                value: bio,
                                isMultiline: true,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        _buildSectionTitle(theme, 'CONTACT & RÉGLAGES'),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          theme,
                          child: Column(
                            children: [
                              _buildActionTile(
                                theme,
                                icon: Icons.phone_android_rounded,
                                title: 'Téléphone',
                                subtitle: data['phone_number'] ?? 'Non renseigné',
                                onTap: () {},
                              ),
                              _buildDivider(theme),
                              _buildActionTile(
                                theme,
                                icon: Icons.email_outlined,
                                title: 'Email',
                                subtitle: data['email'] ?? 'Non renseigné',
                                onTap: () {},
                              ),
                              _buildDivider(theme),
                              _buildActionTile(
                                theme,
                                icon: Icons.notifications_none_rounded,
                                title: 'Paramètres système',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
                              ),
                              if (data['is_admin'] == true) ...[
                                _buildDivider(theme),
                                _buildActionTile(
                                  theme,
                                  icon: Icons.admin_panel_settings_outlined,
                                  title: 'Administration',
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 48),
                        
                        // --- Déconnexion ---
                        _buildInfoCard(
                          theme,
                          color: Colors.redAccent.withValues(alpha: 0.05),
                          borderColor: Colors.redAccent.withValues(alpha: 0.2),
                          child: ListTile(
                            onTap: () {
                              HapticFeedback.heavyImpact();
                              _logout(context, ref);
                            },
                            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                            title: const Text(
                              'Se déconnecter',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded, color: Colors.redAccent.withValues(alpha: 0.5)),
                          ),
                        ),

                        const SizedBox(height: 32),
                        
                        // Version de l'application
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'EMINI CONNECT',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'v1.2.0 - Stable Release',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Espace supplémentaire pour éviter la barre de navigation (Fix Scroll)
                        SizedBox(height: 120 + MediaQuery.of(context).viewPadding.bottom),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.primary.withValues(alpha: 0.8),
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, {required Widget child, Color? color, Color? borderColor}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color ?? (theme.brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(ThemeData theme, {required IconData icon, required String label, required String value, bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(ThemeData theme, {required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), size: 22),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))) : null,
      trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  Widget _buildStatusSelector(BuildContext context, WidgetRef ref, ThemeData theme, String currentStatus) {
    final statuses = ['online', 'busy', 'dnd', 'meeting', 'remote'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: statuses.map((statusKey) {
          final isSelected = currentStatus == statusKey;
          final info = _StatusUI.fromKey(statusKey);
          
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                if (!isSelected) {
                  HapticFeedback.mediumImpact();
                  ref.read(profileProvider.notifier).updateProfile(presenceStatus: statusKey);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? info.color.withValues(alpha: 0.15) : theme.colorScheme.onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? info.color.withValues(alpha: 0.5) : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(info.icon, size: 18, color: isSelected ? info.color : theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 8),
                    Text(
                      info.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
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

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      indent: 72,
      endIndent: 16,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
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
              maxLines: fieldKey == 'bio' ? 3 : 1,
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
                      ref.read(profileProvider.notifier).updateProfile(fullName: newValue);
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
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor.withValues(alpha: 0.35),
                const Color(0xFF040301),
              ],
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 44),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onPickAvatar();
                },
                child: Stack(
                  children: [
                    _LargeAvatar(avatarUrl: avatarUrl, initial: initial, primaryColor: primaryColor),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Color(0xFF040301), shape: BoxShape.circle),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(color: statusInfo.color, shape: BoxShape.circle),
                        ),
                      ),
                    ),
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
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 90,
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
        radius: 64,
        backgroundColor: primaryColor,
        child: Text(initial, style: const TextStyle(fontSize: 52, color: Colors.black, fontWeight: FontWeight.w300)),
      );
    }

    return FutureBuilder<String>(
      future: MediaService().getDownloadUrl(avatarUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CircleAvatar(
            radius: 64,
            backgroundColor: primaryColor,
            backgroundImage: CachedNetworkImageProvider(snapshot.data!),
          );
        }
        return CircleAvatar(
          radius: 64,
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
