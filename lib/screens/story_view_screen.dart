
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/status_model.dart';
import '../providers/home_provider.dart';
import '../widgets/authenticated_image.dart';

class StoryViewScreen extends ConsumerStatefulWidget {
  final List<StatusModel> stories;
  final int initialIndex;

  const StoryViewScreen({super.key, required this.stories, this.initialIndex = 0});

  @override
  ConsumerState<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends ConsumerState<StoryViewScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _animController = AnimationController(vsync: this);

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _loadStory(story: widget.stories[_currentIndex]);
  }

  void _loadStory({required StatusModel story}) {
    _animController.stop();
    _animController.reset();
    _animController.duration = const Duration(seconds: 5);
    _animController.forward();

    // Mark as read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeProvider.notifier).markStatusAsRead(story.id);
    });
  }

  void _nextStory() {
    if (_currentIndex + 1 < widget.stories.length) {
      setState(() {
        _currentIndex++;
        _loadStory(story: widget.stories[_currentIndex]);
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _loadStory(story: widget.stories[_currentIndex]);
        _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTapDown: (details) {
            if (details.globalPosition.dx < size.width / 3) {
              _previousStory();
            } else if (details.globalPosition.dx > 2 * size.width / 3) {
              _nextStory();
            }
          },
          onLongPressStart: (_) => _animController.stop(),
          onLongPressEnd: (_) => _animController.forward(),
          child: Stack(
            children: [
              // Background (Pure black as requested for flat)
              Container(color: Colors.black),

              // Content
              PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.stories.length,
                itemBuilder: (context, index) {
                  final s = widget.stories[index];
                  if (s.mediaUrl != null && s.mediaUrl!.isNotEmpty) {
                    return Center(
                      child: Image.network(
                        s.mediaUrl!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator(color: Colors.white));
                        },
                      ),
                    );
                  } else {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF00796B),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        s.text ?? "",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                },
              ),

              // Segmented Progress Bars
              Positioned(
                top: 50,
                left: 10,
                right: 10,
                child: Row(
                  children: widget.stories.asMap().entries.map((entry) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Stack(
                          children: [
                            Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            if (entry.key <= _currentIndex)
                              AnimatedBuilder(
                                animation: _animController,
                                builder: (context, child) {
                                  double widthFactor = 1.0;
                                  if (entry.key == _currentIndex) {
                                    widthFactor = _animController.value;
                                  } else if (entry.key < _currentIndex) {
                                    widthFactor = 1.0;
                                  } else {
                                    widthFactor = 0.0;
                                  }
                                  return FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: widthFactor,
                                    child: Container(
                                      height: 3,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Top Header (User Info)
              Positioned(
                top: 65,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: story.userAvatar != null ? AuthenticatedImageProvider(story.userAvatar!) : null,
                      child: story.userAvatar == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            story.userName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            "${DateTime.now().difference(story.createdAt).inHours}h ago",
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
