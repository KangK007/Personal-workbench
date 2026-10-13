import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/backup_service.dart';
import 'package:personal_workbench/services/focus_service.dart';
import 'package:personal_workbench/services/notification_service.dart';
import 'package:personal_workbench/services/search_service.dart';
import 'package:personal_workbench/services/share_capture_service.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MemoryDatabase extends AppDatabase {
  final records = <String, WorkspaceRecord>{};
  bool failNextBatch = false;

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    records[record.id] = record;
  }

  @override
  Future<void> saveRecords(
    Iterable<WorkspaceRecord> values, {
    bool markDirty = true,
  }) async {
    if (failNextBatch) {
      failNextBatch = false;
      throw StateError('batch failed');
    }
    for (final record in values) {
      records[record.id] = record;
    }
  }

  @override
  Future<void> close() async {}
}

WorkbenchController _controller(AppDatabase database) => WorkbenchController(
  database: database,
  backupService: BackupService(),
  searchService: SearchService(),
  focusService: FocusService(),
  notificationService: NotificationService(),
  shareCaptureService: ShareCaptureService(),
  syncService: SupabaseSyncService(null),
);

Future<
  ({
    WorkbenchController controller,
    WorkspaceRecord source,
    WorkspaceRecord target,
    List<WorkspaceRecord> tasks,
  })
>
_fixture(AppDatabase database) async {
  final controller = _controller(database);
  final source = await controller.createTaskGroup(
    title: '来源链',
    sequential: true,
  );
  final target = await controller.createTaskGroup(
    title: '目标群',
    sequential: false,
  );
  final tasks = <WorkspaceRecord>[];
  for (final title in ['甲', '乙', '丙', '丁', '戊']) {
    final task = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: title,
      projectId: 'project-a',
    );
    tasks.add(task);
    await controller.addRecord(task);
    await controller.addTaskToGroup(
      task: task,
      group: tasks.length <= 3 ? source : target,
    );
  }
  return (controller: controller, source: source, target: target, tasks: tasks);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test('group transfer and undo retain order and unrelated edits', () async {
    final fixture = await _fixture(_MemoryDatabase());
    final controller = fixture.controller;
    addTearDown(controller.dispose);
    final moving = fixture.tasks[1];
    final transfer = await controller.moveTaskBetweenGroups(
      task: moving,
      sourceGroup: fixture.source,
      targetGroup: fixture.target,
    );
    expect(
      controller.groupMembers(fixture.source.id).map((task) => task.title),
      ['甲', '丙'],
    );
    expect(
      controller.groupMembers(fixture.target.id).map((task) => task.title),
      ['丁', '戊', '乙'],
    );
    expect(controller.latestRecordById(moving).projectId, moving.projectId);
    expect(controller.latestRecordById(moving).status, moving.status);
    await controller.updateRecord(fixture.tasks[2].copyWith(title: '丙已编辑'));
    final extra = WorkspaceRecord.create(kind: RecordKind.task, title: '新成员');
    await controller.addRecord(extra);
    await controller.addTaskToGroup(task: extra, group: fixture.source);
    await controller.undoTaskGroupTransfer(transfer);
    expect(
      controller.groupMembers(fixture.source.id).map((task) => task.title),
      ['甲', '乙', '丙已编辑', '新成员'],
    );
    expect(
      controller.groupMembers(fixture.target.id).map((task) => task.title),
      ['丁', '戊'],
    );
    final active = controller.relations.where(
      (record) =>
          record.data['taskId'] == moving.id && record.data['active'] != false,
    );
    expect(active, hasLength(1));
    expect(active.single.id, transfer.sourceRelationId);
  });

  test(
    'failed transfer keeps controller and stored membership unchanged',
    () async {
      final database = _MemoryDatabase();
      final fixture = await _fixture(database);
      addTearDown(fixture.controller.dispose);
      final before = database.records.map(
        (id, record) => MapEntry(id, record.encode()),
      );
      database.failNextBatch = true;
      await expectLater(
        fixture.controller.moveTaskBetweenGroups(
          task: fixture.tasks[1],
          sourceGroup: fixture.source,
          targetGroup: fixture.target,
        ),
        throwsStateError,
      );
      expect(
        fixture.controller
            .groupMembers(fixture.source.id)
            .map((task) => task.title),
        ['甲', '乙', '丙'],
      );
      expect(
        database.records.map((id, record) => MapEntry(id, record.encode())),
        before,
      );
    },
  );

  test('failed undo keeps the move and can be retried', () async {
    final database = _MemoryDatabase();
    final fixture = await _fixture(database);
    addTearDown(fixture.controller.dispose);
    final transfer = await fixture.controller.moveTaskBetweenGroups(
      task: fixture.tasks[1],
      sourceGroup: fixture.source,
      targetGroup: fixture.target,
    );
    database.failNextBatch = true;
    await expectLater(
      fixture.controller.undoTaskGroupTransfer(transfer),
      throwsStateError,
    );
    expect(
      fixture.controller
          .groupMembers(fixture.target.id)
          .map((task) => task.title),
      ['丁', '戊', '乙'],
    );
    await fixture.controller.undoTaskGroupTransfer(transfer);
    expect(
      fixture.controller
          .groupMembers(fixture.source.id)
          .map((task) => task.title),
      ['甲', '乙', '丙'],
    );
  });

  test('stale undo does not overwrite a later transfer', () async {
    final fixture = await _fixture(_MemoryDatabase());
    addTearDown(fixture.controller.dispose);
    final third = await fixture.controller.createTaskGroup(
      title: '后续目标',
      sequential: false,
    );
    final first = await fixture.controller.moveTaskBetweenGroups(
      task: fixture.tasks[1],
      sourceGroup: fixture.source,
      targetGroup: fixture.target,
    );
    final second = await fixture.controller.moveTaskBetweenGroups(
      task: fixture.tasks[1],
      sourceGroup: fixture.target,
      targetGroup: third,
    );
    await expectLater(
      fixture.controller.undoTaskGroupTransfer(first),
      throwsFormatException,
    );
    expect(
      fixture.controller.groupMembers(third.id).single.id,
      fixture.tasks[1].id,
    );
    await fixture.controller.undoTaskGroupTransfer(second);
    await fixture.controller.undoTaskGroupTransfer(first);
    expect(
      fixture.controller
          .groupMembers(fixture.source.id)
          .map((task) => task.title),
      ['甲', '乙', '丙'],
    );
  });

  test(
    'group transfer and undo persist through the SQLite batch path',
    () async {
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        overridePath: inMemoryDatabasePath,
      );
      final fixture = await _fixture(database);
      addTearDown(fixture.controller.dispose);
      final transfer = await fixture.controller.moveTaskBetweenGroups(
        task: fixture.tasks[1],
        sourceGroup: fixture.source,
        targetGroup: fixture.target,
      );
      var stored = await database.loadRecords();
      var active = stored.where(
        (record) =>
            record.kind == RecordKind.relation &&
            record.data['taskId'] == transfer.taskId &&
            record.data['active'] != false,
      );
      expect(active.single.data['groupId'], fixture.target.id);
      await fixture.controller.undoTaskGroupTransfer(transfer);
      stored = await database.loadRecords();
      active = stored.where(
        (record) =>
            record.kind == RecordKind.relation &&
            record.data['taskId'] == transfer.taskId &&
            record.data['active'] != false,
      );
      expect(active.single.data['groupId'], fixture.source.id);
      expect(active.single.data['position'], 1);
    },
  );
}
