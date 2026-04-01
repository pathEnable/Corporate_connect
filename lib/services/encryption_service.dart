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

  /// Exporter la clé privée sous forme de phrase mnémonique (12 mots)
  Future<String> exportRecoveryPhrase() async {
    final keyPair = await getLocalKeyPair();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    // Utiliser les 32 octets de la clé X25519 comme entropie pour BIP39
    // Note: BIP39 standardise l'entropie de 128 à 256 bits (16-32 bytes). 32 bytes = 24 mots. 
    // Pour 12 mots, il faut 16 bytes. X25519 utilise 32 bytes.
    // On va utiliser les 32 octets pour 24 mots pour une sécurité maximale, 
    // ou tronquer proprement si 12 mots sont préférés (moins sécurisé mais plus simple).
    // Restons sur 24 mots (plus pro pour du E2EE) ou 12 mots via les 16 premiers octets.
    // L'idéal est la phrase complète de 32 bytes -> 24 mots.
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
    
    // Mettre à jour la clé publique sur le serveur pour refléter le changement
    final keyPair = await _algorithm.newKeyPairFromSeed(entropyBytes);
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBase64 = base64Encode(publicKey.bytes);
    await AuthService().updateProfile(publicKey: publicKeyBase64);
    
    debugPrint("🔐 Clé E2EE restaurée avec succès.");
  }

  /// Récupérer la clé publique locale en Base64
  Future<String> getLocalPublicKeyBase64() async {
    final keyPair = await getLocalKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  /// Chiffrer un message pour un destinataire
  Future<String> encrypt(String plainText, String recipientPublicKeyBase64) async {
    final keyPair = await getLocalKeyPair();
    final recipientPublicKey = SimplePublicKey(
      base64Decode(recipientPublicKeyBase64),
      type: KeyPairType.x25519,
    );

    // 1. Calculer le secret partagé Diffie-Hellman
    final sharedSecret = await _algorithm.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: recipientPublicKey,
    );

    // 2. Chiffrer avec AES-GCM
    final secretBox = await _aesApp.encrypt(
      utf8.encode(plainText),
      secretKey: sharedSecret,
    );

    // On combine le nonce et le cipher text pour le transport
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
      
      // Extraire Nonce (12 bytes), CipherText, et MAC (16 bytes)
      final nonce = combined.sublist(0, 12);
      final macBytes = combined.sublist(combined.length - 16);
      final cipherText = combined.sublist(12, combined.length - 16);

      // 1. Recalculer le même secret partagé
      final sharedSecret = await _algorithm.sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: senderPublicKey,
      );

      // 2. Déchiffrer
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
}
