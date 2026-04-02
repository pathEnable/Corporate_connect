import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'auth_service.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _algorithm = X25519();
  final _aesApp = AesGcm.with256bits();
  final _secureStorage = const FlutterSecureStorage();

  /// Générer ou récupérer la paire de clés locale
  Future<SimpleKeyPair> getLocalKeyPair() async {
    // 1. Tenter de lire depuis le stockage sécurisé
    String? privateKeyBase64 = await _secureStorage.read(key: 'e2ee_private_key');

    // 2. Migration depuis SharedPreferences (Légué)
    if (privateKeyBase64 == null) {
      final prefs = await SharedPreferences.getInstance();
      privateKeyBase64 = prefs.getString('e2ee_private_key');
      
      if (privateKeyBase64 != null) {
        await _secureStorage.write(key: 'e2ee_private_key', value: privateKeyBase64);
        await prefs.remove('e2ee_private_key');
        debugPrint("🔐 Clé E2EE migrée vers le stockage sécurisé.");
      }
    }

    if (privateKeyBase64 != null) {
      final privateKeyBytes = base64Decode(privateKeyBase64);
      return await _algorithm.newKeyPairFromSeed(privateKeyBytes);
    } else {
      // Générer une nouvelle clé (entropie aléatoire)
      final newKeyPair = await _algorithm.newKeyPair();
      final privateKey = await newKeyPair.extractPrivateKeyBytes();
      final newPrivateKeyBase64 = base64Encode(privateKey);
      
      await _secureStorage.write(key: 'e2ee_private_key', value: newPrivateKeyBase64);
      
      // Publier la clé publique initiale sur le serveur
      final publicKey = await newKeyPair.extractPublicKey();
      final publicKeyBase64 = base64Encode(publicKey.bytes);
      await AuthService().updateProfile(publicKey: publicKeyBase64);
      
      return newKeyPair;
    }
  }

  /// Récupérer les octets de la clé privée pour compute()
  Future<Uint8List?> getPrivateKeyBytes() async {
    String? privateKeyBase64 = await _secureStorage.read(key: 'e2ee_private_key');
    if (privateKeyBase64 != null) {
      return base64Decode(privateKeyBase64);
    }
    return null;
  }

  /// Exporter la clé privée sous forme de phrase mnémonique (12 mots)
  Future<String> exportRecoveryPhrase() async {
    final keyPair = await getLocalKeyPair();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    return bip39.entropyToMnemonic(hex.encode(privateKeyBytes));
  }

  /// Restaurer la clé depuis une phrase mnémonique
  Future<void> importFromRecoveryPhrase(String mnemonic) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception("Phrase de récupération invalide.");
    }
    
    final entropyHex = bip39.mnemonicToEntropy(mnemonic);
    final entropyBytes = hex.decode(entropyHex);
    
    final privateKeyBase64 = base64Encode(entropyBytes);
    await _secureStorage.write(key: 'e2ee_private_key', value: privateKeyBase64);
    
    final keyPair = await _algorithm.newKeyPairFromSeed(entropyBytes);
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBase64 = base64Encode(publicKey.bytes);
    await AuthService().updateProfile(publicKey: publicKeyBase64);
  }

  /// Chiffrer un message pour un destinataire
  Future<String> encrypt(String plainText, String recipientPublicKeyBase64) async {
    final keyPair = await getLocalKeyPair();
    final recipientPublicKey = SimplePublicKey(
      base64Decode(recipientPublicKeyBase64),
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _algorithm.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: recipientPublicKey,
    );

    final secretBox = await _aesApp.encrypt(
      utf8.encode(plainText),
      secretKey: sharedSecret,
    );

    final combined = Uint8List(secretBox.nonce.length + secretBox.cipherText.length + secretBox.mac.bytes.length);
    combined.setRange(0, secretBox.nonce.length, secretBox.nonce);
    combined.setRange(secretBox.nonce.length, secretBox.nonce.length + secretBox.cipherText.length, secretBox.cipherText);
    combined.setRange(secretBox.nonce.length + secretBox.cipherText.length, combined.length, secretBox.mac.bytes);

    return base64Encode(combined);
  }

  /// Déchiffrer un message reçu
  Future<String> decrypt(String combinedBase64, String senderPublicKeyBase64) async {
    try {
      final keyPair = await getLocalKeyPair();
      final senderPublicKey = SimplePublicKey(
        base64Decode(senderPublicKeyBase64),
        type: KeyPairType.x25519,
      );

      final combined = base64Decode(combinedBase64);
      final nonce = combined.sublist(0, 12);
      final macBytes = combined.sublist(combined.length - 16);
      final cipherText = combined.sublist(12, combined.length - 16);

      final sharedSecret = await _algorithm.sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: senderPublicKey,
      );

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
      final clearTextBytes = await _aesApp.decrypt(
        secretBox,
        secretKey: sharedSecret,
      );

      return utf8.decode(clearTextBytes);
    } catch (e) {
      debugPrint("Erreur déchiffrement: $e");
      return "[Message chiffré illisible]";
    }
  }

  /// Méthode statique pour déchiffrer une liste de messages via compute()
  /// Cela évite de bloquer l'interface (ANR) pendant le traitement de masse.
  static Future<List<Map<String, dynamic>>> decryptBulk(Map<String, dynamic> params) async {
    final List<Map<String, dynamic>> messages = List<Map<String, dynamic>>.from(params['messages']);
    final Map<String, String> memberKeys = Map<String, String>.from(params['memberKeys']);
    final Uint8List privateKeyBytes = params['privateKeyBytes'];

    final algorithm = X25519();
    final aesApp = AesGcm.with256bits();
    
    final keyPair = await algorithm.newKeyPairFromSeed(privateKeyBytes);

    for (var msg in messages) {
      final bool isText = msg['message_type'] == 'text';
      if (isText && msg['content'] != null && msg['is_decrypted'] != true) {
        final senderId = msg['sender_id'].toString();
        
        if (memberKeys.containsKey(senderId)) {
          final String content = msg['content'];
          if (content.length > 20 && !content.contains(' ')) {
            try {
              final senderPublicKey = SimplePublicKey(
                base64Decode(memberKeys[senderId]!),
                type: KeyPairType.x25519,
              );

              final sharedSecret = await algorithm.sharedSecretKey(
                keyPair: keyPair,
                remotePublicKey: senderPublicKey,
              );

              final combined = base64Decode(content);
              if (combined.length > 28) { // 12 (nonce) + 16 (mac)
                final nonce = combined.sublist(0, 12);
                final macBytes = combined.sublist(combined.length - 16);
                final cipherText = combined.sublist(12, combined.length - 16);

                final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
                final clearTextBytes = await aesApp.decrypt(
                  secretBox,
                  secretKey: sharedSecret,
                );
                
                msg['content'] = utf8.decode(clearTextBytes);
                msg['is_encrypted'] = true;
              }
            } catch (_) {
              // Silently fail for individual messages in bulk
            }
          }
          msg['is_decrypted'] = true;
        }
      }
    }
    return messages;
  }
}
