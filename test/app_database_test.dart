import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/attachment.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
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

  test('markClean does not overwrite an edit made during sync', () async {
    sqfliteFfiInit();
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: inMemoryDatabasePath,
    );
    final stamp = DateTime.utc(2026, 8, 9, 8);
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
      updatedAt: stamp.add(const Duration(minutes: 1)),
    );

    await database.saveRecord(uploaded);
    await database.saveRecord(edited);
    await database.markClean([uploaded]);

    final stored = (await database.loadRecords()).single;
    expect(stored.title, 'new local edit');
    expect(stored.syncState, SyncState.dirty);
    await database.close();
  });

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
