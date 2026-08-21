import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/core/models/workspace_models_v3.dart';
import 'package:personal_workbench/core/models/attachment.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/backup_service.dart';
import 'package:personal_workbench/services/focus_service.dart';
import 'package:personal_workbench/services/growth_service.dart';
import 'package:personal_workbench/services/notification_service.dart';
import 'package:personal_workbench/services/search_service.dart';
import 'package:personal_workbench/services/share_capture_service.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

String _key(WorkspaceRecord record) => '${record.kind.name}:${record.id}';

class _MemoryDatabase extends AppDatabase {
  final Map<String, WorkspaceRecord> records = {};
  final Map<String, String> metadata = {};

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
    for (final record in values) {
      await saveRecord(record, markDirty: markDirty);
    }
  }

  @override
  Future<void> permanentlyDelete(String id, RecordKind kind) async {
    records.remove('${kind.name}:$id');
  }

  @override
  Future<void> permanentlyDeleteRecords(
    Iterable<({String id, RecordKind kind})> values,
  ) async {
    for (final value in values) {
      records.remove('${value.kind.name}:${value.id}');
    }
  }

  @override
  Future<List<Attachment>> loadAttachments({String? ownerRecordId}) async =>
      const [];

  @override
  Future<String?> readMetadata(String key) async => metadata[key];

  @override
  Future<void> writeMetadata(String key, String value) async {
    metadata[key] = value;
  }

  @override
  Future<void> close() async {}
}

class _FailingMigrationDatabase extends AppDatabase {
  _FailingMigrationDatabase(this.sourcePath, this.backupPath);

  final String sourcePath;
  final String backupPath;
  bool closed = false;

  @override
  Future<(String, String)?> pendingMigrationBackupPaths() async =>
      (sourcePath, backupPath);

  @override
  Future<(String, String)?> migrationBackupPaths() async =>
      (sourcePath, backupPath);

  @override
  Future<Database> get database async =>
      throw StateError('simulated migration failure');

  @override
  Future<void> close() async {
    closed = true;
  }
}

WorkbenchController _controller(
  DateTime now, {
  NotificationService? notifications,
}) => WorkbenchController(
  database: _MemoryDatabase(),
  backupService: BackupService(),
  searchService: SearchService(),
  focusService: FocusService(),
  notificationService: notifications ?? NotificationService(),
  shareCaptureService: ShareCaptureService(),
  syncService: SupabaseSyncService(null),
  now: () => now,
);

class _ReviewNotifications extends NotificationService {
  int dailySchedules = 0;
  int cancels = 0;

  @override
  bool get supportsSystemNotifications => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required DateTime when,
    String? body,
  }) async {}

  @override
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required DateTime firstAt,
  }) async {
    dailySchedules++;
  }

  @override
  Future<void> cancel(int id) async {
    cancels++;
  }
}

WorkbenchController _databaseController(AppDatabase database, DateTime now) =>
    WorkbenchController(
      database: database,
      backupService: BackupService(),
      searchService: SearchService(),
      focusService: FocusService(),
      notificationService: NotificationService(),
      shareCaptureService: ShareCaptureService(),
      syncService: SupabaseSyncService(null),
      now: () => now,
    );

WorkspaceRecord _task(String title) => WorkspaceRecord.create(
  kind: RecordKind.task,
  title: title,
  scheduledFor: DateTime(2026, 8, 9, 9),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 8, 9, 10);

  setUpAll(sqfliteFfiInit);

  test('fresh database seeds disabled restriction defaults', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: inMemoryDatabasePath,
    );
    final controller = _databaseController(database, now);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.allRecords, hasLength(1));
    expect(controller.restrictionProfile, isNotNull);
    expect(controller.restrictionProfile!.enabled, isFalse);
    expect(controller.advancedFeaturesEnabled, isFalse);
    expect(controller.gameFeaturesEnabled, isTrue);
    expect(controller.gameFeaturesPromptPending, isFalse);
    expect(await database.readMetadata('advanced_features_enabled'), 'false');
    expect(await database.readMetadata('game_features_enabled'), 'true');
    expect(await database.readMetadata('game_features_prompt_seen'), 'true');
  });

  group('RSIP v3 state machine', () {
    test('legacy Android RSIP records are normalized on write', () async {
      final controller = _controller(now);
      addTearDown(controller.dispose);
      final legacy = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: '旧入口节点',
        body: '完成一个最小动作',
        data: const {
          'protocol': 'rsip',
          'rsipChainCount': 7,
          'rsipInternalization': 65,
        },
      );

      await controller.addRecord(legacy);

      final normalized = controller.rsipNodes.single;
      expect(normalized.stage, 'E1');
      expect(normalized.cumulativeExecutionDays, 7);
      expect(normalized.record.data['recordType'], 'rsipNode');
      expect(normalized.record.data['rsipInternalization'], 65);
      expect(normalized.record.id, legacy.id);
    });

    test('strict split batch counts as one daily addition', () async {
      final controller = _controller(now);
      addTearDown(controller.dispose);

      final nodes = await controller.splitRsipGoal(
        goal: '稳定作息',
        items: const [
          {'title': '固定关灯', 'rule': '23:00 前关灯'},
          {'title': '固定起床', 'rule': '07:00 起床', 'passive': true},
        ],
      );

      expect(nodes, hasLength(2));
      expect(
        nodes.map((node) => node.data['splitBatchId']).toSet(),
        hasLength(1),
      );
      expect(controller.canAddRsipNode(), isFalse);
      expect(
        controller.protocolEvents.where(
          (event) => event.data['action'] == 'split_batch_created',
        ),
        hasLength(1),
      );
    });

    test(
      'group tolerance archives subtree then collapses whole group',
      () async {
        final controller = _controller(now);
        addTearDown(controller.dispose);
        await controller.setRsipAllowMultiplePerDay(true);
        final group = await controller.saveRsipNodeGroup(
          title: '作息组',
          initialTolerance: 2,
        );
        final first = await controller.saveRsipNode(
          title: '早睡',
          rule: '23:00 前关灯',
          type: RsipNodeType.habit,
          groupId: group.id,
        );
        final second = await controller.saveRsipNode(
          title: '早起',
          rule: '07:00 前离床',
          type: RsipNodeType.habit,
          groupId: group.id,
        );
        final child = await controller.saveRsipNode(
          title: '晨间喝水',
          rule: '离床后喝一杯水',
          type: RsipNodeType.ritual,
          parentId: first.id,
          groupId: group.id,
        );

        final firstPreview = controller.previewRsipViolation(first);
        expect(firstPreview.remainingToleranceBefore, 2);
        expect(firstPreview.remainingToleranceAfter, 1);
        expect(firstPreview.collapsesWholeGroup, isFalse);
        expect(firstPreview.archiveNodeIds, containsAll([first.id, child.id]));
        await controller.settleRsipNode(
          first,
          status: RsipExecutionStatus.violated,
          reason: '超过规定时间',
        );
        expect(controller.activeRsipHabits.map((node) => node.id), [second.id]);
        expect(controller.rsipNodeGroups.single.remainingTolerance, 1);

        final secondPreview = controller.previewRsipViolation(second);
        expect(secondPreview.collapsesWholeGroup, isTrue);
        expect(secondPreview.endsRun, isTrue);
        await controller.settleRsipNode(
          second,
          status: RsipExecutionStatus.violated,
          reason: '未按闹钟起床',
        );
        expect(controller.activeRsipHabits, isEmpty);
        expect(controller.rsipRunRecords.single.endedAt, isNotNull);
        expect(controller.rsipLibraryNodes, hasLength(3));
      },
    );

    test(
      '21 consecutive executions reach E2 and reinforcement absorbs violation',
      () async {
        var clock = DateTime(2026, 7, 1, 10);
        final controller = WorkbenchController(
          database: _MemoryDatabase(),
          backupService: BackupService(),
          searchService: SearchService(),
          focusService: FocusService(),
          notificationService: NotificationService(),
          shareCaptureService: ShareCaptureService(),
          syncService: SupabaseSyncService(null),
          now: () => clock,
        );
        addTearDown(controller.dispose);
        final node = await controller.saveRsipNode(
          title: '每日复盘',
          rule: '睡前写三句话',
          type: RsipNodeType.ritual,
        );

        for (var day = 0; day < 21; day++) {
          clock = DateTime(2026, 7, 1 + day, 10);
          await controller.settleRsipNode(
            node,
            status: RsipExecutionStatus.executed,
            reinforce: day == 20,
          );
        }
        final e2 = controller.rsipNodes.single;
        expect(e2.stage, 'E2');
        expect(e2.consecutiveExecutions, 21);
        expect(e2.cumulativeExecutionDays, 21);
        expect(e2.reinforcement, 1);

        clock = DateTime(2026, 7, 22, 10);
        final preview = controller.previewRsipViolation(e2.record);
        expect(preview.onlyConsumesReinforcement, isTrue);
        expect(preview.archiveNodeIds, isEmpty);
        await controller.settleRsipNode(
          e2.record,
          status: RsipExecutionStatus.violated,
          reason: '当天突发就医',
        );
        expect(controller.activeRsipHabits.single.id, node.id);
        expect(controller.rsipNodes.single.reinforcement, 0);
      },
    );

    test(
      'daily settlement is idempotent and correction keeps an audit event',
      () async {
        final controller = _controller(now);
        addTearDown(controller.dispose);
        final node = await controller.saveRsipNode(
          title: '桌面清理',
          rule: '离开前恢复桌面',
          type: RsipNodeType.habit,
        );

        await controller.settleRsipNode(
          node,
          status: RsipExecutionStatus.executed,
        );
        await controller.settleRsipNode(
          node,
          status: RsipExecutionStatus.executed,
        );
        expect(controller.rsipExecutionRecords, hasLength(1));
        expect(controller.rsipNodes.single.totalExecutions, 1);
        expect(
          () => controller.settleRsipNode(
            node,
            status: RsipExecutionStatus.skipped,
          ),
          throwsA(isA<FormatException>()),
        );

        await controller.settleRsipNode(
          node,
          status: RsipExecutionStatus.skipped,
          correctionReason: '误触完成按钮',
        );
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
      },
    );

    test('RSIP settlement changes logical day at the 4 AM boundary', () async {
      var clock = DateTime(2026, 8, 14, 3, 30);
      final controller = WorkbenchController(
        database: _MemoryDatabase(),
        backupService: BackupService(),
        searchService: SearchService(),
        focusService: FocusService(),
        notificationService: NotificationService(),
        shareCaptureService: ShareCaptureService(),
        syncService: SupabaseSyncService(null),
        now: () => clock,
      );
      addTearDown(controller.dispose);
      final node = await controller.saveRsipNode(
        title: '边界检查',
        rule: '在逻辑日内只结算一次',
        type: RsipNodeType.policy,
      );

      await controller.settleRsipNode(
        node,
        status: RsipExecutionStatus.executed,
      );
      clock = DateTime(2026, 8, 14, 3, 59);
      await controller.settleRsipNode(
        node,
        status: RsipExecutionStatus.executed,
      );
      expect(controller.rsipExecutionRecords, hasLength(1));
      expect(
        controller.rsipExecutionRecords.single.logicalDayKey,
        '2026-08-13',
      );

      clock = DateTime(2026, 8, 14, 4);
      await controller.settleRsipNode(
        node,
        status: RsipExecutionStatus.executed,
      );
      expect(
        controller.rsipExecutionRecords
            .map((record) => record.logicalDayKey)
            .toSet(),
        {'2026-08-13', '2026-08-14'},
      );
      expect(controller.rsipNodes.single.consecutiveExecutions, 2);
    });

    test(
      'task completion automatically settles linked RSIP once per day',
      () async {
        final controller = _controller(now);
        addTearDown(controller.dispose);
        final task = _task('完成实验记录');
        await controller.addRecord(task);
        final node = await controller.saveRsipNode(
          title: '实验后记录',
          rule: '实验结束立即补全记录',
          type: RsipNodeType.trigger,
        );
        await controller.saveRsipTaskLink(
          nodeId: node.id,
          chainId: task.id,
          chainKind: RsipTaskChainKind.unit,
          triggerEvent: RsipTaskLinkTriggerEvent.taskCompleted,
          effect: RsipTaskLinkEffect.markRsipExecuted,
        );

        await controller.settleTask(task, status: WorkStatus.done);

        expect(controller.rsipExecutionRecords, hasLength(1));
        expect(
          controller.rsipExecutionRecords.single.status,
          RsipExecutionStatus.executed,
        );
        expect(controller.rsipExecutionRecords.single.sourceId, task.id);
      },
    );

    test(
      'library restore starts a new run and resets group tolerance',
      () async {
        final controller = _controller(now);
        addTearDown(controller.dispose);
        await controller.setRsipAllowMultiplePerDay(true);
        final group = await controller.saveRsipNodeGroup(
          title: '恢复组',
          initialTolerance: 1,
        );
        final node = await controller.saveRsipNode(
          title: '可恢复节点',
          rule: '完成最小动作',
          type: RsipNodeType.policy,
          groupId: group.id,
        );
        await controller.settleRsipNode(
          node,
          status: RsipExecutionStatus.violated,
          reason: '本轮失败',
        );
        expect(controller.rsipRunRecords.single.endedAt, isNotNull);
        expect(controller.rsipNodeGroups.single.remainingTolerance, 0);

        await controller.restoreRsipNode(node);

        expect(controller.activeRsipHabits.single.id, node.id);
        expect(controller.rsipNodes.single.stage, 'E0');
        expect(controller.rsipNodeGroups.single.remainingTolerance, 1);
        expect(controller.rsipRunRecords, hasLength(2));
        expect(
          controller.rsipRunRecords.where((run) => run.endedAt == null),
          hasLength(1),
        );
      },
    );

    test(
      'RSIP to task confirmation action is persisted and deduplicated',
      () async {
        final controller = _controller(now);
        addTearDown(controller.dispose);
        final task = _task('启动分析脚本');
        await controller.addRecord(task);
        final node = await controller.saveRsipNode(
          title: '开始分析',
          rule: '数据检查后启动分析任务',
          type: RsipNodeType.trigger,
        );
        for (var index = 0; index < 2; index++) {
          await controller.saveRsipTaskLink(
            nodeId: node.id,
            chainId: task.id,
            chainKind: RsipTaskChainKind.unit,
            triggerEvent: RsipTaskLinkTriggerEvent.rsipMarkedExecuted,
            effect: RsipTaskLinkEffect.promptStartChain,
            automation: RsipTaskLinkAutomation.confirm,
          );
        }
        expect(controller.rsipTaskLinks, hasLength(1));

        await controller.settleRsipNode(
          node,
          status: RsipExecutionStatus.executed,
        );
        final action = controller.pendingRsipTaskActions(node.id).single;
        await controller.applyRsipTaskAction(action);
        await controller.applyRsipTaskAction(action);

        expect(
          controller.tasks.singleWhere((value) => value.id == task.id).status,
          WorkStatus.doing,
        );
        expect(controller.pendingRsipTaskActions(node.id), isEmpty);
        expect(
          controller.protocolEvents.where(
            (event) => event.data['action'] == 'rsip_task_link_triggered',
          ),
          hasLength(1),
        );
      },
    );

    test(
      'strict mode switch requires daily settlement and records history',
      () async {
        final controller = _controller(now);
        addTearDown(controller.dispose);
        final node = await controller.saveRsipNode(
          title: '模式检查',
          rule: '先结算再切换',
          type: RsipNodeType.policy,
        );

        await expectLater(
          controller.setRsipStrictMode(false),
          throwsA(isA<FormatException>()),
        );
        await controller.settleRsipNode(
          node,
          status: RsipExecutionStatus.skipped,
        );
        await controller.setRsipStrictMode(false);

        expect(controller.rsipStrictMode, isFalse);
        expect(controller.rsipAllowMultiplePerDay, isTrue);
        expect(
          controller.protocolEvents.where(
            (event) => event.data['action'] == 'mode_changed',
          ),
          hasLength(1),
        );
      },
    );
  });

  test('failed migration surfaces a clear error', () async {
    final directory = await Directory.systemTemp.createTemp(
      'workbench-migration-recovery-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}${Platform.pathSeparator}legacy.db');
    final backup = '${source.path}.pre-v2.dpapi';
    final original = List<int>.generate(32, (index) => index);
    await source.writeAsBytes(original);
    final database = _FailingMigrationDatabase(source.path, backup);
    final controller = WorkbenchController(
      database: database,
      backupService: BackupService(),
      searchService: SearchService(),
      focusService: FocusService(),
      notificationService: NotificationService(),
      shareCaptureService: ShareCaptureService(),
      syncService: SupabaseSyncService(null),
      now: () => now,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.error, contains('初始化失败'));
  });

  test('failed task settlement requires a reason', () async {
    final controller = _controller(now);
    addTearDown(controller.dispose);
    final task = _task('verify alignment');
    await controller.addRecord(task);

    expect(
      () => controller.settleTask(task, status: WorkStatus.failed),
      throwsA(isA<FormatException>()),
    );

    await controller.settleTask(
      task,
      status: WorkStatus.failed,
      reason: 'instrument unavailable',
    );
    final stored = controller.tasks.single;
    expect(stored.status, WorkStatus.failed);
    expect(stored.data['settlementReason'], 'instrument unavailable');
  });

  test(
    'rescheduling preserves the old instance and creates a linked one',
    () async {
      final controller = _controller(now);
      addTearDown(controller.dispose);
      final task = _task('process spectrum');
      await controller.addRecord(task);
      final target = DateTime(2026, 8, 11, 9);

      final replacement = await controller.rescheduleTaskInstance(
        task,
        target,
        reason: 'waiting for calibration',
      );

      expect(controller.tasks, hasLength(2));
      final original = controller.tasks.firstWhere(
        (item) => item.id == task.id,
      );
      expect(original.status, WorkStatus.rescheduled);
      expect(original.scheduledFor, task.scheduledFor);
      expect(original.data['rescheduledToId'], replacement.id);
      expect(replacement.data['rescheduledFromId'], original.id);
      expect(replacement.scheduledFor, target);
    },
  );

  test(
    'existing installation does not enable game features implicitly',
    () async {
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        overridePath: inMemoryDatabasePath,
      );
      await database.saveRecord(_task('existing task'));
      final controller = _databaseController(database, now);
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.gameFeaturesEnabled, isFalse);
      expect(controller.gameFeaturesPromptPending, isTrue);
      expect(await database.readMetadata('game_features_enabled'), 'false');

      await controller.answerGameFeaturesPrompt(enable: true);
      expect(controller.gameFeaturesEnabled, isTrue);
      expect(controller.gameFeaturesPromptPending, isFalse);
      expect(await database.readMetadata('game_features_prompt_seen'), 'true');
    },
  );

  test('existing installation game prompt is only offered once', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: inMemoryDatabasePath,
    );
    await database.saveRecord(_task('existing task'));
    final controller = _databaseController(database, now);
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.answerGameFeaturesPrompt(enable: false);

    await controller.initialize();

    expect(controller.gameFeaturesEnabled, isFalse);
    expect(controller.gameFeaturesPromptPending, isFalse);
  });

  test(
    'legacy protocol data enables advanced mode without data loss',
    () async {
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        overridePath: inMemoryDatabasePath,
      );
      final legacyHabit = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: 'Legacy RSIP',
        data: const {'protocol': 'rsip', 'rsipActive': false},
      );
      await database.saveRecord(legacyHabit);
      final controller = _databaseController(database, now);
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.advancedFeaturesEnabled, isTrue);

      await controller.setAdvancedFeaturesEnabled(false);

      expect(controller.advancedFeaturesEnabled, isFalse);
      expect(controller.habits.single.hasRsipProtocol, isTrue);
      expect(
        (await database.loadRecords())
            .firstWhere((record) => record.id == legacyHabit.id)
            .hasRsipProtocol,
        isTrue,
      );
    },
  );

  test('startToday enforces 1-3 unique unfinished commitments', () async {
    final controller = _controller(now);
    addTearDown(controller.dispose);
    final tasks = List.generate(4, (index) => _task('task $index'));
    for (final task in tasks) {
      await controller.addRecord(task);
    }

    await expectLater(
      controller.startToday(commitments: const [], plannedHabits: const []),
      throwsFormatException,
    );
    await expectLater(
      controller.startToday(commitments: tasks, plannedHabits: const []),
      throwsFormatException,
    );
    await controller.startToday(
      commitments: tasks.take(3).toList(),
      plannedHabits: const [],
    );

    expect(controller.commitmentIds, hasLength(3));
  });

  test('startToday accepts one commitment', () async {
    final controller = _controller(now);
    addTearDown(controller.dispose);
    final task = _task('single');
    await controller.addRecord(task);

    await controller.startToday(commitments: [task], plannedHabits: const []);

    expect(controller.commitmentIds, [task.id]);
  });

  test('startToday can be undone before progress and restores focus', () async {
    final controller = _controller(now);
    addTearDown(controller.dispose);
    final previousFocus = _task('previous focus').withData('isFocus', true);
    final selected = _task('selected');
    await controller.addRecord(previousFocus);
    await controller.addRecord(selected);
    await controller.startToday(
      commitments: [selected],
      plannedHabits: const [],
    );

    expect(await controller.undoStartToday(), isTrue);
    expect(controller.todayPlan, isNull);
    expect(
      controller.tasks
          .firstWhere((task) => task.id == previousFocus.id)
          .isFocus,
      isTrue,
    );
    expect(
      controller.tasks.firstWhere((task) => task.id == selected.id).isFocus,
      isFalse,
    );
  });

  test('startToday cannot be undone after a commitment is completed', () async {
    final controller = _controller(now);
    addTearDown(controller.dispose);
    final task = _task('completed');
    await controller.addRecord(task);
    await controller.startToday(commitments: [task], plannedHabits: const []);
    await controller.toggleTaskDone(controller.tasks.single);

    expect(await controller.undoStartToday(), isFalse);
    expect(controller.todayPlan, isNotNull);
  });

  test('completed commitments cannot be replaced', () async {
    final controller = _controller(now);
    addTearDown(controller.dispose);
    final committed = _task('committed');
    final replacement = _task('replacement');
    await controller.addRecord(committed);
    await controller.addRecord(replacement);
    await controller.startToday(
      commitments: [committed],
      plannedHabits: const [],
    );
    await controller.toggleTaskDone(committed);

    await expectLater(
      controller.replaceTodayCommitment(
        slot: 0,
        replacement: replacement,
        reason: '优先级变化',
      ),
      throwsFormatException,
    );
  });

  test(
    'closeToday requires and applies incomplete task dispositions',
    () async {
      final controller = _controller(now);
      addTearDown(controller.dispose);
      final committed = _task('committed');
      final tomorrow = _task('tomorrow');
      await controller.addRecord(committed);
      await controller.addRecord(tomorrow);
      await controller.startToday(
        commitments: [committed],
        plannedHabits: const [],
      );

      await expectLater(
        controller.closeToday(
          reasons: const {},
          dispositions: const {},
          tomorrowCommitments: [tomorrow],
        ),
        throwsFormatException,
      );
      await controller.closeToday(
        reasons: {committed.id: '外部阻塞', tomorrow.id: '收尾时跳过'},
        dispositions: {committed.id: 'tomorrow', tomorrow.id: 'skipped'},
        tomorrowCommitments: [tomorrow],
      );

      expect(controller.todayPlan?.data['closedAt'], isNotNull);
      final updated = controller.tasks.firstWhere(
        (task) => task.id == committed.id,
      );
      expect(updated.status, WorkStatus.rescheduled);
      final replacement = controller.tasks.firstWhere(
        (task) => task.data['rescheduledFromId'] == committed.id,
      );
      expect(replacement.scheduledFor, DateTime(2026, 8, 10));
      expect(
        controller.activeRecords.any(
          (record) => record.data['recordType'] == 'dayCloseSnapshot',
        ),
        isTrue,
      );
      expect(
        controller.reviewForPeriod(ReviewPeriodType.daily, '2026-08-09'),
        isNotNull,
      );
    },
  );

  test(
    'closed task correction keeps frozen snapshot and records audit',
    () async {
      final controller = _controller(now);
      addTearDown(controller.dispose);
      final task = _task('correct after closing');
      await controller.addRecord(task);
      await controller.startToday(commitments: [task], plannedHabits: const []);
      await controller.closeToday(
        reasons: {task.id: '原始失败原因'},
        dispositions: {task.id: 'failed'},
      );

      final failed = controller.tasks.firstWhere((item) => item.id == task.id);
      final snapshot = controller.protocolEvents.firstWhere(
        (record) => record.data['recordType'] == 'dayCloseSnapshot',
      );
      await controller.correctSettledTask(
        task: failed,
        status: WorkStatus.done,
        reason: '补录纸质实验记录',
        resultNote: '实验于当天完成',
      );

      final corrected = controller.tasks.firstWhere(
        (item) => item.id == task.id,
      );
      expect(corrected.status, WorkStatus.done);
      expect(corrected.data['correctionReason'], '补录纸质实验记录');
      expect(controller.todayClosed, isTrue);
      final frozenFacts = (snapshot.data['taskFacts'] as List).cast<Map>();
      expect(
        frozenFacts.firstWhere((fact) => fact['id'] == task.id)['status'],
        WorkStatus.failed,
      );
      final audit = controller.protocolEvents.firstWhere(
        (record) => record.data['recordType'] == 'taskCorrection',
      );
      expect(audit.data['beforeStatus'], WorkStatus.failed);
      expect(audit.data['afterStatus'], WorkStatus.done);
      expect(audit.data['dayCloseSnapshotId'], snapshot.id);
    },
  );

  test(
    'suggestedTodayTasks picks the highest priority unfinished three',
    () async {
      final controller = _controller(now);
      addTearDown(controller.dispose);
      final low = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '低优先级',
        scheduledFor: now,
        data: const {'priority': 1},
      );
      final high = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '高优先级',
        scheduledFor: now,
        data: const {'priority': 3},
      );
      final medium = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '中优先级',
        scheduledFor: now,
        data: const {'priority': 2},
      );
      final done = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '已完成',
        scheduledFor: now,
        status: WorkStatus.done,
        data: const {'priority': 4},
      );
      for (final task in [low, high, medium, done]) {
        await controller.addRecord(task);
      }

      expect(controller.suggestedTodayTasks.map((task) => task.title), [
        '高优先级',
        '中优先级',
        '低优先级',
      ]);
    },
  );

  test('today commitments can be adjusted before focus evidence', () async {
    final controller = _controller(now);
    addTearDown(controller.dispose);
    final first = _task('第一项');
    final second = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '第二项',
      scheduledFor: now,
    );
    await controller.addRecord(first);
    await controller.addRecord(second);
    await controller.startToday(commitments: [first], plannedHabits: const []);
    expect(controller.canUpdateTodayCommitments, isTrue);
    await controller.updateTodayCommitments([second]);
    expect(controller.activeCommitmentIds, [second.id]);
  });

  test('quickCapture accepts scheduling and project context', () async {
    final controller = _controller(now);
    addTearDown(controller.dispose);
    final record = await controller.quickCapture(
      kind: RecordKind.task,
      text: '安排到今天',
      scheduledFor: now,
      projectId: 'project-1',
    );

    expect(record.status, WorkStatus.todo);
    expect(record.scheduledFor, now);
    expect(record.projectId, 'project-1');
    expect(record.hasCtdpProtocol, isFalse);
  });

  test(
    'quickCapture appends to the existing diary for the logical day',
    () async {
      final controller = _controller(now);
      addTearDown(controller.dispose);
      final first = await controller.quickCapture(
        kind: RecordKind.diary,
        text: '第一条记录',
      );
      final second = await controller.quickCapture(
        kind: RecordKind.diary,
        text: '第二条记录',
      );

      expect(second.id, first.id);
      expect(second.body, contains('第一条记录'));
      expect(second.body, contains('第二条记录'));
      expect(controller.diaries, hasLength(1));
    },
  );

  test('logical day boundary switches at the configured hour', () {
    const defaultService = GrowthService();
    expect(
      defaultService.logicalDay(DateTime(2026, 8, 10, 3, 59)),
      DateTime(2026, 8, 9),
    );
    expect(
      defaultService.logicalDay(DateTime(2026, 8, 10, 4)),
      DateTime(2026, 8, 10),
    );
    const earlyService = GrowthService(logicalDayBoundaryHour: 2);
    expect(
      earlyService.logicalDay(DateTime(2026, 8, 10, 1, 59)),
      DateTime(2026, 8, 9),
    );
  });

  test(
    'one-time task defaults to logical-day end while explicit due wins',
    () async {
      final controller = _controller(DateTime(2026, 8, 10, 1, 30));
      addTearDown(controller.dispose);
      final automatic = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: 'automatic deadline',
        scheduledFor: DateTime(2026, 8, 10, 1, 30),
      );
      final explicit = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: 'explicit deadline',
        scheduledFor: DateTime(2026, 8, 10, 1, 30),
        dueAt: DateTime(2026, 8, 12, 18),
      );

      await controller.addRecord(automatic);
      await controller.addRecord(explicit);

      expect(
        controller.tasks.firstWhere((task) => task.id == automatic.id).dueAt,
        DateTime(2026, 8, 10, 4),
      );
      expect(
        controller.tasks.firstWhere((task) => task.id == explicit.id).dueAt,
        DateTime(2026, 8, 12, 18),
      );
      expect(controller.tasksForDay(DateTime(2026, 8, 9, 12)), hasLength(2));
      expect(controller.tasksForDay(DateTime(2026, 8, 10, 12)), isEmpty);
    },
  );

  test('recurrence generation clamps month end and is idempotent', () async {
    final controller = _controller(DateTime(2028, 1, 31, 10));
    addTearDown(controller.dispose);
    final task = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: 'month end',
      scheduledFor: DateTime(2028, 1, 31, 9),
      data: const {'recurrence': 'monthly', 'completionWindowMinutes': 1440},
    );
    await controller.addRecord(task);
    await controller.ensureTaskInstancesThrough(DateTime(2028, 3, 31));
    final dates = controller.tasks
        .where((record) => record.title == 'month end')
        .map((record) => record.scheduledFor)
        .whereType<DateTime>()
        .toSet();
    expect(dates, contains(DateTime(2028, 2, 29, 9)));
    expect(dates, contains(DateTime(2028, 3, 31, 9)));
    final count = controller.tasks.length;
    await controller.ensureTaskInstancesThrough(DateTime(2028, 3, 31));
    expect(controller.tasks, hasLength(count));
  });

  test('sequential group locks successors until skip and continue', () async {
    final controller = _controller(now);
    addTearDown(controller.dispose);
    final first = _task('first');
    final second = _task('second');
    await controller.addRecord(first);
    await controller.addRecord(second);
    final group = await controller.createTaskGroup(
      title: 'chain',
      sequential: true,
    );
    await controller.addTaskToGroup(task: first, group: group);
    await controller.addTaskToGroup(task: second, group: group);
    expect(controller.isTaskGroupMemberLocked(second, group), isTrue);
    await controller.skipTaskAndContinueChain(first);
    expect(controller.isTaskGroupMemberLocked(second, group), isFalse);
  });

  test(
    'sequential group reorder is versioned and cannot cross started task',
    () async {
      final controller = _controller(now);
      addTearDown(controller.dispose);
      final first = _task('first');
      final second = _task('second');
      final third = _task('third');
      await controller.addRecord(first);
      await controller.addRecord(second);
      await controller.addRecord(third);
      final group = await controller.createTaskGroup(
        title: 'versioned chain',
        sequential: true,
      );
      await controller.addTaskToGroup(task: first, group: group);
      await controller.addTaskToGroup(task: second, group: group);
      await controller.addTaskToGroup(task: third, group: group);

      await controller.reorderTaskGroupMember(
        task: third,
        group: group,
        targetIndex: 1,
        reason: '先完成依赖较少的节点',
      );
      expect(controller.groupMembers(group.id).map((task) => task.title), [
        'first',
        'third',
        'second',
      ]);
      final updatedGroup = controller.taskGroups.single;
      expect(updatedGroup.data['version'], 2);
      expect(
        controller.protocolEvents.any(
          (event) => event.data['recordType'] == 'taskGroupReorder',
        ),
        isTrue,
      );

      final startedFirst = controller.tasks
          .firstWhere((task) => task.id == first.id)
          .copyWith(status: WorkStatus.doing);
      await controller.updateRecord(startedFirst);
      expect(
        controller.taskGroupMemberCanMove(
          controller.tasks.firstWhere((task) => task.id == third.id),
          updatedGroup,
          0,
        ),
        isFalse,
      );
      await expectLater(
        controller.reorderTaskGroupMember(
          task: controller.tasks.firstWhere((task) => task.id == third.id),
          group: updatedGroup,
          targetIndex: 0,
          reason: '不应越过已开始节点',
        ),
        throwsFormatException,
      );
    },
  );

  test('task keeps one primary project and related projects', () async {
    final controller = _controller(now);
    addTearDown(controller.dispose);
    final task = _task('shared task');
    final primary = WorkspaceRecord.create(
      kind: RecordKind.project,
      title: 'primary',
    );
    final related = WorkspaceRecord.create(
      kind: RecordKind.project,
      title: 'related',
    );
    await controller.addRecord(task);
    await controller.addRecord(primary);
    await controller.addRecord(related);
    await controller.linkTaskToProject(
      task: task,
      project: primary,
      primary: true,
    );
    final current = controller.tasks.firstWhere(
      (record) => record.id == task.id,
    );
    await controller.linkTaskToProject(task: current, project: related);
    expect(
      controller.projectsForTask(current).map((project) => project.id),
      containsAll([primary.id, related.id]),
    );
  });

  test('period review updates one primary record and keeps versions', () async {
    final controller = _controller(now);
    addTearDown(controller.dispose);
    final start = DateTime(2026, 8, 9);
    for (final body in ['v1', 'v2']) {
      await controller.savePeriodReview(
        type: ReviewPeriodType.daily,
        periodKey: '2026-08-09',
        periodStart: start,
        periodEnd: start.add(const Duration(days: 1)),
        body: body,
      );
    }
    final reviews = controller.notes.where(
      (record) => record.data['periodKey'] == '2026-08-09',
    );
    expect(reviews, hasLength(1));
    expect((reviews.single.data['versions'] as List), hasLength(1));
  });

  test('daily review reads newest diary draft and preserves legacy record', () async {
    final controller = _controller(now);
    addTearDown(controller.dispose);
    final day = DateTime(2026, 8, 9);
    final older = WorkspaceRecord.create(
      kind: RecordKind.diary,
      title: '旧日记',
      body: '较早正文',
      scheduledFor: day,
      data: {'completedToday': '早期完成'},
    );
    await controller.addRecord(older);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final newer = WorkspaceRecord.create(
      kind: RecordKind.diary,
      title: '最新日记',
      body: '最新正文',
      scheduledFor: day,
      data: {
        'completedToday': '完成实验',
        'blockers': '设备等待',
        'tomorrowPlan': '整理数据',
        'mood': 4,
      },
    );
    await controller.addRecord(newer);

    expect(controller.latestDiaryForDay(day)?.id, newer.id);
    expect(controller.dailyReviewSourceForDay(day)?.id, newer.id);
    final review = await controller.savePeriodReview(
      type: ReviewPeriodType.daily,
      periodKey: '2026-08-09',
      periodStart: day,
      periodEnd: day.add(const Duration(days: 1)),
      title: newer.title,
      body: newer.body,
      mood: 4,
      completedToday: '完成实验',
      blockers: '设备等待',
      tomorrowPlan: '整理数据',
      legacyDiaryId: newer.id,
    );
    expect(review.kind, RecordKind.note);
    expect(review.data['recordType'], 'periodReview');
    expect(review.data['legacyDiaryId'], newer.id);
    expect(review.data['migratedFrom'], 'diary');
    expect(review.data['mood'], 4);
    expect(controller.diaries, hasLength(2));
    expect(controller.dailyReviewSourceForDay(day)?.id, review.id);
  });

  test('period review snapshot changes only after explicit refresh', () async {
    final controller = _controller(now);
    addTearDown(controller.dispose);
    final start = DateTime(2026, 8, 9);
    final task = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: 'settled',
      scheduledFor: start,
      status: WorkStatus.done,
      data: {'completedAt': DateTime(2026, 8, 9, 10).toIso8601String()},
    );
    await controller.addRecord(task);
    var review = await controller.savePeriodReview(
      type: ReviewPeriodType.daily,
      periodKey: '2026-08-09',
      periodStart: start,
      periodEnd: start.add(const Duration(days: 1)),
      body: 'manual text',
    );
    final current = controller.tasks.firstWhere((item) => item.id == task.id);
    await controller.updateRecord(current.copyWith(status: WorkStatus.failed));

    expect(controller.reviewStatisticsChanged(review), isTrue);
    review = await controller.savePeriodReview(
      type: ReviewPeriodType.daily,
      periodKey: '2026-08-09',
      periodStart: start,
      periodEnd: start.add(const Duration(days: 1)),
      body: 'updated manual text',
    );
    expect((review.data['snapshot'] as Map)['completed'], 1);
    review = await controller.refreshPeriodReviewSnapshot(
      review,
      reason: '任务状态已留痕更正',
    );
    expect((review.data['snapshot'] as Map)['failed'], 1);
    expect(review.body, 'updated manual text');
  });

  test(
    'review snapshot includes focus and overdue draft can be skipped',
    () async {
      final notifications = _ReviewNotifications();
      final controller = _controller(now, notifications: notifications);
      addTearDown(controller.dispose);
      final start = DateTime(2026, 8, 8);
      final task = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: 'settled task',
        scheduledFor: start,
        status: WorkStatus.done,
        projectId: 'project-1',
        data: {'settledAt': DateTime(2026, 8, 8, 12).toIso8601String()},
      );
      final focus = WorkspaceRecord.create(
        kind: RecordKind.focusSession,
        title: task.title,
        parentId: task.id,
        projectId: 'project-1',
        scheduledFor: DateTime(2026, 8, 8, 11),
        status: WorkStatus.done,
        data: const {'seconds': 900},
      );
      final draft = WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '日回顾 · 2026-08-08',
        scheduledFor: start,
        data: {
          'recordType': 'periodReview',
          'periodType': ReviewPeriodType.daily.name,
          'periodKey': '2026-08-08',
          'periodStart': start.toUtc().toIso8601String(),
          'periodEnd': start
              .add(const Duration(days: 1))
              .toUtc()
              .toIso8601String(),
          'draft': true,
        },
      );
      await controller.addRecord(task);
      await controller.addRecord(focus);
      await controller.addRecord(draft);

      await controller.scheduleReviewReminders();
      expect(notifications.dailySchedules, 1);
      final review = await controller.savePeriodReview(
        type: ReviewPeriodType.daily,
        periodKey: '2026-08-08',
        periodStart: start,
        periodEnd: start.add(const Duration(days: 1)),
        body: 'facts',
      );
      final snapshot = review.data['snapshot'] as Map;
      expect(snapshot['focusSessionIds'], [focus.id]);
      expect(snapshot['focusSeconds'], 900);
      expect(snapshot['projectIds'], ['project-1']);
      expect(review.data['draft'], isFalse);

      final skippedDraft = draft.copyWith(
        data: {...draft.data, 'periodKey': '2026-08-07'},
      );
      await controller.updateRecord(skippedDraft);
      await controller.skipPeriodReview(skippedDraft, reason: '本期无新增记录');
      final skipped = controller.notes.firstWhere(
        (record) => record.id == skippedDraft.id,
      );
      expect(skipped.data['reviewSkipped'], isTrue);
      expect(skipped.data['reviewSkipReason'], '本期无新增记录');
      expect(notifications.cancels, greaterThan(0));
    },
  );

  test(
    'recurring task scope updates future but preserves settled history',
    () async {
      final controller = _controller(DateTime(2026, 8, 10, 10));
      addTearDown(controller.dispose);
      final start = DateTime(2026, 8, 10, 9);
      final definition = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: 'Old title',
        scheduledFor: start,
        data: const {'recordType': 'taskDefinition', 'recurrence': 'daily'},
      );
      await controller.addRecord(definition);
      await controller.ensureTaskInstancesThrough(DateTime(2026, 8, 13));
      final instances =
          controller.tasks
              .where((task) => task.data['definitionId'] == definition.id)
              .toList()
            ..sort((a, b) => a.scheduledFor!.compareTo(b.scheduledFor!));
      await controller.updateRecord(
        instances.first.copyWith(status: WorkStatus.done),
      );
      final selected = instances[1];

      await controller.updateTaskWithScope(
        original: selected,
        updated: selected.copyWith(title: 'New title'),
        scope: TaskEditScope.future,
      );

      final refreshed =
          controller.tasks
              .where((task) => task.data['definitionId'] == definition.id)
              .toList()
            ..sort((a, b) => a.scheduledFor!.compareTo(b.scheduledFor!));
      expect(refreshed.first.title, 'Old title');
      expect(refreshed.first.status, WorkStatus.done);
      expect(
        refreshed.skip(1).every((task) => task.title == 'New title'),
        isTrue,
      );
    },
  );

  test(
    'scheduled focus requires confirmation and resolves conflicts',
    () async {
      final now = DateTime(2026, 8, 10, 10);
      final controller = _controller(now);
      addTearDown(controller.dispose);
      final first = await controller.saveFocusPreset(
        title: 'first',
        mode: FocusMode.custom,
        minutes: 25,
        scheduleMode: 'once',
        scheduledAt: now.subtract(const Duration(minutes: 2)),
      );
      final second = await controller.saveFocusPreset(
        title: 'second',
        mode: FocusMode.stopwatch,
        minutes: 25,
        scheduleMode: 'once',
        scheduledAt: now.subtract(const Duration(minutes: 1)),
      );

      expect(controller.pendingFocusPresets, hasLength(2));
      await controller.confirmScheduledFocus(first);

      expect(controller.pendingFocusPresets, isEmpty);
      final events = controller.protocolEvents.where(
        (event) => event.data['recordType'] == 'focusScheduleEvent',
      );
      expect(
        events.firstWhere((event) => event.parentId == first.id).data['action'],
        'start_confirmed',
      );
      expect(
        events
            .firstWhere((event) => event.parentId == second.id)
            .data['action'],
        'conflict_not_selected',
      );
      expect(controller.recordsOf(RecordKind.focusSession), isEmpty);
    },
  );
}
