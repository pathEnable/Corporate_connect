import 'package:flutter/material.dart';
import '../models/status_model.dart';

class StoryViewScreen extends StatefulWidget {
  final List<StatusModel> stories;
  final int initialIndex;

  const StoryViewScreen({super.key, required this.stories, this.initialIndex = 0});

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _animController = AnimationController(vsync: this);

    _loadStory(story: widget.stories[_currentIndex]);

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animController.stop();
        _animController.reset();
        setState(() {
          if (_currentIndex + 1 < widget.stories.length) {
            _currentIndex++;
            _loadStory(story: widget.stories[_currentIndex]);
            _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          } else {
            Navigator.pop(context);
          }
        });
      }
    });
  }

  void _loadStory({required StatusModel story}) {
    _animController.stop();
    _animController.reset();
    _animController.duration = const Duration(seconds: 5); // 5 secondes par story
    _animController.forward();
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            // Précédent
            if (_currentIndex > 0) {
              setState(() {
                _currentIndex--;
                _loadStory(story: widget.stories[_currentIndex]);
                _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              });
            }
          } else if (details.globalPosition.dx > 2 * width / 3) {
            // Suivant
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
        },
        child: Stack(
          children: [
            // Image / Vidéo (Pour l'instant image par défaut)
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.stories.length,
              itemBuilder: (context, index) {
                final s = widget.stories[index];
                return Center(
                  child: s.mediaUrl != null && s.mediaUrl!.isNotEmpty
                      ? Image.network(s.mediaUrl!, fit: BoxFit.contain, width: double.infinity)
                      : Container(
                          color: const Color(0xFF004D40),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(40),
                          child: Text(
                            s.text ?? "",
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                );
              },
            ),
            // Barres de progression
            Positioned(
              top: 40,
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
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)),
                          ),
                          entry.key == _currentIndex
                              ? AnimatedBuilder(
                                  animation: _animController,
                                  builder: (context, child) {
                                    return Container(
                                      height: 3,
                                      width: MediaQuery.of(context).size.width * _animController.value / widget.stories.length,
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)),
                                    );
                                  },
                                )
                              : Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: entry.key < _currentIndex ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Info Utilisateur
            Positioned(
              top: 55,
              left: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: story.userAvatar != null ? NetworkImage(story.userAvatar!) : null,
                    backgroundColor: Colors.grey,
                    child: story.userAvatar == null ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(story.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(
                        "${DateTime.now().difference(story.createdAt).inHours}h ago",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Fermer
            Positioned(
              top: 55,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
