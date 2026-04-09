import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/api_config.dart';
import '../services/local_database.dart';

/// État de la liste des contacts (annuaire de l'entreprise).
class ContactsState {
  final List<Map<String, dynamic>> contacts;
  final bool isLoading;
  final String? errorMessage;

  const ContactsState({
    this.contacts = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  ContactsState copyWith({
    List<Map<String, dynamic>>? contacts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final contactsProvider = NotifierProvider<ContactsNotifier, ContactsState>(() {
  return ContactsNotifier();
});

/// Provider global pour l'annuaire de l'entreprise.
/// Les données sont chargées une seule fois par AppDataProvider,
/// puis partagées entre tous les écrans qui en ont besoin.
class ContactsNotifier extends Notifier<ContactsState> {
  final AuthService _authService = AuthService();

  @override
  ContactsState build() {
    // Pas d'auto-chargement : AppDataProvider pilote l'initialisation.
    return const ContactsState();
  }

  /// Phase 1 : Charger depuis le cache SQLite (instantané, < 30ms).
  /// Appelé par AppDataProvider avant la navigation.
  Future<void> loadFromSQLite() async {
    if (kIsWeb) {
      state = state.copyWith(isLoading: false);
      return;
    }
    try {
      final cached = await LocalDatabase.instance.getProfiles();
      if (cached.isNotEmpty) {
        state = state.copyWith(contacts: cached, isLoading: false);
        debugPrint('✅ Contacts chargés depuis SQLite: ${cached.length}');
      } else {
        // Toujours en chargement pour la sync API
        debugPrint('ℹ️ Contacts: Pas de cache SQLite');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur cache contacts SQLite: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Phase 2 : Synchroniser avec l'API (appelé en arrière-plan).
  /// Met à jour le cache SQLite et l'état global.
  Future<void> loadContacts() async {
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
        final decodedBody = utf8.decode(response.bodyBytes);
        final list = List<Map<String, dynamic>>.from(jsonDecode(decodedBody));

        // Sauvegarder en cache SQLite
        if (!kIsWeb) {
          await LocalDatabase.instance.saveProfiles(list);
        }

        state = state.copyWith(contacts: list, isLoading: false);
        debugPrint('✅ Contacts synchronized depuis API: ${list.length}');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur sync contacts API: $e');
      if (state.contacts.isEmpty) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  /// Pull-to-refresh manuel depuis ContactsScreen.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await loadContacts();
  }
}
