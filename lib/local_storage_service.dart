import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'models.dart';

class LocalStorageService {
  LocalStorageService._();

  static final LocalStorageService instance = LocalStorageService._();

  static const _databaseName = 'xii_chat_local.db';
  static const _databaseVersion = 2;

  Database? _database;

  Future<void> initialize() async {
    if (_database != null) {
      return;
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final appDir = await getApplicationSupportDirectory();
    final dbPath = p.join(appDir.path, _databaseName);

    _database = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _upgradeSchema(db, oldVersion, newVersion);
        },
      ),
    );
  }

  Database get _db {
    final db = _database;
    if (db == null) {
      throw StateError('数据库尚未初始化。');
    }
    return db;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_activated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        generation_options_json TEXT,
        local_images_json TEXT,
        FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE generated_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        message_id INTEGER NOT NULL,
        image_url TEXT,
        image_bytes_base64 TEXT,
        file_name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE,
        FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE session_switch_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        switched_at TEXT NOT NULL,
        FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_messages_session_created ON messages(session_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_generated_images_created ON generated_images(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_session_switch_logs_session ON session_switch_logs(session_id)',
    );
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_state (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  Future<String?> readAppState(String key) async {
    final rows = await _db.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value']?.toString();
  }

  Future<void> writeAppState(String key, String value) async {
    await _db.insert(
      'app_state',
      {
        'key': key,
        'value': value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAppState(String key) async {
    await _db.delete(
      'app_state',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  Future<void> clearAllLocalData() async {
    await _db.transaction((txn) async {
      await txn.delete('generated_images');
      await txn.delete('messages');
      await txn.delete('session_switch_logs');
      await txn.delete('sessions');
      await txn.delete('app_state');
    });
  }

  Future<ChatSessionInfo?> loadLatestSession() async {
    final lastSessionId = await loadLastActiveSessionId();
    if (lastSessionId != null) {
      final sessions = await loadSessions();
      for (final session in sessions) {
        if (session.id == lastSessionId) {
          return session;
        }
      }
    }

    final sessions = await loadSessions();
    if (sessions.isEmpty) {
      return null;
    }
    return sessions.first;
  }

  Future<int?> loadLastActiveSessionId() async {
    return int.tryParse(await readAppState('last_active_session_id') ?? '');
  }

  Future<List<ChatSessionInfo>> loadSessions() async {
    final rows = await _db.rawQuery('''
      SELECT
        s.id,
        s.title,
        s.created_at,
        s.updated_at,
        s.last_activated_at,
        COUNT(DISTINCT m.id) AS message_count,
        COUNT(DISTINCT l.id) AS switch_count
      FROM sessions s
      LEFT JOIN messages m ON m.session_id = s.id
      LEFT JOIN session_switch_logs l ON l.session_id = s.id
      GROUP BY s.id
      ORDER BY COALESCE(s.last_activated_at, s.updated_at) DESC, s.id DESC
    ''');

    return rows.map(_mapSessionInfo).toList(growable: false);
  }

  Future<ChatSessionInfo> createSession({String? title}) async {
    final now = DateTime.now().toIso8601String();
    final resolvedTitle = (title == null || title.trim().isEmpty)
        ? '新对话 ${DateTime.now().month}/${DateTime.now().day} ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}'
        : title.trim();

    final id = await _db.insert('sessions', {
      'title': resolvedTitle,
      'created_at': now,
      'updated_at': now,
      'last_activated_at': now,
    });

    await _db.insert('session_switch_logs', {
      'session_id': id,
      'switched_at': now,
    });

    return ChatSessionInfo(
      id: id,
      title: resolvedTitle,
      createdAt: DateTime.parse(now),
      updatedAt: DateTime.parse(now),
      lastActivatedAt: DateTime.parse(now),
      messageCount: 0,
      switchCount: 1,
    );
  }

  Future<void> renameSession(int sessionId, String title) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return;
    }

    await _db.update(
      'sessions',
      {
        'title': trimmedTitle,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteSession(int sessionId) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'generated_images',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await txn.delete(
        'messages',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await txn.delete(
        'session_switch_logs',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await txn.delete(
        'sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      final stateRows = await txn.query(
        'app_state',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['last_active_session_id'],
        limit: 1,
      );
      final savedLastId = stateRows.isEmpty
          ? null
          : int.tryParse(stateRows.first['value']?.toString() ?? '');
      if (savedLastId == sessionId) {
        await txn.delete(
          'app_state',
          where: 'key = ?',
          whereArgs: ['last_active_session_id'],
        );
      }
    });
  }

  Future<void> clearSessionMessages(int sessionId) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'generated_images',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await txn.delete(
        'messages',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await txn.update(
        'sessions',
        {
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  Future<void> activateSession(int sessionId) async {
    final now = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      await txn.update(
        'sessions',
        {
          'last_activated_at': now,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      await txn.insert('session_switch_logs', {
        'session_id': sessionId,
        'switched_at': now,
      });
      await txn.insert(
        'app_state',
        {
          'key': 'last_active_session_id',
          'value': sessionId.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<List<ChatMessage>> loadMessages(int sessionId) async {
    final messageRows = await _db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC, id ASC',
    );

    if (messageRows.isEmpty) {
      return const <ChatMessage>[];
    }

    final imageRows = await _db.query(
      'generated_images',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC, id ASC',
    );

    final imagesByMessageId = <int, List<GeneratedImageAsset>>{};
    for (final row in imageRows) {
      final messageId = row['message_id'] as int;
      imagesByMessageId
          .putIfAbsent(messageId, () => <GeneratedImageAsset>[])
          .add(_mapGeneratedImage(row));
    }

    return messageRows.map((row) {
      final id = row['id'] as int;
      return ChatMessage(
        id: id,
        text: (row['text'] as String?) ?? '',
        role: _parseRole((row['role'] as String?) ?? 'bot'),
        createdAt: DateTime.parse(row['created_at'] as String),
        generationOptions: _decodeGenerationOptions(
          row['generation_options_json'] as String?,
        ),
        localImages: _decodeLocalImages(row['local_images_json'] as String?),
        generatedImages: imagesByMessageId[id] ?? const <GeneratedImageAsset>[],
      );
    }).toList(growable: false);
  }

  Future<ChatMessage> saveMessage({
    required int sessionId,
    required ChatMessage message,
  }) async {
    final createdAt = message.createdAt.toIso8601String();

    final messageId = await _db.transaction((txn) async {
      final insertedMessageId = await txn.insert('messages', {
        'session_id': sessionId,
        'role': message.role.name,
        'text': message.text,
        'created_at': createdAt,
        'generation_options_json':
            _encodeGenerationOptions(message.generationOptions),
        'local_images_json': _encodeLocalImages(message.localImages),
      });

      for (final image in message.generatedImages) {
        await txn.insert('generated_images', {
          'session_id': sessionId,
          'message_id': insertedMessageId,
          'image_url': image.imageUrl,
          'image_bytes_base64':
              image.hasBytes ? base64Encode(image.bytes!) : null,
          'file_name': image.fileName,
          'mime_type': image.mimeType,
          'created_at': createdAt,
        });
      }

      await txn.update(
        'sessions',
        {
          'updated_at': createdAt,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      return insertedMessageId;
    });

    return ChatMessage(
      id: messageId,
      text: message.text,
      role: message.role,
      createdAt: message.createdAt,
      generatedImages: message.generatedImages,
      localImages: message.localImages,
      generationOptions: message.generationOptions,
    );
  }

  Future<void> maybeUpdateSessionTitleFromMessage(
    int sessionId,
    String rawText,
  ) async {
    final text = rawText.trim();
    if (text.isEmpty) {
      return;
    }

    final current = await _db.query(
      'sessions',
      columns: ['title'],
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (current.isEmpty) {
      return;
    }

    final currentTitle = (current.first['title'] as String?) ?? '';
    if (!currentTitle.startsWith('新对话 ')) {
      return;
    }

    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final nextTitle = normalized.length <= 24
        ? normalized
        : '${normalized.substring(0, 24)}...';

    await _db.update(
      'sessions',
      {
        'title': nextTitle,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<GeneratedImageHistoryEntry>> loadGeneratedImageHistory() async {
    final rows = await _db.rawQuery('''
      SELECT
        gi.id,
        gi.session_id,
        gi.message_id,
        gi.image_url,
        gi.image_bytes_base64,
        gi.file_name,
        gi.mime_type,
        gi.created_at,
        s.title AS session_title,
        m.text AS message_text,
        m.generation_options_json
      FROM generated_images gi
      INNER JOIN sessions s ON s.id = gi.session_id
      INNER JOIN messages m ON m.id = gi.message_id
      ORDER BY gi.created_at DESC, gi.id DESC
    ''');

    return rows.map((row) {
      final options = _decodeGenerationOptions(
        row['generation_options_json'] as String?,
      );
      return GeneratedImageHistoryEntry(
        id: row['id'] as int,
        sessionId: row['session_id'] as int,
        messageId: row['message_id'] as int,
        sessionTitle: (row['session_title'] as String?) ?? '未命名会话',
        messageText: (row['message_text'] as String?) ?? '',
        createdAt: DateTime.parse(row['created_at'] as String),
        size: options?.size,
        quality: options?.quality,
        image: _mapGeneratedImage(row),
      );
    }).toList(growable: false);
  }

  Future<List<SessionSwitchLogEntry>> loadSessionSwitchLogs({
    int? sessionId,
    int limit = 100,
  }) async {
    final rows = await _db.query(
      'session_switch_logs',
      where: sessionId == null ? null : 'session_id = ?',
      whereArgs: sessionId == null ? null : [sessionId],
      orderBy: 'switched_at DESC, id DESC',
      limit: limit,
    );

    return rows
        .map(
          (row) => SessionSwitchLogEntry(
            id: row['id'] as int,
            sessionId: row['session_id'] as int,
            switchedAt: DateTime.parse(row['switched_at'] as String),
          ),
        )
        .toList(growable: false);
  }

  ChatSessionInfo _mapSessionInfo(Map<String, Object?> row) {
    return ChatSessionInfo(
      id: row['id'] as int,
      title: (row['title'] as String?) ?? '未命名会话',
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      lastActivatedAt: row['last_activated_at'] == null
          ? null
          : DateTime.parse(row['last_activated_at'] as String),
      messageCount: _toInt(row['message_count']),
      switchCount: _toInt(row['switch_count']),
    );
  }

  GeneratedImageAsset _mapGeneratedImage(Map<String, Object?> row) {
    final imageBytesBase64 = row['image_bytes_base64'] as String?;
    return GeneratedImageAsset(
      bytes: imageBytesBase64 == null
          ? null
          : Uint8List.fromList(base64Decode(imageBytesBase64)),
      imageUrl: row['image_url'] as String?,
      fileName: (row['file_name'] as String?) ?? 'generated.png',
      mimeType: (row['mime_type'] as String?) ?? 'image/png',
    );
  }

  Role _parseRole(String rawRole) {
    return rawRole == Role.user.name ? Role.user : Role.bot;
  }

  String? _encodeGenerationOptions(ImageGenerationOptions? options) {
    if (options == null) {
      return null;
    }
    return jsonEncode({
      'size': options.size,
      'quality': options.quality,
    });
  }

  ImageGenerationOptions? _decodeGenerationOptions(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final size = decoded['size']?.toString();
    final quality = decoded['quality']?.toString();
    final legacyAspectRatio = decoded['aspectRatio']?.toString();

    if ((size == null || size.isEmpty) &&
        (quality == null || quality.isEmpty) &&
        (legacyAspectRatio == null || legacyAspectRatio.isEmpty)) {
      return null;
    }

    return ImageGenerationOptions(
      size: size?.isNotEmpty == true
          ? size!
          : _mapLegacyAspectRatioToSize(legacyAspectRatio),
      quality: quality?.isNotEmpty == true ? quality! : 'auto',
    ).normalized();
  }

  String _mapLegacyAspectRatioToSize(String? aspectRatio) {
    switch (aspectRatio) {
      case '1:1':
        return '1024x1024';
      case '3:2':
      case '16:9':
        return '1536x1024';
      case '2:3':
      case '9:16':
        return '1024x1536';
      default:
        return 'auto';
    }
  }

  String? _encodeLocalImages(List<ChatImageAttachment> images) {
    if (images.isEmpty) {
      return null;
    }

    return jsonEncode(
      images
          .map(
            (image) => {
              'name': image.name,
              'mimeType': image.mimeType,
              'bytesBase64': base64Encode(image.bytes),
            },
          )
          .toList(growable: false),
    );
  }

  List<ChatImageAttachment> _decodeLocalImages(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return const <ChatImageAttachment>[];
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return const <ChatImageAttachment>[];
    }

    return decoded.whereType<Map>().map((item) {
      final bytesBase64 = item['bytesBase64']?.toString() ?? '';
      return ChatImageAttachment(
        bytes: Uint8List.fromList(base64Decode(bytesBase64)),
        name: item['name']?.toString() ?? 'image.png',
        mimeType: item['mimeType']?.toString() ?? 'image/png',
      );
    }).toList(growable: false);
  }

  int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
