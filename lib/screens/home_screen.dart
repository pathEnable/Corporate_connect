import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../widgets/premium_background.dart';
import '../providers/connectivity_provider.dart';

import 'contacts_screen.dart';
import 'calls_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'new_group_screen.dart';
import '../widgets/ui_helpers.dart';
import '../services/push_notification_service.dart';
import '../widgets/home/home_chats_tab.dart';
import 'status_tab_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeChatsTab(),
    const ContactsScreen(),
    const CallsScreen(),
    const StatusTabScreen(),
    const ProfileScreen(),
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

    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: PremiumBackground(
        child: Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          appBar: _currentIndex == 0 ? _buildHomeAppBar() : null,
          body: Column(
            children: [
              // --- Bandeau Hors-ligne ---
              _OfflineBanner(),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildNavBar(theme),
          floatingActionButton: _currentIndex == 0 
            ? FloatingActionButton(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.black,
                elevation: 4,
                child: const Icon(Icons.group_add_rounded),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, FadeSlideRoute(page: const NewGroupScreen()));
                },
              )
            : null,
        ),
      ),
    );
  }

  Widget _buildNavBar(ThemeData theme) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF040301) : Colors.white,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.chat_bubble_rounded, 'Chat'),
              _buildNavItem(1, Icons.contacts_rounded, 'Contacts'),
              _buildNavItem(2, Icons.call_rounded, 'Appels'),
              _buildNavItem(3, Icons.donut_large_rounded, 'Stories'),
              _buildNavItem(4, Icons.person_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              size: isSelected ? 26 : 24,
            ),
            if (isSelected)
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHomeAppBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AppBar(
      title: const Text(
        'Corporate Connect',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
      ),
      backgroundColor: isDark ? const Color(0xFF040301) : Colors.white,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      shape: Border(
        bottom: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, FadeSlideRoute(page: const SearchScreen()));
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, FadeSlideRoute(page: const SettingsScreen()));
          },
        ),
      ],
    );
  }
}

/// Bandeau affiché en haut quand il n'y a pas de connexion Internet (style WhatsApp)
class _OfflineBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncConnectivity = ref.watch(connectivityProvider);

    return asyncConnectivity.when(
      data: (isConnected) {
        if (isConnected) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: Colors.redAccent.shade700,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'Pas de connexion Internet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
