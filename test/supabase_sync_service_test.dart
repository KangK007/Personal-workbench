import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

WorkspaceRecord _record({
  required String id,
  required String title,
  required DateTime updatedAt,
  DateTime? deletedAt,
  RecordKind kind = RecordKind.task,
  SyncState syncState = SyncState.clean,
}) {
  return WorkspaceRecord(
    id: id,
    kind: kind,
    title: title,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    syncState: syncState,
  );
}

String _key(WorkspaceRecord record) => '${record.kind.name}:${record.id}';

class _MemoryDatabase extends AppDatabase {
  _MemoryDatabase(Iterable<WorkspaceRecord> records) {
    for (final record in records) {
      saved[_key(record)] = record;
    }
  }

  final Map<String, WorkspaceRecord> saved = {};

  @override
  Future<List<WorkspaceRecord>> loadRecords({
    bool includeDeleted = true,
    String? accountId,
  }) async => saved.values.toList();

  @override
  Future<List<WorkspaceRecord>> loadDirtyRecords({String? accountId}) async =>
      saved.values
          .where((record) => record.syncState == SyncState.dirty)
          .toList();

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    saved[_key(record)] = record.copyWith(
      syncState: markDirty ? SyncState.dirty : SyncState.clean,
      touch: false,
    );
  }

  @override
  Future<void> markClean(
    Iterable<WorkspaceRecord> records, {
    String? accountId,
  }) async {
    for (final record in records) {
      final current = saved[_key(record)];
      if (current?.updatedAt == record.updatedAt) {
        saved[_key(record)] = current!.copyWith(
          syncState: SyncState.clean,
          touch: false,
        );
      }
    }
  }

  @override
  Future<bool> saveRemoteRecordIfUnchanged(
    WorkspaceRecord record, {
    required String accountId,
    required WorkspaceRecord? expectedLocal,
    WorkspaceRecord? conflictCopy,
  }) async {
    final key = _key(record);
    final current = saved[key];
    if (expectedLocal == null
        ? current != null
        : current?.encode() != expectedLocal.encode()) {
      return false;
    }
    if (conflictCopy != null) {
      saved[_key(conflictCopy)] = conflictCopy.copyWith(
        syncState: SyncState.dirty,
        touch: false,
      );
    }
    saved[key] = record.copyWith(syncState: SyncState.clean, touch: false);
    return true;
  }

  @override
  Future<void> close() async {}
}

class _FakeRemote implements WorkspaceSyncRemote {
  _FakeRemote(
    this.records, {
    this.fetchError,
    this.deleteError,
    this.userId = 'user-1',
    this.beforeFetch,
  });

  final List<WorkspaceRecord> records;
  final Object? fetchError;
  final Object? deleteError;
  final Future<void> Function()? beforeFetch;
  final List<int> offsets = [];
  final List<Map<String, dynamic>> uploaded = [];
  final List<Map<String, dynamic>> deleted = [];

  @override
  final String userId;

  @override
  Future<List<Map<String, dynamic>>> fetchPage({
    required int offset,
    required int limit,
  }) async {
    offsets.add(offset);
    await beforeFetch?.call();
    if (fetchError case final error?) throw error;
    final end = (offset + limit).clamp(0, records.length);
    if (offset >= records.length) return const [];
    return records
        .sublist(offset, end)
        .map(
          (record) => {
            'id': record.id,
            'kind': record.kind.name,
            'payload': record.toJson(),
            'updated_at': record.updatedAt.toUtc().toIso8601String(),
            'deleted_at': record.deletedAt?.toUtc().toIso8601String(),
          },
        )
        .toList();
  }

  @override
  Future<void> upsert(List<Map<String, dynamic>> rows) async {
    uploaded.addAll(rows);
  }

  @override
  Future<void> delete(List<Map<String, dynamic>> keys) async {
    if (deleteError case final error?) throw error;
    deleted.addAll(keys);
  }
}

void main() {
  test('sync downloads every remote page', () async {
    final stamp = DateTime.utc(2026, 8, 9, 8);
    final remote = _FakeRemote([
      _record(id: '1', title: 'one', updatedAt: stamp),
      _record(id: '2', title: 'two', updatedAt: stamp),
      _record(id: '3', title: 'three', updatedAt: stamp),
    ]);
    final database = _MemoryDatabase(const []);
    final service = SupabaseSyncService.withRemote(remote, pageSize: 2);

    final result = await service.sync(database);

    expect(result.downloaded, 3);
    expect(remote.offsets, [0, 2]);
    expect(database.saved, hasLength(3));
    expect(
      database.saved.values.every(
        (record) => record.syncState == SyncState.clean,
      ),
      isTrue,
    );
  });

  test(
    'newer remote edit preserves a conflict copy for every record kind',
    () async {
      final local = _record(
        id: 'shared',
        title: 'local task',
        updatedAt: DateTime.utc(2026, 8, 9, 8),
        syncState: SyncState.dirty,
      );
      final remoteRecord = _record(
        id: 'shared',
        title: 'remote task',
        updatedAt: DateTime.utc(2026, 8, 9, 9),
      );
      final database = _MemoryDatabase([local]);
      final remote = _FakeRemote([remoteRecord]);

      final result = await SupabaseSyncService.withRemote(
        remote,
      ).sync(database);

      expect(result.conflicts, 1);
      expect(result.uploaded, 0);
      expect(database.saved['task:shared']?.title, 'remote task');
      expect(
        database.saved.values.any(
          (record) =>
              record.kind == RecordKind.task &&
              record.title == 'local task（冲突副本）' &&
              record.syncState == SyncState.dirty,
        ),
        isTrue,
      );
    },
  );

  test(
    'newer remote tombstone is not overwritten by a stale dirty snapshot',
    () async {
      final local = _record(
        id: 'deleted-remotely',
        title: 'stale local edit',
        updatedAt: DateTime.utc(2026, 8, 9, 8),
        syncState: SyncState.dirty,
      );
      final remoteRecord = _record(
        id: 'deleted-remotely',
        title: 'remote deletion',
        updatedAt: DateTime.utc(2026, 8, 9, 9),
        deletedAt: DateTime.utc(2026, 8, 9, 9),
      );
      final database = _MemoryDatabase([local]);
      final remote = _FakeRemote([remoteRecord]);

      final result = await SupabaseSyncService.withRemote(
        remote,
      ).sync(database);

      expect(result.uploaded, 0);
      expect(remote.uploaded, isEmpty);
      expect(database.saved['task:deleted-remotely']?.isDeleted, isTrue);
    },
  );

  test(
    'network failures become retryable sync errors without cleaning data',
    () async {
      final local = _record(
        id: 'local',
        title: 'keep me',
        updatedAt: DateTime.utc(2026, 8, 9, 8),
        syncState: SyncState.dirty,
      );
      final database = _MemoryDatabase([local]);
      final remote = _FakeRemote(const [], fetchError: Exception('offline'));

      await expectLater(
        SupabaseSyncService.withRemote(remote).sync(database),
        throwsA(
          isA<SyncException>().having(
            (error) => error.message,
            'message',
            contains('检查网络'),
          ),
        ),
      );
      expect(database.saved['task:local']?.syncState, SyncState.dirty);
    },
  );

  test('successful upload marks only the uploaded version clean', () async {
    final local = _record(
      id: 'local',
      title: 'upload me',
      updatedAt: DateTime.utc(2026, 8, 9, 8),
      syncState: SyncState.dirty,
    );
    final database = _MemoryDatabase([local]);
    final remote = _FakeRemote(const []);

    final result = await SupabaseSyncService.withRemote(remote).sync(database);

    expect(result.uploaded, 1);
    expect(remote.uploaded.single['id'], 'local');
    expect(database.saved['task:local']?.syncState, SyncState.clean);
  });

  test(
    'syncing as another account never uploads or exposes prior account rows',
    () async {
      sqfliteFfiInit();
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        overridePath: inMemoryDatabasePath,
      );
      addTearDown(database.close);
      final accountARecord = _record(
        id: 'private-to-a',
        title: 'account A private note',
        updatedAt: DateTime.utc(2026, 8, 9, 8),
        syncState: SyncState.dirty,
      );
      await database.activateAccount('account-a');
      await database.saveRecord(accountARecord);
      final remoteB = _FakeRemote(const [], userId: 'account-b');

      final result = await SupabaseSyncService.withRemote(
        remoteB,
      ).sync(database);

      expect(result.uploaded, 0);
      expect(remoteB.uploaded, isEmpty);
      expect(await database.loadRecords(accountId: 'account-b'), isEmpty);
      await database.activateAccount('account-a');
      expect((await database.loadRecords()).single.title, accountARecord.title);
      expect(
        (await database.loadDirtyRecords()).single.title,
        accountARecord.title,
      );
    },
  );

  test(
    'remote fetch never overwrites an edit made while sync is in flight',
    () async {
      sqfliteFfiInit();
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        overridePath: inMemoryDatabasePath,
      );
      addTearDown(database.close);
      final initial = _record(
        id: 'during-sync',
        title: 'initial local value',
        updatedAt: DateTime.utc(2026, 8, 9, 8),
      );
      final editedDuringSync = _record(
        id: initial.id,
        title: 'new local edit',
        updatedAt: DateTime.utc(2026, 8, 9, 10),
        syncState: SyncState.dirty,
      );
      await database.saveRecord(initial, markDirty: false);
      final remote = _FakeRemote([
        _record(
          id: initial.id,
          title: 'remote value',
          updatedAt: DateTime.utc(2026, 8, 9, 9),
        ),
      ], beforeFetch: () => database.saveRecord(editedDuringSync));

      await SupabaseSyncService.withRemote(remote).sync(database);

      final saved = (await database.loadRecords()).single;
      expect(saved.title, 'new local edit');
      expect(saved.syncState, SyncState.dirty);
      expect(
        (await database.loadDirtyRecords()).single.title,
        'new local edit',
      );
    },
  );

  test(
    'account switch during fetch cannot write one account response to another partition',
    () async {
      sqfliteFfiInit();
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        overridePath: inMemoryDatabasePath,
      );
      addTearDown(database.close);
      final sharedLocal = _record(
        id: 'same-id',
        title: 'same local content',
        updatedAt: DateTime.utc(2026, 8, 9, 8),
      );
      await database.activateAccount('account-a');
      await database.saveRecord(sharedLocal, markDirty: false);
      await database.activateAccount('account-b');
      await database.saveRecord(sharedLocal, markDirty: false);
      await database.activateAccount('account-a');
      final remote = _FakeRemote(
        [
          _record(
            id: sharedLocal.id,
            title: 'account A newer cloud content',
            updatedAt: DateTime.utc(2026, 8, 9, 9),
          ),
        ],
        userId: 'account-a',
        beforeFetch: () => database.activateAccount('account-b'),
      );

      await SupabaseSyncService.withRemote(remote).sync(database);

      expect((await database.loadRecords()).single.title, 'same local content');
    },
  );

  test('deleteRecords removes the matching remote keys', () async {
    final record = _record(
      id: 'remote-only',
      title: 'delete me',
      updatedAt: DateTime.utc(2026, 8, 9, 8),
    );
    final remote = _FakeRemote(const []);

    await SupabaseSyncService.withRemote(remote).deleteRecords([record]);

    expect(remote.deleted, [
      {'id': record.id, 'kind': record.kind.name},
    ]);
  });

  test('deleteRecords reports remote failures', () async {
    final remote = _FakeRemote(
      const [],
      deleteError: Exception('remote unavailable'),
    );
    final record = _record(
      id: 'keep-local',
      title: 'keep me',
      updatedAt: DateTime.utc(2026, 8, 9, 8),
    );

    await expectLater(
      SupabaseSyncService.withRemote(remote).deleteRecords([record]),
      throwsException,
    );
    expect(remote.deleted, isEmpty);
  });
}
