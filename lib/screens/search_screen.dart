import 'package:flutter/material.dart';
import '../services/search_service.dart';
import '../services/room_service.dart';
import 'chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchService _searchService = SearchService();
  final RoomService _roomService = RoomService();
  final TextEditingController _controller = TextEditingController();

  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  Future<void> _performSearch(String query) async {
    if (query.length < 2) return;
    setState(() => _isLoading = true);

    try {
      final results = await _searchService.globalSearch(query);
      if (mounted) {
        setState(() {
          _profiles = List<Map<String, dynamic>>.from(results['profiles'] ?? []);
          _rooms = List<Map<String, dynamic>>.from(results['rooms'] ?? []);
          _isLoading = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Rechercher...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            if (value.length >= 2) {
              _performSearch(value);
            } else {
              setState(() {
                _profiles = [];
                _rooms = [];
                _hasSearched = false;
              });
            }
          },
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() {
                  _profiles = [];
                  _rooms = [];
                  _hasSearched = false;
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
          : !_hasSearched
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Rechercher des contacts ou des groupes',
                          style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                    ],
                  ),
                )
              : (_profiles.isEmpty && _rooms.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('Aucun résultat', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        // Section Contacts
                        if (_profiles.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text('CONTACTS', style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[600], letterSpacing: 1)),
                          ),
                          ..._profiles.map((p) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF004D40),
                              backgroundImage: p['avatar'] != null ? NetworkImage(p['avatar']) : null,
                              child: p['avatar'] == null
                                  ? Text(p['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white))
                                  : null,
                            ),
                            title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('@${p['username']}', style: TextStyle(color: Colors.grey[500])),
                            onTap: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                final room = await _roomService.createPrivateRoom(p['id']);
                                if (context.mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        roomId: room['id'],
                                        roomName: p['name'],
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                messenger.showSnackBar(SnackBar(content: Text("Erreur: $e")));
                              }
                            },
                          )),
                        ],
                        // Section Groupes
                        if (_rooms.isNotEmpty) ...[
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Text('GROUPES', style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[600], letterSpacing: 1)),
                          ),
                          ..._rooms.map((r) => ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFF004D40),
                              child: Icon(Icons.group, color: Colors.white),
                            ),
                            title: Text(r['name'] ?? 'Groupe', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(r['is_group'] == true ? 'Groupe' : 'Discussion',
                                style: TextStyle(color: Colors.grey[500])),
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    roomId: r['id'],
                                    roomName: r['name'] ?? 'Discussion',
                                    isGroup: r['is_group'] ?? false,
                                  ),
                                ),
                              );
                            },
                          )),
                        ],
                      ],
                    ),
    );
  }
}
