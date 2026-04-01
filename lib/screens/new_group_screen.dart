import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../services/api_config.dart';
import 'chat_screen.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final AuthService _authService = AuthService();
  final RoomService _roomService = RoomService();
  final TextEditingController _nameController = TextEditingController();
  final List<Map<String, dynamic>> _selectedContacts = [];
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/profiles/directory'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(response.bodyBytes)));
        if (mounted) {
          setState(() {
            _contacts = list;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleContact(Map<String, dynamic> contact) {
    setState(() {
      if (_selectedContacts.any((c) => c['id'] == contact['id'])) {
        _selectedContacts.removeWhere((c) => c['id'] == contact['id']);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez donner un nom au groupe')),
      );
      return;
    }
    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins un membre')),
      );
      return;
    }

    try {
      final memberIds = _selectedContacts.map((c) => c['id'] as String).toList();
      final room = await _roomService.createGroup(_nameController.text.trim(), memberIds);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              roomId: room['id'],
              roomName: room['name'],
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
        title: const Text('Nouveau Groupe'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          if (_selectedContacts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _createGroup,
                child: Text(
                  'CRÉER', 
                  style: TextStyle(
                    color: theme.colorScheme.primary, 
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                  )
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Nom du groupe
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primary.withAlpha(20),
                  child: Icon(Icons.groups_rounded, color: theme.colorScheme.primary, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autofocus: false,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Sujet du groupe...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des sélectionnés (Horizontal)
          if (_selectedContacts.isNotEmpty)
            Container(
              height: 100,
              padding: const EdgeInsets.only(bottom: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedContacts.length,
                itemBuilder: (context, index) {
                  final contact = _selectedContacts[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: theme.colorScheme.primary,
                              child: Text(
                                (contact['full_name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: () => _toggleContact(contact),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(color: theme.colorScheme.onSurface.withAlpha(150), shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contact['full_name'].split(' ')[0],
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(180)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          const Divider(height: 1),

          // Liste des contacts
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      final isSelected = _selectedContacts.any((c) => c['id'] == contact['id']);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: theme.colorScheme.primary.withAlpha(isSelected ? 255 : 40),
                              child: Text(
                                (contact['full_name'] ?? 'U')[0].toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                            if (isSelected)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(color: theme.colorScheme.secondary, shape: BoxShape.circle),
                                  child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        title: Text(contact['full_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          contact['job_title'] ?? 'Membre Connect', 
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(150))
                        ),
                        onTap: () => _toggleContact(contact),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
