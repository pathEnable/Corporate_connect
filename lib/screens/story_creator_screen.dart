import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_provider.dart';

class StoryCreatorScreen extends ConsumerStatefulWidget {
  const StoryCreatorScreen({super.key});

  @override
  ConsumerState<StoryCreatorScreen> createState() => _StoryCreatorScreenState();
}

class _StoryCreatorScreenState extends ConsumerState<StoryCreatorScreen> {
  final TextEditingController _textController = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  
  int _colorIndex = 0;
  final List<Color> _statusColors = [
    const Color(0xFF00796B), // Vert Emini
    const Color(0xFF8E24AA), // Violet
    const Color(0xFFE53935), // Rouge
    const Color(0xFF3949AB), // Indigo
    const Color(0xFFF4511E), // Orange
    const Color(0xFF00B0FF), // Bleu
    const Color(0xFF43A047), // Vert Clair
    const Color(0xFF212121), // Sombre
  ];

  void _cycleColor() {
    setState(() {
      _colorIndex = (_colorIndex + 1) % _statusColors.length;
    });
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_textController.text.isEmpty && _imageFile == null) return;

    setState(() => _isUploading = true);

    try {
      String? mediaUrl;
      if (_imageFile != null) {
        mediaUrl = _imageFile!.path; 
      }

      await ref.read(homeProvider.notifier).createStatus(
        text: _textController.text,
        mediaUrl: mediaUrl,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la création de la story")),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Hero(
      tag: 'story_creator',
      child: Scaffold(
        backgroundColor: _imageFile != null ? Colors.black : _statusColors[_colorIndex],
        body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Content (Image or Gradient)
          if (_imageFile != null)
            Positioned.fill(
              child: Image.file(_imageFile!, fit: BoxFit.cover),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _statusColors[_colorIndex],
                      _statusColors[_colorIndex].withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),

          // 2. Immersive Overlay (Gradient to read text)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                  ],
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ),
              ),
            ),
          ),

          // 3. Central Text Input
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: TextField(
                controller: _textController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
                decoration: InputDecoration(
                  hintText: "Quoi de neuf ?",
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                  border: InputBorder.none,
                ),
                maxLines: null,
                autofocus: true,
              ),
            ),
          ),

          // 4. Top Controls (Close & Mode)
          Positioned(
            top: topPadding + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircularButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.pop(context),
                  color: Colors.black38,
                ),
                Row(
                  children: [
                    if (_imageFile == null)
                      _buildCircularButton(
                        icon: Icons.palette_rounded,
                        onTap: _cycleColor,
                        color: Colors.black38,
                      ),
                    const SizedBox(width: 12),
                    _buildCircularButton(
                      icon: _imageFile != null ? Icons.image_not_supported_rounded : Icons.image_rounded,
                      onTap: _imageFile != null ? () => setState(() => _imageFile = null) : _pickImage,
                      color: Colors.black38,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 5. Bottom Actions (Publish)
          Positioned(
            bottom: bottomPadding + 30,
            left: 20,
            right: 20,
            child: Row(
              children: [
                const Spacer(),
                GestureDetector(
                  onTap: _isUploading ? null : _submit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isUploading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                          )
                        else ...[
                          const Text(
                            'PARTAGER',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCircularButton({required IconData icon, required VoidCallback onTap, required Color color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
