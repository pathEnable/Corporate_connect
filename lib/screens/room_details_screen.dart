import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_database.dart';
import '../services/media_service.dart';
import '../providers/profile_provider.dart';
import '../providers/room_details_provider.dart';
import '../widgets/premium_background.dart';
import '../widgets/authenticated_image.dart';
import 'image_viewer_screen.dart';
import 'add_member_picker_screen.dart';

class RoomDetailsScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;
  final bool isGroup;
  final List<Map<String, dynamic>> members;

  const RoomDetailsScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.isGroup,
    required this.members,
  });

  @override
  ConsumerState<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends ConsumerState<RoomDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Déléguer l'initialisation des membres au provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomDetailsProvider(widget.roomId).notifier).initMembers(widget.members);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Écoute les changements d'état pour afficher les SnackBars
    ref.listen(roomDetailsProvider(widget.roomId), (_, next) {
      if (!mounted) return;
      if (next.status == RoomDetailsStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
        ref.read(roomDetailsProvider(widget.roomId).notifier).clearFeedback();
      } else if (next.status == RoomDetailsStatus.success && next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!, style: const TextStyle(color: Colors.green))),
        );
        ref.read(roomDetailsProvider(widget.roomId).notifier).clearFeedback();
        // Retourner à l'écran précédent pour forcer le rechargement
        Navigator.pop(context, true);
      }
    });

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(theme),
            SliverToBoxAdapter(
              child: _buildTabHeader(theme),
            ),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMembersTab(),
                  _MediaTab(roomId: widget.roomId, type: 'image'),
                  _MediaTab(roomId: widget.roomId, type: 'file'),
                  _MediaTab(roomId: widget.roomId, type: 'audio'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.03),
      elevation: 0,
      shape: Border(
        bottom: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (widget.isGroup)
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showGroupMenu(context),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          widget.roomName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        background: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [theme.colorScheme.primary.withValues(alpha: 0.1), Colors.transparent],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'room_avatar_${widget.roomId}',
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.colorScheme.primary,
                    child: Icon(
                      widget.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                      size: 50,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabHeader(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF040301) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: theme.colorScheme.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(icon: Icon(Icons.people_alt_rounded, size: 20), text: 'Social'),
          Tab(icon: Icon(Icons.image_rounded, size: 20), text: 'Images'),
          Tab(icon: Icon(Icons.cloud_rounded, size: 20), text: 'Drive'),
          Tab(icon: Icon(Icons.mic_rounded, size: 20), text: 'Vocal'),
        ],
      ),
    );
  }

  // ─── Bottom Sheet "menu groupe" ─────────────────────────────────────────────

  void _showGroupMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
              title: const Text(
                'Quitter le groupe',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context); // fermer le bottom sheet
                _confirmLeaveRoom();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── Confirmation quitter le groupe (UI seule) ──────────────────────────────

  Future<void> _confirmLeaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le groupe ?'),
        content: const Text('Ceci supprimera le groupe de votre liste.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('QUITTER', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final profile = ref.read(profileProvider).profileData;
      if (profile != null) {
        // ✅ Logique métier dans le notifier, pas dans le widget
        final success = await ref
            .read(roomDetailsProvider(widget.roomId).notifier)
            .leaveRoom(widget.roomId, profile['id']);
        if (success && mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      }
    }
  }

  // ─── Onglet membres ─────────────────────────────────────────────────────────

  Widget _buildMembersTab() {
    final theme = Theme.of(context);
    final detailsState = ref.watch(roomDetailsProvider(widget.roomId));
    final currentUserId = ref.read(profileProvider).profileData?['id'];
    final members = detailsState.members.isNotEmpty ? detailsState.members : widget.members;
    final bool isUserAdmin = members.any(
      (m) => m['id'] == currentUserId && m['is_admin_member'] == true,
    );
    final isLoading = detailsState.status == RoomDetailsStatus.loading;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            if (widget.isGroup && isUserAdmin)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: ListTile(
                  onTap: isLoading ? null : () => _openAddMemberPicker(members),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_add_rounded, color: theme.colorScheme.primary, size: 22),
                  ),
                  title: Text(
                    'Ajouter des membres',
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ...members.map((member) {
              final bool isAdmin = member['is_admin_member'] == true;
              final bool isMe = member['id'] == currentUserId;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: isAdmin
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface.withValues(alpha: 0.2),
                  child: Text(
                    (member['full_name'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      color: isAdmin ? Colors.black : theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  isMe ? "${member['full_name']} (Vous)" : member['full_name'],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: isAdmin
                    ? Text(
                        'Admin',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      )
                    : null,
                trailing: isMe ? null : const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
              );
            }),
          ],
        ),
        // Indicateur de chargement global sans bloquer tout l'écran
        if (isLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  // ─── Navigation vers le sélecteur de membres ────────────────────────────────

  Future<void> _openAddMemberPicker(List<Map<String, dynamic>> members) async {
    final existingIds = members.map((m) => m['id'] as String).toList();
    final selectedIds = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddMemberPickerScreen(existingMemberIds: existingIds),
      ),
    );

    if (selectedIds != null && selectedIds.isNotEmpty && mounted) {
      // ✅ Logique métier dans le notifier, pas dans le widget
      await ref
          .read(roomDetailsProvider(widget.roomId).notifier)
          .addMembers(widget.roomId, selectedIds);
    }
  }
}

// ─── Widget dédié aux médias (images, fichiers, audio) ──────────────────────

class _MediaTab extends StatefulWidget {
  final String roomId;
  final String type;
  const _MediaTab({required this.roomId, required this.type});
  @override
  State<_MediaTab> createState() => _MediaTabState();
}

class _MediaTabState extends State<_MediaTab> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final msgs = await LocalDatabase.instance.getMediaMessages(widget.roomId, type: widget.type);
    if (mounted) setState(() { _messages = msgs; _isLoading = false; });
  }

  // ─── Icône selon l'extension du fichier ─────────────────────────────────

  static IconData _fileIcon(String url) {
    final ext = url.split('.').last.toLowerCase().split('?').first;
    switch (ext) {
      case 'pdf':  return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx': return Icons.description_rounded;
      case 'xls':
      case 'xlsx': return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx': return Icons.slideshow_rounded;
      case 'zip':
      case 'rar':  return Icons.folder_zip_rounded;
      case 'mp4':
      case 'mov':  return Icons.movie_rounded;
      case 'mp3':
      case 'wav':  return Icons.audiotrack_rounded;
      default:     return Icons.insert_drive_file_rounded;
    }
  }

  static Color _fileColor(String url) {
    final ext = url.split('.').last.toLowerCase().split('?').first;
    switch (ext) {
      case 'pdf':  return Colors.red;
      case 'doc':
      case 'docx': return Colors.blue.shade600;
      case 'xls':
      case 'xlsx': return Colors.green.shade600;
      case 'ppt':
      case 'pptx': return Colors.orange;
      case 'zip':
      case 'rar':  return Colors.brown;
      case 'mp4':
      case 'mov':  return Colors.purple;
      default:     return Colors.grey;
    }
  }

  // ─── Grouper les fichiers par mois ──────────────────────────────────────

  Map<String, List<Map<String, dynamic>>> _groupByMonth(List<Map<String, dynamic>> msgs) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final msg in msgs) {
      try {
        final dt = DateTime.parse(msg['created_at'].toString());
        final key = '${_monthName(dt.month)} ${dt.year}';
        grouped.putIfAbsent(key, () => []).add(msg);
      } catch (_) {
        grouped.putIfAbsent('Sans date', () => []).add(msg);
      }
    }
    return grouped;
  }

  String _monthName(int month) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.type == 'file' ? Icons.cloud_off_rounded : Icons.perm_media_outlined,
              size: 56,
              color: Colors.grey.withAlpha(100),
            ),
            const SizedBox(height: 12),
            Text(
              widget.type == 'file' ? 'Aucun fichier partagé' : 'Aucun media trouvé',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // ─── Onglet Images : grille ───────────────────────────────────────────
    if (widget.type == 'image') {
      return GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final url = _messages[index]['content'];
          return FutureBuilder<String>(
            future: MediaService().getDownloadUrl(url),
            builder: (context, snap) {
              if (snap.hasData) {
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ImageViewerScreen(imageUrl: snap.data!)),
                  ),
                  child: Hero(
                    tag: snap.data!,
                    child: AuthenticatedNetworkImage(imageUrl: snap.data!, fit: BoxFit.cover),
                  ),
                );
              }
              return Container(color: Colors.grey.withValues(alpha: 0.1));
            },
          );
        },
      );
    }

    // ─── Onglet Vocal : liste simple ──────────────────────────────────────
    if (widget.type == 'audio') {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          final theme = Theme.of(context);
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withAlpha(20),
              child: Icon(Icons.mic_rounded, color: theme.colorScheme.primary, size: 20),
            ),
            title: Text(
              msg['content'].toString().split('/').last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(msg['created_at'].toString().split('T')[0]),
          );
        },
      );
    }

    // ─── Onglet Drive (fichiers) : groupe par mois + icônes par type ─────
    final grouped = _groupByMonth(_messages);
    final groups = grouped.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: groups.length,
      itemBuilder: (context, gi) {
        final groupTitle = groups[gi].key;
        final files = groups[gi].value;
        final theme = Theme.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─ En-tête du groupe (mois) ─
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 14, color: theme.colorScheme.primary.withAlpha(180)),
                  const SizedBox(width: 6),
                  Text(
                    groupTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Divider(
                      color: theme.colorScheme.primary.withAlpha(30),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            // ─ Fichiers du groupe ─
            ...files.map((msg) {
              final url = msg['content'].toString();
              final fileName = url.split('/').last.split('?').first;
              final icon = _fileIcon(url);
              final color = _fileColor(url);
              final date = msg['created_at'].toString().split('T')[0];

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withAlpha(50)),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                title: Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                subtitle: Text(
                  date,
                  style: TextStyle(
                      fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(120)),
                ),
                trailing: Icon(Icons.download_rounded, color: theme.colorScheme.primary, size: 20),
              );
            }),
          ],
        );
      },
    );
  }
}
