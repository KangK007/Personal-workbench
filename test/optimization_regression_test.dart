import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/core/models/attachment.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/backup_service.dart';
import 'package:personal_workbench/services/focus_service.dart';
import 'package:personal_workbench/services/notification_service.dart';
import 'package:personal_workbench/services/search_service.dart';
import 'package:personal_workbench/services/share_capture_service.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';
import 'package:personal_workbench/ui/widgets/task_group_editor_dialog.dart';
import 'package:personal_workbench/ui/widgets/task_hierarchy.dart';
import 'package:personal_workbench/ui/widgets/relation_picker_dialog.dart';
import 'package:personal_workbench/ui/widgets/markdown_editor_dialog.dart';
import 'package:personal_workbench/ui/widgets/common.dart';
import 'package:personal_workbench/ui/pages/review_page.dart';
import 'package:personal_workbench/ui/pages/habits_page.dart';
import 'package:personal_workbench/ui/pages/growth_page.dart';
import 'package:personal_workbench/ui/pages/projects_page.dart';
import 'package:personal_workbench/ui/pages/plan_page.dart';
import 'package:personal_workbench/ui/pages/today_page.dart';
import 'package:personal_workbench/ui/widgets/task_row.dart';

class _MemoryDatabase extends AppDatabase {
  final Map<String, WorkspaceRecord> records = {};
  int saveCount = 0;
  Completer<void>? saveGate;
  bool failNextBatch = false;

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    saveCount++;
    final gate = saveGate;
    if (gate != null) await gate.future;
    records['${record.kind.name}:${record.id}'] = record;
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
      await saveRecord(record, markDirty: markDirty);
    }
  }

  @override
  Future<List<Attachment>> loadAttachments({String? ownerRecordId}) async =>
      const [];

  @override
  Future<void> close() async {}
}

WorkbenchController _controller(_MemoryDatabase database, DateTime now) =>
    _controllerWithClock(database, () => now);

WorkbenchController _controllerWithClock(
  _MemoryDatabase database,
  DateTime Function() now,
) => WorkbenchController(
  database: database,
  backupService: BackupService(),
  searchService: SearchService(),
  focusService: FocusService(),
  notificationService: NotificationService(),
  shareCaptureService: ShareCaptureService(),
  syncService: SupabaseSyncService(null),
  now: now,
);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('zh_CN'));

  test(
    'task hierarchy supports nesting, filtering, missing parents and cycles',
    () {
      final root = WorkspaceRecord.create(kind: RecordKind.task, title: '根');
      final child = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '子',
        parentId: root.id,
      );
      final grandchild = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '孙',
        parentId: child.id,
      );
      final nested = buildTaskHierarchy(
        visibleTasks: [root, child, grandchild],
        allRecords: [root, child, grandchild],
      );
      expect(nested.map((entry) => entry.task.title), ['根', '子', '孙']);
      expect(nested.map((entry) => entry.depth), [0, 1, 2]);
      expect(taskRelationInfo(grandchild, [root, child, grandchild]).path, [
        '根',
        '子',
      ]);

      final filtered = buildTaskHierarchy(
        visibleTasks: [child],
        allRecords: [root, child],
      );
      expect(filtered.single.depth, 0);
      expect(filtered.single.relation.state, TaskRelationState.parentFiltered);

      final missing = child.copyWith(parentId: 'missing');
      expect(
        taskRelationInfo(missing, [missing]).state,
        TaskRelationState.missing,
      );

      final cycleA = root.copyWith(parentId: child.id);
      final cycleB = child.copyWith(parentId: cycleA.id);
      final cycle = buildTaskHierarchy(
        visibleTasks: [cycleA, cycleB],
        allRecords: [cycleA, cycleB],
      );
      expect(
        cycle.map((entry) => entry.relation.state),
        everyElement(TaskRelationState.cycle),
      );

      final collapsedRoot = buildTaskHierarchy(
        visibleTasks: [root, child, grandchild],
        allRecords: [root, child, grandchild],
        collapsedIds: {root.id},
      );
      expect(collapsedRoot.map((entry) => entry.task.title), ['根']);

      final collapsedChild = buildTaskHierarchy(
        visibleTasks: [root, child, grandchild],
        allRecords: [root, child, grandchild],
        collapsedIds: {child.id},
      );
      expect(collapsedChild.map((entry) => entry.task.title), ['根', '子']);
    },
  );

  test('task hierarchy bounds depth and keeps a drill path', () {
    final tasks = <WorkspaceRecord>[];
    for (var depth = 0; depth < 7; depth++) {
      tasks.add(
        WorkspaceRecord.create(
          kind: RecordKind.task,
          title: '层级 $depth',
          parentId: tasks.lastOrNull?.id,
        ),
      );
    }
    final first = buildTaskHierarchy(
      visibleTasks: tasks,
      allRecords: tasks,
      maxDepth: 2,
    );
    expect(first.map((entry) => entry.task.title), ['层级 0', '层级 1', '层级 2']);
    expect(first.last.canDrill, isTrue);
    final drilled = buildTaskHierarchy(
      visibleTasks: tasks,
      allRecords: tasks,
      maxDepth: 2,
      rootTaskId: tasks[2].id,
    );
    expect(drilled.map((entry) => entry.depth), [0, 1, 2]);
    expect(drilled.map((entry) => entry.task.title), ['层级 2', '层级 3', '层级 4']);
    expect(taskHierarchyPath(tasks[4].id, tasks).map((task) => task.title), [
      '层级 0',
      '层级 1',
      '层级 2',
      '层级 3',
      '层级 4',
    ]);
  });

  testWidgets(
    'plan and project groups drill deep trees and return at 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _controller(_MemoryDatabase(), DateTime(2026, 8, 10));
      addTearDown(controller.dispose);
      final project = WorkspaceRecord.create(
        kind: RecordKind.project,
        title: '深层项目',
      );
      await controller.addRecord(project);
      final group = await controller.createTaskGroup(
        title: '深层任务群',
        sequential: false,
        projectId: project.id,
      );
      final tasks = <WorkspaceRecord>[];
      for (var depth = 0; depth < 7; depth++) {
        final task = WorkspaceRecord.create(
          kind: RecordKind.task,
          title: '层级 $depth',
          parentId: tasks.lastOrNull?.id,
          projectId: project.id,
        );
        tasks.add(task);
        await controller.addRecord(task);
        await controller.addTaskToGroup(task: task, group: group);
      }
      for (final inProject in [false, true]) {
        for (final reducedMotion in [false, true]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          final page = inProject
              ? ProjectsPage(
                  controller: controller,
                  selectedProjectId: project.id,
                  initialTab: ProjectDetailTab.groups,
                  showHeader: false,
                  showTabs: false,
                )
              : PlanPage(
                  controller: controller,
                  initialTab: PlanTab.groups,
                  showHeader: false,
                  showTabs: false,
                );
          await tester.pumpWidget(
            _host(
              Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    disableAnimations: reducedMotion,
                  ),
                  child: page,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('深层任务群'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('深层任务群'));
          await tester.pumpAndSettle();
          expect(find.widgetWithText(ListTile, '层级 6'), findsNothing);
          for (var drill = 0; drill < 2; drill++) {
            await tester.ensureVisible(find.byTooltip('进入子层'));
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('进入子层'));
            await tester.pumpAndSettle();
          }
          expect(find.widgetWithText(ListTile, '层级 6'), findsOneWidget);
          await tester.ensureVisible(find.byTooltip('返回上一层'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('返回上一层'));
          await tester.pumpAndSettle();
          expect(find.widgetWithText(ListTile, '层级 6'), findsNothing);
          if (find.text('全部层级').evaluate().isEmpty) {
            await tester.tap(find.byTooltip('选择上级层级'));
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(find.text('全部层级'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('全部层级'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('返回上一层'), findsNothing);
          expect(find.widgetWithText(ListTile, '层级 0'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  final memberMotionVariant = ValueVariant<bool>({false, true});
  testWidgets('adding a deep group member reveals and focuses its row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(_MemoryDatabase(), DateTime(2026, 8, 10));
    addTearDown(controller.dispose);
    final group = await controller.createTaskGroup(
      title: '新增成员任务群',
      sequential: false,
    );
    final tasks = <WorkspaceRecord>[];
    for (var depth = 0; depth < 5; depth++) {
      final task = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '已有层级 $depth',
        parentId: tasks.lastOrNull?.id,
      );
      tasks.add(task);
      await controller.addRecord(task);
      await controller.addTaskToGroup(task: task, group: group);
    }
    final added = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '新增深层成员',
      parentId: tasks.last.id,
    );
    for (var index = 0; index < 80; index++) {
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.task,
          title: '候选成员 $index',
          scheduledFor: DateTime(2026, 8, 10, 8, index),
        ),
      );
    }
    await controller.addRecord(added);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: memberMotionVariant.currentValue!,
            ),
            child: PlanPage(
              controller: controller,
              initialTab: PlanTab.groups,
              showHeader: false,
              showTabs: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('任务群操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('任务群操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加任务'));
    await tester.pumpAndSettle();
    expect(find.text('新增深层成员'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('新增深层成员'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Scrollable),
          )
          .last,
      maxScrolls: 60,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增深层成员'));
    await tester.pumpAndSettle();
    expect(
      controller.groupMembers(group.id).map((task) => task.id),
      contains(added.id),
    );
    final row = find.widgetWithText(ListTile, '新增深层成员');
    expect(row, findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'TaskGroupMember.${added.id}',
    );
    final rect = tester.getRect(row);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(568));
    expect(find.byTooltip('返回上一层'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: memberMotionVariant);

  final groupMoveMotionVariant = ValueVariant<bool>({false, true});
  testWidgets('project group menu move can retry and undo at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = _MemoryDatabase();
    final controller = _controller(database, DateTime(2026, 8, 10));
    addTearDown(controller.dispose);
    final project = WorkspaceRecord.create(
      kind: RecordKind.project,
      title: '跨组项目',
    );
    await controller.addRecord(project);
    final source = await controller.createTaskGroup(
      title: '来源任务群',
      sequential: false,
      projectId: project.id,
    );
    final target = await controller.createTaskGroup(
      title: '目标任务群',
      sequential: false,
      projectId: project.id,
    );
    final task = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '移动成员',
      projectId: project.id,
    );
    await controller.addRecord(task);
    await controller.addTaskToGroup(task: task, group: source);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: groupMoveMotionVariant.currentValue!,
            ),
            child: ProjectsPage(
              controller: controller,
              selectedProjectId: project.id,
              initialTab: ProjectDetailTab.groups,
              showHeader: false,
              showTabs: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('来源任务群'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('来源任务群'));
    await tester.pumpAndSettle();
    final row = find.widgetWithText(ListTile, '移动成员');
    final menu = find.descendant(
      of: row,
      matching: find.byType(PopupMenuButton<String>),
    );
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移到其他任务群'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RadioListTile<String>, '目标任务群'));
    await tester.pump();
    database.failNextBatch = true;
    await tester.tap(find.text('移动'));
    await tester.pumpAndSettle();
    expect(find.text('移动失败，请重试。'), findsOneWidget);
    expect(controller.groupMembers(source.id).single.id, task.id);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(controller.groupMembers(target.id).single.id, task.id);
    final movedRow = find.widgetWithText(ListTile, '移动成员');
    expect(tester.getRect(movedRow).bottom, lessThanOrEqualTo(568));
    expect(
      tester.getRect(movedRow).bottom,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(SnackBar)).dy),
    );
    final card = find
        .descendant(
          of: find.byKey(ValueKey('project-group-card-${target.id}')),
          matching: find.byType(Card),
        )
        .first;
    expect(
      (tester.widget<Card>(card).shape as RoundedRectangleBorder).side.width,
      2,
    );
    database.failNextBatch = true;
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(find.text('撤销失败，请重试。'), findsOneWidget);
    expect(controller.groupMembers(target.id).single.id, task.id);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(controller.groupMembers(source.id).single.id, task.id);
    expect(controller.groupMembers(target.id), isEmpty);
    expect(tester.takeException(), isNull);
  }, variant: groupMoveMotionVariant);

  testWidgets('desktop group drag highlights the target and supports undo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(_MemoryDatabase(), DateTime(2026, 8, 10));
    addTearDown(controller.dispose);
    final project = WorkspaceRecord.create(
      kind: RecordKind.project,
      title: '拖放项目',
    );
    await controller.addRecord(project);
    final source = await controller.createTaskGroup(
      title: '拖放来源',
      sequential: false,
      projectId: project.id,
    );
    final target = await controller.createTaskGroup(
      title: '拖放目标',
      sequential: false,
      projectId: project.id,
    );
    final task = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '可拖放成员',
      projectId: project.id,
    );
    await controller.addRecord(task);
    await controller.addTaskToGroup(task: task, group: source);
    await tester.pumpWidget(
      _host(
        ProjectsPage(
          controller: controller,
          selectedProjectId: project.id,
          initialTab: ProjectDetailTab.groups,
          showHeader: false,
          showTabs: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('拖放来源'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('拖放来源'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('拖放目标'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byTooltip('拖动到其他任务群')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.text('拖放目标')));
    await tester.pump();
    expect(find.byIcon(Icons.move_to_inbox_outlined), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.groupMembers(target.id).single.id, task.id);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(controller.groupMembers(source.id).single.id, task.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('task group dialog owns controllers and rejects empty title', (
    tester,
  ) async {
    final database = _MemoryDatabase();
    final controller = _controller(database, DateTime(2026, 8, 10, 10));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showTaskGroupEditor(context: context, controller: controller),
            child: const Text('打开'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请填写任务群名称。'), findsOneWidget);
    expect(find.text('新建任务群'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('新建任务群'), findsNothing);
  });

  testWidgets(
    'task group dialog prevents duplicate save while database is pending',
    (tester) async {
      final database = _MemoryDatabase()..saveGate = Completer<void>();
      final controller = _controller(database, DateTime(2026, 8, 10, 10));
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showTaskGroupEditor(context: context, controller: controller),
              child: const Text('打开'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '唯一任务群');
      await tester.tap(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(database.saveCount, 1);
      database.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('新建任务群'), findsNothing);
    },
  );

  test(
    'period review rejects a future period and habit uses logical day',
    () async {
      final database = _MemoryDatabase();
      final now = DateTime(2026, 8, 10, 3, 59);
      final controller = _controller(database, now);
      addTearDown(controller.dispose);
      await expectLater(
        controller.savePeriodReview(
          type: ReviewPeriodType.daily,
          periodKey: '2026-08-10',
          periodStart: DateTime(2026, 8, 10),
          periodEnd: DateTime(2026, 8, 11),
          body: 'future',
        ),
        throwsFormatException,
      );
      expect(controller.growthService.logicalDay(now), DateTime(2026, 8, 9));
    },
  );

  test('habit check-in switches logical day exactly at 04:00', () async {
    var now = DateTime(2026, 8, 10, 3, 59);
    final database = _MemoryDatabase();
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
    final habit = WorkspaceRecord.create(kind: RecordKind.habit, title: '边界习惯');
    await controller.addRecord(habit);
    await controller.setHabitTodayStatus(habit, WorkStatus.done);
    expect(
      controller.habitLogForDay(habit.id, DateTime(2026, 8, 9))?.status,
      WorkStatus.done,
    );
    now = DateTime(2026, 8, 10, 4);
    await controller.setHabitTodayStatus(habit, WorkStatus.done);
    expect(
      controller.habitLogForDay(habit.id, DateTime(2026, 8, 10))?.status,
      WorkStatus.done,
    );
  });

  testWidgets('relation picker applies only on complete and restores focus', (
    tester,
  ) async {
    final database = _MemoryDatabase();
    final controller = _controller(database, DateTime(2026, 8, 10, 10));
    addTearDown(controller.dispose);
    final project = WorkspaceRecord.create(
      kind: RecordKind.project,
      title: '项目甲',
    );
    await controller.addRecord(project);
    final relationFocus = FocusNode(debugLabel: 'test.relations');
    addTearDown(relationFocus.dispose);
    RelationSelection? selection;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            focusNode: relationFocus,
            onPressed: () async {
              selection = await showRelationPickerDialog(
                context: context,
                controller: controller,
                initialTaskIds: const [],
                initialProjectIds: const [],
                returnFocusNode: relationFocus,
              );
            },
            child: const Text('关联'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('关联'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, '项目 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('项目甲'));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(selection, isNull);
    expect(relationFocus.hasFocus, isTrue);

    await tester.tap(find.text('关联'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '项目 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('项目甲'));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(selection?.projectIds, contains(project.id));
    expect(relationFocus.hasFocus, isTrue);
  });

  testWidgets('relation picker searches beyond its first page at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(_MemoryDatabase(), DateTime(2026, 8, 10));
    addTearDown(controller.dispose);
    for (var index = 1; index <= 100; index++) {
      await controller.addRecord(
        WorkspaceRecord.create(kind: RecordKind.task, title: '任务 $index'),
      );
    }
    final project = WorkspaceRecord.create(
      kind: RecordKind.project,
      title: '小窗口项目',
    );
    await controller.addRecord(project);
    final goal = WorkspaceRecord.create(kind: RecordKind.goal, title: '关联目标');
    final note = WorkspaceRecord.create(kind: RecordKind.note, title: '关联笔记');
    await controller.addRecord(goal);
    await controller.addRecord(note);
    RelationSelection? selection;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selection = await showRelationPickerDialog(
                  context: context,
                  controller: controller,
                  initialTaskIds: const [],
                  initialProjectIds: const [],
                );
              },
              child: const Text('关联'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('关联'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CheckboxListTile).evaluate().length, lessThan(40));

    await tester.enterText(find.byType(TextField), '任务 99');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.widgetWithText(CheckboxListTile, '任务 99'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(CheckboxListTile, '任务 99'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CheckboxListTile, '任务 99'));
    await tester.pump();
    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '项目 1'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '项目 1'));
    await tester.pump();
    await tester.tap(find.text('小窗口项目'));
    await tester.pump();
    for (final entry in [('目标 1', '关联目标'), ('笔记 1', '关联笔记')]) {
      final chip = find.widgetWithText(ChoiceChip, entry.$1);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, entry.$2));
      await tester.pump();
    }
    expect(find.text('已选 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(selection?.taskIds.length, 1);
    expect(selection?.projectIds, contains(project.id));
    expect(selection?.goalIds, contains(goal.id));
    expect(selection?.noteIds, contains(note.id));
  });

  testWidgets(
    'markdown goal and note relations survive save and draft protection',
    (tester) async {
      final controller = _controller(_MemoryDatabase(), DateTime(2026, 8, 10));
      addTearDown(controller.dispose);
      final goal = WorkspaceRecord.create(kind: RecordKind.goal, title: '论文目标');
      final linkedNote = WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '相关研究笔记',
      );
      final note = WorkspaceRecord.create(kind: RecordKind.note, title: '当前笔记');
      final review = WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '回顾不能混入',
        data: const {'recordType': 'periodReview'},
      );
      for (final record in [goal, linkedNote, note, review]) {
        await controller.addRecord(record);
      }
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showMarkdownNoteEditor(
                context,
                controller,
                note: controller.notes.firstWhere(
                  (record) => record.id == note.id,
                ),
              ),
              child: const Text('编辑关系'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('编辑关系'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关联记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '目标 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, '论文目标'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, '笔记 1'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(CheckboxListTile, '当前笔记'), findsNothing);
      expect(find.widgetWithText(CheckboxListTile, '回顾不能混入'), findsNothing);
      await tester.tap(find.widgetWithText(CheckboxListTile, '相关研究笔记'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('保存修改？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final saved = controller.notes.firstWhere(
        (record) => record.id == note.id,
      );
      expect(saved.data['relatedGoalIds'], [goal.id]);
      expect(saved.data['relatedNoteIds'], [linkedNote.id]);
      await tester.tap(find.text('编辑关系'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关联记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '笔记 1'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, '相关研究笔记'),
            )
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('review saves goal and note relations from the shared picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(
      _MemoryDatabase(),
      DateTime(2026, 8, 10, 10),
    );
    addTearDown(controller.dispose);
    final goal = WorkspaceRecord.create(kind: RecordKind.goal, title: '回顾目标');
    final note = WorkspaceRecord.create(kind: RecordKind.note, title: '回顾关联笔记');
    await controller.addRecord(goal);
    await controller.addRecord(note);
    await tester.pumpWidget(_host(ReviewPage(controller: controller)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('关联记录'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关联记录'));
    await tester.pumpAndSettle();
    for (final entry in [('目标 1', '回顾目标'), ('笔记 1', '回顾关联笔记')]) {
      final chip = find.widgetWithText(ChoiceChip, entry.$1);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, entry.$2));
      await tester.pump();
    }
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('保存日回顾'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存日回顾'));
    await tester.pumpAndSettle();
    final review = controller.notes.singleWhere(
      (record) => record.data['recordType'] == 'periodReview',
    );
    expect(review.data['relatedGoalIds'], [goal.id]);
    expect(review.data['relatedNoteIds'], [note.id]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review library opens a preview before current-period editing', (
    tester,
  ) async {
    final database = _MemoryDatabase();
    final controller = _controller(database, DateTime(2026, 8, 10, 10));
    addTearDown(controller.dispose);
    final review = await controller.savePeriodReview(
      type: ReviewPeriodType.daily,
      periodKey: '2026-08-10',
      periodStart: DateTime(2026, 8, 10),
      periodEnd: DateTime(2026, 8, 11),
      title: '今日回顾',
      body: '正文预览',
    );
    await tester.pumpWidget(_host(ReviewPage(controller: controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('回顾库'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(review.title));
    // Markdown preview can keep a ticker alive during its first layout.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('回顾预览'), findsOneWidget);
    expect(find.text('正文预览'), findsOneWidget);
    expect(find.text('编辑本期'), findsOneWidget);
  });

  testWidgets('review facts keep symmetric metric insets on compact widths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(_MemoryDatabase(), DateTime(2026, 10, 4));
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(ReviewPage(controller: controller)));
    await tester.pump();

    final surfaceFinder = find.byType(LogSurface).first;
    final surface = tester.renderObject<RenderBox>(surfaceFinder);
    final metrics = find.descendant(
      of: surfaceFinder,
      matching: find.byType(ListTile),
    );
    expect(metrics, findsNWidgets(5));
    final first = tester.renderObject<RenderBox>(metrics.at(0));
    final second = tester.renderObject<RenderBox>(metrics.at(1));
    final surfaceLeft = surface.localToGlobal(Offset.zero).dx;
    final surfaceRight = surfaceLeft + surface.size.width;
    final leftInset = first.localToGlobal(Offset.zero).dx - surfaceLeft;
    final rightInset =
        surfaceRight - second.localToGlobal(Offset.zero).dx - second.size.width;

    expect(surface.size.width, closeTo(320, 1));
    expect(leftInset, closeTo(rightInset, 1));
  });

  testWidgets('failed RSIP check-in is visibly locked', (tester) async {
    final database = _MemoryDatabase();
    final controller = _controller(database, DateTime(2026, 8, 10, 10));
    addTearDown(controller.dispose);
    final habit = WorkspaceRecord.create(
      kind: RecordKind.habit,
      title: '失败节点',
      data: {
        'protocol': 'rsip',
        'rsipActive': true,
        'rsipMinimumAction': '记录一次',
      },
    );
    await controller.addRecord(habit);
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.habitLog,
        title: habit.title,
        parentId: habit.id,
        scheduledFor: DateTime(2026, 8, 10),
        status: WorkStatus.failed,
      ),
    );
    await tester.pumpWidget(_host(HabitsPage(controller: controller)));
    await tester.pump();
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '已失败'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('task row expands full metadata in a narrow column', (
    tester,
  ) async {
    final controller = _controller(
      _MemoryDatabase(),
      DateTime(2026, 8, 10, 10),
    );
    addTearDown(controller.dispose);
    final task = WorkspaceRecord.create(kind: RecordKind.task, title: '元数据任务');
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 320,
          child: TaskRow(task: task, controller: controller, dense: true),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('未安排时间'), findsOneWidget);
    expect(find.text('优先级 普通'), findsNothing);
    await tester.tap(find.byTooltip('展开任务详情'));
    await tester.pumpAndSettle();
    expect(find.textContaining('安排 未安排'), findsOneWidget);
    expect(find.textContaining('截止 无截止'), findsOneWidget);
    expect(find.text('状态 待办'), findsOneWidget);
    expect(find.text('优先级 普通'), findsOneWidget);
    expect(find.text('循环 不循环'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('task row keeps schedule metadata on one line at desktop width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _controller(
      _MemoryDatabase(),
      DateTime(2026, 8, 10, 10),
    );
    addTearDown(controller.dispose);
    final task = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '桌面详情任务',
      scheduledFor: DateTime(2026, 12, 1),
      dueAt: DateTime(2026, 12, 2),
    );
    await tester.pumpWidget(_host(TaskRow(task: task, controller: controller)));
    await tester.pump();
    await tester.tap(find.byTooltip('展开任务详情'));
    await tester.pumpAndSettle();

    final schedule = find.text('安排 12月1日 → 截止 12月2日');
    expect(schedule, findsOneWidget);
    expect(tester.getSize(schedule).height, lessThan(24));
    final metadataTop = tester.getTopLeft(schedule).dy;
    for (final label in const ['状态 待办', '优先级 普通', '循环 不循环']) {
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      expect(tester.getSize(finder).height, lessThan(24));
      expect(tester.getTopLeft(finder).dy, closeTo(metadataTop, 1));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed parent hides children and aligns branch marker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _controller(
      _MemoryDatabase(),
      DateTime(2026, 8, 10, 10),
    );
    addTearDown(controller.dispose);
    final parent = WorkspaceRecord.create(kind: RecordKind.task, title: '父任务');
    final child = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '子任务',
      parentId: parent.id,
    );
    await controller.addRecord(parent);
    await controller.addRecord(child);

    await tester.pumpWidget(
      _host(
        PlanPage(controller: controller, showHeader: false, showTabs: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('子任务'), findsOneWidget);
    final branchMarker = find.byWidgetPredicate(
      (widget) =>
          widget is Icon &&
          widget.icon == Icons.subdirectory_arrow_right &&
          widget.size == 18,
    );
    expect(branchMarker, findsOneWidget);
    expect(
      tester.getCenter(branchMarker).dx,
      closeTo(tester.getCenter(find.byType(Checkbox).first).dx, 1),
    );

    await tester.tap(find.byTooltip('收起子任务'));
    await tester.pumpAndSettle();

    expect(find.text('子任务'), findsNothing);
    expect(branchMarker, findsNothing);
    expect(find.byTooltip('展开子任务'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'task group primary project persists without changing members',
    () async {
      final controller = _controller(
        _MemoryDatabase(),
        DateTime(2026, 8, 10, 10),
      );
      addTearDown(controller.dispose);
      final project = WorkspaceRecord.create(
        kind: RecordKind.project,
        title: '主项目',
      );
      await controller.addRecord(project);
      final task = WorkspaceRecord.create(kind: RecordKind.task, title: '群成员');
      await controller.addRecord(task);
      final group = await controller.createTaskGroup(
        title: '带主项目任务群',
        sequential: false,
        projectId: project.id,
      );
      await controller.addTaskToGroup(task: task, group: group);
      final cleared = await controller.updateTaskGroup(
        group: group,
        title: group.title,
        sequential: false,
        timeLimitMinutes: null,
        projectId: null,
      );
      expect(cleared.projectId, isNull);
      expect(controller.groupMembers(cleared.id).map((item) => item.id), [
        task.id,
      ]);
    },
  );

  testWidgets(
    'project overview shows legacy group inference and single-open panels',
    (tester) async {
      final controller = _controller(
        _MemoryDatabase(),
        DateTime(2026, 8, 10, 10),
      );
      addTearDown(controller.dispose);
      final project = WorkspaceRecord.create(
        kind: RecordKind.project,
        title: '项目概览',
      );
      await controller.addRecord(project);
      final task = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '项目成员',
        projectId: project.id,
      );
      await controller.addRecord(task);
      final group = await controller.createTaskGroup(
        title: '旧任务群',
        sequential: false,
      );
      await controller.addTaskToGroup(
        task: controller.tasks.first,
        group: group,
      );
      await tester.pumpWidget(
        _host(
          SizedBox(width: 1200, child: ProjectsPage(controller: controller)),
        ),
      );
      await tester.pump();
      final groupsTile = find.widgetWithText(ExpansionTile, '任务群');
      await tester.ensureVisible(groupsTile);
      await tester.pumpAndSettle();
      await tester.tap(groupsTile);
      await tester.pumpAndSettle();
      expect(find.textContaining('根据成员推断'), findsOneWidget);
      final groupTile = find.byKey(PageStorageKey('project-group-${group.id}'));
      await tester.ensureVisible(find.text('旧任务群'));
      await tester.pumpAndSettle();
      expect(groupTile, findsOneWidget);
      await tester.tap(find.text('旧任务群'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: groupTile, matching: find.text('项目成员')),
        findsOneWidget,
      );
      expect(find.textContaining('并行执行'), findsOneWidget);
      final tasksTile = find.widgetWithText(ExpansionTile, '任务');
      await tester.ensureVisible(tasksTile);
      await tester.pumpAndSettle();
      await tester.tap(tasksTile);
      await tester.pump();
      expect(find.textContaining('根据成员推断'), findsNothing);
    },
  );

  testWidgets('project review row opens its own period and record', (
    tester,
  ) async {
    final controller = _controller(
      _MemoryDatabase(),
      DateTime(2026, 8, 10, 10),
    );
    addTearDown(controller.dispose);
    final project = WorkspaceRecord.create(
      kind: RecordKind.project,
      title: '回顾关联项目',
    );
    await controller.addRecord(project);
    final review = await controller.savePeriodReview(
      type: ReviewPeriodType.weekly,
      periodKey: '2026-W33',
      periodStart: DateTime(2026, 8, 10),
      periodEnd: DateTime(2026, 8, 17),
      title: '项目周回顾',
      body: '已完成访谈整理',
      relatedProjectIds: {project.id},
    );
    WorkspaceRecord? opened;
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 1200,
          child: ProjectsPage(
            controller: controller,
            selectedProjectId: project.id,
            onOpenReview: (record) => opened = record,
          ),
        ),
      ),
    );
    await tester.pump();
    final reviewsTile = find.widgetWithText(ExpansionTile, '笔记与回顾');
    await tester.ensureVisible(reviewsTile);
    await tester.pumpAndSettle();
    await tester.tap(reviewsTile);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '回顾 1'));
    await tester.pumpAndSettle();
    final reviewRow = find.ancestor(
      of: find.text(review.title),
      matching: find.byType(Card),
    );
    await tester.ensureVisible(reviewRow);
    await tester.pumpAndSettle();
    await tester.tap(reviewRow);
    await tester.pump();
    expect(opened?.id, review.id);
    expect(review.data['periodType'], 'weekly');

    var returned = false;
    await tester.pumpWidget(
      _host(
        ReviewPage(
          controller: controller,
          initialTab: ReviewTab.weekly,
          initialPreview: opened,
          onBackToProject: () => returned = true,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('回顾预览'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('已完成访谈整理'),
      120,
      scrollable: find
          .descendant(
            of: find.byType(ReviewPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('已完成访谈整理'), findsOneWidget);
    await tester.tap(find.text('返回项目'));
    await tester.pump();
    expect(returned, isTrue);
  });

  testWidgets(
    'project detail remains reachable in a short window with 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _controller(_MemoryDatabase(), DateTime(2026, 8, 10));
      addTearDown(controller.dispose);
      final project = WorkspaceRecord.create(
        kind: RecordKind.project,
        title: '小窗口项目',
      );
      await controller.addRecord(project);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ProjectsPage(
              controller: controller,
              selectedProjectId: project.id,
              showHeader: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reviewsTile = find.widgetWithText(ExpansionTile, '笔记与回顾');
      await tester.ensureVisible(reviewsTile);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(reviewsTile);
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.bottom, lessThanOrEqualTo(568));
      await tester.tap(reviewsTile);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('review guards unsaved text before moving to another period', (
    tester,
  ) async {
    final controller = _controller(
      _MemoryDatabase(),
      DateTime(2026, 8, 10, 10),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(ReviewPage(controller: controller)));
    await tester.pump();
    final reviewScroll = find
        .descendant(
          of: find.byType(ReviewPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('标题'),
      180,
      scrollable: reviewScroll,
    );
    await tester.enterText(find.byType(TextField).first, '未保存的标题');
    await tester.scrollUntilVisible(
      find.byTooltip('上一期间'),
      -180,
      scrollable: reviewScroll,
    );
    await tester.tap(find.byTooltip('上一期间'));
    await tester.pumpAndSettle();
    expect(find.text('保存当前回顾？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('标题'),
      180,
      scrollable: reviewScroll,
    );
    expect(find.text('未保存的标题'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byTooltip('上一期间'),
      -180,
      scrollable: reviewScroll,
    );
    await tester.tap(find.byTooltip('上一期间'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃修改'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('标题'),
      180,
      scrollable: reviewScroll,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      isEmpty,
    );
  });

  testWidgets(
    'time ruler advances on minute boundaries with an injected clock',
    (tester) async {
      var now = DateTime(2026, 8, 10, 16);
      final controller = _controllerWithClock(_MemoryDatabase(), () => now);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              height: 600,
              child: TodayPage(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();
      final marker = find.byKey(const ValueKey('time-ruler-marker'));
      expect(marker, findsOneWidget);
      expect(find.bySemanticsLabel('当前时间 16:00，自然日进度 67%'), findsOneWidget);
      for (var hour = 0; hour < 24; hour++) {
        expect(find.byKey(ValueKey('time-ruler-hour-$hour')), findsOneWidget);
      }
      expect(tester.getTopLeft(marker).dx, closeTo(382, 1));

      final previousX = tester.getTopLeft(marker).dx;
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getTopLeft(marker).dx, previousX);
      now = now.add(const Duration(seconds: 59));
      await tester.pump(const Duration(seconds: 59));
      expect(tester.getTopLeft(marker).dx, greaterThan(previousX));
    },
  );

  testWidgets('time ruler resets at local midnight', (tester) async {
    var now = DateTime(2026, 8, 10, 23, 59, 59);
    final controller = _controllerWithClock(_MemoryDatabase(), () => now);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(SizedBox(width: 800, child: TodayPage(controller: controller))),
    );
    await tester.pump();
    final marker = find.byKey(const ValueKey('time-ruler-marker'));
    final endOfDayX = tester.getTopLeft(marker).dx;

    now = DateTime(2026, 8, 11);
    await tester.pump(const Duration(seconds: 1));
    expect(find.bySemanticsLabel('当前时间 00:00，自然日进度 0%'), findsOneWidget);
    expect(tester.getTopLeft(marker).dx, lessThan(endOfDayX));
  });

  testWidgets('time ruler uses compact labels on dense landscape widths', (
    tester,
  ) async {
    final controller = _controllerWithClock(
      _MemoryDatabase(),
      () => DateTime(2026, 8, 10, 16),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 914,
          height: 400,
          child: TodayPage(controller: controller),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('00'), findsOneWidget);
    expect(find.text('23'), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
    expect(find.bySemanticsLabel('00:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('today progress animates once and respects reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final now = DateTime(2026, 8, 10, 12);
    final controller = _controllerWithClock(_MemoryDatabase(), () => now);
    addTearDown(controller.dispose);
    final completed = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '已完成任务',
      status: WorkStatus.done,
      scheduledFor: now,
      data: {'settledAt': now.toIso8601String()},
    );
    final pending = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '待完成任务',
      scheduledFor: now,
    );
    await controller.addRecord(completed);
    await controller.addRecord(pending);

    Widget page() =>
        _host(TodayPage(controller: controller, showHeader: false));
    double ringProgress() =>
        (tester
                        .widget<CustomPaint>(
                          find.byKey(const ValueKey('today-progress-ring')),
                        )
                        .painter
                    as dynamic)
                .ratio
            as double;

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(ringProgress(), closeTo(0.5, 0.001));
    expect(find.bySemanticsLabel('今日任务完成进度 50%'), findsOneWidget);

    await controller.toggleTaskDone(pending);
    await tester.pumpWidget(page());
    expect(ringProgress(), closeTo(0.5, 0.001));
    expect(find.bySemanticsLabel('今日任务完成进度 100%'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 120));
    expect(ringProgress(), allOf(greaterThan(0.5), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 120));
    expect(ringProgress(), closeTo(1, 0.001));

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    await controller.toggleTaskDone(controller.latestRecordById(pending));
    await tester.pumpWidget(page());
    expect(ringProgress(), closeTo(0.5, 0.001));
    expect(find.bySemanticsLabel('今日任务完成进度 50%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('today task rows reflow in 160ms and undo restores the row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final now = DateTime(2026, 8, 10, 12);
    final controller = _controllerWithClock(_MemoryDatabase(), () => now);
    addTearDown(controller.dispose);
    final tasks = [
      for (var index = 0; index < 3; index++)
        WorkspaceRecord.create(
          kind: RecordKind.task,
          title: '位移任务 $index',
          scheduledFor: now,
        ),
    ];
    for (final task in tasks) {
      await controller.addRecord(task);
    }
    Widget page() =>
        _host(TodayPage(controller: controller, showHeader: false));
    Finder row(WorkspaceRecord task) =>
        find.byKey(ValueKey('today-task-${task.id}'));
    final list = find.byKey(const PageStorageKey('today-task-scroll-今日'));
    double rowOffset(WorkspaceRecord task) =>
        tester.getTopLeft(row(task)).dy - tester.getTopLeft(list).dy;

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.ensureVisible(row(tasks[1]));
    await tester.pumpAndSettle();
    final start = rowOffset(tasks[1]);

    await controller.toggleTaskDone(tasks[0]);
    await tester.pumpWidget(page());
    expect(rowOffset(tasks[1]), closeTo(start, 0.1));
    await tester.pump(const Duration(milliseconds: 80));
    final middle = rowOffset(tasks[1]);
    expect(middle, lessThan(start));
    await tester.pump(const Duration(milliseconds: 80));
    final settled = rowOffset(tasks[1]);
    expect(settled, lessThan(middle));
    expect(row(tasks[0]), findsNothing);

    await controller.toggleTaskDone(controller.latestRecordById(tasks[0]));
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(row(tasks[0]), findsOneWidget);
    expect(rowOffset(tasks[1]), closeTo(start, 0.1));

    await controller.toggleTaskDone(tasks[0]);
    await tester.pumpWidget(page());
    await tester.pump(const Duration(milliseconds: 80));
    final reversingFrom = rowOffset(tasks[1]);
    await controller.toggleTaskDone(controller.latestRecordById(tasks[0]));
    await tester.pumpWidget(page());
    expect(rowOffset(tasks[1]), closeTo(reversingFrom, 0.1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(rowOffset(tasks[1]), greaterThan(reversingFrom));
    await tester.pump(const Duration(milliseconds: 80));
    expect(row(tasks[0]), findsOneWidget);
    expect(rowOffset(tasks[1]), closeTo(start, 0.1));

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    await controller.toggleTaskDone(tasks[0]);
    await tester.pumpWidget(page());
    expect(rowOffset(tasks[1]), closeTo(settled, 0.1));
    await tester.pump(const Duration(milliseconds: 160));
    expect(row(tasks[0]), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('today releases a departed row outside the lazy viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 8, 10, 12);
    final controller = _controllerWithClock(_MemoryDatabase(), () => now);
    addTearDown(controller.dispose);
    final tasks = [
      for (var index = 0; index < 40; index++)
        WorkspaceRecord.create(
          kind: RecordKind.task,
          title: '长列表任务 $index',
          scheduledFor: now,
        ),
    ];
    for (final task in tasks) {
      await controller.addRecord(task);
    }
    Widget page() =>
        _host(TodayPage(controller: controller, showHeader: false));
    final list = find.byKey(const PageStorageKey('today-task-scroll-今日'));
    int childCount() =>
        tester.widget<ListView>(list).childrenDelegate.estimatedChildCount!;

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(childCount(), 40);
    expect(find.text('长列表任务 39'), findsNothing);

    await controller.toggleTaskDone(tasks.last);
    await tester.pumpWidget(page());
    expect(childCount(), 40);
    await tester.pump(const Duration(milliseconds: 200));
    expect(childCount(), 39);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'today collapses an emptied secondary section with its last row',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime(2026, 8, 10, 12);
      final controller = _controllerWithClock(_MemoryDatabase(), () => now);
      addTearDown(controller.dispose);
      final commitment = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '今日重点任务',
        scheduledFor: now,
      );
      final secondary = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '普通今日任务',
        scheduledFor: now,
      );
      await controller.addRecord(commitment);
      await controller.addRecord(secondary);
      await controller.startToday(
        commitments: [commitment],
        plannedHabits: const [],
      );
      Widget page() =>
          _host(TodayPage(controller: controller, showHeader: false));
      final section = find.byKey(const ValueKey('today-pending-section'));

      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await tester.ensureVisible(section);
      await tester.pumpAndSettle();
      final height = tester.getSize(section).height;
      expect(height, greaterThan(0));

      await controller.toggleTaskDone(secondary);
      await tester.pumpWidget(page());
      expect(tester.getSize(section).height, closeTo(height, 0.1));
      await tester.pump(const Duration(milliseconds: 80));
      final middle = tester.getSize(section).height;
      expect(middle, allOf(greaterThan(0), lessThan(height)));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getSize(section).height, closeTo(0, 0.1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('today fits five tasks schedule and focus action at 1440x900', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 8, 10, 12);
    final controller = _controllerWithClock(_MemoryDatabase(), () => now);
    addTearDown(controller.dispose);
    final tasks = [
      for (var index = 0; index < 5; index++)
        WorkspaceRecord.create(
          kind: RecordKind.task,
          title: '首屏任务 $index',
          scheduledFor: now,
        ),
    ];
    for (final task in tasks) {
      await controller.addRecord(task);
    }
    await controller.createTimeBlock(
      task: tasks[0],
      start: DateTime(2026, 8, 10, 9),
      minutes: 50,
    );
    await controller.startToday(
      commitments: tasks.take(3).toList(),
      plannedHabits: const [],
    );
    await tester.pumpWidget(
      _host(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 1223,
            child: WorkbenchViewport(
              child: TodayPage(controller: controller, onOpenFocus: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final task in tasks) {
      final title = find.text(task.title).first;
      expect(title, findsOneWidget);
      expect(tester.getRect(title).bottom, lessThanOrEqualTo(900));
    }
    final timeline = find.text('时间安排');
    expect(timeline, findsOneWidget);
    expect(tester.getRect(timeline).bottom, lessThanOrEqualTo(900));
    final block = find.text('09:00 · 50 分钟');
    expect(block, findsOneWidget);
    expect(tester.getRect(block).bottom, lessThanOrEqualTo(900));
    final summary = find.text('待办 5 · 完成 0 · 专注 0m');
    expect(summary, findsOneWidget);
    expect(tester.widget<Text>(summary).maxLines, 1);
    final focus = find.widgetWithText(FilledButton, '开始专注').last;
    expect(tester.getRect(focus).left, greaterThan(750));
    expect(tester.getRect(focus).bottom, lessThanOrEqualTo(900));

    tester.view.physicalSize = const Size(1440, 450);
    await tester.pumpAndSettle();
    expect(tester.getRect(timeline).bottom, lessThanOrEqualTo(450));
    expect(tester.getRect(focus).bottom, lessThanOrEqualTo(450));
    expect(tester.takeException(), isNull);
  });

  testWidgets('today focus action fits a short window at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 450);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controllerWithClock(
      _MemoryDatabase(),
      () => DateTime(2026, 8, 10, 12),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: WorkbenchViewport(
            child: TodayPage(controller: controller, onOpenFocus: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final focus = find.widgetWithText(FilledButton, '开始专注');
    expect(focus, findsOneWidget);
    expect(tester.getRect(focus).bottom, lessThanOrEqualTo(450));
    expect(tester.takeException(), isNull);
  });

  testWidgets('habit and growth matrices cover every day of the month', (
    tester,
  ) async {
    final cases = <(DateTime, int)>[
      (DateTime(2026, 2, 12), 28),
      (DateTime(2024, 2, 12), 29),
      (DateTime(2026, 4, 12), 30),
      (DateTime(2026, 8, 12), 31),
    ];
    for (final entry in cases) {
      final controller = _controller(_MemoryDatabase(), entry.$1);
      addTearDown(controller.dispose);
      final habit = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: '月度习惯',
      );
      await controller.addRecord(habit);

      await tester.pumpWidget(
        _host(SizedBox(width: 412, child: HabitsPage(controller: controller))),
      );
      await tester.pumpAndSettle();
      expect(find.text('近两周 · 今天可点按修改'), findsOneWidget);
      if (entry.$1.month == 2) {
        expect(
          find.byKey(ValueKey('habit-day:${habit.id}:${entry.$1.year}-1-30')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(
          ValueKey(
            'habit-day:${habit.id}:${entry.$1.year}-${entry.$1.month}-${entry.$2}',
          ),
        ),
        findsNothing,
      );
      await tester.tap(find.text('展开整月'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          ValueKey(
            'habit-day:${habit.id}:${entry.$1.year}-${entry.$1.month}-${entry.$2}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey(
            'habit-day:${habit.id}:${entry.$1.year}-${entry.$1.month}-${entry.$2 + 1}',
          ),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      expect(
        find.bySemanticsLabel(
          '月度习惯，${entry.$1.month}月${entry.$1.day - 1}日，未记录，仅展示',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          '月度习惯，${entry.$1.month}月${entry.$1.day}日，未记录，可修改',
        ),
        findsOneWidget,
      );
      if (entry.$1.day < entry.$2) {
        expect(
          find.bySemanticsLabel(
            '月度习惯，${entry.$1.month}月${entry.$1.day + 1}日，未记录，仅展示',
          ),
          findsOneWidget,
        );
      }

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 412,
            child: GrowthPage(controller: controller, now: entry.$1),
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('growth-day:${entry.$2}')),
        220,
        scrollable: find
            .descendant(
              of: find.byType(GrowthPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byKey(ValueKey('growth-day:${entry.$2}')), findsOneWidget);
      expect(find.byKey(ValueKey('growth-day:${entry.$2 + 1}')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
