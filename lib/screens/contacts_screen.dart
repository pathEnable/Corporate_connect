import '../widgets/authenticated_image.dart';
import 'package:flutter/material.dart';
import '../services/room_service.dart';
import '../services/local_database.dart';
import '../services/media_service.dart';
import '../providers/contacts_provider.dart';
import 'chat_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final RoomService _roomService = RoomService();
  final MediaService _mediaService = MediaService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Pas d'appel API ici : les données sont déjà dans contactsProvider (chargé par AppDataProvider)
  }

  void _filterContacts(String query) {
    setState(() => _searchQuery = query);
  }

  Future<void> _startChat(Map<String, dynamic> contact) async {
    try {
      // Vérifier la connectivité
      final connectivityResults = await Connectivity().checkConnectivity();
      final isOffline = connectivityResults.every((r) => r == ConnectivityResult.none);

      if (isOffline) {
        // ═══ MODE HORS-LIGNE ═══
        final tempId = "draft_${DateTime.now().millisecondsSinceEpoch}";
        final contactId = contact['id'].toString();
        final contactName = contact['full_name'] ?? 'Discussion';

        // 1. Sauvegarder dans la file d'attente de synchro
        await LocalDatabase.instance.savePendingRoom(
          tempId: tempId,
          name: contactName,
          isGroup: false,
          memberIds: contactId,
        );

        // 2. Pré-créer le salon localement pour qu'il apparaisse dans la liste Home
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
              builder: (_) => ChatScreen(
                roomId: tempId,
                roomName: contactName,
              ),
            ),
          );
        }
        return;
      }

      // ═══ MODE EN LIGNE ═══
      final room = await _roomService.createPrivateRoom(contact['id']);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              roomId: room['id'].toString(),
              roomName: contact['full_name'] ?? 'Discussion',
              avatarUrl: contact['avatar_url'],
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
    final contactsState = ref.watch(contactsProvider);

    // Filtrage local depuis les données du provider global
    final allContacts = contactsState.contacts;
    final filtered = _searchQuery.isEmpty
        ? allContacts
        : allContacts.where((c) {
            final name = (c['full_name'] ?? '').toString().toLowerCase();
            final username = (c['username'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase()) || username.contains(_searchQuery.toLowerCase());
          }).toList();

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
      body: RefreshIndicator(
        onRefresh: () => ref.read(contactsProvider.notifier).refresh(),
        child: Column(
          children: [
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
            Expanded(
              child: contactsState.isLoading && allContacts.isEmpty
                  ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                  : filtered.isEmpty
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
                          itemCount: filtered.length,
                          padding: const EdgeInsets.only(bottom: 24),
                          separatorBuilder: (context, index) => Divider(height: 1, indent: 80, color: theme.dividerColor.withAlpha(30)),
                          itemBuilder: (context, index) {
                            final contact = filtered[index];
                            final String? avatarUrl = contact['avatar_url'];
                            final String initial = (contact['full_name'] ?? 'U')[0].toUpperCase();
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                              leading: _ContactAvatar(
                                avatarUrl: avatarUrl,
                                initial: initial,
                                mediaService: _mediaService,
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
      ),
    );
  }
}

class _ContactAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initial;
  final MediaService mediaService;

  const _ContactAvatar({
    required this.avatarUrl,
    required this.initial,
    required this.mediaService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: theme.colorScheme.primary,
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }

    return FutureBuilder<String>(
      future: mediaService.getDownloadUrl(avatarUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CircleAvatar(
            radius: 26,
            backgroundImage: AuthenticatedImageProvider(snapshot.data!),
            backgroundColor: theme.colorScheme.primary.withAlpha(40),
          );
        }
        return CircleAvatar(
          radius: 26,
          backgroundColor: theme.colorScheme.primary.withAlpha(40),
          child: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}

