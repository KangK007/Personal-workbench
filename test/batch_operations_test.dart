import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/attachment.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/backup_service.dart';
import 'package:personal_workbench/services/focus_service.dart';
import 'package:personal_workbench/services/attachment_service.dart';
import 'package:personal_workbench/services/notification_service.dart';
import 'package:personal_workbench/services/search_service.dart';
import 'package:personal_workbench/services/share_capture_service.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';

String _key(WorkspaceRecord record) => '${record.kind.name}:${record.id}';

class _MemoryDatabase extends AppDatabase {
  final records = <String, WorkspaceRecord>{};
  final attachments = <Attachment>[];
  Object? saveRecordsError;
  Object? deleteRecordsError;

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    records[_key(record)] = record;
  }

  @override
  Future<void> saveRecords(
    Iterable<WorkspaceRecord> values, {
    bool markDirty = true,
  }) async {
    if (saveRecordsError case final error?) throw error;
    for (final record in values) {
      records[_key(record)] = record;
    }
  }

  @override
  Future<void> permanentlyDeleteRecords(
    Iterable<({String id, RecordKind kind})> keys,
  ) async {
    if (deleteRecordsError case final error?) throw error;
    for (final key in keys) {
      records.remove('${key.kind.name}:${key.id}');
    }
  }

  @override
  Future<List<Attachment>> loadAttachments({String? ownerRecordId}) async =>
      attachments
          .where(
            (attachment) =>
                ownerRecordId == null ||
                attachment.ownerRecordId == ownerRecordId,
          )
          .toList(growable: false);

  @override
  Future<void> close() async {}
}

class _FailingRemote implements WorkspaceSyncRemote {
  @override
  String get userId => 'test-user';

  @override
  Future<void> delete(List<Map<String, dynamic>> keys) async {
    throw StateError('cloud delete failed');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPage({
    required int offset,
    required int limit,
  }) async => const [];

  @override
  Future<void> upsert(List<Map<String, dynamic>> rows) async {}
}

WorkbenchController _controller(
  _MemoryDatabase database, {
  SupabaseSyncService? syncService,
  AttachmentService? attachmentService,
}) => WorkbenchController(
  database: database,
  backupService: BackupService(),
  searchService: SearchService(),
  focusService: FocusService(),
  notificationService: NotificationService(),
  shareCaptureService: ShareCaptureService(),
  syncService: syncService ?? SupabaseSyncService(null),
  attachmentService: attachmentService,
  now: () => DateTime(2026, 8, 18, 10),
);

Future<List<WorkspaceRecord>> _addTasks(
  WorkbenchController controller,
  int count,
) async {
  for (var index = 0; index < count; index++) {
    await controller.addRecord(
      WorkspaceRecord.create(kind: RecordKind.task, title: '任务 $index'),
    );
  }
  return controller.tasks.toList(growable: false);
}

void main() {
  test('batch status preserves completion and reopen semantics', () async {
    final controller = _controller(_MemoryDatabase());
    addTearDown(controller.dispose);
    final tasks = await _addTasks(controller, 2);

    for (final status in const [
      WorkStatus.inbox,
      WorkStatus.todo,
      WorkStatus.doing,
      WorkStatus.cancelled,
      WorkStatus.done,
    ]) {
      final result = await controller.batchSetTaskStatus(tasks, status);
      expect(result.succeeded, 2);
      expect(controller.tasks.every((task) => task.status == status), isTrue);
    }

    final reopened = await controller.batchSetTaskStatus(
      tasks,
      WorkStatus.doing,
    );
    expect(reopened.succeeded, 2);
    expect(
      controller.tasks.every((task) => task.status == WorkStatus.doing),
      isTrue,
    );
  });

  test(
    'batch date, project, and trash operations affect selected instances',
    () async {
      final database = _MemoryDatabase();
      final controller = _controller(database);
      addTearDown(controller.dispose);
      final tasks = await _addTasks(controller, 2);
      final project = WorkspaceRecord.create(
        kind: RecordKind.project,
        title: '研究项目',
      );
      await controller.addRecord(project);

      final targetDate = DateTime(2026, 8, 20, 9);
      expect(
        (await controller.batchScheduleTasks([
          tasks.first,
        ], targetDate)).succeeded,
        1,
      );
      expect(controller.tasks.first.scheduledFor, targetDate);
      expect(
        (await controller.batchSetTaskProject([
          tasks.first,
        ], project.id)).succeeded,
        1,
      );
      expect(controller.tasks.first.projectId, project.id);
      await controller.batchScheduleTasks([tasks.first], null);
      expect(controller.tasks.first.scheduledFor, isNull);
      expect(controller.tasks.first.status, WorkStatus.todo);
      await controller.batchSetTaskProject([tasks.first], null);
      expect(controller.tasks.first.projectId, isNull);

      expect((await controller.batchMoveTasksToTrash(tasks)).succeeded, 2);
      expect(
        controller.trashRecords.where(
          (record) => record.kind == RecordKind.task,
        ),
        hasLength(2),
      );
      expect((await controller.restoreRecords([tasks.first])).succeeded, 1);
      expect(
        controller.trashRecords.where(
          (record) => record.kind == RecordKind.task,
        ),
        hasLength(1),
      );
      expect(database.records, isNotEmpty);
    },
  );

  test(
    'batch completion advances only the selected recurring instance',
    () async {
      final controller = _controller(_MemoryDatabase());
      addTearDown(controller.dispose);
      final task = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '循环协议任务',
        scheduledFor: DateTime(2026, 8, 18, 9),
        data: const {
          'protocol': 'ctdp',
          'ctdpTrigger': '开始实验记录',
          'ctdpChainCount': 2,
          'recurrence': 'daily',
        },
      );
      await controller.addRecord(task);

      final result = await controller.batchSetTaskStatus([
        task,
      ], WorkStatus.done);

      expect(result.succeeded, 1);
      final completed = controller.tasks.firstWhere(
        (record) => record.id == task.id,
      );
      final next = controller.tasks.firstWhere(
        (record) => record.scheduledFor == DateTime(2026, 8, 19, 9),
      );
      final later = controller.tasks.firstWhere(
        (record) => record.scheduledFor == DateTime(2026, 8, 20, 9),
      );
      expect(completed.status, WorkStatus.done);
      expect(completed.ctdpChainCount, 3);
      expect(next.status, WorkStatus.todo);
      expect(next.ctdpChainCount, 3);
      expect(next.scheduledFor, DateTime(2026, 8, 19, 9));
      expect(later.ctdpChainCount, 2);
    },
  );

  test('batch transaction failure leaves controller state unchanged', () async {
    final database = _MemoryDatabase();
    final controller = _controller(database);
    addTearDown(controller.dispose);
    final task = (await _addTasks(controller, 1)).single;
    final project = WorkspaceRecord.create(
      kind: RecordKind.project,
      title: '不会写入的项目',
    );
    await controller.addRecord(project);
    database.saveRecordsError = StateError('save failed');

    final result = await controller.batchSetTaskProject([task], project.id);

    expect(result.succeeded, 0);
    expect(result.failed, 1);
    expect(controller.tasks.single.projectId, isNull);
  });

  test('task group edits and removal preserve member tasks', () async {
    final controller = _controller(_MemoryDatabase());
    addTearDown(controller.dispose);
    final tasks = await _addTasks(controller, 2);
    final group = await controller.createTaskGroup(
      title: '论文任务群',
      sequential: true,
      timeLimitMinutes: 120,
    );
    await controller.addTaskToGroup(task: tasks.first, group: group);
    await controller.addTaskToGroup(task: tasks.last, group: group);

    final updated = await controller.updateTaskGroup(
      group: group,
      title: '论文任务群（修订）',
      sequential: true,
      timeLimitMinutes: 180,
    );
    expect(updated.title, '论文任务群（修订）');
    expect(controller.groupMembers(group.id), hasLength(2));

    await controller.removeTaskFromGroup(task: tasks.first, group: updated);
    expect(controller.groupMembers(group.id), hasLength(1));
    expect(controller.tasks, hasLength(2));

    await controller.setTaskStatus(tasks.last, WorkStatus.doing);
    expect(controller.taskGroupModeLocked(updated), isTrue);
    expect(
      () => controller.updateTaskGroup(
        group: updated,
        title: '不允许切换模式',
        sequential: false,
        timeLimitMinutes: 180,
      ),
      throwsFormatException,
    );
    final renamed = await controller.updateTaskGroup(
      group: updated,
      title: '仍可修改名称',
      sequential: true,
      timeLimitMinutes: 240,
    );
    expect(renamed.title, '仍可修改名称');
  });

  test(
    'deleting and restoring a task group cascades only membership',
    () async {
      final controller = _controller(_MemoryDatabase());
      addTearDown(controller.dispose);
      final tasks = await _addTasks(controller, 2);
      final group = await controller.createTaskGroup(
        title: '可恢复任务群',
        sequential: false,
      );
      await controller.addTaskToGroup(task: tasks.first, group: group);
      await controller.addTaskToGroup(task: tasks.last, group: group);
      await controller.removeTaskFromGroup(task: tasks.last, group: group);

      expect((await controller.moveTaskGroupToTrash(group)).succeeded, 1);
      expect(controller.tasks, hasLength(2));
      expect(
        controller.trashRecords.any((record) => record.id == group.id),
        isTrue,
      );
      expect(
        controller.trashRecords.any(
          (record) =>
              record.kind == RecordKind.relation &&
              record.data['deletedWithTaskGroupId'] == group.id,
        ),
        isFalse,
      );

      expect((await controller.restoreTaskGroup(group)).succeeded, 1);
      expect(controller.groupMembers(group.id), hasLength(1));
      expect(controller.groupMembers(group.id).single.id, tasks.first.id);
      expect(controller.tasks, hasLength(2));

      await controller.moveTaskGroupToTrash(group);
      final deletion = await controller.permanentlyDeleteRecords([group]);
      expect(deletion.succeeded, 1);
      expect(controller.tasks, hasLength(2));
      expect(controller.taskGroups, isEmpty);
    },
  );

  test('task group restore skips members now assigned elsewhere', () async {
    final controller = _controller(_MemoryDatabase());
    addTearDown(controller.dispose);
    final task = (await _addTasks(controller, 1)).single;
    final first = await controller.createTaskGroup(
      title: '原任务群',
      sequential: false,
    );
    final second = await controller.createTaskGroup(
      title: '新任务群',
      sequential: false,
    );
    await controller.addTaskToGroup(task: task, group: first);
    await controller.moveTaskGroupToTrash(first);
    await controller.addTaskToGroup(task: task, group: second);

    final result = await controller.restoreTaskGroup(first);

    expect(result.succeeded, 1);
    expect(result.failed, 1);
    expect(controller.groupMembers(first.id), isEmpty);
    expect(controller.groupMembers(second.id).single.id, task.id);
  });

  test('batch task group assignment reports and replaces conflicts', () async {
    final controller = _controller(_MemoryDatabase());
    addTearDown(controller.dispose);
    final tasks = await _addTasks(controller, 2);
    final first = await controller.createTaskGroup(
      title: '第一任务群',
      sequential: false,
    );
    final second = await controller.createTaskGroup(
      title: '第二任务群',
      sequential: false,
    );
    await controller.addTaskToGroup(task: tasks.first, group: first);

    final partial = await controller.batchSetTaskGroup(tasks, second.id);
    expect(partial.succeeded, 1);
    expect(partial.failed, 1);
    expect(controller.groupMembers(first.id).single.id, tasks.first.id);
    expect(controller.groupMembers(second.id).single.id, tasks.last.id);

    final replaced = await controller.batchSetTaskGroup(
      [tasks.first],
      second.id,
      replaceExisting: true,
    );
    expect(replaced.succeeded, 1);
    expect(controller.groupMembers(first.id), isEmpty);
    expect(controller.groupMembers(second.id), hasLength(2));

    final cleared = await controller.batchSetTaskGroup(
      tasks,
      null,
      replaceExisting: true,
    );
    expect(cleared.succeeded, 2);
    expect(controller.groupMembers(second.id), isEmpty);
  });

  test('batch task group replacement compacts source positions', () async {
    final controller = _controller(_MemoryDatabase());
    addTearDown(controller.dispose);
    final tasks = await _addTasks(controller, 3);
    final source = await controller.createTaskGroup(
      title: '来源任务群',
      sequential: false,
    );
    final target = await controller.createTaskGroup(
      title: '目标任务群',
      sequential: false,
    );
    for (final task in tasks) {
      await controller.addTaskToGroup(task: task, group: source);
    }

    final result = await controller.batchSetTaskGroup(
      [tasks[1]],
      target.id,
      replaceExisting: true,
    );

    expect(result.succeeded, 1);
    expect(controller.groupMembers(source.id).map((task) => task.id), [
      tasks[0].id,
      tasks[2].id,
    ]);
    final positions =
        controller.relations
            .where(
              (relation) =>
                  relation.data['relationType'] == 'taskGroupMember' &&
                  relation.data['groupId'] == source.id &&
                  relation.data['active'] != false,
            )
            .map((relation) => relation.data['position'])
            .toList()
          ..sort((a, b) => (a as int).compareTo(b as int));
    expect(positions, [0, 1]);
  });

  test(
    'permanent deletion preserves local data when cloud deletion fails',
    () async {
      final database = _MemoryDatabase();
      final controller = _controller(
        database,
        syncService: SupabaseSyncService.withRemote(_FailingRemote()),
      );
      addTearDown(controller.dispose);
      final task = (await _addTasks(controller, 1)).single;
      await controller.moveToTrash(task);

      final result = await controller.permanentlyDeleteRecords([task]);

      expect(result.succeeded, 0);
      expect(result.failed, 1);
      expect(controller.trashRecords.single.id, task.id);
      expect(database.records, contains(_key(task)));
    },
  );

  test(
    'permanent deletion preserves memory when local deletion fails',
    () async {
      final database = _MemoryDatabase();
      final controller = _controller(database);
      addTearDown(controller.dispose);
      final task = (await _addTasks(controller, 1)).single;
      await controller.moveToTrash(task);
      database.deleteRecordsError = StateError('local delete failed');

      final result = await controller.permanentlyDeleteRecords([task]);

      expect(result.succeeded, 0);
      expect(result.failed, 1);
      expect(controller.trashRecords.single.id, task.id);
      expect(database.records, contains(_key(task)));
    },
  );

  test(
    'attachment quarantine rolls back files when database deletion fails',
    () async {
      final directory = await Directory.systemTemp.createTemp('batch-delete-');
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final database = _MemoryDatabase();
      final owner = WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '带附件记录',
      );
      final attachmentsDirectory = Directory(
        '${directory.path}${Platform.pathSeparator}attachments',
      );
      await attachmentsDirectory.create(recursive: true);
      final file = File(
        '${attachmentsDirectory.path}${Platform.pathSeparator}image.png',
      );
      await file.writeAsBytes(const [1, 2, 3]);
      database.attachments.add(
        Attachment(
          id: 'image',
          ownerRecordId: owner.id,
          ownerKind: owner.kind,
          fileName: 'image.png',
          relativePath: 'attachments/image.png',
          mimeType: 'image/png',
          sizeBytes: 3,
          sha256: 'unused',
          createdAt: DateTime(2026, 8, 18),
        ),
      );
      final service = AttachmentService(database: database, root: directory);

      await expectLater(
        service.deleteForRecordsAtomically([
          owner,
        ], commitDatabase: () async => throw StateError('database failed')),
        throwsStateError,
      );

      expect(await file.exists(), isTrue);
      expect(
        directory.listSync().whereType<Directory>().where(
          (entry) => entry.path.contains('.attachments-delete-'),
        ),
        isEmpty,
      );
    },
  );
}
