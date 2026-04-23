import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../../providers/chat_provider.dart';
import '../../services/media_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_config.dart';
import '../../screens/media_preview_screen.dart';

class MessageInput extends ConsumerStatefulWidget {
  final String roomId;
  final Map<String, dynamic>? replyingTo;
  final VoidCallback onCancelReply;
  final List<Map<String, dynamic>> members;
  final Map<String, dynamic>? editingMessage;
  final VoidCallback? onCancelEdit;

  const MessageInput({
    super.key,
    required this.roomId,
    this.replyingTo,
    required this.onCancelReply,
    this.members = const [],
    this.editingMessage,
    this.onCancelEdit,
  });

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final MediaService _mediaService = MediaService();
  late final RecorderController _recorderController;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FocusNode _focusNode = FocusNode();

  bool _isTyping = false;
  bool _isUploading = false;
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  bool _isListening = false;
  
  double _panDx = 0.0;
  double _panDy = 0.0;
  double _uploadProgress = 0.0;
  Timer? _typingDebounce;

  int _recordDuration = 0;
  Timer? _recordTimer;

  // === Mentions ===
  List<Map<String, dynamic>> _mentionSuggestions = [];


  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _recorderController = RecorderController();
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

    // Détection des mentions @
    _detectMention();
  }

  void _detectMention() {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor <= 0) {
      if (_mentionSuggestions.isNotEmpty) setState(() => _mentionSuggestions = []);
      return;
    }

    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');

    if (atIndex == -1) {
      if (_mentionSuggestions.isNotEmpty) setState(() => _mentionSuggestions = []);
      return;
    }

    // Vérifier qu'il n'y a pas d'espace entre @ et le curseur
    final query = before.substring(atIndex + 1);
    if (query.contains(' ')) {
      if (_mentionSuggestions.isNotEmpty) setState(() => _mentionSuggestions = []);
      return;
    }


    final suggestions = widget.members.where((m) {
      final name = (m['username'] ?? m['name'] ?? '').toLowerCase();
      return name.contains(query.toLowerCase());
    }).take(5).toList();

    setState(() => _mentionSuggestions = suggestions);
  }

  void _insertMention(Map<String, dynamic> member) {
    final name = member['username'] ?? member['name'] ?? '';
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');
    final after = text.substring(cursor);

    final newText = '${text.substring(0, atIndex)}@$name $after';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: (atIndex + name.length + 2).toInt()),
    );
    setState(() => _mentionSuggestions = []);
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    HapticFeedback.mediumImpact();

    // Mode édition : modifier le message existant
    if (widget.editingMessage != null) {
      final msgId = widget.editingMessage!['id']?.toString() ?? '';
      if (msgId.isNotEmpty) {
        ref.read(chatProvider(widget.roomId).notifier).editMessage(msgId, text);
      }
      _controller.clear();
      widget.onCancelEdit?.call();
      return;
    }
    
    final extraData = widget.replyingTo != null 
        ? {
            'reply_to_id': widget.replyingTo!['id'] ?? widget.replyingTo!['message_id'],
            'metadata_': {
              'reply_to_content': widget.replyingTo!['content'],
            }
          } 
        : null;

    ref.read(chatProvider(widget.roomId).notifier).sendMessage(text, 'text', extraData: extraData);
    _controller.clear();
    widget.onCancelReply();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _typingDebounce?.cancel();
    _recordTimer?.cancel();
    _recorderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF121212) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 15),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 8, 
        right: 8, 
        top: 8, 
        bottom: MediaQuery.of(context).padding.bottom + 10
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_mentionSuggestions.isNotEmpty)
            _buildMentionSuggestions(theme),
          if (widget.editingMessage != null) _buildEditHeader(theme),
          if (widget.replyingTo != null && widget.editingMessage == null) _buildReplyHeader(theme),
          if (_isUploading) _buildUploadingBar(theme),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_isRecording)
                _buildIconButton(
                  icon: Icons.add_rounded,
                  color: theme.colorScheme.primary.withAlpha(200),
                  onPressed: _showAttachmentMenu,
                ),
              const SizedBox(width: 4),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _isRecording ? _buildRecordingUI(theme) : _buildInputUI(theme),
                ),
              ),
              const SizedBox(width: 8),
              _buildActionCircle(theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMentionSuggestions(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _mentionSuggestions.length,
        itemBuilder: (context, index) {
          final member = _mentionSuggestions[index];
          final name = member['username'] ?? member['name'] ?? 'Inconnu';
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 12,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 10, color: theme.colorScheme.primary),
              ),
            ),
            title: Text(name, style: const TextStyle(fontSize: 14)),
            onTap: () => _insertMention(member),
          );
        },
      ),
    );
  }

  Widget _buildReplyHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
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
    );
  }

  Widget _buildEditHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Colors.blue, width: 3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_rounded, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Modifier le message",
                  style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.editingMessage!['content'] ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () {
              _controller.clear();
              widget.onCancelEdit?.call();
            },
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(covariant MessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pré-remplir le champ de texte lors du passage en mode édition
    if (widget.editingMessage != null && oldWidget.editingMessage == null) {
      final content = widget.editingMessage!['content']?.toString() ?? '';
      _controller.text = content;
      _controller.selection = TextSelection.collapsed(offset: content.length);
      _focusNode.requestFocus();
    }
    // Vider le champ quand on quitte le mode édition
    if (widget.editingMessage == null && oldWidget.editingMessage != null) {
      _controller.clear();
    }
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
    final isDark = theme.brightness == Brightness.dark;
    
    return TextField(
      key: const ValueKey('input_ui'),
      controller: _controller,
      focusNode: _focusNode,
      maxLines: 6,
      minLines: 1,
      style: const TextStyle(fontSize: 16),
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: 'Message',
        hintStyle: TextStyle(
          fontSize: 16, 
          color: isDark ? Colors.grey[400] : Colors.grey[600]
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: theme.colorScheme.primary.withAlpha(100), width: 1.5),
        ),
        isDense: true,
      ),
    );
  }

  Widget _buildRecordingUI(ThemeData theme) {
    if (_isRecordingLocked) {
      // UX "Verrouillé" (comme WhatsApp)
      return Container(
        key: const ValueKey('recording_locked_ui'),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 22),
              onPressed: () => _stopRecording(cancel: true),
            ),
            Text(
              _formatDuration(_recordDuration), 
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AudioWaveforms(
                size: const Size(double.infinity, 24),
                recorderController: _recorderController,
                enableGesture: false,
                waveStyle: WaveStyle(
                  waveColor: theme.colorScheme.primary,
                  extendWaveform: true,
                  showMiddleLine: false,
                  waveThickness: 2.0,
                  spacing: 4.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: () => _stopRecording(cancel: false),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      );
    } else {
      // UX "En maintien" (comme WhatsApp)
      return Container(
        key: const ValueKey('recording_hold_ui'),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(_recordDuration), 
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
            const Spacer(),
            const Icon(Icons.chevron_left_rounded, size: 20, color: Colors.grey),
            const SizedBox(width: 4),
            const Text(
              "Glissez pour annuler",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(width: 16), // Espace pour ne pas coller au gros bouton micro
          ],
        ),
      );
    }
  }

  Widget _buildActionCircle(ThemeData theme) {
    bool canSend = _isTyping || _controller.text.trim().isNotEmpty;
    bool isRec = _isRecording;

    if (_isRecordingLocked) {
      return const SizedBox.shrink(); // Hide the hold button when locked
    }

    return GestureDetector(
      onLongPressStart: (_) {
        if (!canSend && !isRec) {
          _startRecording();
        }
      },
      onLongPressMoveUpdate: (details) {
        if (!isRec || _isRecordingLocked) return;
        
        _panDx += details.localOffsetFromOrigin.dx - _panDx;
        _panDy += details.localOffsetFromOrigin.dy - _panDy;
        
        // Swipe up to lock
        if (_panDy < -50) {
          setState(() => _isRecordingLocked = true);
          HapticFeedback.heavyImpact();
        }
        
        // Swipe left to cancel
        if (_panDx < -50) {
          _stopRecording(cancel: true);
        }
      },
      onLongPressEnd: (_) {
        if (isRec && !_isRecordingLocked) {
          _stopRecording(cancel: false);
        }
        _panDx = 0.0;
        _panDy = 0.0;
      },
      onTap: () {
        if (canSend) {
          _handleSend();
        } else {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Maintenez appuyé pour enregistrer un message vocal.', style: TextStyle(color: Colors.white)),
              backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.9),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          HapticFeedback.lightImpact();
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Le cadenas qui apparaît au-dessus du micro (comme WhatsApp)
          if (isRec && !_isRecordingLocked)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: const Icon(Icons.lock_rounded, size: 24, color: Colors.grey),
            ),
            
          // Le bouton d'action principal
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (isRec && !_isRecordingLocked) ? 70 : 48, // Beaucoup plus gros
            height: (isRec && !_isRecordingLocked) ? 70 : 48,
            decoration: BoxDecoration(
              color: isRec ? theme.colorScheme.primary : theme.colorScheme.primary, // Reste de la couleur du thème
              shape: BoxShape.circle,
              boxShadow: isRec ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 4,
                )
              ] : null,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  (canSend) ? Icons.send_rounded : Icons.mic_rounded,
                  key: ValueKey(canSend ? 'send' : 'mic'),
                  color: Colors.white,
                  size: (isRec && !_isRecordingLocked) ? 32 : 22,
                ),
              ),
            ),

          ),
        ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentOption(icon: Icons.poll_rounded, color: Colors.teal, label: 'Sondage', onTap: () { Navigator.pop(context); _showPollModal(); }),
                    _AttachmentOption(icon: Icons.check_circle_outline_rounded, color: Colors.green, label: 'Tâche', onTap: () { Navigator.pop(context); _showTaskModal(); }),
                    _AttachmentOption(icon: Icons.event_rounded, color: Colors.redAccent, label: 'Réunion', onTap: () { Navigator.pop(context); _showMeetingModal(); }),
                    _AttachmentOption(icon: Icons.schedule_rounded, color: Colors.indigo, label: 'Prog.', onTap: () { Navigator.pop(context); _showScheduleModal(); }),
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
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission microphone requise.')),
          );
        }
        return;
      }

      if (await _recorderController.checkPermission()) {
        HapticFeedback.mediumImpact();
        
        // Initialize Speech to text based on preferences
        final prefs = await SharedPreferences.getInstance();
        final sttEnabled = prefs.getBool('privacy_stt_enabled') ?? true;
        
        if (sttEnabled) {
          bool available = await _speech.initialize();
          if (available) {
            setState(() => _isListening = true);
            _speech.listen(
              onResult: (result) {
                // Transcription désactivée pour l'instant
              },
              localeId: 'fr_FR',
            );
          }
        }

        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorderController.record(path: path);
        
        if (mounted) {
          setState(() {
            _isRecording = true;
            _isRecordingLocked = false;
            _panDx = 0.0;
            _panDy = 0.0;
          });
        }
        _startTimer();
      }
    } catch (_) {}
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    try {
      if (_isListening) {
        await _speech.stop();
        _isListening = false;
      }
      
      final path = await _recorderController.stop();
      _stopTimer();
      
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isRecordingLocked = false;
        });
      }

      if (!cancel && path != null) {
        HapticFeedback.lightImpact();
        final bytes = await File(path).readAsBytes();
        _uploadAndSend(bytes, 'audio_record.m4a', 'audio', localPath: path);
      } else {
        HapticFeedback.heavyImpact();
      }
      
      if (mounted) {
        setState(() {
          // Reset recording state
        });
      }
    } catch (_) {}
  }

  Future<void> _uploadAndSend(Uint8List bytes, String filename, String type, {String? localPath}) async {
    if (mounted) setState(() { _isUploading = true; _uploadProgress = 0.0; });
    try {
      final result = await _mediaService.uploadFile(bytes, filename: filename, onProgress: (sent, total) {
          if (total > 0 && mounted) setState(() => _uploadProgress = sent / total);
        },
      );
      ref.read(chatProvider(widget.roomId).notifier).sendMessage(
        result['url'], 
        type,
        localPath: localPath,
        extraData: {
          'filename': filename,
          'file_size': bytes.length,
        },
      );
    } catch (_) {}
    if (mounted) setState(() { _isUploading = false; });
  }

  Future<void> _pickImage() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      final List<SelectedMedia> selected = [];
      for (var img in images) {
        final bytes = await img.readAsBytes();
        selected.add(SelectedMedia(
          bytes: bytes, 
          filename: img.name, 
          type: 'image',
          file: File(img.path),
        ));
      }
      _navigateToPreview(selected);
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      _navigateToPreview([
        SelectedMedia(
          bytes: await image.readAsBytes(), 
          filename: image.name, 
          type: 'image', 
          file: File(image.path),
        )
      ]);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
    if (result != null) {
      final List<SelectedMedia> selected = result.files
        .where((f) => f.bytes != null)
        .map((f) => SelectedMedia(
          bytes: f.bytes!, 
          filename: f.name, 
          type: 'file',
          file: f.path != null ? File(f.path!) : null,
        )).toList();
      if (selected.isNotEmpty) _navigateToPreview(selected);
    }
  }

  void _navigateToPreview(List<SelectedMedia> media) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPreviewScreen(roomId: widget.roomId, initialMedia: media)));
  }

  void _showPollModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _CreatePollModal(roomId: widget.roomId),
      ),
    );
  }

  void _showTaskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _CreateTaskModal(roomId: widget.roomId),
      ),
    );
  }

  void _showScheduleModal() {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Rédigez d\'abord un message à programmer.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ScheduleModal(
          roomId: widget.roomId, 
          onSchedule: (DateTime scheduledDate) async {
            // Appeler l'API REST de programmation (pas le WebSocket !)
            final messageContent = _controller.text.trim();
            if (messageContent.isEmpty) return;
            _controller.clear();
            
            try {
              final token = await AuthService().getToken();
              final response = await http.post(
                Uri.parse('${ApiConfig.baseUrl}/rooms/${widget.roomId}/messages/schedule'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode({
                  'content': messageContent,
                  'message_type': 'text',
                  'scheduled_for': scheduledDate.toUtc().toIso8601String(),
                }),
              );
              
              if (!context.mounted) return;
              if (response.statusCode == 200 || response.statusCode == 201) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📅 Message programmé pour le ${scheduledDate.day}/${scheduledDate.month} à ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: Colors.indigo,
                  ),
                );
              } else {
                final body = jsonDecode(response.body);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ ${body['detail'] ?? 'Erreur lors de la programmation'}'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Erreur réseau : $e'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
        ),
      ),
    );
  }

  void _showMeetingModal() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.event_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Planifier une réunion',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Titre de la réunion',
                      prefixIcon: const Icon(Icons.title_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText: 'Description (optionnelle)',
                      prefixIcon: const Icon(Icons.description_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(startDate != null ? 'Début: ${startDate!.day}/${startDate!.month} ${startDate!.hour}:${startDate!.minute.toString().padLeft(2, '0')}' : 'Sélectionner le début'),
                    leading: const Icon(Icons.play_circle_outline_rounded),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                      if (d == null) return;
                      if (!context.mounted) return;
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (t == null) return;
                      setModalState(() {
                        startDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                        endDate = startDate!.add(const Duration(hours: 1)); // Default end
                      });
                    },
                  ),
                  ListTile(
                    title: Text(endDate != null ? 'Fin: ${endDate!.day}/${endDate!.month} ${endDate!.hour}:${endDate!.minute.toString().padLeft(2, '0')}' : 'Sélectionner la fin'),
                    leading: const Icon(Icons.stop_circle_outlined),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: startDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                      if (d == null) return;
                      if (!context.mounted) return;
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (t == null) return;
                      setModalState(() => endDate = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      onPressed: () {
                        if (titleCtrl.text.trim().isEmpty || startDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Veuillez définir un titre et une date de début.')),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        _sendMeeting(titleCtrl.text.trim(), descCtrl.text.trim(), startDate!, endDate);
                      },
                      child: const Text('PLANIFIER', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _sendMeeting(String title, String desc, DateTime start, DateTime? end) {
    HapticFeedback.mediumImpact();
    final metadata = {
      'title': title,
      'description': desc,
      'start_date': start.toIso8601String(),
      'end_date': end?.toIso8601String(),
    };
    ref.read(chatProvider(widget.roomId).notifier).sendMessage(
          'Rejoignez ma réunion : $title',
          'meeting',
          extraData: {'metadata_': metadata}, // use metadata_ explicitly if backend requires it, or just use extraData
        );
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

// ================= MODALS D'EXTENSIONS =================

class _CreatePollModal extends ConsumerStatefulWidget {
  final String roomId;
  const _CreatePollModal({required this.roomId});

  @override
  ConsumerState<_CreatePollModal> createState() => _CreatePollModalState();
}

class _CreatePollModalState extends ConsumerState<_CreatePollModal> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionsControllers = [TextEditingController(), TextEditingController()];

  @override
  void dispose() {
    _questionController.dispose();
    for (var c in _optionsControllers) { c.dispose(); }
    super.dispose();
  }

  void _addOption() {
    if (_optionsControllers.length < 5) {
      setState(() => _optionsControllers.add(TextEditingController()));
    }
  }

  void _submit() {
    final question = _questionController.text.trim();
    final options = _optionsControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (question.isEmpty || options.length < 2) return;
    
    // Structure des options
    final optionsData = options.map((opt) => {'text': opt}).toList();

    ref.read(chatProvider(widget.roomId).notifier).sendMessage(
      question,
      'poll',
      extraData: {
        'metadata_': {
          'question': question,
          'options': optionsData,
          'votes': {}, // Initialiser comme un objet pour le backend
          'total_votes': 0,
        }
      }
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 40, height: 4, alignment: Alignment.center, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
          const Text("Créer un sondage", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextField(controller: _questionController, decoration: const InputDecoration(labelText: "Posez votre question...", border: OutlineInputBorder())),
          const SizedBox(height: 16),
          ...List.generate(_optionsControllers.length, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: TextField(controller: _optionsControllers[index], decoration: InputDecoration(hintText: "Option ${index + 1}", border: const UnderlineInputBorder())),
          )),
          if (_optionsControllers.length < 5)
            TextButton.icon(onPressed: _addOption, icon: const Icon(Icons.add), label: const Text("Ajouter une option")),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text("Envoyer le sondage")),
        ],
      ),
    );
  }
}

class _CreateTaskModal extends ConsumerStatefulWidget {
  final String roomId;
  const _CreateTaskModal({required this.roomId});

  @override
  ConsumerState<_CreateTaskModal> createState() => _CreateTaskModalState();
}

class _CreateTaskModalState extends ConsumerState<_CreateTaskModal> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedAssigneeId;
  DateTime? _deadline;

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final chatState = ref.read(chatProvider(widget.roomId));
    final assigneeName = _selectedAssigneeId != null ? chatState.members[_selectedAssigneeId] : null;

    ref.read(chatProvider(widget.roomId).notifier).sendMessage(
      title,
      'task',
      extraData: {
        'metadata_': {
          'description': _descController.text.trim(),
          'status': 'todo',
          'assignee_id': _selectedAssigneeId,
          'assignee_name': assigneeName,
          'deadline': _deadline != null ? "${_deadline!.day}/${_deadline!.month}/${_deadline!.year}" : null,
          'is_done': false,
        }
      }
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.roomId));
    final members = chatState.members;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 40, height: 4, alignment: Alignment.center, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
          const Text("Nouvelle tâche", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Titre de la tâche", border: OutlineInputBorder(), prefixIcon: Icon(Icons.title))),
          const SizedBox(height: 16),
          TextField(controller: _descController, maxLines: 2, decoration: const InputDecoration(labelText: "Description (optionnel)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.description))),
          const SizedBox(height: 16),
          
          // Sélection de l'assigné
          DropdownButtonFormField<String>(
            initialValue: _selectedAssigneeId,
            decoration: const InputDecoration(labelText: "Assigner à", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
            items: [
              const DropdownMenuItem(value: null, child: Text("Tout le monde")),
              ...members.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
            ],
            onChanged: (val) => setState(() => _selectedAssigneeId = val),
          ),
          const SizedBox(height: 16),

          // Sélection de la deadline
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _deadline ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) setState(() => _deadline = date);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: "Date limite", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
              child: Text(_deadline == null ? "Aucune" : "${_deadline!.day}/${_deadline!.month}/${_deadline!.year}"),
            ),
          ),
          
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Créer et Envoyer"),
          ),
        ],
      ),
    );
  }
}

class _ScheduleModal extends StatefulWidget {
  final String roomId;
  final Function(DateTime) onSchedule;
  const _ScheduleModal({required this.roomId, required this.onSchedule});

  @override
  State<_ScheduleModal> createState() => _ScheduleModalState();
}

class _ScheduleModalState extends State<_ScheduleModal> {
  DateTime _selectedDate = DateTime.now().add(const Duration(minutes: 5));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 40, height: 4, alignment: Alignment.center, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
          const Text("Programmer l'envoi", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Text(
            "Le message actuellement rédigé sera envoyé à la date indiquée ci-dessous.",
            style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text("Date et Heure"),
            subtitle: Text("${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} à ${_selectedDate.hour}:${_selectedDate.minute.toString().padLeft(2, '0')}"),
            trailing: const Icon(Icons.edit_calendar),
            onTap: () async {
              final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (!context.mounted) return;
              if (date == null) return;
              
              final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_selectedDate));
              if (!context.mounted) return;
              if (time == null) return;
              
              setState(() {
                _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
              });
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onSchedule(_selectedDate);
            },
            child: const Text("Confirmer la programmation"),
          ),
        ],
      ),
    );
  }
}
