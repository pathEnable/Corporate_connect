import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chat_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
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
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE rooms (
        id TEXT PRIMARY KEY,
        name TEXT,
        is_group INTEGER,
        last_message TEXT
      )
    ''');
  }

  Future<void> saveMessage(Map<String, dynamic> msg) async {
    final db = await instance.database;
    await db.insert(
      'messages',
      {
        'id': msg['id'] ?? msg['message_id'],
        'room_id': msg['room_id'],
        'sender_id': msg['sender_id'],
        'content': msg['content'],
        'message_type': msg['message_type'],
        'status': msg['status'] ?? 'sent',
        'is_read': (msg['is_read'] == true || msg['is_read'] == 1) ? 1 : 0,
        'reply_to_id': msg['reply_to_id'],
        'reply_to_content': msg['reply_to_content'],
        'created_at': msg['created_at'] ?? msg['timestamp'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMessageStatus(String id, String status, {String? newId}) async {
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

  Future<List<Map<String, dynamic>>> getMessages(String roomId) async {
    final db = await instance.database;
    return await db.query(
      'messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> saveRooms(List<Map<String, dynamic>> rooms) async {
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
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getRooms() async {
    final db = await instance.database;
    final result = await db.query('rooms');
    return result.map((row) {
      return {
        ...row,
        'is_group': row['is_group'] == 1,
      };
    }).toList();
  }

  Future<int> getCacheSize() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'chat_cache.db');
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> clearCache() async {
    final db = await instance.database;
    await db.execute('DELETE FROM messages');
    await db.execute('DELETE FROM rooms');
    // Facultatif: Vider aussi l'espace pour réduire la taille du fichier physique
    await db.execute('VACUUM');
  }

  Future<List<Map<String, dynamic>>> getMediaMessages(String roomId, {String? type}) async {
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
}


