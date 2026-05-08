import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../services/api_config.dart';
import '../widgets/premium_background.dart';
import '../widgets/authenticated_image.dart';

class AddMemberPickerScreen extends StatefulWidget {
  final List<String> existingMemberIds;

  const AddMemberPickerScreen({super.key, required this.existingMemberIds});

  @override
  State<AddMemberPickerScreen> createState() => _AddMemberPickerScreenState();
}

class _AddMemberPickerScreenState extends State<AddMemberPickerScreen> {
  final AuthService _authService = AuthService();
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
        // Filter out existing members
        final filteredList = list.where((c) => !widget.existingMemberIds.contains(c['id'])).toList();
        
        if (mounted) {
          setState(() {
            _contacts = filteredList;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleContact(Map<String, dynamic> contact) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedContacts.any((c) => c['id'] == contact['id'])) {
        _selectedContacts.removeWhere((c) => c['id'] == contact['id']);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  void _submitSelection() {
    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins un membre')),
      );
      return;
    }
    
    HapticFeedback.mediumImpact();
    final memberIds = _selectedContacts.map((c) => c['id'] as String).toList();
    Navigator.pop(context, memberIds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Ajouter des membres', style: TextStyle(fontWeight: FontWeight.bold)),
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
            if (_selectedContacts.isNotEmpty)
              TextButton(
                onPressed: _submitSelection,
                child: Text(
                  'AJOUTER', 
                  style: TextStyle(
                    color: theme.colorScheme.primary, 
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  )
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // Liste des sélectionnés (Horizontal)
            if (_selectedContacts.isNotEmpty)
              _buildSelectedList(theme),
    
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "CONTACTS",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.grey),
                ),
              ),
            ),
    
            // Liste des contacts
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                  : _contacts.isEmpty 
                      ? const Center(child: Text('Aucun nouveau contact disponible'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 0),
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) {
                            final contact = _contacts[index];
                            final isSelected = _selectedContacts.any((c) => c['id'] == contact['id']);
                            return _buildContactTile(contact, isSelected, theme);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedList(ThemeData theme) {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    _buildContactAvatar(
                      contact['full_name'] ?? 'U',
                      contact['avatar_url'],
                      28,
                      theme.colorScheme.primary,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () => _toggleContact(contact),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  contact['full_name'].split(' ')[0],
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContactTile(Map<String, dynamic> contact, bool isSelected, ThemeData theme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Stack(
        children: [
          _buildContactAvatar(
            contact['full_name'] ?? 'U',
            contact['avatar_url'],
            24,
            isSelected ? theme.colorScheme.primary : theme.colorScheme.surface.withValues(alpha: 0.5),
            textColor: isSelected ? Colors.black : theme.colorScheme.primary,
          ),
          if (isSelected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 14, color: Colors.black),
              ),
            ),
        ],
      ),
      title: Text(contact['full_name'], style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        contact['job_title'] ?? 'Membre Connect', 
        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))
      ),
      onTap: () => _toggleContact(contact),
    );
  }

  Widget _buildContactAvatar(String name, String? avatarUrl, double radius, Color bgColor, {Color textColor = Colors.black}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
        ),
        child: ClipOval(
          child: AuthenticatedNetworkImage(
            imageUrl: ApiConfig.getMediaUrl(avatarUrl),
            fit: BoxFit.cover,
            width: radius * 2,
            height: radius * 2,
            errorWidget: (context, url, error) => Center(
              child: Text(initial, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(initial, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
    );
  }
}
