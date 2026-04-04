import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/media_service.dart';
import '../../screens/media_preview_screen.dart';

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
  final _audioRecorder = AudioRecorder();

  bool _isTyping = false;
  bool _isUploading = false;
  bool _isRecording = false;
  double _uploadProgress = 0.0;
  Timer? _typingDebounce;

  int _recordDuration = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final typing = _controller.text.isNotEmpty;
    if (typing != _isTyping) {
      if (mounted) setState(() => _isTyping = typing);
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
    
    HapticFeedback.mediumImpact();
    
    final extraData = widget.replyingTo != null 
        ? {'reply_to_id': widget.replyingTo!['id'] ?? widget.replyingTo!['message_id']} 
        : null;

    ref.read(chatProvider(widget.roomId).notifier).sendMessage(text, 'text', extraData: extraData);
    _controller.clear();
    widget.onCancelReply();
  }

  @override
  void dispose() {
    _controller.dispose();
    _typingDebounce?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          padding: EdgeInsets.only(
            left: 12, 
            right: 12, 
            top: 10, 
            bottom: MediaQuery.of(context).padding.bottom + 10
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.replyingTo != null) _buildReplyHeader(theme),
              if (_isUploading) _buildUploadingBar(theme),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!_isRecording)
                    _buildIconButton(
                      icon: Icons.add_circle_outline_rounded,
                      color: theme.colorScheme.primary,
                      onPressed: _showAttachmentMenu,
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _isRecording ? _buildRecordingUI(theme) : _buildInputUI(theme),
                  ),
                  const SizedBox(width: 8),
                  _buildActionCircle(theme),
                ],
              ),
            ],
          ),
    );
  }

  Widget _buildReplyHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "En réponse à",
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.replyingTo!['content'] ?? "Fichier",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildUploadingBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: _uploadProgress > 0 ? _uploadProgress : null,
          minHeight: 3,
          color: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
    );
  }

  Widget _buildInputUI(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _controller,
        maxLines: 5,
        minLines: 1,
        style: const TextStyle(fontSize: 15),
        decoration: const InputDecoration(
          hintText: 'Écrire un message...',
          hintStyle: TextStyle(fontSize: 15, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (_) => _handleSend(),
      ),
    );
  }

  Widget _buildRecordingUI(ThemeData theme) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: () => _stopRecording(cancel: true),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          const _RecordingBlinkDot(),
          const SizedBox(width: 8),
          Text(_formatDuration(_recordDuration), 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          const Text(
            "Enregistrement...",
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCircle(ThemeData theme) {
    bool canSend = _isTyping || _controller.text.trim().isNotEmpty;
    bool isRec = _isRecording;

    return GestureDetector(
      onTap: () {
        if (canSend) {
          _handleSend();
        } else if (isRec) {
          _stopRecording(cancel: false); // Envoie l'audio
        } else {
          _startRecording();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            (canSend || isRec) ? Icons.send_rounded : Icons.mic_none_rounded,
            color: Colors.black,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, color: color, size: 28),
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentOption(icon: Icons.camera_alt_rounded, color: Colors.blue, label: 'Caméra', onTap: () { Navigator.pop(context); _takePhoto(); }),
                    _AttachmentOption(icon: Icons.image_rounded, color: Colors.purple, label: 'Images', onTap: () { Navigator.pop(context); _pickImage(); }),
                    _AttachmentOption(icon: Icons.insert_drive_file_rounded, color: Colors.orange, label: 'Document', onTap: () { Navigator.pop(context); _pickFile(); }),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
      ),
    );
  }

  // Audio Logic (Simplified for Redesign)
  void _startTimer() {
    _recordDuration = 0;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) setState(() => _recordDuration++);
    });
  }

  void _stopTimer() {
    _recordTimer?.cancel();
    _recordTimer = null;
    _recordDuration = 0;
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        HapticFeedback.mediumImpact();
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        if (mounted) {
          setState(() {
            _isRecording = true;
          });
        }
        _startTimer();
      }
    } catch (_) {}
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    try {
      final path = await _audioRecorder.stop();
      _stopTimer();
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }

      if (!cancel && path != null) {
        HapticFeedback.lightImpact();
        final bytes = await File(path).readAsBytes();
        _uploadAndSend(bytes, 'audio_record.m4a', 'audio');
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }

  Future<void> _uploadAndSend(Uint8List bytes, String filename, String type) async {
    if (mounted) setState(() { _isUploading = true; _uploadProgress = 0.0; });
    try {
      final result = await _mediaService.uploadFile(bytes, filename: filename, onProgress: (sent, total) {
          if (total > 0 && mounted) setState(() => _uploadProgress = sent / total);
        },
      );
      ref.read(chatProvider(widget.roomId).notifier).sendMessage(result['url'], type);
    } catch (_) {}
    if (mounted) setState(() { _isUploading = false; });
  }

  Future<void> _pickImage() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      final List<SelectedMedia> selected = [];
      for (var img in images) {
        selected.add(SelectedMedia(bytes: await img.readAsBytes(), filename: img.name, type: 'image', file: File(img.path)));
      }
      _navigateToPreview(selected);
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      _navigateToPreview([SelectedMedia(bytes: await image.readAsBytes(), filename: image.name, type: 'image', file: File(image.path))]);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
    if (result != null) {
      final List<SelectedMedia> selected = result.files.where((f) => f.bytes != null).map((f) => SelectedMedia(bytes: f.bytes!, filename: f.name, type: 'file')).toList();
      if (selected.isNotEmpty) _navigateToPreview(selected);
    }
  }

  void _navigateToPreview(List<SelectedMedia> media) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPreviewScreen(roomId: widget.roomId, initialMedia: media)));
  }
}

class _RecordingBlinkDot extends StatefulWidget {
  const _RecordingBlinkDot();
  @override
  State<_RecordingBlinkDot> createState() => _RecordingBlinkDotState();
}

class _RecordingBlinkDotState extends State<_RecordingBlinkDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)));
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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
