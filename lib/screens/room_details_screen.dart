import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_database.dart';
import '../services/media_service.dart';
import '../services/room_service.dart';
import '../providers/profile_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/chat/message_bubble.dart';
import 'image_viewer_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

class _RoomDetailsScreenState extends ConsumerState<RoomDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Détails du groupe'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          if (widget.isGroup)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'leave') _leaveRoom();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app_rounded, color: Colors.red, size: 20),
                      SizedBox(width: 12),
                      Text('Quitter le groupe', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerColor.withAlpha(50)),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: theme.colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            isScrollable: false,
            tabs: const [
              Tab(text: 'Membres'),
              Tab(text: 'Médias'),
              Tab(text: 'Docs'),
              Tab(text: 'Vocal'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
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
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Hero(
            tag: 'room_avatar_${widget.roomId}',
            child: CircleAvatar(
              radius: 45,
              backgroundColor: theme.colorScheme.primary.withAlpha(26),
              child: Icon(
                widget.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                size: 45,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.roomName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.isGroup ? '${widget.members.length} membres' : 'Conversation privée',
            style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(153), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _promoteMember(String userId) async {
    try {
      await RoomService().promoteMember(widget.roomId, userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membre promu administrateur')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _demoteMember(String userId) async {
    try {
      await RoomService().demoteMember(widget.roomId, userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membre rétrogradé')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _removeMember(String userId) async {
    try {
      await RoomService().removeMember(widget.roomId, userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membre retiré du groupe')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le groupe ?'),
        content: const Text('Vous ne recevrez plus les messages de ce groupe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULER')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('QUITTER', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final profile = ref.read(profileProvider).profileData;
        if (profile != null) {
          await RoomService().leaveRoom(widget.roomId, profile['id']);
          if (mounted) {
            Navigator.pop(context); // Retour détails
            Navigator.pop(context); // Retour chat
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Widget _buildMembersTab() {
    final theme = Theme.of(context);
    final currentUserId = ref.read(profileProvider).profileData?['id'];
    final bool isUserAdmin = widget.members.any((m) => m['id'] == currentUserId && m['is_admin_member'] == true);

    if (widget.members.isEmpty) {
      return const Center(child: Text("Aucun membre trouvé"));
    }

    return Column(
      children: [
        if (widget.isGroup && isUserAdmin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              onTap: () {
                // Rediriger vers un sélecteur d'utilisateurs (NewGroupScreen ou similaire)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fonction 'Ajouter des membres' en cours de déploiement")));
              },
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
              ),
              title: Text('Ajouter des membres', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: widget.members.length,
            itemBuilder: (context, index) {
              final member = widget.members[index];
              final bool isAdmin = member['is_admin_member'] == true;
              final bool isMe = member['id'] == currentUserId;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withAlpha(isAdmin ? 255 : 30),
                  child: Text(
                    (member['full_name'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(color: isAdmin ? theme.colorScheme.onPrimary : theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  isMe ? "${member['full_name']} (Vous)" : (member['full_name'] ?? 'Utilisateur'), 
                  style: const TextStyle(fontWeight: FontWeight.w600)
                ),
                subtitle: isAdmin ? Text('Administrateur', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600)) : null,
                trailing: isUserAdmin && !isMe ? PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'promote') _promoteMember(member['id']);
                    if (val == 'demote') _demoteMember(member['id']);
                    if (val == 'remove') _removeMember(member['id']);
                  },
                  itemBuilder: (context) => [
                    if (!isAdmin)
                      const PopupMenuItem(value: 'promote', child: Text('Promouvoir Admin')),
                    if (isAdmin)
                      const PopupMenuItem(value: 'demote', child: Text('Rétrograder')),
                    const PopupMenuItem(value: 'remove', child: Text('Retirer du groupe', style: TextStyle(color: Colors.red))),
                  ],
                  icon: const Icon(Icons.more_vert_rounded),
                ) : (isAdmin ? Icon(Icons.verified_user_rounded, color: theme.colorScheme.primary, size: 20) : null),
              );
            },
          ),
        ),
      ],
    );
  }
}

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
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    if (_messages.isEmpty) {
      String emptyText = "Aucune image trouvée";
      if (widget.type == 'file') emptyText = "Aucun document trouvé";
      if (widget.type == 'audio') emptyText = "Aucun message vocal trouvé";
      return Center(child: Text(emptyText, style: const TextStyle(color: Colors.grey)));
    }

    if (widget.type == 'image') return _buildImageGrid();
    if (widget.type == 'file') return _buildFileList();
    return _buildAudioList();
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final url = _messages[index]['content'];
        return FutureBuilder<String>(
          future: MediaService().getDownloadUrl(url),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final dlUrl = snapshot.data!;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ImageViewerScreen(imageUrl: dlUrl)),
                ),
                child: Hero(
                  tag: dlUrl,
                  child: CachedNetworkImage(
                    imageUrl: dlUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey.withAlpha(20)),
                  ),
                ),
              );
            }
            return Container(color: Colors.grey.withAlpha(10), child: const Center(child: Icon(Icons.image_rounded, color: Colors.grey)));
          },
        );
      },
    );
  }

  Widget _buildFileList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final filename = msg['content'].toString().split('/').last;
        final extension = filename.split('.').last.toLowerCase();
        
        IconData icon = Icons.insert_drive_file;
        Color iconColor = Colors.blue;
        if (['pdf'].contains(extension)) {
          icon = Icons.picture_as_pdf;
          iconColor = Colors.red;
        }

        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor),
          ),
          title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(_formatDate(msg['created_at'])),
          onTap: () async {
            try {
              final dlUrl = await MediaService().getDownloadUrl(msg['content']);
              final uri = Uri.parse(dlUrl);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
        );
      },
    );
  }

  Widget _buildAudioList() {
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length,
      separatorBuilder: (_, _) => Divider(height: 1, indent: 70, color: theme.dividerColor.withAlpha(30)),
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withAlpha(20),
            child: Icon(Icons.mic_rounded, color: theme.colorScheme.primary),
          ),
          title: AudioBubbleContent(url: msg['content'], isMe: false),
          subtitle: Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(_formatDate(msg['created_at']), style: const TextStyle(fontSize: 11)),
          ),
        );
      },
    );
  }

  String _formatDate(String dtString) {
    try {
      final dt = DateTime.parse(dtString);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
