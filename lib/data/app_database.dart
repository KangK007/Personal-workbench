import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/models/attachment.dart';
import '../core/models/workspace_record.dart';

class AppDatabase {
  static const schemaVersion = 4;

  AppDatabase({DatabaseFactory? factory, String? overridePath})
    : _factoryOverride = factory,
      _pathOverride = overridePath;

  final DatabaseFactory? _factoryOverride;
  final String? _pathOverride;
  Database? _database;
  String _activeAccountId = '';
  bool _signedOutView = true;

  String get activeAccountId => _activeAccountId;

  /// Switches the local record partition. Legacy rows remain in the ownerless
  /// local partition and are never silently assigned to a signed-in account.
  Future<void> activateAccount(String? accountId) async {
    if (runtimeType != AppDatabase) {
      _activeAccountId = accountId ?? '';
      _signedOutView = accountId == null;
      return;
    }
    final target =
        accountId ?? await readMetadata('last_active_account_v4') ?? '';
    _activeAccountId = target;
    _signedOutView = accountId == null;
    if (target.isNotEmpty) {
      await writeMetadata('last_active_account_v4', target);
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;

    final DatabaseFactory factory;
    if (_factoryOverride != null) {
      factory = _factoryOverride;
    } else if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    } else {
      factory = databaseFactory;
    }

    final path = _pathOverride ?? await _defaultPath();
    _database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE workspace_records (
            account_id TEXT NOT NULL DEFAULT '',
            id TEXT NOT NULL,
            kind TEXT NOT NULL,
            payload TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            sync_state TEXT NOT NULL,
            PRIMARY KEY (account_id, id, kind)
          )
        ''');
          await db.execute(
            'CREATE INDEX record_kind_index ON workspace_records(account_id, kind)',
          );
          await db.execute(
            'CREATE INDEX record_updated_index ON workspace_records(account_id, updated_at)',
          );
          await db.execute('''
          CREATE TABLE app_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
          await db.execute('''
            CREATE TABLE attachments (
              account_id TEXT NOT NULL DEFAULT '', id TEXT NOT NULL,
              owner_record_id TEXT NOT NULL, owner_kind TEXT NOT NULL,
              file_name TEXT NOT NULL, relative_path TEXT NOT NULL,
              mime_type TEXT NOT NULL, size_bytes INTEGER NOT NULL,
              sha256 TEXT NOT NULL, created_at INTEGER NOT NULL,
              PRIMARY KEY (account_id, id)
            )
          ''');
          await db.execute(
            'CREATE INDEX attachment_owner_index '
            'ON attachments(account_id, owner_record_id, owner_kind)',
          );
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
          if (oldVersion < 4) {
            await _upgradeToVersionFour(db);
            await db.insert('app_metadata', {
              'key': 'schema_migration_v4',
              'value': jsonEncode({
                'from': oldVersion,
                'to': newVersion,
                'migratedAt': DateTime.now().toUtc().toIso8601String(),
              }),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        },
      ),
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
    return (path, '$path.pre-v4.dpapi');
  }

  static Future<void> _createVersionTwoTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attachments (
        id TEXT NOT NULL,
        owner_record_id TEXT NOT NULL,
        owner_kind TEXT NOT NULL,
        file_name TEXT NOT NULL,
        relative_path TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        sha256 TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS attachment_owner_index '
      'ON attachments(owner_record_id, owner_kind)',
    );
  }

  static Future<void> _createVersionFourTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workspace_records_v4 (
        account_id TEXT NOT NULL DEFAULT '',
        id TEXT NOT NULL,
        kind TEXT NOT NULL,
        payload TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        sync_state TEXT NOT NULL,
        PRIMARY KEY (account_id, id, kind)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attachments_v4 (
        account_id TEXT NOT NULL DEFAULT '',
        id TEXT NOT NULL,
        owner_record_id TEXT NOT NULL,
        owner_kind TEXT NOT NULL,
        file_name TEXT NOT NULL,
        relative_path TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        sha256 TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (account_id, id)
      )
    ''');
  }

  static Future<void> _upgradeToVersionFour(DatabaseExecutor db) async {
    await _createVersionFourTables(db);
    await db.execute('''
      INSERT INTO workspace_records_v4
        (account_id, id, kind, payload, updated_at, deleted_at, sync_state)
      SELECT '', id, kind, payload, updated_at, deleted_at, sync_state
      FROM workspace_records
    ''');
    await db.execute('''
      INSERT INTO attachments_v4
        (account_id, id, owner_record_id, owner_kind, file_name, relative_path,
         mime_type, size_bytes, sha256, created_at)
      SELECT '', id, owner_record_id, owner_kind, file_name, relative_path,
             mime_type, size_bytes, sha256, created_at
      FROM attachments
    ''');
    await db.execute('DROP TABLE workspace_records');
    await db.execute('DROP TABLE attachments');
    await db.execute(
      'ALTER TABLE workspace_records_v4 RENAME TO workspace_records',
    );
    await db.execute('ALTER TABLE attachments_v4 RENAME TO attachments');
    await db.execute(
      'CREATE INDEX record_kind_index ON workspace_records(account_id, kind)',
    );
    await db.execute(
      'CREATE INDEX record_updated_index ON workspace_records(account_id, updated_at)',
    );
    await db.execute(
      'CREATE INDEX attachment_owner_index '
      'ON attachments(account_id, owner_record_id, owner_kind)',
    );
  }

  Future<String> _defaultPath() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return p.join(directory.path, 'personal_workbench.sqlite');
  }

  Future<List<WorkspaceRecord>> loadRecords({
    bool includeDeleted = true,
    String? accountId,
  }) async {
    final db = await database;
    final selectedAccountId = accountId ?? _activeAccountId;
    final includeOwnerless = accountId == null && _signedOutView;
    final rows = await db.query(
      'workspace_records',
      where: includeDeleted
          ? (includeOwnerless
                ? "account_id = ? OR account_id = ''"
                : 'account_id = ?')
          : (includeOwnerless
                ? "(account_id = ? OR account_id = '') AND deleted_at IS NULL"
                : 'account_id = ? AND deleted_at IS NULL'),
      whereArgs: [selectedAccountId],
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
      'account_id': _activeAccountId,
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
          'account_id': _activeAccountId,
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

  Future<List<WorkspaceRecord>> loadDirtyRecords({String? accountId}) async {
    final db = await database;
    final selectedAccountId = accountId ?? _activeAccountId;
    final includeOwnerless = accountId == null && _signedOutView;
    final rows = await db.query(
      'workspace_records',
      where: includeOwnerless
          ? "(account_id = ? OR account_id = '') AND sync_state = ?"
          : 'account_id = ? AND sync_state = ?',
      whereArgs: [selectedAccountId, SyncState.dirty.name],
    );
    return rows
        .map(
          (row) => WorkspaceRecord.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  /// Applies a fetched cloud version only while the local snapshot is still
  /// current. This keeps edits made during network I/O from being overwritten.
  Future<bool> saveRemoteRecordIfUnchanged(
    WorkspaceRecord record, {
    required String accountId,
    required WorkspaceRecord? expectedLocal,
    WorkspaceRecord? conflictCopy,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'workspace_records',
        columns: ['payload'],
        where: 'account_id = ? AND id = ? AND kind = ?',
        whereArgs: [accountId, record.id, record.kind.name],
        limit: 1,
      );
      if (expectedLocal == null) {
        if (rows.isNotEmpty) return false;
      } else {
        if (rows.isEmpty) return false;
        final current = WorkspaceRecord.fromJson(
          jsonDecode(rows.single['payload'] as String) as Map<String, dynamic>,
        );
        if (current.encode() != expectedLocal.encode()) return false;
      }

      if (conflictCopy != null) {
        final storedConflict = conflictCopy.copyWith(
          syncState: SyncState.dirty,
          touch: false,
        );
        await txn.insert('workspace_records', {
          'account_id': accountId,
          'id': storedConflict.id,
          'kind': storedConflict.kind.name,
          'payload': storedConflict.encode(),
          'updated_at': storedConflict.updatedAt.millisecondsSinceEpoch,
          'deleted_at': storedConflict.deletedAt?.millisecondsSinceEpoch,
          'sync_state': SyncState.dirty.name,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final stored = record.copyWith(syncState: SyncState.clean, touch: false);
      await txn.insert('workspace_records', {
        'account_id': accountId,
        'id': stored.id,
        'kind': stored.kind.name,
        'payload': stored.encode(),
        'updated_at': stored.updatedAt.millisecondsSinceEpoch,
        'deleted_at': stored.deletedAt?.millisecondsSinceEpoch,
        'sync_state': SyncState.clean.name,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  Future<void> markClean(
    Iterable<WorkspaceRecord> records, {
    String? accountId,
  }) async {
    final db = await database;
    final selectedAccountId = accountId ?? _activeAccountId;
    await db.transaction((txn) async {
      for (final record in records) {
        final rows = await txn.query(
          'workspace_records',
          columns: ['payload'],
          where: 'account_id = ? AND id = ? AND kind = ?',
          whereArgs: [selectedAccountId, record.id, record.kind.name],
          limit: 1,
        );
        if (rows.isEmpty) continue;
        final payload = rows.single['payload'] as String;
        final current = WorkspaceRecord.fromJson(
          jsonDecode(payload) as Map<String, dynamic>,
        );
        if (current.updatedAt != record.updatedAt) continue;
        final clean = current.copyWith(
          syncState: SyncState.clean,
          touch: false,
        );
        await txn.update(
          'workspace_records',
          {'sync_state': SyncState.clean.name, 'payload': clean.encode()},
          where: 'account_id = ? AND id = ? AND kind = ? AND payload = ?',
          whereArgs: [selectedAccountId, record.id, record.kind.name, payload],
        );
      }
    });
  }

  Future<void> permanentlyDelete(String id, RecordKind kind) async {
    await permanentlyDeleteRecords([(id: id, kind: kind)]);
  }

  Future<void> permanentlyDeleteRecords(
    Iterable<({String id, RecordKind kind})> keys,
  ) async {
    final values = keys.toList(growable: false);
    if (values.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final key in values) {
        batch.delete(
          'attachments',
          where: 'account_id = ? AND owner_record_id = ? AND owner_kind = ?',
          whereArgs: [_activeAccountId, key.id, key.kind.name],
        );
        batch.delete(
          'workspace_records',
          where: 'account_id = ? AND id = ? AND kind = ?',
          whereArgs: [_activeAccountId, key.id, key.kind.name],
        );
      }
      await batch.commit(noResult: true);
    });
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
      await txn.delete(
        'workspace_records',
        where: 'account_id = ?',
        whereArgs: [_activeAccountId],
      );
      if (attachments != null) {
        await txn.delete(
          'attachments',
          where: 'account_id = ?',
          whereArgs: [_activeAccountId],
        );
      }
      final batch = txn.batch();
      for (final record in records) {
        final stored = markDirty
            ? record.copyWith(syncState: SyncState.dirty, touch: false)
            : record.copyWith(syncState: SyncState.clean, touch: false);
        batch.insert('workspace_records', {
          'account_id': _activeAccountId,
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
          batch.insert('attachments', {
            ...attachment.toDatabase(),
            'account_id': _activeAccountId,
          });
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
          'account_id': _activeAccountId,
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
    await db.insert('attachments', {
      ...attachment.toDatabase(),
      'account_id': _activeAccountId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Attachment>> loadAttachments({String? ownerRecordId}) async {
    final db = await database;
    final rows = await db.query(
      'attachments',
      where: ownerRecordId == null
          ? (_signedOutView
                ? "account_id = ? OR account_id = ''"
                : 'account_id = ?')
          : (_signedOutView
                ? "(account_id = ? OR account_id = '') AND owner_record_id = ?"
                : 'account_id = ? AND owner_record_id = ?'),
      whereArgs: ownerRecordId == null
          ? [_activeAccountId]
          : [_activeAccountId, ownerRecordId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Attachment.fromDatabase).toList(growable: false);
  }

  Future<int> attachmentBytes() async {
    final db = await database;
    final rows = await db.rawQuery(
      _signedOutView
          ? "SELECT COALESCE(SUM(size_bytes), 0) AS total FROM attachments WHERE account_id = ? OR account_id = ''"
          : 'SELECT COALESCE(SUM(size_bytes), 0) AS total FROM attachments WHERE account_id = ?',
      [_activeAccountId],
    );
    return (rows.single['total'] as num?)?.toInt() ?? 0;
  }

  Future<void> deleteAttachment(String id) async {
    final db = await database;
    await db.delete(
      'attachments',
      where: 'account_id = ? AND id = ?',
      whereArgs: [_activeAccountId, id],
    );
  }

  Future<void> replaceAttachments(Iterable<Attachment> attachments) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'attachments',
        where: 'account_id = ?',
        whereArgs: [_activeAccountId],
      );
      final batch = txn.batch();
      for (final attachment in attachments) {
        batch.insert('attachments', {
          ...attachment.toDatabase(),
          'account_id': _activeAccountId,
        });
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
