import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/encryption_service.dart';

class KeyBackupScreen extends StatefulWidget {
  const KeyBackupScreen({super.key});

  @override
  State<KeyBackupScreen> createState() => _KeyBackupScreenState();
}

class _KeyBackupScreenState extends State<KeyBackupScreen> {
  String? _mnemonic;
  bool _isRevealed = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMnemonic();
  }

  Future<void> _loadMnemonic() async {
    try {
      final phrase = await EncryptionService().exportRecoveryPhrase();
      if (mounted) {
        setState(() {
          _mnemonic = phrase;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard() {
    if (_mnemonic == null) return;
    Clipboard.setData(ClipboardData(text: _mnemonic!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phrase copiée dans le presse-papiers')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    List<String> words = _mnemonic?.split(' ') ?? [];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Sauvegarde de Sécurité'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shield_rounded, size: 64, color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Votre phrase de récupération',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ces 24 mots sont la seule clé de vos messages chiffrés. Si vous perdez cet appareil, cette phrase vous permettra de tout récupérer.',
                  style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150), fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'IMPORTANT: Ne partagez JAMAIS cette phrase. Quiconque la possède peut lire vos messages.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 32),
                
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.dividerColor.withAlpha(50)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(words.length, (index) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.dividerColor.withAlpha(30)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${index + 1}. ', style: TextStyle(color: theme.colorScheme.primary.withAlpha(150), fontSize: 10)),
                                Text(words[index], style: const TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    if (!_isRevealed)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _isRevealed = true),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withAlpha(240),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility_off_rounded, color: theme.colorScheme.primary),
                                  const SizedBox(height: 8),
                                  const Text('Appuyez pour révéler', style: TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isRevealed ? _copyToClipboard : null,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Tout copier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
