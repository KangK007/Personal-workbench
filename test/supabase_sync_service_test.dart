import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';

WorkspaceRecord _record({
  required String id,
  required String title,
  required DateTime updatedAt,
  RecordKind kind = RecordKind.task,
  SyncState syncState = SyncState.clean,
}) {
  return WorkspaceRecord(
    id: id,
    kind: kind,
    title: title,
    createdAt: updatedAt,
    updatedAt: updatedAt,
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
  }) async => saved.values.toList();

  @override
  Future<List<WorkspaceRecord>> loadDirtyRecords() async => saved.values
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
  Future<void> markClean(Iterable<WorkspaceRecord> records) async {
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
  Future<void> close() async {}
}

class _FakeRemote implements WorkspaceSyncRemote {
  _FakeRemote(this.records, {this.fetchError, this.deleteError});

  final List<WorkspaceRecord> records;
  final Object? fetchError;
  final Object? deleteError;
  final List<int> offsets = [];
  final List<Map<String, dynamic>> uploaded = [];
  final List<Map<String, dynamic>> deleted = [];

  @override
  String get userId => 'user-1';

  @override
  Future<List<Map<String, dynamic>>> fetchPage({
    required int offset,
    required int limit,
  }) async {
    offsets.add(offset);
    if (fetchError case final error?) throw error;
    final end = (offset + limit).clamp(0, records.length);
    if (offset >= records.length) return const [];
    return records
        .sublist(offset, end)
        .map((record) => {'payload': record.toJson()})
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
