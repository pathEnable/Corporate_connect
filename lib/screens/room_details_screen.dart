import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_database.dart';
import '../services/media_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/chat/message_bubble.dart'; // Pour réutiliser AudioBubbleContent

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Détails'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF004D40),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF004D40),
            isScrollable: false,
            tabs: const [
              Tab(text: 'Membres'),
              Tab(text: 'Médias'),
              Tab(text: 'Docs'),
              Tab(text: 'Vocal'),
            ],
          ),
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
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF004D40).withValues(alpha: 0.1),
            child: Icon(
              widget.isGroup ? Icons.group : Icons.person,
              size: 40,
              color: const Color(0xFF004D40),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.roomName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.isGroup ? '${widget.members.length} membres' : 'Conversation privée',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    if (widget.members.isEmpty) {
      return const Center(child: Text("Aucun membre trouvé"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: widget.members.length,
      itemBuilder: (context, index) {
        final member = widget.members[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF004D40),
            child: Icon(Icons.person, color: Colors.white),
          ),
          title: Text(member['full_name'] ?? member['username'] ?? 'Utilisateur'),
          subtitle: member['is_admin_member'] == true ? const Text('Administrateur', style: TextStyle(color: Color(0xFF004D40))) : null,
        );
      },
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
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
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
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final url = _messages[index]['content'];
        return GestureDetector(
          onTap: () async {
            // Optionnel : Ouvrir en plein écran
            try {
              final dlUrl = await MediaService().getDownloadUrl(url);
              final uri = Uri.parse(dlUrl);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            } catch (_) {}
          },
          child: Container(
            color: Colors.grey[200],
            child: FutureBuilder<String>(
              future: MediaService().getDownloadUrl(url),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.network(snapshot.data!, fit: BoxFit.cover);
                }
                return const Center(child: Icon(Icons.image, color: Colors.grey));
              },
            ),
          ),
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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFF5F5F5),
            child: Icon(Icons.mic, color: Color(0xFF004D40)),
          ),
          title: AudioBubbleContent(url: msg['content'], isMe: false),
          subtitle: Text(_formatDate(msg['created_at'])),
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
