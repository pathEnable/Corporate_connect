import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'contacts_screen.dart';
import 'calls_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import '../widgets/ui_helpers.dart';
import '../services/push_notification_service.dart';
import '../widgets/home/home_chats_tab.dart';
import 'new_group_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeChatsTab(),
    ContactsScreen(),
    CallsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (PushNotificationService.initialRouteData != null) {
        PushNotificationService.handleNotificationClick(PushNotificationService.initialRouteData!);
        PushNotificationService.initialRouteData = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _currentIndex == 0 ? _buildHomeAppBar() : null,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: _currentIndex == 0 
        ? FloatingActionButton(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            elevation: 4,
            child: const Icon(Icons.group_add_rounded),
            onPressed: () {
              Navigator.push(context, FadeSlideRoute(page: const NewGroupScreen()));
            },
          ) 
        : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withAlpha(120),
        backgroundColor: theme.colorScheme.surface,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Discussions'),
          BottomNavigationBarItem(icon: Icon(Icons.contacts_rounded), label: 'Annuaire'),
          BottomNavigationBarItem(icon: Icon(Icons.call_rounded), label: 'Appels'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildHomeAppBar() {
    final theme = Theme.of(context);
    return AppBar(
      title: const Text(
        'Corporate Connect',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
      ),
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            Navigator.push(context, FadeSlideRoute(page: const SearchScreen()));
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () {
            Navigator.push(context, FadeSlideRoute(page: const SettingsScreen()));
          },
        ),
      ],
    );
  }
}
