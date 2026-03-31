import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
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
      final response = await http.get(
        Uri.parse('https://hoselike-detrital-nola.ngrok-free.dev/profiles/directory'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        await prefs.setString('cached_contacts', response.body); // Sauvegarde
        final list = List<Map<String, dynamic>>.from(jsonDecode(response.body));
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Annuaire'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            color: const Color(0xFF004D40),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher un collègue...',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Liste des contacts
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Aucun contact trouvé', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) {
                          final contact = _filtered[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF004D40),
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
                              '@${contact['username'] ?? ''}',
                              style: TextStyle(color: Colors.grey[500]),
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
                                        ? const Color(0xFF25D366)
                                        : Colors.grey[300],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chat_bubble_outline, color: Color(0xFF004D40)),
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
