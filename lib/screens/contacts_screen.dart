import 'dart:convert';
import '../widgets/authenticated_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../services/api_config.dart';
import '../services/local_database.dart';

import 'chat_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Constantes de présence ──────────────────────────────────────────────────

const _presenceFilters = [
  {'label': 'Tous', 'value': null},
  {'label': '🟢 En ligne', 'value': 'online'},
  {'label': '🔴 Occupé', 'value': 'busy'},
  {'label': '🔕 DND', 'value': 'dnd'},
  {'label': '📹 Réunion', 'value': 'meeting'},
  {'label': '🏠 Remote', 'value': 'remote'},
  {'label': '✈️ Congé', 'value': 'vacation'},
];

Color _presenceColor(String? status) {
  switch (status) {
    case 'online':    return Colors.green;
    case 'busy':      return Colors.orange;
    case 'dnd':       return Colors.red;
    case 'meeting':   return Colors.purple;
    case 'remote':    return Colors.blue;
    case 'vacation':  return Colors.teal;
    default:          return Colors.grey;
  }
}

String _presenceLabel(String? status) {
  switch (status) {
    case 'online':   return 'En ligne';
    case 'busy':     return 'Occupé';
    case 'dnd':      return 'Ne pas déranger';
    case 'meeting':  return 'En réunion';
    case 'remote':   return 'Télétravail';
    case 'vacation': return 'En congé';
    default:         return 'Hors ligne';
  }
}

// ─── Écran Annuaire ──────────────────────────────────────────────────────────

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final AuthService _authService = AuthService();
  final RoomService _roomService = RoomService();

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;

  // Filtres actifs
  String? _selectedPresence;
  String? _selectedDepartment;
  List<String> _departments = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Chargement Offline-First ─────────────────────────────────────────────

  Future<void> _loadContacts({
    String? q,
    String? department,
    String? presenceStatus,
  }) async {
    try {
      // 1. Charger depuis le cache SQLite instantanément
      if (!kIsWeb) {
        final cached = await LocalDatabase.instance.getProfiles();
        if (cached.isNotEmpty && mounted) {
          setState(() {
            _contacts = cached;
            _applyLocalFilters();
            _isLoading = false;
          });
        }
      }

      // 2. Fetch en arrière-plan avec les filtres optionnels
      final token = await _authService.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/profiles/directory').replace(
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (department != null) 'department': department,
          if (presenceStatus != null) 'presence_status': presenceStatus,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final list = List<Map<String, dynamic>>.from(jsonDecode(decodedBody));

        // Extraire les départements pour les filtres (si pas de filtre actif)
        if (department == null && presenceStatus == null && (q == null || q.isEmpty)) {
          final depts = list
              .map((c) => c['department']?.toString() ?? '')
              .where((d) => d.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          if (!kIsWeb) await LocalDatabase.instance.saveProfiles(list);
          if (mounted) {
            setState(() {
              _contacts = list;
              _departments = depts;
              _applyLocalFilters();
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _filtered = list;
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted && _contacts.isEmpty) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted && _contacts.isEmpty) setState(() => _isLoading = false);
    }
  }

  void _applyLocalFilters() {
    final q = _searchController.text.toLowerCase();
    _filtered = _contacts.where((c) {
      final name = (c['full_name'] ?? '').toString().toLowerCase();
      final un = (c['username'] ?? '').toString().toLowerCase();
      final jt = (c['job_title'] ?? '').toString().toLowerCase();
      final dept = (c['department'] ?? '').toString().toLowerCase();
      final presence = (c['presence_status'] ?? '').toString();

      final matchesQ = q.isEmpty || name.contains(q) || un.contains(q) || jt.contains(q);
      final matchesDept = _selectedDepartment == null ||
          dept == _selectedDepartment!.toLowerCase();
      final matchesPresence = _selectedPresence == null || presence == _selectedPresence;

      return matchesQ && matchesDept && matchesPresence;
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(_applyLocalFilters);
    // Si l'utilisateur saisit plus de 2 chars, on refetch avec le bon filtre API
    if (value.length > 2) {
      _loadContacts(q: value, department: _selectedDepartment, presenceStatus: _selectedPresence);
    }
  }

  void _onPresenceFilterChanged(String? value) {
    setState(() => _selectedPresence = value);
    _loadContacts(
      q: _searchController.text.isNotEmpty ? _searchController.text : null,
      department: _selectedDepartment,
      presenceStatus: value,
    );
  }

  void _onDepartmentFilterChanged(String? dept) {
    setState(() => _selectedDepartment = dept);
    _loadContacts(
      q: _searchController.text.isNotEmpty ? _searchController.text : null,
      department: dept,
      presenceStatus: _selectedPresence,
    );
  }

  // ─── Navigation vers le chat ────────────────────────────────────────────

  Future<void> _startChat(Map<String, dynamic> contact) async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final isOffline = connectivityResults.every((r) => r == ConnectivityResult.none);

      if (isOffline) {
        final tempId = "draft_${DateTime.now().millisecondsSinceEpoch}";
        final contactId = contact['id'].toString();
        final contactName = contact['full_name'] ?? 'Discussion';

        await LocalDatabase.instance.savePendingRoom(
          tempId: tempId,
          name: contactName,
          isGroup: false,
          memberIds: contactId,
        );
        await LocalDatabase.instance.saveRoom({
          'id': tempId,
          'name': contactName,
          'is_group': 0,
          'last_message': 'Discussion hors-ligne créée...',
          'last_message_time': DateTime.now().toIso8601String(),
          'unread_count': 0,
        });

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(roomId: tempId, roomName: contactName),
            ),
          );
        }
        return;
      }

      final room = await _roomService.createPrivateRoom(contact['id']);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              roomId: room['id'].toString(),
              roomName: contact['full_name'] ?? 'Discussion',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Annuaire', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.03),
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        shape: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Barre de recherche ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Nom, poste, département...',
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

          // ── Filtres Présence ──────────────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _presenceFilters.length,
              itemBuilder: (ctx, i) {
                final f = _presenceFilters[i];
                final val = f['value'];
                final isSelected = _selectedPresence == val;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f['label'] as String),
                    selected: isSelected,
                    onSelected: (_) => _onPresenceFilterChanged(isSelected ? null : val),
                    selectedColor: theme.colorScheme.primary.withAlpha(40),
                    labelStyle: TextStyle(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withAlpha(180),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary.withAlpha(80)
                          : theme.dividerColor.withAlpha(60),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Filtres Département (si disponibles) ──────────────────────
          if (_departments.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                itemCount: _departments.length + 1,
                itemBuilder: (ctx, i) {
                  final dept = i == 0 ? null : _departments[i - 1];
                  final label = dept ?? 'Tous les depts.';
                  final isSelected = _selectedDepartment == dept;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) => _onDepartmentFilterChanged(isSelected ? null : dept),
                      selectedColor: theme.colorScheme.secondary.withAlpha(40),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: isSelected ? theme.colorScheme.secondary : null,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 4),

          // ── Liste des contacts ─────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 64,
                                color: theme.dividerColor.withAlpha(50)),
                            const SizedBox(height: 16),
                            Text('Aucun contact trouvé',
                                style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150))),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        padding: const EdgeInsets.only(bottom: 24),
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, indent: 80, color: theme.dividerColor.withAlpha(30)),
                        itemBuilder: (context, index) {
                          final contact = _filtered[index];
                          final String? avatarUrl = contact['avatar_url'];
                          final String initial = (contact['full_name'] ?? 'U')[0].toUpperCase();
                          final String presence = contact['presence_status'] ?? '';
                          final String dept = contact['department'] ?? '';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                            leading: Stack(
                              children: [
                                _ContactAvatar(
                                  avatarUrl: avatarUrl,
                                  initial: initial,

                                ),
                                // Pastille de présence
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _presenceColor(presence),
                                      border: Border.all(
                                        color: theme.colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              contact['full_name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contact['job_title'] ?? '@${contact['username'] ?? ''}',
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface.withAlpha(150),
                                      fontSize: 12),
                                ),
                                Row(
                                  children: [
                                    if (dept.isNotEmpty) ...[
                                      Icon(Icons.business_rounded,
                                          size: 10,
                                          color: theme.colorScheme.primary.withAlpha(150)),
                                      const SizedBox(width: 3),
                                      Text(
                                        dept,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: theme.colorScheme.primary.withAlpha(180)),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _presenceColor(presence).withAlpha(25),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _presenceLabel(presence),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: _presenceColor(presence),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
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

// ─── Avatar ──────────────────────────────────────────────────────────────────

class _ContactAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initial;

  const _ContactAvatar({
    required this.avatarUrl,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary.withAlpha(30),
      ),
      child: hasAvatar
          ? ClipOval(
              child: AuthenticatedNetworkImage(
                imageUrl: ApiConfig.getMediaUrl(avatarUrl!),
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => _buildFallback(theme),
                placeholder: (context, url) => _buildFallback(theme),
              ),
            )
          : _buildFallback(theme),
    );
  }

  Widget _buildFallback(ThemeData theme) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}
