import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  final MediaService _mediaService = MediaService();

  bool _isTyping = false;
  bool _isRecording = false;
  bool _isUploading = false;
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
      _uploadAndSend(File(image.path), 'image');
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      _uploadAndSend(File(image.path), 'image');
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      _uploadAndSend(File(result.files.single.path!), 'file');
    }
  }

  Future<void> _uploadAndSend(File file, String type) async {
    setState(() => _isUploading = true);
    try {
      final result = await _mediaService.uploadFile(file);
      ref.read(chatProvider(widget.roomId).notifier).sendMessage(result['url'], type);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur d'envoi : $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final tempDir = Directory.systemTemp.path;
      final path = '$tempDir/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path != null) {
      _uploadAndSend(File(path), 'audio');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioRecorder.dispose();
    _typingDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: LinearProgressIndicator(minHeight: 2, color: Color(0xFF004D40), backgroundColor: Colors.transparent),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF004D40), size: 28),
                onPressed: _showAttachmentMenu,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: 5,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
    bool canSend = _isTyping || _controller.text.trim().isNotEmpty;
    return GestureDetector(
      onLongPress: canSend ? null : _startRecording,
      onLongPressEnd: canSend ? null : (_) => _stopRecording(),
      onTap: canSend ? _handleSend : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red : const Color(0xFF004D40),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (_isRecording ? Colors.red : const Color(0xFF004D40)).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3)
            )
          ]
        ),
        child: Icon(
          _isRecording ? Icons.mic : (canSend ? Icons.send : Icons.mic_none),
          color: Colors.white,
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
                _AttachmentOption(icon: Icons.audiotrack, color: Colors.red, label: 'Audio', onTap: () { Navigator.pop(context); _startRecording(); }),
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
