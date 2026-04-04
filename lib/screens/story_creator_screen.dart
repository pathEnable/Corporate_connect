import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/home_provider.dart';
import '../widgets/premium_background.dart';

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
        // In a real app, upload to S3/Firebase here. 
        // For now, we simulate by using the local path (or a placeholder if backend requires URL)
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
    
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Créer une Story', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                child: _isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Partager', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Stack(
                        children: [
                          // Background Image or Gradient
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            height: double.infinity,
                            color: _imageFile != null ? Colors.transparent : _statusColors[_colorIndex],
                            child: _imageFile != null
                                ? Image.file(_imageFile!, fit: BoxFit.cover)
                                : null,
                          ),
                          
                          // Glassy Overlay for Text
                          // Text Input
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: TextField(
                                controller: _textController,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Tapez un statut...",
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 28),
                                  border: InputBorder.none,
                                ),
                                maxLines: null,
                              ),
                            ),
                          ),

                          // Floating Controls
                          Positioned(
                            bottom: 20,
                            right: 20,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_imageFile == null) ...[
                                  _buildGlassButton(
                                    icon: Icons.palette_rounded,
                                    onTap: _cycleColor,
                                    theme: theme,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                _buildGlassButton(
                                  icon: Icons.image_rounded,
                                  onTap: _pickImage,
                                  theme: theme,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap, required ThemeData theme}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
