import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/chat_provider.dart';
import '../services/media_service.dart';

class SelectedMedia {
  final Uint8List bytes;
  final String filename;
  final String type; // 'image' or 'file'
  String caption;
  final File? file; // Optionnel, pour affichage local si possible

  SelectedMedia({
    required this.bytes,
    required this.filename,
    required this.type,
    this.caption = '',
    this.file,
  });
}

class MediaPreviewScreen extends ConsumerStatefulWidget {
  final String roomId;
  final List<SelectedMedia> initialMedia;

  const MediaPreviewScreen({
    super.key,
    required this.roomId,
    required this.initialMedia,
  });

  @override
  ConsumerState<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends ConsumerState<MediaPreviewScreen> {
  late List<SelectedMedia> _mediaList;
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final MediaService _mediaService = MediaService();
  bool _isSending = false;
  double _overallProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _mediaList = List.from(widget.initialMedia);
  }

  Future<void> _addMoreImages() async {
    final List<XFile> images = await ImagePicker().pickMultiImage();
    if (images.isNotEmpty) {
      final List<SelectedMedia> news = [];
      for (var img in images) {
        final bytes = await img.readAsBytes();
        news.add(SelectedMedia(
          bytes: bytes,
          filename: img.name,
          type: 'image',
          file: File(img.path),
        ));
      }
      setState(() => _mediaList.addAll(news));
    }
  }

  Future<void> _addMoreFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result != null) {
      final List<SelectedMedia> news = [];
      for (var f in result.files) {
        if (f.bytes != null) {
          news.add(SelectedMedia(
            bytes: f.bytes!,
            filename: f.name,
            type: 'file',
          ));
        }
      }
      setState(() => _mediaList.addAll(news));
    }
  }

  void _removeCurrent() {
    if (_mediaList.length <= 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _mediaList.removeAt(_currentIndex);
      if (_currentIndex >= _mediaList.length) {
        _currentIndex = _mediaList.length - 1;
      }
    });
  }

  Future<void> _sendAll() async {
    setState(() {
      _isSending = true;
      _overallProgress = 0.0;
    });

    final notifier = ref.read(chatProvider(widget.roomId).notifier);

    try {
      for (int i = 0; i < _mediaList.length; i++) {
        final media = _mediaList[i];
        
        // Upload
        final result = await _mediaService.uploadFile(
          media.bytes, 
          filename: media.filename,
          onProgress: (sent, total) {
            if (total > 0) {
              setState(() => _overallProgress = (i + (sent / total)) / _mediaList.length);
            }
          }
        );

        // Send Message with Caption
        // Send Message with Caption
        final extraData = <String, dynamic>{
          'filename': media.filename,
          'file_size': media.bytes.length,
        };
        if (media.caption.isNotEmpty) {
          extraData['caption'] = media.caption;
        }

        notifier.sendMessage(
          result['url'], 
          media.type, 
          localPath: media.file?.path,
          extraData: extraData,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur d'envoi : $e")));
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _isSending ? null : _removeCurrent,
          ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white),
            onPressed: _isSending ? null : _addMoreImages,
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined, color: Colors.white),
            onPressed: _isSending ? null : _addMoreFiles,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _mediaList.length,
                  onPageChanged: (idx) => setState(() => _currentIndex = idx),
                  itemBuilder: (context, index) {
                    final media = _mediaList[index];
                    return Center(
                      child: media.type == 'image'
                          ? Image.memory(media.bytes, fit: BoxFit.contain)
                          : _buildFilePlaceholder(media),
                    );
                  },
                ),
              ),
              _buildControlPanel(theme),
            ],
          ),
          if (_isSending) _buildLoadingOverlay(theme),
        ],
      ),
    );
  }

  Widget _buildFilePlaceholder(SelectedMedia media) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.insert_drive_file, color: Colors.white54, size: 80),
        const SizedBox(height: 16),
        Text(media.filename, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _buildControlPanel(ThemeData theme) {
    final media = _mediaList[_currentIndex];
    final controller = TextEditingController(text: media.caption);
    controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_mediaList.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_mediaList.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _currentIndex ? 12 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: index == _currentIndex ? theme.colorScheme.primary : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (val) => media.caption = val,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ajouter une légende...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _isSending ? null : _sendAll,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(ThemeData theme) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                "Envoi en cours... ${(_overallProgress * 100).toInt()}%",
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: _overallProgress,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
