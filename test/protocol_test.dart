import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/core/models/workspace_models_v3.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/backup_service.dart';
import 'package:personal_workbench/services/focus_service.dart';
import 'package:personal_workbench/services/notification_service.dart';
import 'package:personal_workbench/services/search_service.dart';
import 'package:personal_workbench/services/share_capture_service.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

WorkbenchController _controller(
  AppDatabase database, {
  DateTime Function()? now,
}) {
  return WorkbenchController(
    database: database,
    backupService: BackupService(),
    searchService: SearchService(),
    focusService: FocusService(),
    notificationService: NotificationService(),
    shareCaptureService: ShareCaptureService(),
    syncService: SupabaseSyncService(null),
    now: now,
  );
}

AppDatabase _database() {
  return AppDatabase(
    factory: databaseFactoryFfi,
    overridePath: inMemoryDatabasePath,
  );
}

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'CTDP completion creates a node and failure resets the main chain',
    () async {
      final database = _database();
      await database.database;
      final controller = _controller(database);
      final task = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: 'CTDP task',
        data: const {
          'protocol': 'ctdp',
          'ctdpTrigger': '戴上帽子',
          'ctdpSessionMinutes': 25,
        },
      );

      await controller.addRecord(task);
      await controller.toggleTaskDone(task);
      final completed = controller.tasks.single;
      expect(completed.ctdpChainCount, 1);

      await controller.toggleTaskDone(completed);
      final reset = controller.tasks.single;
      expect(reset.ctdpChainCount, 0);
      expect(reset.data['ctdpFailureReason'], contains('主链'));
      await database.close();
    },
  );

  test('quick capture creates a standard inbox task', () async {
    final database = _database();
    await database.database;
    final controller = _controller(database);

    final captured = await controller.quickCapture(
      kind: RecordKind.task,
      text: 'Read one paper',
    );

    expect(captured.hasCtdpProtocol, isFalse);
    expect(captured.status, WorkStatus.inbox);
    final persisted = (await database.loadRecords()).firstWhere(
      (record) => record.data['recordType'] == 'taskInstance',
    );
    expect(persisted.hasCtdpProtocol, isFalse);
    expect(persisted.data, isNot(contains('protocol')));
    await database.close();
  });

  test(
    'CTDP reservation, precedent, explicit failure, and timeout form a loop',
    () async {
      final database = _database();
      await database.database;
      final fixedNow = DateTime(2026, 8, 8, 9);
      final controller = _controller(database, now: () => fixedNow);
      final task = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: 'Protocol loop',
        data: const {
          'protocol': 'ctdp',
          'ctdpTrigger': '戴上帽子',
          'ctdpDelayMinutes': 15,
          'ctdpChainCount': 3,
          'ctdpAuxChainCount': 2,
          'ctdpReservationCount': 0,
        },
      );
      await controller.addRecord(task);

      await controller.startCtdpReservation(task);
      var current = controller.tasks.single;
      expect(current.ctdpReservationPending, isTrue);
      expect(
        DateTime.parse(current.data['ctdpReservationDueAt'] as String),
        fixedNow.add(const Duration(minutes: 15)).toUtc(),
      );

      await controller.confirmCtdpTrigger(current);
      current = controller.tasks.single;
      expect(current.ctdpReservationPending, isFalse);
      expect(current.ctdpAuxChainCount, 3);
      expect(current.ctdpReservationCount, 1);

      await controller.recordCtdpPrecedent(current, '接听紧急电话');
      current = controller.tasks.single;
      await controller.recordCtdpPrecedent(current, '接听紧急电话');
      current = controller.tasks.single;
      expect(current.data['ctdpPrecedents'], ['接听紧急电话']);

      await controller.failCtdpTask(current);
      current = controller.tasks.single;
      expect(current.ctdpChainCount, 0);
      expect(current.ctdpAuxChainCount, 3);
      expect(current.data['ctdpFailureReason'], contains('主链'));
      await expectLater(
        controller.confirmCtdpTrigger(current),
        throwsA(isA<FormatException>()),
      );

      final expired = current.copyWith(
        data: {
          ...current.data,
          'ctdpChainCount': 4,
          'ctdpAuxChainCount': 3,
          'ctdpReservationPending': true,
          'ctdpReservationDueAt': fixedNow
              .subtract(const Duration(minutes: 1))
              .toUtc()
              .toIso8601String(),
        },
      );
      await controller.updateRecord(expired);
      await expectLater(
        controller.confirmCtdpTrigger(expired),
        throwsA(isA<FormatException>()),
      );
      current = controller.tasks.single;
      expect(current.ctdpReservationPending, isFalse);
      expect(current.ctdpChainCount, 0);
      expect(current.ctdpAuxChainCount, 0);
      expect(current.data['ctdpFailureReason'], contains('预约超时'));
      await database.close();
    },
  );

  test(
    'recurring CTDP tasks carry the completed chain into the next node',
    () async {
      final database = _database();
      await database.database;
      final controller = _controller(database);
      final task = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: 'Daily protocol',
        scheduledFor: DateTime(2026, 8, 8),
        data: const {
          'protocol': 'ctdp',
          'ctdpTrigger': '坐到书桌前',
          'ctdpChainCount': 2,
          'ctdpReservationPending': true,
          'recurrence': 'daily',
        },
      );
      await controller.addRecord(task);

      await controller.toggleTaskDone(task);

      final completed = controller.tasks.firstWhere(
        (record) => record.id == task.id,
      );
      final next = controller.tasks.firstWhere(
        (record) => record.scheduledFor == DateTime(2026, 8, 9),
      );
      expect(completed.ctdpChainCount, 3);
      expect(next.status, WorkStatus.todo);
      expect(next.ctdpChainCount, 3);
      expect(next.ctdpReservationPending, isFalse);
      expect(next.data['completedAt'], isNull);
      expect(next.scheduledFor, DateTime(2026, 8, 9));
      await database.close();
    },
  );

  test('RSIP skip is auditable and does not collapse the subtree', () async {
    final database = _database();
    await database.database;
    final controller = _controller(database);
    final root = WorkspaceRecord.create(
      kind: RecordKind.habit,
      title: 'RSIP root',
      data: const {
        'protocol': 'rsip',
        'rsipMinimumAction': '读一页',
        'rsipActive': true,
      },
    );
    final child = WorkspaceRecord.create(
      kind: RecordKind.habit,
      title: 'RSIP child',
      parentId: root.id,
      data: const {
        'protocol': 'rsip',
        'rsipMinimumAction': '记一个词',
        'rsipActive': true,
      },
    );

    await controller.addRecord(root);
    await controller.addRecord(child);
    expect(
      controller.canUseRsipParent(recordId: root.id, parentId: child.id),
      isFalse,
    );
    expect(
      controller.canUseRsipParent(recordId: child.id, parentId: root.id),
      isTrue,
    );
    final day = DateTime.now();
    await controller.logHabit(root, day, WorkStatus.done);
    expect(controller.rsipNodes.first.cumulativeExecutionDays, 1);

    await controller.logHabit(root, day, WorkStatus.skipped);
    final updatedRoot = controller.habits.firstWhere(
      (value) => value.id == root.id,
    );
    final updatedChild = controller.habits.firstWhere(
      (value) => value.id == child.id,
    );
    expect(updatedRoot.rsipActive, isTrue);
    expect(updatedChild.rsipActive, isTrue);
    expect(updatedRoot.rsipInternalization, 0);
    expect(updatedChild.rsipFailureCount, 0);
    expect(controller.activeRsipHabits, hasLength(2));
    expect(controller.rsipExecutionRecords, hasLength(1));
    expect(
      controller.rsipExecutionRecords.single.status,
      RsipExecutionStatus.skipped,
    );
    expect(
      controller.protocolEvents.where(
        (event) => event.data['action'] == 'execution_corrected',
      ),
      hasLength(1),
    );
    await database.close();
  });

  test(
    'RSIP daily admission and idempotent settlements preserve history',
    () async {
      final database = _database();
      await database.database;
      final controller = _controller(database);
      final yesterday = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: 'Yesterday node',
        data: {
          'protocol': 'rsip',
          'rsipMinimumAction': '读一页',
          'rsipActive': true,
          'rsipAddedAt': DateTime.now()
              .subtract(const Duration(days: 1))
              .toUtc()
              .toIso8601String(),
        },
      );
      await controller.addRecord(yesterday);
      expect(controller.canAddRsipNode(), isTrue);

      final today = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: 'Today node',
        data: {
          'protocol': 'rsip',
          'rsipMinimumAction': '写一句',
          'rsipActive': true,
          'rsipChainCount': 4,
          'rsipInternalization': 89,
          'rsipAddedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await controller.addRecord(today);
      expect(controller.canAddRsipNode(), isFalse);
      expect(controller.canAddRsipNode(excludingId: today.id), isTrue);

      final day = DateTime.now();
      await controller.logHabit(today, day, WorkStatus.done);
      var current = controller.habits.firstWhere(
        (habit) => habit.id == today.id,
      );
      expect(current.rsipChainCount, 1);
      expect(current.rsipInternalization, 89);
      expect(RsipNode.fromRecord(current).cumulativeExecutionDays, 5);

      await controller.logHabit(today, day, WorkStatus.done);
      current = controller.habits.firstWhere((habit) => habit.id == today.id);
      expect(current.rsipChainCount, 1);
      expect(current.rsipInternalization, 89);

      await controller.logHabit(
        current,
        day.add(const Duration(days: 1)),
        WorkStatus.skipped,
      );
      current = controller.habits.firstWhere((habit) => habit.id == today.id);
      expect(current.rsipActive, isTrue);
      expect(current.rsipChainCount, 0);
      expect(current.rsipInternalization, 89);

      await controller.logHabit(
        current,
        day.add(const Duration(days: 2)),
        WorkStatus.done,
      );
      current = controller.habits.firstWhere((habit) => habit.id == today.id);
      expect(current.rsipActive, isTrue);
      expect(current.rsipChainCount, 1);
      expect(current.rsipInternalization, 89);
      await database.close();
    },
  );

  test('automatic settlement resets expired CTDP reservations', () async {
    final database = _database();
    await database.database;
    var now = DateTime(2026, 8, 8, 9);
    final controller = _controller(database, now: () => now);
    final task = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: 'Expiring chain',
      data: const {
        'protocol': 'ctdp',
        'ctdpTrigger': '戴上帽子',
        'ctdpDelayMinutes': 5,
        'ctdpChainCount': 6,
        'ctdpAuxChainCount': 4,
      },
    );
    await controller.addRecord(task);
    await controller.startCtdpReservation(task);

    now = now.add(const Duration(minutes: 5));
    await controller.settleProtocols();

    final settled = controller.tasks.single;
    expect(settled.ctdpReservationPending, isFalse);
    expect(settled.ctdpChainCount, 0);
    expect(settled.ctdpAuxChainCount, 0);
    expect(settled.ctdpTotalFailures, 1);
    expect(settled.ctdpAuxFailures, 1);
    expect(
      controller.protocolEvents.map((event) => event.data['action']),
      contains('reservation_expired'),
    );
    await database.close();
  });

  test('structured precedents enforce scope and keep usage records', () async {
    final database = _database();
    await database.database;
    final controller = _controller(database);
    final first = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: 'First chain',
      data: const {'protocol': 'ctdp', 'ctdpTrigger': '开始'},
    );
    final second = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: 'Second chain',
      data: const {'protocol': 'ctdp', 'ctdpTrigger': '开始'},
    );
    await controller.addRecord(first);
    await controller.addRecord(second);
    final local = await controller.createExceptionRule(
      name: '仪器报警',
      description: '只有仪器安全报警时可暂停',
      ruleType: 'pause',
      chainId: first.id,
    );
    final global = await controller.createExceptionRule(
      name: '消防警报',
      description: '任何任务均可中断',
      ruleType: 'interruption',
      scope: 'global',
    );

    expect(controller.exceptionRulesFor(first), containsAll([local, global]));
    expect(controller.exceptionRulesFor(second), [global]);
    await controller.useExceptionRule(
      local,
      first,
      action: 'pause_rule_used',
      elapsed: const Duration(minutes: 3),
    );
    expect(
      controller.exceptionRules
          .firstWhere((rule) => rule.id == local.id)
          .data['usageCount'],
      1,
    );
    expect(controller.protocolEvents.first.data['ruleId'], local.id);
    await controller.archiveExceptionRule(local, true);
    expect(controller.exceptionRulesFor(first), [global]);
    await database.close();
  });

  test(
    'CTDP group completes only after every child finishes in its window',
    () async {
      final database = _database();
      await database.database;
      final fixedNow = DateTime(2026, 8, 8, 9);
      final controller = _controller(database, now: () => fixedNow);
      final group = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: 'Experiment group',
        data: const {
          'protocol': 'ctdp',
          'ctdpUnitType': 'group',
          'ctdpGroupTimeLimitHours': 2,
        },
      );
      final first = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: 'Calibrate',
        parentId: group.id,
        data: const {'protocol': 'ctdp', 'ctdpTrigger': '开机'},
      );
      final second = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: 'Measure',
        parentId: group.id,
        data: const {'protocol': 'ctdp', 'ctdpTrigger': '校准后'},
      );
      await controller.addRecord(group);
      await controller.addRecord(first);
      await controller.addRecord(second);
      await controller.startCtdpGroup(group);
      await controller.completeCtdpRound(first, const Duration(minutes: 5));
      expect(
        controller.ctdpTasks
            .firstWhere((item) => item.id == group.id)
            .ctdpChainCount,
        0,
      );

      await controller.completeCtdpRound(second, const Duration(minutes: 8));
      final completedGroup = controller.ctdpTasks.firstWhere(
        (item) => item.id == group.id,
      );
      expect(completedGroup.ctdpChainCount, 1);
      expect(completedGroup.data['ctdpGroupStartedAt'], isNull);
      expect(
        controller.protocolEvents.map((event) => event.data['action']),
        contains('group_completed'),
      );
      await database.close();
    },
  );

  test(
    'RSIP timer, watertight freeze, and daily victory settle end to end',
    () async {
      final database = _database();
      await database.database;
      var now = DateTime(2026, 8, 8, 9);
      final controller = _controller(database, now: () => now);
      final habit = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: 'Check one parameter',
        data: const {
          'protocol': 'rsip',
          'rsipMinimumAction': '核对一条参数',
          'rsipUseTimer': true,
          'rsipTimerMinutes': 1,
          'rsipActive': true,
        },
      );
      await controller.addRecord(habit);
      await controller.startRsipTimer(habit);
      await expectLater(
        controller.completeRsipTimer(habit),
        throwsA(isA<FormatException>()),
      );

      now = now.add(const Duration(minutes: 1));
      await controller.completeRsipTimer(habit);
      var current = controller.habits.single;
      expect(current.rsipChainCount, 1);
      expect(RsipNode.fromRecord(current).cumulativeExecutionDays, 1);
      expect(controller.rsipExecutionRecords, hasLength(1));

      await controller.freezeRsipBranch(
        current,
        until: now.add(const Duration(hours: 2)),
        reason: '实验日保护',
      );
      current = controller.habits.single;
      expect(current.rsipFrozen, isTrue);
      await expectLater(
        controller.startRsipTimer(current),
        throwsA(isA<FormatException>()),
      );
      now = now.add(const Duration(hours: 2));
      await controller.settleProtocols();
      expect(controller.habits.single.rsipFrozen, isFalse);
      await controller.settleProtocols();
      expect(
        controller.protocolEvents.where(
          (event) => event.data['action'] == 'daily_settlement',
        ),
        hasLength(1),
      );

      await controller.recordRsipVictory(title: '按规则完成最小动作', grade: 'small');
      await controller.recordRsipVictory(title: '完成测量与复核', grade: 'big');
      final victories = controller.protocolEvents.where(
        (event) => event.data['action'] == 'daily_victory',
      );
      expect(victories, hasLength(1));
      expect(victories.single.data['grade'], 'big');

      await controller.setRsipAllowMultiplePerDay(true);
      expect(controller.canAddRsipNode(), isTrue);
      await database.close();
    },
  );
}
