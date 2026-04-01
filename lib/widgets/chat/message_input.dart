import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/chat_provider.dart';
import '../../services/media_service.dart';

class MessageInput extends ConsumerStatefulWidget {
  final String roomId;
  final Map<String, dynamic>? replyingTo;
  final VoidCallback onCancelReply;

  const MessageInput({
    super.key,
    required this.roomId,
    this.replyingTo,
    required this.onCancelReply,
  });

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final MediaService _mediaService = MediaService();

  bool _isTyping = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final typing = _controller.text.isNotEmpty;
    if (typing != _isTyping) {
      setState(() => _isTyping = typing);
    }

    _typingDebounce?.cancel();
    if (typing) {
      ref.read(chatProvider(widget.roomId).notifier).sendTyping(true);
      _typingDebounce = Timer(const Duration(seconds: 3), () {
        ref.read(chatProvider(widget.roomId).notifier).sendTyping(false);
      });
    } else {
      ref.read(chatProvider(widget.roomId).notifier).sendTyping(false);
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    final extraData = widget.replyingTo != null 
        ? {'reply_to_id': widget.replyingTo!['id'] ?? widget.replyingTo!['message_id']} 
        : null;

    ref.read(chatProvider(widget.roomId).notifier).sendMessage(text, 'text', extraData: extraData);
    _controller.clear();
    widget.onCancelReply();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      _uploadAndSend(bytes, image.name, 'image');
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final bytes = await image.readAsBytes();
      _uploadAndSend(bytes, image.name, 'image');
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.single.bytes != null) {
      _uploadAndSend(
        result.files.single.bytes!,
        result.files.single.name,
        'file',
      );
    }
  }

  Future<void> _uploadAndSend(Uint8List bytes, String filename, String type) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    
    try {
      final result = await _mediaService.uploadFile(
        bytes,
        filename: filename,
        onProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );
      
      ref.read(chatProvider(widget.roomId).notifier).sendMessage(result['url'], type);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur d'envoi : $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _typingDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -2),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                minHeight: 3,
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.add_circle_outline_rounded,
                    color: theme.colorScheme.primary, size: 28),
                onPressed: _showAttachmentMenu,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white10
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.dividerColor.withAlpha(50)),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: 5,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message...',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildActionCircle(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCircle() {
    final theme = Theme.of(context);
    bool canSend = _isTyping || _controller.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: canSend ? _handleSend : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: theme.colorScheme.primary.withAlpha(76),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ]),
        child: Icon(
          canSend ? Icons.send_rounded : Icons.mic_none_rounded,
          color: theme.colorScheme.onPrimary,
          size: 22,
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(icon: Icons.camera_alt, color: Colors.blue, label: 'Caméra', onTap: () { Navigator.pop(context); _takePhoto(); }),
                _AttachmentOption(icon: Icons.image, color: Colors.purple, label: 'Images', onTap: () { Navigator.pop(context); _pickImage(); }),
                _AttachmentOption(icon: Icons.insert_drive_file, color: Colors.orange, label: 'Document', onTap: () { Navigator.pop(context); _pickFile(); }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _AttachmentOption({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
