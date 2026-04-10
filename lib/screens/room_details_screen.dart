
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/local_database.dart';
import '../services/media_service.dart';
import '../services/room_service.dart';
import '../providers/profile_provider.dart';
import '../widgets/premium_background.dart';
import '../widgets/authenticated_image.dart';
import '../providers/home_provider.dart';
import 'image_viewer_screen.dart';
import 'add_member_picker_screen.dart';
import 'package:image_picker/image_picker.dart';

class RoomDetailsScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;
  final String? avatarUrl;
  final bool isGroup;
  final List<Map<String, dynamic>> members;

  const RoomDetailsScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.avatarUrl,
    required this.isGroup,
    required this.members,
  });

  @override
  ConsumerState<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends ConsumerState<RoomDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _localRoomName;
  late String? _localAvatarUrl;
  late List<Map<String, dynamic>> _localMembers;

  @override
  void initState() {
    super.initState();
    _localRoomName = widget.roomName;
    _localAvatarUrl = widget.avatarUrl;
    _localMembers = List<Map<String, dynamic>>.from(widget.members);
    _tabController = TabController(length: 4, vsync: this);
    
    // Refresh members list on start to ensure we have the absolute latest data
    _refreshMembers();
  }

  Future<void> _refreshMembers() async {
    try {
      final members = await RoomService().getRoomMembers(widget.roomId);
      if (mounted) {
        setState(() => _localMembers = members);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.read(profileProvider).profileData?['id'];
    final bool isUserAdmin = _localMembers.any((m) => m['id'] == currentUserId && m['is_admin_member'] == true);
    final theme = Theme.of(context);

    return PremiumBackground(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          
          // Final sync before exiting
          ref.read(homeProvider.notifier).updateRoomMetadata(
            widget.roomId,
            name: _localRoomName,
            avatarUrl: _localAvatarUrl,
          );
          
          Navigator.pop(context, {
            'name': _localRoomName,
            'avatar_url': _localAvatarUrl,
          });
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(theme, isUserAdmin),
            SliverToBoxAdapter(
              child: _buildTabHeader(theme).animate().fadeIn(delay: 200.ms),
            ),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMembersTab(currentUserId, isUserAdmin),
                  _MediaTab(roomId: widget.roomId, type: 'image'),
                  _MediaTab(roomId: widget.roomId, type: 'file'),
                  _MediaTab(roomId: widget.roomId, type: 'audio'),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
   );
  }

  Widget _buildSliverAppBar(ThemeData theme, bool isUserAdmin) {
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
        onPressed: () => Navigator.maybePop(context),
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
          _localRoomName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        background: Stack(
          alignment: Alignment.center,
          children: [
            // Background Header Glow
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
                  child: GestureDetector(
                    onTap: (widget.isGroup && isUserAdmin) ? _changeGroupPhoto : null,
                    child: Stack(
                      children: [
                        _localAvatarUrl != null && _localAvatarUrl!.isNotEmpty
                            ? FutureBuilder<String>(
                                future: MediaService().getDownloadUrl(_localAvatarUrl!),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return CircleAvatar(
                                      radius: 50,
                                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      backgroundImage: AuthenticatedImageProvider(snapshot.data!),
                                    );
                                  }
                                  return CircleAvatar(
                                    radius: 50,
                                    backgroundColor: theme.colorScheme.primary,
                                    child: Icon(
                                      widget.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                                      size: 50,
                                      color: Colors.black,
                                    ),
                                  );
                                },
                              )
                            : CircleAvatar(
                                radius: 50,
                                backgroundColor: theme.colorScheme.primary,
                                child: Icon(
                                  widget.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                                  size: 50,
                                  color: Colors.black,
                                ),
                              ),
                        if (widget.isGroup && isUserAdmin)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.colorScheme.primary, width: 2),
                              ),
                              child: Icon(Icons.camera_alt_rounded, size: 16, color: theme.colorScheme.primary),
                            ),
                          ),
                      ],
                    ),
                  ),
                ).animate().scale(curve: Curves.easeOutBack, duration: 600.ms),
                const SizedBox(height: 60), // Room for Title
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
          Tab(icon: Icon(Icons.insert_drive_file_rounded, size: 20), text: 'Doc'),
          Tab(icon: Icon(Icons.mic_rounded, size: 20), text: 'Vocal'),
        ],
      ),
    );
  }

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
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Colors.blueAccent),
                  title: const Text('Modifier les infos du groupe', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _editGroupInfo();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                  title: const Text('Quitter le groupe', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _leaveRoom();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  void _editGroupInfo() {
    // To be implemented: a simple dialog to change name/description
    showDialog(
      context: context,
      builder: (dialogContext) {
        final nameController = TextEditingController(text: _localRoomName);
        return AlertDialog(
          title: const Text('Modifier le groupe'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nom du groupe'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ANNULER')),
            TextButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  await RoomService().updateRoom(widget.roomId, name: newName);
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext); // Pop dialog
                  
                  if (!mounted) return;
                  setState(() => _localRoomName = newName);

                  // Notify HomeNotifier for global sync
                  ref.read(homeProvider.notifier).updateRoomMetadata(
                    widget.roomId,
                    name: newName,
                    avatarUrl: _localAvatarUrl,
                  );
                }
              },
              child: const Text('ENREGISTRER'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeMember(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer le membre ?'),
        content: const Text('Cette personne ne pourra plus voir les nouveaux messages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULER')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('RETIRER', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await RoomService().removeMember(widget.roomId, userId);
        if (!mounted) return;
        setState(() {
          _localMembers.removeWhere((m) => m['id'] == userId);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membre retiré')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le groupe ?'),
        content: const Text('Ceci supprimera le groupe de votre liste.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULER')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('QUITTER', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final profile = ref.read(profileProvider).profileData;
      if (profile != null) {
        await RoomService().leaveRoom(widget.roomId, profile['id']);
        if (!mounted) return;
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  Widget _buildMembersTab(String? currentUserId, bool isUserAdmin) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: [
        if (widget.isGroup && isUserAdmin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ListTile(
              onTap: () async {
                final existingIds = _localMembers.map((m) => m['id'] as String).toList();
                final selectedIds = await Navigator.push<List<String>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddMemberPickerScreen(existingMemberIds: existingIds),
                  ),
                );

                if (selectedIds != null && selectedIds.isNotEmpty && mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    for (String id in selectedIds) {
                      await RoomService().addMember(widget.roomId, id);
                    }
                    if (!mounted) return;
                    
                    // Fetch updated members list from backend to get fresh names and avatars
                    final newMembers = await RoomService().getRoomMembers(widget.roomId);
                    
                    if (mounted) {
                      Navigator.pop(context); // Close loading dialog
                      setState(() {
                        _localMembers = newMembers;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Membres ajoutés avec succès !', style: TextStyle(color: Colors.green))),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context); // Close loading dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Erreur lors de l'ajout: $e")),
                      );
                    }
                  }
                }
              },
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.person_add_rounded, color: theme.colorScheme.primary, size: 22),
              ),
              title: Text('Ajouter des membres', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ).animate().fadeIn().slideX(),
        ..._localMembers.asMap().entries.map((entry) {
          final index = entry.key;
          final member = entry.value;
          final bool isAdmin = member['is_admin_member'] == true;
          final bool isMe = member['id'] == currentUserId;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isAdmin ? theme.colorScheme.primary : theme.colorScheme.surface.withValues(alpha: 0.2),
              child: Text(
                (member['full_name'] ?? 'U')[0].toUpperCase(),
                style: TextStyle(color: isAdmin ? Colors.black : theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(isMe ? "${member['full_name']} (Vous)" : member['full_name'], style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: isAdmin ? Text('Admin', style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)) : null,
            trailing: (widget.isGroup && isUserAdmin && !isMe) 
              ? IconButton(
                  icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () => _removeMember(member['id']),
                )
              : (isMe ? null : const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey)),
          ).animate(delay: (index * 40).ms).fadeIn().slideX();
        }),
      ],
    );
  }

  Future<void> _changeGroupPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final bytes = await image.readAsBytes();
        final response = await MediaService().uploadFile(bytes, filename: image.name);
        final url = response['url'];
        await RoomService().updateRoomAvatar(widget.roomId, url);
        
        if (mounted) {
          Navigator.pop(context); // Close loading
          setState(() => _localAvatarUrl = url);
          
          // Notify HomeNotifier for global sync
          ref.read(homeProvider.notifier).updateRoomMetadata(
            widget.roomId,
            name: _localRoomName,
            avatarUrl: url,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo mise à jour !')));
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur upload: $e')));
        }
      }
    }
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
    if (mounted) setState(() { _messages = msgs; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_messages.isEmpty) return const Center(child: Text("Aucun média trouvé", style: TextStyle(color: Colors.grey)));

    if (widget.type == 'image') {
      return GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final url = _messages[index]['content'];
          return FutureBuilder<String>(
            future: MediaService().getDownloadUrl(url),
            builder: (context, snap) {
              if (snap.hasData) {
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(imageUrl: snap.data!))),
                  child: Hero(tag: snap.data!, child: AuthenticatedNetworkImage(imageUrl: snap.data!, fit: BoxFit.cover)),
                );
              }
              return Container(color: Colors.grey.withValues(alpha: 0.1));
            },
          );
        },
      ).animate().fadeIn();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return ListTile(
          leading: Icon(widget.type == 'file' ? Icons.description_rounded : Icons.mic_rounded, color: Colors.grey),
          title: Text(msg['content'].toString().split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(msg['created_at'].toString().split('T')[0]),
        ).animate(delay: (index * 30).ms).fadeIn().slideY();
      },
    );
  }
}
