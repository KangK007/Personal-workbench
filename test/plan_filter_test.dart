import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:personal_workbench/ui/pages/plan_page.dart';
import 'package:personal_workbench/ui/widgets/batch_task_toolbar.dart';
import 'package:personal_workbench/ui/widgets/task_row.dart';

final _now = DateTime(2026, 8, 9, 12);

class _MemoryDatabase extends AppDatabase {
  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {}

  @override
  Future<void> close() async {}
}

WorkspaceRecord _task(
  String id,
  String title, {
  required String status,
  DateTime? scheduledFor,
  DateTime? dueAt,
  required DateTime updatedAt,
  int priority = 0,
}) => WorkspaceRecord(
  id: id,
  kind: RecordKind.task,
  title: title,
  status: status,
  scheduledFor: scheduledFor,
  dueAt: dueAt,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: updatedAt,
  data: {'recordType': 'taskInstance', 'priority': priority},
);

Future<WorkbenchController> _controller() async {
  final controller = WorkbenchController(
    database: _MemoryDatabase(),
    backupService: BackupService(),
    searchService: SearchService(),
    focusService: FocusService(),
    notificationService: NotificationService(),
    shareCaptureService: ShareCaptureService(),
    syncService: SupabaseSyncService(null),
    now: () => _now,
  );
  for (final task in [
    _task(
      'today',
      '今天待办',
      status: WorkStatus.todo,
      scheduledFor: DateTime(2026, 8, 9, 9),
      dueAt: DateTime(2026, 8, 9, 18),
      updatedAt: DateTime(2026, 8, 1),
    ),
    _task(
      'tomorrow',
      '未来进行中',
      status: WorkStatus.doing,
      scheduledFor: DateTime(2026, 8, 10, 9),
      dueAt: DateTime(2026, 8, 10, 18),
      updatedAt: DateTime(2026, 8, 8),
      priority: 3,
    ),
    _task(
      'done',
      '已完成历史',
      status: WorkStatus.done,
      scheduledFor: DateTime(2026, 8, 8, 9),
      dueAt: DateTime(2026, 8, 8, 18),
      updatedAt: DateTime(2026, 8, 9, 11),
    ),
    _task(
      'unscheduled',
      '未安排待办',
      status: WorkStatus.todo,
      dueAt: DateTime(2026, 8, 20),
      updatedAt: DateTime(2026, 8, 4),
    ),
    _task(
      'overdue',
      '已逾期待办',
      status: WorkStatus.todo,
      scheduledFor: DateTime(2026, 8, 7, 9),
      dueAt: DateTime(2026, 8, 8, 18),
      updatedAt: DateTime(2026, 8, 2),
    ),
    _task(
      'due-today',
      '今天到期',
      status: WorkStatus.todo,
      scheduledFor: DateTime(2026, 8, 8, 9),
      dueAt: DateTime(2026, 8, 9, 17),
      updatedAt: DateTime(2026, 8, 3),
    ),
  ]) {
    await controller.addRecord(task);
  }
  return controller;
}

Widget _host(
  WorkbenchController controller, {
  TextScaler? textScaler,
}) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: textScaler == null ? media : media.copyWith(textScaler: textScaler),
      child: child!,
    );
  },
  home: Scaffold(
    body: PlanPage(controller: controller, showHeader: false, showTabs: false),
  ),
);

Future<void> _choose(WidgetTester tester, String key, String label) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop filters status and dates, resets empty result, sorts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('匹配 6 / 6 项'), findsOneWidget);

    await _choose(tester, 'task-filter-status', '已完成');
    expect(find.text('匹配 1 / 6 项'), findsOneWidget);
    expect(tester.widget<TaskRow>(find.byType(TaskRow)).task.title, '已完成历史');

    await _choose(tester, 'task-filter-date', '今天');
    expect(find.text('没有符合条件的任务'), findsOneWidget);
    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();
    expect(find.text('匹配 6 / 6 项'), findsOneWidget);

    await _choose(tester, 'task-filter-date', '今天');
    expect(find.text('匹配 2 / 6 项'), findsOneWidget);
    expect(
      tester
          .widgetList<TaskRow>(find.byType(TaskRow))
          .map((row) => row.task.title),
      containsAll(['今天待办', '今天到期']),
    );
    await _choose(tester, 'task-filter-date', '未来七天');
    expect(find.text('匹配 3 / 6 项'), findsOneWidget);
    await _choose(tester, 'task-filter-date', '已逾期');
    expect(find.text('匹配 1 / 6 项'), findsOneWidget);
    expect(tester.widget<TaskRow>(find.byType(TaskRow)).task.title, '已逾期待办');
    await _choose(tester, 'task-filter-date', '未安排');
    expect(tester.widget<TaskRow>(find.byType(TaskRow)).task.title, '未安排待办');

    await tester.tap(find.text('重置筛选与排序'));
    await tester.pumpAndSettle();
    await _choose(tester, 'task-filter-order', '最近更新');
    expect(
      tester.widget<TaskRow>(find.byType(TaskRow).first).task.title,
      '已完成历史',
    );
    await _choose(tester, 'task-filter-order', '优先级');
    expect(
      tester.widget<TaskRow>(find.byType(TaskRow).first).task.title,
      '未来进行中',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile filter panel collapses and selection remains available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('task-filter-status')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('task-filter-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-filter-status')), findsOneWidget);

    await _choose(tester, 'task-filter-status', '进行中');
    expect(find.text('匹配 1 / 6 项'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('task-filter-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-filter-status')), findsNothing);
    expect(find.text('筛选 1'), findsOneWidget);
    expect(tester.widget<TaskRow>(find.byType(TaskRow)).task.title, '未来进行中');

    await tester.tap(find.text('选择'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BatchTaskToolbar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded filters remain scrollable at 320 with 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(controller, textScaler: const TextScaler.linear(2)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final toggle = find.byKey(const ValueKey('task-filter-toggle'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-filter-status')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
