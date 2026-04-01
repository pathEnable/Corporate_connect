import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../services/api_config.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final AuthService _authService = AuthService();
  final RoomService _roomService = RoomService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      // 1. Charger depuis le cache instantanément
      final prefs = await SharedPreferences.getInstance();
      final cachedContacts = prefs.getString('cached_contacts');
      if (cachedContacts != null && mounted) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(cachedContacts));
        setState(() {
          _contacts = list;
          _filtered = list;
          _isLoading = false;
        });
      }

      // 2. Fetch en arrière plan pour les nouveautés
      final token = await _authService.getToken();
      final String directoryUrl = '${ApiConfig.baseUrl}/profiles/directory';
      
      final response = await http.get(
        Uri.parse(directoryUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        await prefs.setString('cached_contacts', decodedBody);
        final list = List<Map<String, dynamic>>.from(jsonDecode(decodedBody));
        if (mounted) {
          setState(() {
            _contacts = list;
            _filtered = list;
            _isLoading = false;
          });
        }
      } else {
        if (mounted && _contacts.isEmpty) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted && _contacts.isEmpty) setState(() => _isLoading = false);
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _contacts;
      } else {
        _filtered = _contacts.where((c) {
          final name = (c['full_name'] ?? '').toString().toLowerCase();
          final username = (c['username'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase()) || username.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _startChat(Map<String, dynamic> contact) async {
    try {
      final room = await _roomService.createPrivateRoom(contact['id']);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              roomId: room['id'],
              roomName: contact['full_name'] ?? 'Discussion',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Annuaire'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barre de recherche modernisée
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Rechercher un collègue...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120)),
                prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Liste des contacts
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 64, color: theme.dividerColor.withAlpha(50)),
                            const SizedBox(height: 16),
                            Text('Aucun contact trouvé', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150))),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        padding: const EdgeInsets.only(bottom: 24),
                        separatorBuilder: (context, index) => Divider(height: 1, indent: 80, color: theme.dividerColor.withAlpha(30)),
                        itemBuilder: (context, index) {
                          final contact = _filtered[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                            leading: CircleAvatar(
                              radius: 26,
                              backgroundColor: theme.colorScheme.primary,
                              child: Text(
                                (contact['full_name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              contact['full_name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              contact['job_title'] ?? '@${contact['username'] ?? ''}',
                              style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150), fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (contact['is_online'] == true)
                                        ? theme.colorScheme.secondary
                                        : theme.dividerColor.withAlpha(100),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.chat_bubble_outline_rounded, color: theme.colorScheme.primary, size: 20),
                              ],
                            ),
                            onTap: () => _startChat(contact),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
