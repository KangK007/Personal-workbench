import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
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
    await tester.tap(find.text('项目甲'));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(selection, isNull);
    expect(relationFocus.hasFocus, isTrue);

    await tester.tap(find.text('关联'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('项目甲'));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(selection?.projectIds, contains(project.id));
    expect(relationFocus.hasFocus, isTrue);
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

  testWidgets('task row keeps all metadata visible in a narrow column', (
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

    final schedule = find.textContaining('安排 12月1日');
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
      final projectScroll = find
          .descendant(
            of: find.byType(ProjectsPage),
            matching: find.byType(Scrollable),
          )
          .first;
      final groupsTile = find.widgetWithText(ExpansionTile, '任务群');
      await tester.scrollUntilVisible(
        groupsTile,
        180,
        scrollable: projectScroll,
      );
      await tester.tap(groupsTile);
      await tester.pumpAndSettle();
      expect(find.textContaining('根据成员推断'), findsOneWidget);
      final groupTile = find.byKey(PageStorageKey('project-group-${group.id}'));
      await tester.scrollUntilVisible(
        find.text('旧任务群'),
        120,
        scrollable: projectScroll,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('旧任务群'));
      await tester.pumpAndSettle();
      expect(groupTile, findsOneWidget);
      await tester.tap(find.text('旧任务群'));
      await tester.pumpAndSettle();
      expect(find.text('项目成员'), findsOneWidget);
      expect(find.textContaining('并行执行'), findsOneWidget);
      final tasksTile = find.widgetWithText(ExpansionTile, '任务');
      await tester.scrollUntilVisible(
        tasksTile,
        -180,
        scrollable: projectScroll,
      );
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
    final reviewsTile = find.widgetWithText(ExpansionTile, '回顾');
    final scrollable = find
        .descendant(
          of: find.byType(ProjectsPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(reviewsTile, 180, scrollable: scrollable);
    await tester.tap(reviewsTile);
    await tester.pump();
    final reviewRow = find.widgetWithText(ListTile, review.title);
    await tester.scrollUntilVisible(reviewRow, 200, scrollable: scrollable);
    await tester.pumpAndSettle();
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

  testWidgets('time ruler follows the natural day and injected clock', (
    tester,
  ) async {
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
    expect(tester.getTopLeft(marker).dx, greaterThan(previousX));
  });

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
      await tester.pump();
      expect(
        find.byKey(ValueKey('habit-day:${habit.id}:${entry.$2}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('habit-day:${habit.id}:${entry.$2 + 1}')),
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
