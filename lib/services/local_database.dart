import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';
import 'dart:convert';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (kIsWeb) throw UnsupportedError('SQLite non supporté sur Web');
    if (_database != null) return _database!;
    _database = await _initDB('chat_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath, {bool isRetry = false}) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Chiffrement : Récupérer ou générer une clé de 32 caractères
    const secureStorage = FlutterSecureStorage();
    String? dbPassword = await secureStorage.read(key: 'db_password');
    
    if (dbPassword == null) {
      // Générer une clé aléatoire forte au premier lancement
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      dbPassword = base64Url.encode(values);
      await secureStorage.write(key: 'db_password', value: dbPassword);
      debugPrint("🔑 Nouvelle clé de base de données générée et sécurisée.");
    }

    try {
      return await openDatabase(
        path,
        version: 13,
        password: dbPassword, // Paramètre SQLCipher pour chiffrer les fichiers .db
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    } catch (e) {
      debugPrint("❌ Erreur d'ouverture de la base de données SQLCipher : $e");
      if (!isRetry) {
        debugPrint("🔄 Suppression du fichier corrompu et de la clé, tentative de recréation...");
        try {
          await deleteDatabase(path);
          await secureStorage.delete(key: 'db_password');
        } catch (_) {}
        // Récursion unique
        return await _initDB(filePath, isRetry: true);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE messages ADD COLUMN status TEXT DEFAULT 'sent'");
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE messages ADD COLUMN is_read INTEGER DEFAULT 0");
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE messages ADD COLUMN reply_to_id TEXT");
      await db.execute("ALTER TABLE messages ADD COLUMN reply_to_content TEXT");
    }
    if (oldVersion < 7) {
      // Forcer la recréation de la table FTS en cas de corruption ou changement FTS5->FTS4
      await db.execute("DROP TABLE IF EXISTS messages_fts");
      await db.execute('''
        CREATE VIRTUAL TABLE messages_fts USING fts4(
          id,
          room_id,
          content,
          message_type,
          created_at,
          notindexed=id,
          notindexed=room_id,
          notindexed=message_type,
          notindexed=created_at,
          content='messages'
        )
      ''');
      // Repeupler à partir des messages existants
      await db.execute("INSERT INTO messages_fts(id, room_id, content, message_type, created_at) SELECT id, room_id, content, message_type, created_at FROM messages");
    }
    if (oldVersion < 5) {
      // Créer la table FTS pour la recherche rapide
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts4(
          id,
          room_id,
          content,
          message_type,
          created_at,
          notindexed=id,
          notindexed=room_id,
          notindexed=message_type,
          notindexed=created_at,
          content='messages'
        )
      ''');
      // On peuple la table FTS avec les messages existants
      await db.execute("INSERT INTO messages_fts(messages_fts) VALUES('rebuild')");
    }
    if (oldVersion < 6) {
      // Ajout d'index pour accélérer le chargement initial et les tris
      await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_room ON messages(room_id, created_at)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rooms_id ON rooms(id)');
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS profiles (
          id TEXT PRIMARY KEY,
          username TEXT,
          full_name TEXT,
          job_title TEXT,
          avatar_url TEXT,
          is_online INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute("ALTER TABLE messages ADD COLUMN caption TEXT");
    }
    if (oldVersion < 10) {
      await db.execute("ALTER TABLE messages ADD COLUMN local_path TEXT");
    }
    if (oldVersion < 11) {
      await db.execute("ALTER TABLE rooms ADD COLUMN last_message_at TEXT");
      await db.execute("ALTER TABLE rooms ADD COLUMN unread_count INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE rooms ADD COLUMN last_sender_name TEXT");
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rooms_last_msg ON rooms(last_message_at)');
    }
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_rooms (
          temp_id TEXT PRIMARY KEY,
          name TEXT,
          is_group INTEGER DEFAULT 1,
          member_ids TEXT,
          created_at TEXT,
          synced INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 13) {
      await db.execute("ALTER TABLE messages ADD COLUMN metadata_ TEXT");
      await db.execute("ALTER TABLE messages ADD COLUMN reactions TEXT");
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT,
        message_type TEXT,
        status TEXT DEFAULT 'sent',
        is_read INTEGER DEFAULT 0,
        reply_to_id TEXT,
        reply_to_content TEXT,
        caption TEXT,
        local_path TEXT,
        metadata_ TEXT,
        reactions TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts4(
        id,
        room_id,
        content,
        message_type,
        created_at,
        notindexed=id,
        notindexed=room_id,
        notindexed=message_type,
        notindexed=created_at,
        content='messages'
      )
    ''');

    await db.execute('''
      CREATE TABLE rooms (
        id TEXT PRIMARY KEY,
        name TEXT,
        is_group INTEGER,
        last_message TEXT,
        last_message_at TEXT,
        unread_count INTEGER DEFAULT 0,
        last_sender_name TEXT
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_room ON messages(room_id, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rooms_id ON rooms(id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rooms_last_msg ON rooms(last_message_at)');

    await db.execute('''
      CREATE TABLE pending_rooms (
        temp_id TEXT PRIMARY KEY,
        name TEXT,
        is_group INTEGER DEFAULT 1,
        member_ids TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        username TEXT,
        full_name TEXT,
        job_title TEXT,
        avatar_url TEXT,
        is_online INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> saveMessage(Map<String, dynamic> msg) async {
    if (kIsWeb) return;
    final db = await instance.database;
    final id = msg['id'] ?? msg['message_id'];
    
    await db.transaction((txn) async {
      // 1. Sauvegarder dans la table principale
      await txn.insert(
        'messages',
        {
          'id': id,
          'room_id': msg['room_id'],
          'sender_id': msg['sender_id'],
          'content': msg['content'],
          'message_type': msg['message_type'],
          'status': msg['status'] ?? 'sent',
          'is_read': (msg['is_read'] == true || msg['is_read'] == 1) ? 1 : 0,
          'reply_to_id': msg['reply_to_id'],
          'reply_to_content': msg['reply_to_content'],
          'caption': msg['caption'] ?? (msg['data'] != null ? msg['data']['caption'] : null),
          'local_path': msg['local_path'],
          'metadata_': msg['metadata_'] != null ? jsonEncode(msg['metadata_']) : null,
          'reactions': msg['reactions'] != null ? jsonEncode(msg['reactions']) : null,
          'created_at': msg['created_at'] ?? msg['timestamp'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Synchroniser la table FTS (FTS5 gère automatiquement via content='messages' s'il y a des triggers, 
      //    mais ici on utilise un rebâti périodique ou des insertions manuelles si nécessaire. 
      //    Note: Avec content='messages', les insertions dans 'messages' DOIVENT être suivies d'une insertion dans 'messages_fts')
      if (msg['message_type'] == 'text') {
        await txn.insert(
          'messages_fts',
          {
            'id': id,
            'room_id': msg['room_id'],
            'content': msg['content'],
            'message_type': msg['message_type'],
            'created_at': msg['created_at'] ?? msg['timestamp'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Recherche plein texte dans les messages d'un salon ou globalement
  Future<List<Map<String, dynamic>>> searchMessages(String query, {String? roomId}) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    String sql = "SELECT * FROM messages_fts WHERE content MATCH ?";
    List<dynamic> args = ['$query*']; // Recherche par préfixe automatique

    if (roomId != null) {
      sql += " AND room_id = ?";
      args.add(roomId);
    }

    sql += " ORDER BY created_at DESC";
    
    return await db.rawQuery(sql, args);
  }

  Future<void> updateMessageStatus(String id, String status, {String? newId}) async {
    if (kIsWeb) return;
    final db = await instance.database;
    final Map<String, dynamic> data = {'status': status};
    if (newId != null) data['id'] = newId;
    
    await db.update(
      'messages',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateLocalPath(String id, String path) async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.update(
      'messages',
      {'local_path': path},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateReactions(String id, dynamic reactions) async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.update(
      'messages',
      {'reactions': jsonEncode(reactions)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateMetadata(String id, dynamic metadata) async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.update(
      'messages',
      {'metadata_': jsonEncode(metadata)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteMessage(String id) async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateContent(String id, String content) async {
    await updateMessage(id, {'content': content});
  }

  Future<void> updateMessage(String id, Map<String, dynamic> data) async {
    if (kIsWeb) return;
    final db = await instance.database;
    
    // Convertir les types complexes en JSON
    final Map<String, dynamic> values = {};
    data.forEach((key, value) {
      if (key == 'metadata_' || key == 'reactions') {
        values[key] = jsonEncode(value);
      } else {
        values[key] = value;
      }
    });

    if (values.isEmpty) return;

    await db.update(
      'messages',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getMessages(String roomId) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final results = await db.query(
      'messages',
      where: 'room_id = ? AND message_type != ?',
      whereArgs: [roomId, 'reaction'],
      orderBy: 'created_at ASC',
    );


    return results.map((row) {
      final msg = Map<String, dynamic>.from(row);
      if (msg['metadata_'] != null) {
        try {
          msg['metadata_'] = jsonDecode(msg['metadata_']);
        } catch (e) {
          debugPrint("❌ Erreur décodage metadata_: $e");
          msg['metadata_'] = null;
        }
      }
      if (msg['reactions'] != null) {
        try {
          msg['reactions'] = jsonDecode(msg['reactions']);
        } catch (e) {
          debugPrint("❌ Erreur décodage reactions: $e");
          msg['reactions'] = null;
        }
      }
      return msg;
    }).toList();
  }

  Future<void> saveRooms(List<Map<String, dynamic>> rooms) async {
    if (kIsWeb) return;
    final db = await instance.database;
    final batch = db.batch();
    for (var room in rooms) {
      batch.insert(
        'rooms',
        {
          'id': room['id'],
          'name': room['name'],
          'is_group': room['is_group'] == true ? 1 : 0,
          'last_message': room['last_message'],
          'last_message_at': room['last_message_time'] ?? room['last_message_at'],
          'unread_count': room['unread_count'] ?? 0,
          'last_sender_name': room['last_sender_name'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getRooms() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final result = await db.query('rooms', orderBy: 'last_message_at DESC');
    return result.map((row) {
      return {
        ...row,
        'is_group': row['is_group'] == 1,
        'last_message_time': row['last_message_at'],
      };
    }).toList();
  }

  /// Met à jour le dernier message d'un salon (appelé quand un message arrive via WebSocket)
  Future<void> updateRoomLastMessage({
    required String roomId,
    required String lastMessage,
    required String lastMessageAt,
    String? lastSenderName,
    bool incrementUnread = false,
  }) async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.rawUpdate(
      '''UPDATE rooms SET 
         last_message = ?, 
         last_message_at = ?,
         last_sender_name = ?
         ${incrementUnread ? ', unread_count = unread_count + 1' : ''}
         WHERE id = ?''',
      [lastMessage, lastMessageAt, lastSenderName, roomId],
    );
  }

  /// Réinitialise le compteur de non-lus quand l'utilisateur ouvre un salon
  Future<void> resetUnreadCount(String roomId) async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.update(
      'rooms',
      {'unread_count': 0},
      where: 'id = ?',
      whereArgs: [roomId],
    );
   }

  Future<void> saveProfiles(List<Map<String, dynamic>> profiles) async {
    if (kIsWeb) return;
    final db = await instance.database;
    final batch = db.batch();
    for (var profile in profiles) {
      batch.insert(
        'profiles',
        {
          'id': profile['id'],
          'username': profile['username'],
          'full_name': profile['full_name'],
          'job_title': profile['job_title'],
          'avatar_url': profile['avatar_url'],
          'is_online': profile['is_online'] == true ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getProfiles() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final result = await db.query('profiles');
    return result.map((row) {
      return {
        ...row,
        'is_online': row['is_online'] == 1,
      };
    }).toList();
  }

  Future<int> getCacheSize() async {
    if (kIsWeb) return 0;
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'chat_cache.db');
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Erreur calcul taille DB: $e');
      return 0;
    }
  }

  /// Réduit la taille physique du fichier de base de données sans supprimer de données.
  Future<void> optimizeDatabase() async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      await db.execute('VACUUM');
      debugPrint('⚡ Base de données optimisée (VACUUM).');
    } catch (e) {
      debugPrint('❌ Erreur optimisation DB: $e');
    }
  }

  Future<void> clearCache() async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.execute('DELETE FROM messages');
    await db.execute('DELETE FROM rooms');
    await db.execute('DELETE FROM messages_fts'); // Ne pas oublier la table de recherche
    await optimizeDatabase();
  }

  Future<List<Map<String, dynamic>>> getMediaMessages(String roomId, {String? type}) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    String whereClause = 'room_id = ? AND message_type != "text" AND message_type != "call_offer"';
    List<dynamic> whereArgs = [roomId];
    
    if (type != null) {
      whereClause = 'room_id = ? AND message_type = ?';
      whereArgs = [roomId, type];
    }
    
    final result = await db.query(
      'messages',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return result;
  }

  // ═══ GESTION DU MODE HORS-LIGNE (Ouvrir des conversations sans réseau) ═══

  /// Sauvegarde un salon dans la table principale (pour affichage immédiat)
  Future<void> saveRoom(Map<String, dynamic> room) async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.insert('rooms', room, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Ajoute une demande de création de salon à la file d'attente
  Future<String> savePendingRoom({
    required String tempId,
    required String name,
    required bool isGroup,
    required String memberIds,
  }) async {
    if (kIsWeb) return tempId;
    final db = await instance.database;
    await db.insert('pending_rooms', {
      'temp_id': tempId,
      'name': name,
      'is_group': isGroup ? 1 : 0,
      'member_ids': memberIds,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
    return tempId;
  }

  /// Récupère tous les salons en attente de synchronisation
  Future<List<Map<String, dynamic>>> getPendingRooms() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db.query('pending_rooms', where: 'synced = 0');
  }

  /// Une fois synchronisé, on remplace l'ID temporaire par l'ID serveur partout
  Future<void> confirmPendingRoom(String tempId, String realId) async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.transaction((txn) async {
      // 1. Mettre à jour le salon
      await txn.update('rooms', {'id': realId}, where: 'id = ?', whereArgs: [tempId]);
      // 2. Mettre à jour les messages déjà envoyés localement vers ce salon
      await txn.update('messages', {'room_id': realId}, where: 'room_id = ?', whereArgs: [tempId]);
      // 3. Marquer comme synchronisé
      await txn.delete('pending_rooms', where: 'temp_id = ?', whereArgs: [tempId]);
    });
  }
}


