import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../widgets/premium_background.dart';

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

    return PremiumBackground(
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        appBar: _currentIndex == 0 ? _buildHomeAppBar() : null,
        body: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
            // Barre de navigation flottante avec Glassmorphism
            Positioned(
            bottom: 24,
            left: 12,
            right: 12,
            child: _buildFloatingNavBar(theme),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 
        ? Padding(
            padding: const EdgeInsets.only(bottom: 90),
            child: FloatingActionButton(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.black,
                elevation: 4,
                child: const Icon(Icons.group_add_rounded),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, FadeSlideRoute(page: const NewGroupScreen()));
                },
              ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),
          ) 
        : null,
      ),
    );
  }

  Widget _buildFloatingNavBar(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
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
    ).animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutQuart);
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
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              size: isSelected ? 26 : 24,
            ).animate(target: isSelected ? 1 : 0).scale(duration: 200.ms).shimmer(delay: 200.ms),
            if (isSelected)
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
          ],
        ),
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
