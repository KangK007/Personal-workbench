import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/models/attachment.dart';
import '../core/models/workspace_record.dart';

class AppDatabase {
  static const schemaVersion = 3;

  AppDatabase({DatabaseFactory? factory, String? overridePath})
    : _factoryOverride = factory,
      _pathOverride = overridePath;

  final DatabaseFactory? _factoryOverride;
  final String? _pathOverride;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (_factoryOverride != null) {
      databaseFactory = _factoryOverride;
    } else if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = _pathOverride ?? await _defaultPath();
    _database = await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workspace_records (
            id TEXT NOT NULL,
            kind TEXT NOT NULL,
            payload TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            sync_state TEXT NOT NULL,
            PRIMARY KEY (id, kind)
          )
        ''');
        await db.execute(
          'CREATE INDEX record_kind_index ON workspace_records(kind)',
        );
        await db.execute(
          'CREATE INDEX record_updated_index ON workspace_records(updated_at)',
        );
        await db.execute('''
          CREATE TABLE app_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await _createVersionTwoTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createVersionTwoTables(db);
          await db.insert('app_metadata', {
            'key': 'schema_migration_v2',
            'value': jsonEncode({
              'from': oldVersion,
              'to': newVersion,
              'migratedAt': DateTime.now().toUtc().toIso8601String(),
            }),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (oldVersion < 3) {
          await _createVersionTwoTables(db);
          await db.insert('app_metadata', {
            'key': 'schema_migration_v3',
            'value': jsonEncode({
              'from': oldVersion,
              'to': newVersion,
              'migratedAt': DateTime.now().toUtc().toIso8601String(),
            }),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      },
    );
    return _database!;
  }

  Future<(String, String)?> pendingMigrationBackupPaths() async {
    final paths = await migrationBackupPaths();
    if (paths == null) return null;
    final (path, backupPath) = paths;
    if (path == inMemoryDatabasePath) return null;
    final source = File(path);
    if (!await source.exists()) return null;
    if (await File(backupPath).exists()) return null;
    return (source.path, backupPath);
  }

  Future<(String, String)?> migrationBackupPaths() async {
    final String path;
    try {
      path = _pathOverride ?? await _defaultPath();
    } catch (_) {
      return null;
    }
    if (path == inMemoryDatabasePath) return null;
    return (path, '$path.pre-v3.dpapi');
  }

  static Future<void> _createVersionTwoTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attachments (
        id TEXT PRIMARY KEY,
        owner_record_id TEXT NOT NULL,
        owner_kind TEXT NOT NULL,
        file_name TEXT NOT NULL,
        relative_path TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        sha256 TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS attachment_owner_index '
      'ON attachments(owner_record_id, owner_kind)',
    );
  }

  Future<String> _defaultPath() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return p.join(directory.path, 'personal_workbench.sqlite');
  }

  Future<List<WorkspaceRecord>> loadRecords({
    bool includeDeleted = true,
  }) async {
    final db = await database;
    final rows = await db.query(
      'workspace_records',
      where: includeDeleted ? null : 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
    );
    return rows
        .map(
          (row) => WorkspaceRecord.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    final db = await database;
    final stored = markDirty
        ? record.copyWith(syncState: SyncState.dirty, touch: false)
        : record.copyWith(syncState: SyncState.clean, touch: false);
    await db.insert('workspace_records', {
      'id': stored.id,
      'kind': stored.kind.name,
      'payload': stored.encode(),
      'updated_at': stored.updatedAt.millisecondsSinceEpoch,
      'deleted_at': stored.deletedAt?.millisecondsSinceEpoch,
      'sync_state': stored.syncState.name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveRecords(
    Iterable<WorkspaceRecord> records, {
    bool markDirty = true,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final record in records) {
        final stored = markDirty
            ? record.copyWith(syncState: SyncState.dirty, touch: false)
            : record.copyWith(syncState: SyncState.clean, touch: false);
        batch.insert('workspace_records', {
          'id': stored.id,
          'kind': stored.kind.name,
          'payload': stored.encode(),
          'updated_at': stored.updatedAt.millisecondsSinceEpoch,
          'deleted_at': stored.deletedAt?.millisecondsSinceEpoch,
          'sync_state': stored.syncState.name,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<WorkspaceRecord>> loadDirtyRecords() async {
    final db = await database;
    final rows = await db.query(
      'workspace_records',
      where: 'sync_state = ?',
      whereArgs: [SyncState.dirty.name],
    );
    return rows
        .map(
          (row) => WorkspaceRecord.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  Future<void> markClean(Iterable<WorkspaceRecord> records) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final record in records) {
        final clean = record.copyWith(syncState: SyncState.clean, touch: false);
        batch.update(
          'workspace_records',
          {'payload': clean.encode(), 'sync_state': SyncState.clean.name},
          where: 'id = ? AND kind = ? AND updated_at = ?',
          whereArgs: [
            record.id,
            record.kind.name,
            record.updatedAt.millisecondsSinceEpoch,
          ],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> permanentlyDelete(String id, RecordKind kind) async {
    final db = await database;
    await db.delete(
      'workspace_records',
      where: 'id = ? AND kind = ?',
      whereArgs: [id, kind.name],
    );
  }

  Future<void> replaceAll(
    Iterable<WorkspaceRecord> records, {
    bool markDirty = true,
  }) => _replaceAll(records, markDirty: markDirty);

  Future<void> replaceAllWithAttachments(
    Iterable<WorkspaceRecord> records,
    Iterable<Attachment> attachments, {
    bool markDirty = true,
  }) => _replaceAll(records, attachments: attachments, markDirty: markDirty);

  Future<void> _replaceAll(
    Iterable<WorkspaceRecord> records, {
    Iterable<Attachment>? attachments,
    required bool markDirty,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('workspace_records');
      if (attachments != null) await txn.delete('attachments');
      final batch = txn.batch();
      for (final record in records) {
        final stored = markDirty
            ? record.copyWith(syncState: SyncState.dirty, touch: false)
            : record.copyWith(syncState: SyncState.clean, touch: false);
        batch.insert('workspace_records', {
          'id': stored.id,
          'kind': stored.kind.name,
          'payload': stored.encode(),
          'updated_at': stored.updatedAt.millisecondsSinceEpoch,
          'deleted_at': stored.deletedAt?.millisecondsSinceEpoch,
          'sync_state': stored.syncState.name,
        });
      }
      if (attachments != null) {
        for (final attachment in attachments) {
          batch.insert('attachments', attachment.toDatabase());
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<String?> readMetadata(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> writeMetadata(String key, String value) async {
    final db = await database;
    await db.insert('app_metadata', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> applyDomainMigration(
    Iterable<WorkspaceRecord> records,
    String report, {
    String metadataKey = 'domain_migration_v2',
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final record in records) {
        batch.insert('workspace_records', {
          'id': record.id,
          'kind': record.kind.name,
          'payload': record.encode(),
          'updated_at': record.updatedAt.millisecondsSinceEpoch,
          'deleted_at': record.deletedAt?.millisecondsSinceEpoch,
          'sync_state': record.syncState.name,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      batch.insert('app_metadata', {
        'key': metadataKey,
        'value': report,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    });
  }

  Future<void> saveAttachment(Attachment attachment) async {
    final db = await database;
    await db.insert(
      'attachments',
      attachment.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Attachment>> loadAttachments({String? ownerRecordId}) async {
    final db = await database;
    final rows = await db.query(
      'attachments',
      where: ownerRecordId == null ? null : 'owner_record_id = ?',
      whereArgs: ownerRecordId == null ? null : [ownerRecordId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Attachment.fromDatabase).toList(growable: false);
  }

  Future<int> attachmentBytes() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) AS total FROM attachments',
    );
    return (rows.single['total'] as num?)?.toInt() ?? 0;
  }

  Future<void> deleteAttachment(String id) async {
    final db = await database;
    await db.delete('attachments', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAttachments(Iterable<Attachment> attachments) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('attachments');
      final batch = txn.batch();
      for (final attachment in attachments) {
        batch.insert('attachments', attachment.toDatabase());
      }
      await batch.commit(noResult: true);
    });
  }

  Future<String?> readLocalGameState() => readMetadata('local_game_state_v1');

  Future<void> writeLocalGameState(String value) =>
      writeMetadata('local_game_state_v1', value);

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
