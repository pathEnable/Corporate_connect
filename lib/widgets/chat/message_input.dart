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

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      _uploadAndSend(File(result.files.single.path!), 'file');
    }
  }

  Future<void> _uploadAndSend(File file, String type) async {
    try {
      final result = await _mediaService.uploadFile(file);
      ref.read(chatProvider(widget.roomId).notifier).sendMessage(result['url'], type);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur d'envoi : $e")));
      }
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFF004D40)),
                onPressed: _showAttachmentMenu,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onLongPress: _isTyping ? null : _startRecording,
                onLongPressEnd: _isTyping ? null : (_) => _stopRecording(),
                onTap: _isTyping ? _handleSend : null,
                child: CircleAvatar(
                  backgroundColor: _isRecording ? Colors.red : const Color(0xFF004D40),
                  child: Icon(
                    _isRecording ? Icons.mic : (_isTyping ? Icons.send : Icons.mic_none),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.purple),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }
}
