import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/attachment.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'schema upgrade keeps legacy rows ownerless and isolates account partitions',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'account-isolation-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}legacy.db';
      final stamp = DateTime.utc(2026, 8, 9, 8);
      final legacyRecord = WorkspaceRecord(
        id: 'legacy-id',
        kind: RecordKind.note,
        title: 'legacy local note',
        createdAt: stamp,
        updatedAt: stamp,
        syncState: SyncState.dirty,
      );
      final legacyAttachment = Attachment(
        id: 'legacy-attachment',
        ownerRecordId: legacyRecord.id,
        ownerKind: legacyRecord.kind,
        fileName: 'legacy.png',
        relativePath: 'attachments/legacy-attachment.png',
        mimeType: 'image/png',
        sizeBytes: 1,
        sha256: 'legacy',
        createdAt: stamp,
      );
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) async {
            await db.execute('''
            CREATE TABLE workspace_records (
              id TEXT NOT NULL, kind TEXT NOT NULL, payload TEXT NOT NULL,
              updated_at INTEGER NOT NULL, deleted_at INTEGER,
              sync_state TEXT NOT NULL, PRIMARY KEY (id, kind)
            )
          ''');
            await db.execute('''
            CREATE TABLE app_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)
          ''');
            await db.execute('''
            CREATE TABLE attachments (
              id TEXT PRIMARY KEY, owner_record_id TEXT NOT NULL,
              owner_kind TEXT NOT NULL, file_name TEXT NOT NULL,
              relative_path TEXT NOT NULL, mime_type TEXT NOT NULL,
              size_bytes INTEGER NOT NULL, sha256 TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
            await db.insert('workspace_records', {
              'id': legacyRecord.id,
              'kind': legacyRecord.kind.name,
              'payload': legacyRecord.encode(),
              'updated_at': stamp.millisecondsSinceEpoch,
              'sync_state': SyncState.dirty.name,
            });
            await db.insert('attachments', legacyAttachment.toDatabase());
          },
        ),
      );
      await legacy.close();

      final database = AppDatabase(
        factory: databaseFactoryFfi,
        overridePath: path,
      );
      addTearDown(database.close);

      await database.database;
      await database.activateAccount('account-b');
      expect(await database.loadRecords(), isEmpty);
      expect(await database.loadAttachments(), isEmpty);

      final accountARecord = WorkspaceRecord(
        id: 'shared-id',
        kind: legacyRecord.kind,
        title: 'account A copy',
        createdAt: stamp,
        updatedAt: stamp,
      );
      final accountAAttachment = Attachment(
        id: 'shared-attachment',
        ownerRecordId: accountARecord.id,
        ownerKind: accountARecord.kind,
        fileName: 'a.png',
        relativePath: 'attachments/shared-attachment.png',
        mimeType: 'image/png',
        sizeBytes: 1,
        sha256: 'a',
        createdAt: stamp,
      );
      await database.activateAccount('account-a');
      await database.saveRecord(accountARecord);
      await database.saveAttachment(accountAAttachment);

      final accountBRecord = accountARecord.copyWith(title: 'account B copy');
      final accountBAttachment = Attachment(
        id: accountAAttachment.id,
        ownerRecordId: accountBRecord.id,
        ownerKind: accountBRecord.kind,
        fileName: 'b.png',
        relativePath: 'attachments/shared-attachment.png',
        mimeType: 'image/png',
        sizeBytes: 1,
        sha256: 'b',
        createdAt: stamp,
      );
      await database.activateAccount('account-b');
      await database.saveRecord(accountBRecord);
      await database.saveAttachment(accountBAttachment);
      await database.replaceAll([accountBRecord], markDirty: false);
      expect((await database.loadRecords()).single.title, 'account B copy');
      expect((await database.loadAttachments()).single.fileName, 'b.png');
      await database.permanentlyDelete(accountBRecord.id, accountBRecord.kind);
      expect(await database.loadAttachments(), isEmpty);
      expect(await database.loadRecords(), isEmpty);

      await database.activateAccount('account-a');
      expect((await database.loadRecords()).single.title, 'account A copy');
      expect((await database.loadAttachments()).single.fileName, 'a.png');
      await database.activateAccount(null);
      expect(
        (await database.loadRecords()).map((record) => record.title),
        contains('legacy local note'),
      );
      expect(await database.loadDirtyRecords(), hasLength(2));
      expect(
        (await database.loadAttachments()).map((attachment) => attachment.id),
        contains(legacyAttachment.id),
      );

      final afterSignOut = AppDatabase(
        factory: databaseFactoryFfi,
        overridePath: path,
      );
      addTearDown(afterSignOut.close);
      await afterSignOut.database;
      await afterSignOut.activateAccount(null);
      expect(
        (await afterSignOut.loadRecords()).map((record) => record.title),
        containsAll(['legacy local note', 'account A copy']),
      );
      expect(
        (await afterSignOut.loadRecords()).map((record) => record.title),
        isNot(contains('account B copy')),
      );
      await afterSignOut.activateAccount('account-a');
      expect((await afterSignOut.loadRecords()).single.title, 'account A copy');
    },
  );

  test('factory override does not initialize the process default', () async {
    sqfliteFfiInit();
    expect(() => databaseFactory, throwsStateError);
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: inMemoryDatabasePath,
    );

    await database.database;

    expect(() => databaseFactory, throwsStateError);
    await database.close();
  });

  test('local database persists and restores soft-deleted records', () async {
    sqfliteFfiInit();
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: inMemoryDatabasePath,
    );
    final record = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '数据库验证',
    );

    await database.saveRecord(record);
    expect((await database.loadRecords()).single.title, '数据库验证');

    await database.saveRecord(record.copyWith(deletedAt: DateTime.now()));
    expect(await database.loadRecords(includeDeleted: false), isEmpty);

    await database.saveRecord(record.copyWith(deletedAt: null));
    expect(await database.loadRecords(includeDeleted: false), hasLength(1));
    await database.close();
  });

  test('markClean updates the sync state returned by loadRecords', () async {
    sqfliteFfiInit();
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: inMemoryDatabasePath,
    );
    final snapshot = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: 'uploaded task',
    );

    await database.saveRecord(snapshot);
    expect((await database.loadRecords()).single.syncState, SyncState.dirty);

    await database.markClean([snapshot]);

    expect((await database.loadRecords()).single.syncState, SyncState.clean);
    await database.close();
  });

  test(
    'markClean does not overwrite an edit within the same millisecond',
    () async {
      sqfliteFfiInit();
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        overridePath: inMemoryDatabasePath,
      );
      final stamp = DateTime.utc(2026, 8, 9, 8, 0, 0, 123, 456);
      final uploaded = WorkspaceRecord(
        id: 'concurrent',
        kind: RecordKind.task,
        title: 'uploaded version',
        createdAt: stamp,
        updatedAt: stamp,
      );
      final edited = WorkspaceRecord(
        id: uploaded.id,
        kind: uploaded.kind,
        title: 'new local edit',
        createdAt: stamp,
        updatedAt: stamp.add(const Duration(microseconds: 100)),
      );
      expect(edited.updatedAt, isNot(uploaded.updatedAt));
      expect(
        edited.updatedAt.millisecondsSinceEpoch,
        uploaded.updatedAt.millisecondsSinceEpoch,
      );

      await database.saveRecord(uploaded);
      await database.saveRecord(edited);
      await database.markClean([uploaded]);

      final stored = (await database.loadRecords()).single;
      expect(stored.title, 'new local edit');
      expect(stored.syncState, SyncState.dirty);
      await database.close();
    },
  );

  test(
    'replaceAll can restore records without scheduling cloud upload',
    () async {
      sqfliteFfiInit();
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        overridePath: inMemoryDatabasePath,
      );
      final record = WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '本地恢复记录',
      );

      await database.replaceAll([record], markDirty: false);

      expect((await database.loadRecords()).single.syncState, SyncState.clean);
      expect(await database.loadDirtyRecords(), isEmpty);
      await database.close();
    },
  );

  test('records and attachments are replaced in one transaction', () async {
    sqfliteFfiInit();
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: inMemoryDatabasePath,
    );
    final oldRecord = WorkspaceRecord.create(
      kind: RecordKind.note,
      title: '旧记录',
    );
    final oldAttachment = Attachment(
      id: 'old-attachment',
      ownerRecordId: oldRecord.id,
      ownerKind: oldRecord.kind,
      fileName: 'old.png',
      relativePath: 'attachments/old-attachment.png',
      mimeType: 'image/png',
      sizeBytes: 1,
      sha256: 'old',
      createdAt: DateTime(2026, 8, 15),
    );
    await database.saveRecord(oldRecord);
    await database.saveAttachment(oldAttachment);

    final restoredRecord = WorkspaceRecord.create(
      kind: RecordKind.note,
      title: '恢复记录',
    );
    await database.replaceAllWithAttachments(
      [restoredRecord],
      const [],
      markDirty: false,
    );

    expect((await database.loadRecords()).single.title, '恢复记录');
    expect(await database.loadAttachments(), isEmpty);
    await database.close();
  });

  test('failed attachment replacement rolls back restored records', () async {
    sqfliteFfiInit();
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: inMemoryDatabasePath,
    );
    final oldRecord = WorkspaceRecord.create(
      kind: RecordKind.note,
      title: '事务前记录',
    );
    final oldAttachment = Attachment(
      id: 'old-attachment',
      ownerRecordId: oldRecord.id,
      ownerKind: oldRecord.kind,
      fileName: 'old.png',
      relativePath: 'attachments/old-attachment.png',
      mimeType: 'image/png',
      sizeBytes: 1,
      sha256: 'old',
      createdAt: DateTime(2026, 8, 15),
    );
    await database.saveRecord(oldRecord);
    await database.saveAttachment(oldAttachment);
    final duplicate = Attachment(
      id: 'duplicate',
      ownerRecordId: 'restored',
      ownerKind: RecordKind.note,
      fileName: 'duplicate.png',
      relativePath: 'attachments/duplicate.png',
      mimeType: 'image/png',
      sizeBytes: 1,
      sha256: 'duplicate',
      createdAt: DateTime(2026, 8, 15),
    );

    await expectLater(
      database.replaceAllWithAttachments(
        [WorkspaceRecord.create(kind: RecordKind.note, title: '不应保留')],
        [duplicate, duplicate],
        markDirty: false,
      ),
      throwsA(isA<DatabaseException>()),
    );

    expect((await database.loadRecords()).single.title, '事务前记录');
    expect((await database.loadAttachments()).single.id, oldAttachment.id);
    await database.close();
  });

  test('local game state is stored outside workspace records', () async {
    sqfliteFfiInit();
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: inMemoryDatabasePath,
    );

    await database.writeLocalGameState('{"points":10}');

    expect(await database.readLocalGameState(), '{"points":10}');
    expect(await database.loadRecords(), isEmpty);
    expect(await database.loadDirtyRecords(), isEmpty);
    await database.close();
  });
}
