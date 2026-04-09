 import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../services/api_config.dart';
import '../services/local_database.dart';
import '../services/offline_sync_service.dart';
import '../widgets/premium_background.dart';
import 'chat_screen.dart';

class NewGroupScreen extends ConsumerStatefulWidget {
  const NewGroupScreen({super.key});

  @override
  ConsumerState<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends ConsumerState<NewGroupScreen> {
  final AuthService _authService = AuthService();
  final RoomService _roomService = RoomService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _selectedContacts = [];
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterContacts);
    _loadContacts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = query.isEmpty
          ? _contacts
          : _contacts.where((c) {
              final name = (c['full_name'] ?? '').toString().toLowerCase();
              final job = (c['job_title'] ?? '').toString().toLowerCase();
              return name.contains(query) || job.contains(query);
            }).toList();
    });
  }

  Future<void> _loadContacts() async {
    // ═══ PHASE 1 : Cache SQLite instantané (fonctionne hors-ligne) ═══
    try {
      final cached = await LocalDatabase.instance.getProfiles();
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _contacts = cached;
          _filteredContacts = cached;
          _isLoading = false;
        });
      }
    } catch (_) {}

    // ═══ PHASE 2 : Mise à jour réseau en arrière-plan ═══
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/profiles/directory'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(
            jsonDecode(utf8.decode(response.bodyBytes)));
        // Mettre à jour le cache SQLite
        LocalDatabase.instance.saveProfiles(list);
        if (mounted) {
          setState(() {
            _contacts = list;
            _filteredContacts = _searchController.text.isEmpty
                ? list
                : _filteredContacts; // Garder le filtre actif
            _isLoading = false;
            _isOffline = false;
          });
        }
      }
    } catch (_) {
      // Pas de réseau — on utilise le cache déjà chargé
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = _contacts.isEmpty; // Hors-ligne ET pas de cache
        });
      }
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

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez donner un nom au groupe')),
      );
      return;
    }
    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez sélectionner au moins un membre')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final memberIds = _selectedContacts.map((c) => c['id'].toString()).toList();
    final groupName = _nameController.text.trim();

    // ═══ TENTATIVE EN LIGNE D'ABORD ═══
    final connectivityResult = await Connectivity().checkConnectivity();
    final isConnected =
        connectivityResult.any((r) => r != ConnectivityResult.none);

    if (isConnected) {
      try {
        final room = await _roomService.createGroup(groupName, memberIds);
        // Sauvegarder en cache SQLite pour la prochaine ouverture offline
        await LocalDatabase.instance.saveRoom(room);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                roomId: room['id'].toString(),
                roomName: room['name'] ?? groupName,
                isGroup: true,
              ),
            ),
          );
        }
        return;
      } catch (_) {
        // Échec réseau malgré connexion → fallback hors-ligne
      }
    }

    // ═══ MODE HORS-LIGNE : Créer localement et mettre en file d'attente ═══
    try {
      final tempId = 'draft_${DateTime.now().millisecondsSinceEpoch}';

      // Sauvegarder dans la table principale pour affichage immédiat
      await LocalDatabase.instance.saveRoom({
        'id': tempId,
        'name': groupName,
        'is_group': 1,
        'last_message': null,
        'last_message_at': DateTime.now().toIso8601String(),
        'unread_count': 0,
      });

      await LocalDatabase.instance.savePendingRoom(
        tempId: tempId,
        name: groupName,
        isGroup: true,
        memberIds: memberIds.join(','),
      );

      // Tenter une synchro immédiate (peut réussir si connexion intermittente)
      ref.read(offlineSyncProvider).syncPendingRooms();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Groupe créé localement. Il sera synchronisé dès le retour du réseau.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF00695C),
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              roomId: tempId,
              roomName: groupName,
              isGroup: true,
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

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Nouveau Groupe',
              style: TextStyle(fontWeight: FontWeight.bold)),
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
                onPressed: _createGroup,
                child: Text(
                  'CRÉER',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ).animate().fadeIn().scale(),
          ],
        ),
        body: Column(
          children: [
            // Bandeau hors-ligne
            if (_isOffline)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                color: Colors.orange.shade800,
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hors-ligne — Aucun contact en cache. Connectez-vous pour charger l\'annuaire.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Nom du groupe
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: theme.colorScheme.primary,
                      child: const Icon(Icons.groups_rounded,
                          color: Colors.black, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Sujet du groupe...',
                          hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.1),
            ),

            // Membres sélectionnés
            if (_selectedContacts.isNotEmpty)
              _buildSelectedList(theme).animate().fadeIn(),

            // Barre de recherche
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un contact...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.15)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  filled: true,
                  fillColor: theme.colorScheme.surface.withValues(alpha: 0.5),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _isOffline ? 'CONTACTS (CACHE)' : 'CONTACTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: _isOffline ? Colors.orange.shade600 : Colors.grey,
                  ),
                ),
              ),
            ),

            // Liste des contacts
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: theme.colorScheme.primary))
                  : _filteredContacts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: _filteredContacts.length,
                          itemBuilder: (context, index) {
                            final contact = _filteredContacts[index];
                            final isSelected = _selectedContacts
                                .any((c) => c['id'] == contact['id']);
                            return _buildContactTile(contact, isSelected, theme)
                                .animate(delay: (index * 20).ms)
                                .fadeIn()
                                .slideX(begin: 0.05);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Aucun contact trouvé',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedList(ThemeData theme) {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(top: 12, bottom: 4),
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
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        (contact['full_name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () => _toggleContact(contact),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  contact['full_name'].split(' ')[0],
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ).animate().scale();
        },
      ),
    );
  }

  Widget _buildContactTile(
      Map<String, dynamic> contact, bool isSelected, ThemeData theme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surface.withValues(alpha: 0.5),
            child: Text(
              (contact['full_name'] ?? 'U')[0].toUpperCase(),
              style: TextStyle(
                color: isSelected ? Colors.black : theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.greenAccent, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    size: 14, color: Colors.black),
              ),
            ),
        ],
      ),
      title: Text(contact['full_name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        contact['job_title'] ?? 'Membre Connect',
        style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
      ),
      onTap: () => _toggleContact(contact),
    );
  }
}
