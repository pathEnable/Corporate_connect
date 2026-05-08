import 'package:flutter/material.dart';
import '../widgets/authenticated_image.dart';
import '../services/search_service.dart';
import '../services/room_service.dart';
import '../widgets/premium_background.dart';
import '../services/api_config.dart';
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
    if (query.trim().length < 2) return;
    setState(() => _isLoading = true);

    try {
      final results = await _searchService.globalSearch(query.trim());
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF040301) : Colors.white,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          shape: Border(
            bottom: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          title: TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(color: theme.colorScheme.onSurface),
            cursorColor: theme.colorScheme.primary,
            decoration: InputDecoration(
              hintText: 'Rechercher...',
              hintStyle: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120)),
              border: InputBorder.none,
            ),
            onChanged: (value) {
              if (value.trim().length >= 2) {
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
                icon: const Icon(Icons.clear_rounded),
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
            ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            : !_hasSearched
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_rounded, size: 80, color: theme.dividerColor.withAlpha(50)),
                        const SizedBox(height: 16),
                        Text(
                          'Rechercher des contacts ou des groupes',
                          style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withAlpha(150)),
                        ),
                      ],
                    ),
                  )
                : (_profiles.isEmpty && _rooms.isEmpty)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 80, color: theme.dividerColor.withAlpha(50)),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun résultat', 
                              style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withAlpha(150)),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          if (_profiles.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                              child: Text(
                                'CONTACTS', 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 12, 
                                  color: theme.colorScheme.primary, 
                                  letterSpacing: 1.2
                                ),
                              ),
                            ),
                            ..._profiles.map((p) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                              leading: _buildProfileAvatar(theme, p),
                              title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '@${p['username']}', 
                                style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150), fontSize: 13)
                              ),
                              onTap: () async {
                                final String targetUserId = p['id'];
                                final String targetUserName = p['name'];
                                final navigator = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  final room = await _roomService.createPrivateRoom(targetUserId);
                                  if (!mounted) return;
                                  navigator.pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        roomId: room['id'],
                                        roomName: targetUserName,
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text("Erreur: $e")),
                                    );
                                  }
                                }
                              },
                            )),
                          ],
                          if (_rooms.isNotEmpty) ...[
                            const Divider(height: 32),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                              child: Text(
                                'GROUPES', 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 12, 
                                  color: theme.colorScheme.primary, 
                                  letterSpacing: 1.2
                                ),
                              ),
                            ),
                            ..._rooms.map((r) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: theme.colorScheme.primary.withAlpha(30),
                                child: Icon(Icons.groups_rounded, color: theme.colorScheme.primary, size: 24),
                              ),
                              title: Text(r['name'] ?? 'Groupe', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                r['is_group'] == true ? 'Canal de groupe' : 'Discussion privée',
                                style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150), fontSize: 13)
                              ),
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
      ),
    );
  }
  Widget _buildProfileAvatar(ThemeData theme, Map<String, dynamic> profile) {
    final String? avatarUrl = profile['avatar'];
    final String initial = profile['name'][0].toUpperCase();

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary,
      ),
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? ClipOval(
              child: Image(
                image: AuthenticatedImageProvider(ApiConfig.getMediaUrl(avatarUrl)),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallback(initial),
              ),
            )
          : _buildFallback(initial),
    );
  }

  Widget _buildFallback(String initial) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}
